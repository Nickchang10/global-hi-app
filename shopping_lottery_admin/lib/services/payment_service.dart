// lib/services/payment_service.dart
//
// ✅ PaymentService（最終可編譯完整版｜已移除 unnecessary_cast）
// ------------------------------------------------------------
// 用途：
// - 建立付款紀錄（payments）
// - 寫回 orders/{orderId}.payment 狀態（pending/paid/failed/cod）
// - 提供 stream 監聽付款狀態（by paymentId / by orderId）
//
// Firestore 結構（建議）：
// - orders/{orderId}
//    - payment: { status, provider, method, paymentId, transactionId, raw, updatedAt }
// - payments/{paymentId}
//    - { orderId, userId, provider, method, amount, currency, status, transactionId, raw, createdAt, updatedAt }
//
// 依賴：cloud_firestore
//

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 付款狀態
class PaymentStatus {
  static const pending = 'pending';
  static const paid = 'paid';
  static const failed = 'failed';
  static const cod = 'cod';
  static const refunded = 'refunded';
}

/// 付款資料模型
class PaymentRecord {
  final String paymentId;
  final String orderId;
  final String userId;
  final String provider; // e.g. ecpay/stripe/manual/cod
  final String method; // e.g. card/atm/applepay/cash
  final double amount;
  final String currency;
  final String status;
  final String transactionId;
  final Map<String, dynamic> raw;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PaymentRecord({
    required this.paymentId,
    required this.orderId,
    required this.userId,
    required this.provider,
    required this.method,
    required this.amount,
    required this.currency,
    required this.status,
    required this.transactionId,
    required this.raw,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return PaymentRecord(
      paymentId: doc.id,
      orderId: _s(d['orderId']),
      userId: _s(d['userId']),
      provider: _s(d['provider']),
      method: _s(d['method']),
      amount: _asDouble(d['amount']),
      currency: _s(d['currency']).isEmpty ? 'TWD' : _s(d['currency']),
      status: _s(d['status']).isEmpty ? PaymentStatus.pending : _s(d['status']),
      transactionId: _s(d['transactionId']),
      raw: _asMap(d['raw']),
      createdAt: _toDate(d['createdAt']),
      updatedAt: _toDate(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'orderId': orderId,
    'userId': userId,
    'provider': provider,
    'method': method,
    'amount': amount,
    'currency': currency,
    'status': status,
    'transactionId': transactionId,
    'raw': raw,
  };
}

class PaymentService {
  final FirebaseFirestore _db;
  final String ordersCol;
  final String paymentsCol;

  PaymentService({
    FirebaseFirestore? db,
    this.ordersCol = 'orders',
    this.paymentsCol = 'payments',
  }) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection(ordersCol);

  CollectionReference<Map<String, dynamic>> get _payments =>
      _db.collection(paymentsCol);

  // ===========================================================
  // 建立付款（會同步寫回 order.payment）
  // ===========================================================

  Future<PaymentRecord> createPaymentForOrder({
    required String orderId,
    String provider = 'manual',
    String method = 'card',
    String currency = 'TWD',
    String? transactionId,
    Map<String, dynamic>? raw,
  }) async {
    final oid = orderId.trim();
    if (oid.isEmpty) throw ArgumentError('orderId 不可為空');

    final orderRef = _orders.doc(oid);
    final orderSnap = await orderRef.get();
    final order = orderSnap.data() ?? <String, dynamic>{};

    final userId = _s(order['userId']);
    final amount = _extractOrderTotal(order);
    final pid = _payments.doc().id;

    final data = <String, dynamic>{
      'orderId': oid,
      'userId': userId,
      'provider': provider.trim(),
      'method': method.trim(),
      'amount': amount,
      'currency': currency.trim().isEmpty ? 'TWD' : currency.trim(),
      'status': PaymentStatus.pending,
      'transactionId': (transactionId ?? '').trim(),
      'raw': raw ?? <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _db.runTransaction((tx) async {
      tx.set(_payments.doc(pid), data);

      tx.update(orderRef, {
        'payment': <String, dynamic>{
          'status': PaymentStatus.pending,
          'provider': provider.trim(),
          'method': method.trim(),
          'paymentId': pid,
          'transactionId': (transactionId ?? '').trim(),
          'raw': raw ?? <String, dynamic>{},
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    final created = await _payments.doc(pid).get();
    return PaymentRecord.fromDoc(created);
  }

  // ===========================================================
  // 狀態更新（付款成功/失敗/COD）
  // ===========================================================

  Future<void> markPaid({
    required String orderId,
    required String paymentId,
    String? transactionId,
    Map<String, dynamic>? raw,
  }) async {
    await _setStatus(
      orderId: orderId,
      paymentId: paymentId,
      status: PaymentStatus.paid,
      transactionId: transactionId,
      raw: raw,
    );
  }

  Future<void> markFailed({
    required String orderId,
    required String paymentId,
    String? reason,
    Map<String, dynamic>? raw,
  }) async {
    final mergedRaw = <String, dynamic>{
      if (raw != null) ...raw,
      if ((reason ?? '').trim().isNotEmpty) 'reason': reason!.trim(),
    };

    await _setStatus(
      orderId: orderId,
      paymentId: paymentId,
      status: PaymentStatus.failed,
      raw: mergedRaw,
    );
  }

  Future<void> markCod({
    required String orderId,
    String provider = 'cod',
    String method = 'cash',
  }) async {
    final oid = orderId.trim();
    if (oid.isEmpty) throw ArgumentError('orderId 不可為空');

    final orderRef = _orders.doc(oid);

    await orderRef.update({
      'payment': <String, dynamic>{
        'status': PaymentStatus.cod,
        'provider': provider.trim(),
        'method': method.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _setStatus({
    required String orderId,
    required String paymentId,
    required String status,
    String? transactionId,
    Map<String, dynamic>? raw,
  }) async {
    final oid = orderId.trim();
    final pid = paymentId.trim();
    if (oid.isEmpty) throw ArgumentError('orderId 不可為空');
    if (pid.isEmpty) throw ArgumentError('paymentId 不可為空');

    final orderRef = _orders.doc(oid);
    final payRef = _payments.doc(pid);

    await _db.runTransaction((tx) async {
      tx.update(payRef, {
        'status': status,
        if ((transactionId ?? '').trim().isNotEmpty)
          'transactionId': transactionId!.trim(),
        if (raw != null) 'raw': raw,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.update(orderRef, {
        'payment.status': status,
        'payment.paymentId': pid,
        if ((transactionId ?? '').trim().isNotEmpty)
          'payment.transactionId': transactionId!.trim(),
        if (raw != null) 'payment.raw': raw,
        if (status == PaymentStatus.paid) 'status': 'paid',
        'payment.updatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (status == PaymentStatus.paid)
          'paidAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ===========================================================
  // Streams / Reads
  // ===========================================================

  Stream<PaymentRecord?> streamPayment(String paymentId) {
    final pid = paymentId.trim();
    if (pid.isEmpty) return const Stream<PaymentRecord?>.empty();
    return _payments.doc(pid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return PaymentRecord.fromDoc(doc);
    });
  }

  /// 取最新一筆 payments (by orderId)
  Stream<PaymentRecord?> streamLatestPaymentByOrder(String orderId) {
    final oid = orderId.trim();
    if (oid.isEmpty) return const Stream<PaymentRecord?>.empty();

    final q = _payments
        .where('orderId', isEqualTo: oid)
        .orderBy('createdAt', descending: true)
        .limit(1);

    return q.snapshots().map((snap) {
      final docs = snap.docs;
      if (docs.isEmpty) return null;
      return PaymentRecord.fromDoc(docs.first);
    });
  }

  Future<PaymentRecord?> getPayment(String paymentId) async {
    final pid = paymentId.trim();
    if (pid.isEmpty) return null;
    final doc = await _payments.doc(pid).get();
    if (!doc.exists) return null;
    return PaymentRecord.fromDoc(doc);
  }

  // ===========================================================
  // Demo/Mock：模擬第三方回傳（可選用）
  // ===========================================================

  /// 模擬金流回傳：random 成功/失敗（預設 80% 成功）
  Future<void> simulateGatewayCallback({
    required String orderId,
    required String paymentId,
    double successRate = 0.8,
  }) async {
    final r = Random().nextDouble();
    final txId = 'TX-${DateTime.now().millisecondsSinceEpoch}';
    if (r <= successRate) {
      await markPaid(
        orderId: orderId,
        paymentId: paymentId,
        transactionId: txId,
        raw: {'mock': true, 'gateway': 'simulate', 'ok': true},
      );
    } else {
      await markFailed(
        orderId: orderId,
        paymentId: paymentId,
        reason: '模擬付款失敗',
        raw: {'mock': true, 'gateway': 'simulate', 'ok': false},
      );
    }
  }

  // ===========================================================
  // Helpers
  // ===========================================================

  double _extractOrderTotal(Map<String, dynamic> order) {
    // 兼容 totals.total 或 total 或 amount
    final totals = _asMap(order['totals']);
    final v = totals['total'] ?? order['total'] ?? order['amount'];
    final total = _asDouble(v);

    // 防呆：不允許負數
    return max<double>(0.0, total);
  }
}

// ------------------------------------------------------------
// 🔧 Shared helpers（避免 unnecessary_cast / null-aware 問題）
// ------------------------------------------------------------

String _s(dynamic v) => (v ?? '').toString().trim();

Map<String, dynamic> _asMap(dynamic v) {
  if (v == null) return <String, dynamic>{};
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

double _asDouble(dynamic v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  final s = (v ?? '').toString().trim();
  return double.tryParse(s) ?? 0.0;
}

DateTime? _toDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}
