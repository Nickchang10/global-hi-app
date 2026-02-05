import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('orders');

  // =====================================================
  // 讀取
  // =====================================================

  static Future<DocumentSnapshot<Map<String, dynamic>>> getOrder(
    String orderId,
  ) {
    return _col.doc(orderId).get();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchOrder(
    String orderId,
  ) {
    return _col.doc(orderId).snapshots();
  }

  // =====================================================
  // 訂單狀態流轉（核心）
  // =====================================================

  /// 合法狀態流轉表（與後台 / Cloud Function 對齊）
  static const Map<String, List<String>> _allowedTransitions = {
    'pending_payment': ['paid', 'cancelled'],
    'paid': ['shipping', 'refunded'],
    'shipping': ['completed', 'refunded'],
    'completed': [],
    'cancelled': [],
    'refunded': [],
  };

  static Future<void> updateStatus({
    required String orderId,
    required String toStatus,
    String? note,
  }) async {
    final uid = _auth.currentUser?.uid ?? 'system';

    await _db.runTransaction((tx) async {
      final ref = _col.doc(orderId);
      final snap = await tx.get(ref);

      if (!snap.exists) {
        throw Exception('訂單不存在');
      }

      final data = snap.data()!;
      final String fromStatus = data['status'] as String? ?? '';

      final allowed = _allowedTransitions[fromStatus] ?? const [];
      if (!allowed.contains(toStatus)) {
        throw Exception('非法狀態轉換：$fromStatus → $toStatus');
      }

      tx.update(ref, {
        'status': toStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'logs': FieldValue.arrayUnion([
          _buildLog(
            action: 'status_change',
            by: uid,
            note: '$fromStatus → $toStatus${note != null ? '｜$note' : ''}',
          ),
        ]),
      });
    });
  }

  // =====================================================
  // 出貨
  // =====================================================

  static Future<void> markAsShipped({
    required String orderId,
    required String carrier,
    required String trackingNo,
    String? note,
  }) async {
    final uid = _auth.currentUser?.uid ?? 'system';

    await _db.runTransaction((tx) async {
      final ref = _col.doc(orderId);
      final snap = await tx.get(ref);

      if (!snap.exists) {
        throw Exception('訂單不存在');
      }

      final data = snap.data()!;
      if (data['status'] != 'paid') {
        throw Exception('只有已付款訂單才能出貨');
      }

      tx.update(ref, {
        'status': 'shipping',
        'shipping': {
          'carrier': carrier,
          'trackingNo': trackingNo,
          'shippedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
        'logs': FieldValue.arrayUnion([
          _buildLog(
            action: 'shipping',
            by: uid,
            note: '物流：$carrier｜$trackingNo${note != null ? '｜$note' : ''}',
          ),
        ]),
      });
    });
  }

  // =====================================================
  // 退款
  // =====================================================

  static Future<void> refund({
    required String orderId,
    required num amount,
    required String reason,
  }) async {
    final uid = _auth.currentUser?.uid ?? 'system';

    await _db.runTransaction((tx) async {
      final ref = _col.doc(orderId);
      final snap = await tx.get(ref);

      if (!snap.exists) {
        throw Exception('訂單不存在');
      }

      final data = snap.data()!;
      final status = data['status'];

      if (!['paid', 'shipping'].contains(status)) {
        throw Exception('目前狀態不可退款');
      }

      tx.update(ref, {
        'status': 'refunded',
        'refund': {
          'amount': amount,
          'reason': reason,
          'status': 'completed',
          'refundedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
        'logs': FieldValue.arrayUnion([
          _buildLog(
            action: 'refund',
            by: uid,
            note: '金額：$amount｜原因：$reason',
          ),
        ]),
      });
    });
  }

  // =====================================================
  // 取消（未付款）
  // =====================================================

  static Future<void> cancel({
    required String orderId,
    required String reason,
  }) async {
    final uid = _auth.currentUser?.uid ?? 'system';

    await _db.runTransaction((tx) async {
      final ref = _col.doc(orderId);
      final snap = await tx.get(ref);

      if (!snap.exists) {
        throw Exception('訂單不存在');
      }

      final data = snap.data()!;
      if (data['status'] != 'pending_payment') {
        throw Exception('只有未付款訂單可以取消');
      }

      tx.update(ref, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
        'logs': FieldValue.arrayUnion([
          _buildLog(
            action: 'cancel',
            by: uid,
            note: reason,
          ),
        ]),
      });
    });
  }

  // =====================================================
  // 共用 Log Builder
  // =====================================================

  static Map<String, dynamic> _buildLog({
    required String action,
    required String by,
    String? note,
  }) {
    return {
      'action': action,
      'by': by,
      'note': note ?? '',
      'at': Timestamp.now(),
    };
  }
}
