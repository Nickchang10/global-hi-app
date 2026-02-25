// lib/services/order_admin_service.dart
//
// ✅ OrderAdminService（最終可編譯完整版｜已補齊 if 區塊大括號｜已修正 doc comment < > HTML 警告）
// ------------------------------------------------------------
// Admin / Vendor 後台訂單管理常用服務：
// - 訂單列表（含條件篩選、分頁）
// - 單筆讀取
// - 更新訂單狀態 / 付款狀態 / 出貨狀態
// - 設定物流資訊（tracking / carrier / shippedAt）
// - 退款標記（refund 狀態）
// - 新增/更新管理備註（adminNote）
// - 批次更新（狀態、備註、標籤）
//
// 只依賴：cloud_firestore
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';

class OrderAdminService {
  final FirebaseFirestore _db;
  final String ordersCol;

  OrderAdminService({FirebaseFirestore? db, this.ordersCol = 'orders'})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection(ordersCol);

  // ===========================================================
  // Queries
  // ===========================================================

  /// 訂單列表（可篩選 + 分頁）
  Future<QuerySnapshot<Map<String, dynamic>>> fetchOrders({
    String? vendorId,
    String? status,
    String? paymentStatus,
    String? shippingStatus,
    String? keyword,
    DateTime? from,
    DateTime? to,
    int limit = 30,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> q = _ref;

    final vid = (vendorId ?? '').trim();
    if (vid.isNotEmpty) {
      q = q.where('vendorId', isEqualTo: vid);
    }

    final st = (status ?? '').trim();
    if (st.isNotEmpty) {
      q = q.where('status', isEqualTo: st);
    }

    final ps = (paymentStatus ?? '').trim();
    if (ps.isNotEmpty) {
      q = q.where('payment.status', isEqualTo: ps);
    }

    final ss = (shippingStatus ?? '').trim();
    if (ss.isNotEmpty) {
      q = q.where('shipping.status', isEqualTo: ss);
    }

    if (from != null) {
      q = q.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(_startOfDay(from)),
      );
    }
    if (to != null) {
      q = q.where(
        'createdAt',
        isLessThanOrEqualTo: Timestamp.fromDate(_endOfDay(to)),
      );
    }

    // Firestore 限制：where + orderBy 需要對齊索引
    q = q.orderBy('createdAt', descending: true);

    // keyword：提供「弱化可用」的查法（不保證涵蓋所有欄位）
    final kw = (keyword ?? '').trim();
    if (kw.isNotEmpty) {
      // 優先用 orderNo 精準查（若你要全文檢索建議另做 searchKey 或外掛搜尋）
      q = q.where('orderNo', isEqualTo: kw);
    }

    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    return q.limit(limit).get();
  }

  /// 訂單串流（即時更新）
  Stream<QuerySnapshot<Map<String, dynamic>>> streamOrders({
    String? vendorId,
    String? status,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> q = _ref;

    final vid = (vendorId ?? '').trim();
    if (vid.isNotEmpty) {
      q = q.where('vendorId', isEqualTo: vid);
    }

    final st = (status ?? '').trim();
    if (st.isNotEmpty) {
      q = q.where('status', isEqualTo: st);
    }

    q = q.orderBy('createdAt', descending: true).limit(limit);
    return q.snapshots();
  }

  /// 單筆讀取
  Future<DocumentSnapshot<Map<String, dynamic>>> getOrder(String orderId) {
    return _ref.doc(orderId).get();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamOrder(String orderId) {
    return _ref.doc(orderId).snapshots();
  }

  // ===========================================================
  // Updates
  // ===========================================================

  /// 更新訂單狀態（status）
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? adminUid,
    String? note,
  }) async {
    final data = <String, dynamic>{
      'status': status.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if ((note ?? '').trim().isNotEmpty) {
      data['adminNote'] = note!.trim();
    }
    if ((adminUid ?? '').trim().isNotEmpty) {
      data['updatedBy'] = adminUid!.trim();
    }

    await _ref.doc(orderId).update(data);
  }

  /// 更新付款狀態 payment.status（例如 pending/paid/failed/cod）
  Future<void> updatePaymentStatus(
    String orderId,
    String paymentStatus, {
    String? provider,
    String? method,
    String? transactionId,
  }) async {
    final data = <String, dynamic>{
      'payment.status': paymentStatus.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if ((provider ?? '').trim().isNotEmpty) {
      data['payment.provider'] = provider!.trim();
    }
    if ((method ?? '').trim().isNotEmpty) {
      data['payment.method'] = method!.trim();
    }
    if ((transactionId ?? '').trim().isNotEmpty) {
      data['payment.transactionId'] = transactionId!.trim();
    }

    // 若標記 paid，順便寫 paidAt（如果你的 schema 需要）
    final ps = paymentStatus.trim().toLowerCase();
    if (ps == 'paid' || ps == 'success' || ps == 'succeeded') {
      data['paidAt'] = FieldValue.serverTimestamp();
    }

    await _ref.doc(orderId).update(data);
  }

  /// 更新出貨狀態 shipping.status（例如 pending/packing/shipped/delivered）
  Future<void> updateShippingStatus(
    String orderId,
    String shippingStatus,
  ) async {
    await _ref.doc(orderId).update({
      'shipping.status': shippingStatus.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 設定物流資訊
  Future<void> setShippingInfo(
    String orderId, {
    String? carrier,
    String? trackingNo,
    DateTime? shippedAt,
    String? shippingStatus, // optional 同步更新 shipping.status
  }) async {
    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};

    if ((carrier ?? '').trim().isNotEmpty) {
      data['shipping.carrier'] = carrier!.trim();
    }
    if ((trackingNo ?? '').trim().isNotEmpty) {
      data['shipping.trackingNo'] = trackingNo!.trim();
    }
    if (shippedAt != null) {
      data['shipping.shippedAt'] = Timestamp.fromDate(shippedAt);
    } else {
      // 不強制寫入 shippedAt，避免覆蓋
    }
    if ((shippingStatus ?? '').trim().isNotEmpty) {
      data['shipping.status'] = shippingStatus!.trim();
    }

    await _ref.doc(orderId).update(data);
  }

  /// 設定/更新管理備註
  Future<void> setAdminNote(
    String orderId,
    String note, {
    String? adminUid,
  }) async {
    final data = <String, dynamic>{
      'adminNote': note.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if ((adminUid ?? '').trim().isNotEmpty) {
      data['updatedBy'] = adminUid!.trim();
    }

    await _ref.doc(orderId).update(data);
  }

  /// 退款標記（不做金流實際退款，只是後台狀態）
  Future<void> markRefund(
    String orderId, {
    required String refundStatus, // requested/approved/rejected/refunded
    double? refundAmount,
    String? reason,
    String? adminUid,
  }) async {
    final data = <String, dynamic>{
      'refund.status': refundStatus.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (refundAmount != null) {
      data['refund.amount'] = refundAmount;
    }
    if ((reason ?? '').trim().isNotEmpty) {
      data['refund.reason'] = reason!.trim();
    }
    if ((adminUid ?? '').trim().isNotEmpty) {
      data['refund.updatedBy'] = adminUid!.trim();
    }

    final rs = refundStatus.trim().toLowerCase();
    if (rs == 'refunded') {
      data['refund.refundedAt'] = FieldValue.serverTimestamp();
    }

    await _ref.doc(orderId).update(data);
  }

  // ===========================================================
  // Batch
  // ===========================================================

  /// 批次更新訂單狀態
  Future<void> batchUpdateStatus(
    List<String> orderIds,
    String status, {
    String? adminUid,
  }) async {
    final ids = orderIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.isEmpty) {
      return;
    }

    final batch = _db.batch();
    for (final id in ids) {
      batch.update(_ref.doc(id), {
        'status': status.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        if ((adminUid ?? '').trim().isNotEmpty) 'updatedBy': adminUid!.trim(),
      });
    }
    await batch.commit();
  }

  /// 批次寫入 adminNote（會覆蓋）
  Future<void> batchSetAdminNote(
    List<String> orderIds,
    String note, {
    String? adminUid,
  }) async {
    final ids = orderIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.isEmpty) {
      return;
    }

    final batch = _db.batch();
    for (final id in ids) {
      batch.update(_ref.doc(id), {
        'adminNote': note.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        if ((adminUid ?? '').trim().isNotEmpty) 'updatedBy': adminUid!.trim(),
      });
    }
    await batch.commit();
  }

  /// 批次加/移除標籤（orders.tags: `List<String>`）
  Future<void> batchUpdateTags(
    List<String> orderIds, {
    List<String> add = const [],
    List<String> remove = const [],
    String? adminUid,
  }) async {
    final ids = orderIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.isEmpty) {
      return;
    }

    final addTags = add
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final rmTags = remove
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final batch = _db.batch();
    for (final id in ids) {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        if ((adminUid ?? '').trim().isNotEmpty) 'updatedBy': adminUid!.trim(),
      };

      if (addTags.isNotEmpty) {
        data['tags'] = FieldValue.arrayUnion(addTags);
      }
      if (rmTags.isNotEmpty) {
        data['tags'] = FieldValue.arrayRemove(rmTags);
      }

      batch.update(_ref.doc(id), data);
    }
    await batch.commit();
  }

  // ===========================================================
  // Helpers
  // ===========================================================

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 0, 0, 0);
  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59);
}
