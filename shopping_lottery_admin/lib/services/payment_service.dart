// lib/services/payment_service.dart
//
// ✅ PaymentService（完整版・可編譯最終版）
//
// 功能總覽：
// - initPayment(orderId, method)：初始化付款（產生 paymentUrl / 寫入 payment/provider/status）
// - updatePaymentStatus(orderId, newStatus)：更新付款狀態，並同步 orders.status + timeline
// - getPaymentStatus / getPaymentProvider：查詢狀態
// - markPaid / markFailed / markCancelled：測試用快捷
//
// Firestore：orders/{orderId}
//   - status: String (OrderStatus.name)
//   - paymentUrl: String?
//   - payment: {
//       status: String (PaymentStatus.name)
//       method: String (PaymentMethod.name 或自訂字串)
//       provider: String (PaymentProvider.name)
//       updatedAt: Timestamp
//     }
//   - timeline: Array<{type, at, ...}>
//
// 依賴：cloud_firestore, models/order_enums.dart
// ⚠️ 本檔不重複宣告 fromAny helpers，直接使用 order_enums.dart 內的：
//   - paymentStatusFromAny / paymentProviderFromAny / paymentMethodFromAny / orderStatusFromAny
//   - *_Ext.label / isFinal / isPending 等
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_enums.dart';

class PaymentException implements Exception {
  final String code;
  final String message;
  PaymentException(this.code, this.message);

  @override
  String toString() => 'PaymentException($code): $message';
}

/// 初始化結果
class PaymentInitResult {
  final PaymentProvider provider;
  final PaymentStatus status;
  final String orderId;
  final String? paymentUrl;

  const PaymentInitResult({
    required this.provider,
    required this.status,
    required this.orderId,
    this.paymentUrl,
  });

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'provider': provider.name,
        'status': status.name,
        'paymentUrl': paymentUrl,
      };
}

class PaymentService {
  PaymentService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _orders => _db.collection('orders');

  String _s(dynamic v) => (v ?? '').toString().trim();

  // ------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------

  /// ✅ 初始化付款流程
  ///
  /// - method 支援：
  ///   - 'cod' / 'cash'：貨到付款（寫入 PaymentStatus.cod + OrderStatus.codPending，不產生 paymentUrl）
  ///   - 包含 'line'：LinePay（產生示意 URL）
  ///   - 其他：Stripe（產生示意 URL）
  ///
  /// - forceNewLink=true：忽略既有 paymentUrl，強制重建（通常不需要）
  Future<PaymentInitResult> initPayment(
    String orderId, {
    required String method,
    bool forceNewLink = false,
  }) async {
    final oid = _s(orderId);
    if (oid.isEmpty) {
      throw PaymentException('invalid_order_id', 'orderId 不可為空');
    }

    final ref = _orders.doc(oid);
    final snap = await ref.get();
    if (!snap.exists) {
      throw PaymentException('order_not_found', '找不到訂單：$oid');
    }

    final data = snap.data() ?? <String, dynamic>{};

    final payMap = (data['payment'] is Map)
        ? Map<String, dynamic>.from(data['payment'] as Map)
        : <String, dynamic>{};

    final existingUrl = _s(data['paymentUrl']);

    final currentPaymentStatus = paymentStatusFromAny(
      payMap['status'],
      fallback: PaymentStatus.pending,
    );

    final currentProvider = paymentProviderFromAny(
      payMap['provider'],
      fallback: PaymentProvider.stripe,
    );

    // ✅ 已有付款連結，且仍在等待付款 -> 直接回傳（避免重複產生）
    if (!forceNewLink &&
        existingUrl.isNotEmpty &&
        (currentPaymentStatus == PaymentStatus.pending || currentPaymentStatus == PaymentStatus.init)) {
      return PaymentInitResult(
        provider: currentProvider,
        status: currentPaymentStatus,
        orderId: oid,
        paymentUrl: existingUrl,
      );
    }

    // ✅ 若已是終態（paid/failed/cancelled），也不建議重建付款
    if (!forceNewLink && currentPaymentStatus.isFinal) {
      return PaymentInitResult(
        provider: currentProvider,
        status: currentPaymentStatus,
        orderId: oid,
        paymentUrl: existingUrl.isEmpty ? null : existingUrl,
      );
    }

    final methodNorm = _normalizeMethod(method);
    final provider = _providerFromMethod(methodNorm);

    // ✅ 貨到付款：不產生 URL，直接把狀態寫成 COD
    if (provider == PaymentProvider.cod) {
      await ref.set(
        {
          'payment': {
            'status': PaymentStatus.cod.name,
            'method': methodNorm,
            'provider': PaymentProvider.cod.name,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          'status': OrderStatus.codPending.name,
          'paymentUrl': '',
          'updatedAt': FieldValue.serverTimestamp(),
          'timeline': FieldValue.arrayUnion([
            {
              'type': 'payment_init',
              'provider': PaymentProvider.cod.name,
              'method': methodNorm,
              'status': PaymentStatus.cod.name,
              'at': FieldValue.serverTimestamp(),
            }
          ]),
        },
        SetOptions(merge: true),
      );

      return PaymentInitResult(
        provider: PaymentProvider.cod,
        status: PaymentStatus.cod,
        orderId: oid,
        paymentUrl: null,
      );
    }

    // ✅ Stripe / LinePay：產生示意 URL（你可替換成真實付款連結）
    final payUrl = _buildMockPaymentUrl(provider: provider, orderId: oid);

    await ref.set(
      {
        'payment': {
          'status': PaymentStatus.pending.name,
          'method': methodNorm,
          'provider': provider.name,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'status': OrderStatus.pendingPayment.name,
        'paymentUrl': payUrl,
        'updatedAt': FieldValue.serverTimestamp(),
        'timeline': FieldValue.arrayUnion([
          {
            'type': 'payment_init',
            'provider': provider.name,
            'method': methodNorm,
            'status': PaymentStatus.pending.name,
            'paymentUrl': payUrl,
            'at': FieldValue.serverTimestamp(),
          }
        ]),
      },
      SetOptions(merge: true),
    );

    return PaymentInitResult(
      provider: provider,
      status: PaymentStatus.pending,
      orderId: oid,
      paymentUrl: payUrl,
    );
  }

  /// ✅ 更新付款狀態，並同步訂單主狀態 + timeline
  Future<void> updatePaymentStatus(
    String orderId,
    PaymentStatus newStatus, {
    String? reason,
  }) async {
    final oid = _s(orderId);
    if (oid.isEmpty) {
      throw PaymentException('invalid_order_id', 'orderId 不可為空');
    }

    final ref = _orders.doc(oid);
    final snap = await ref.get();
    if (!snap.exists) {
      throw PaymentException('not_found', '訂單不存在：$oid');
    }

    final newOrderStatus = _orderStatusFromPayment(newStatus);

    await ref.set(
      {
        'payment': {
          'status': newStatus.name,
          'updatedAt': FieldValue.serverTimestamp(),
          if (_s(reason).isNotEmpty) 'reason': _s(reason),
        },
        'status': newOrderStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'timeline': FieldValue.arrayUnion([
          {
            'type': 'payment_update',
            'status': newStatus.name,
            'orderStatus': newOrderStatus.name,
            if (_s(reason).isNotEmpty) 'reason': _s(reason),
            'at': FieldValue.serverTimestamp(),
          }
        ]),
        if (newStatus == PaymentStatus.paid) 'paidAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// ✅ 取得付款狀態
  Future<PaymentStatus> getPaymentStatus(String orderId) async {
    final oid = _s(orderId);
    if (oid.isEmpty) {
      throw PaymentException('invalid_order_id', 'orderId 不可為空');
    }

    final snap = await _orders.doc(oid).get();
    if (!snap.exists) {
      throw PaymentException('not_found', '訂單不存在：$oid');
    }

    final data = snap.data() ?? <String, dynamic>{};
    final pay = data['payment'];
    if (pay is Map) {
      return paymentStatusFromAny((pay as Map)['status'], fallback: PaymentStatus.pending);
    }
    return PaymentStatus.pending;
  }

  /// ✅ 取得付款供應商
  Future<PaymentProvider> getPaymentProvider(String orderId) async {
    final oid = _s(orderId);
    if (oid.isEmpty) {
      throw PaymentException('invalid_order_id', 'orderId 不可為空');
    }

    final snap = await _orders.doc(oid).get();
    if (!snap.exists) {
      throw PaymentException('not_found', '訂單不存在：$oid');
    }

    final data = snap.data() ?? <String, dynamic>{};
    final pay = data['payment'];
    if (pay is Map) {
      return paymentProviderFromAny((pay as Map)['provider'], fallback: PaymentProvider.stripe);
    }
    return PaymentProvider.stripe;
  }

  /// ✅ 測試用快捷
  Future<void> markPaid(String orderId) => updatePaymentStatus(orderId, PaymentStatus.paid);
  Future<void> markFailed(String orderId) => updatePaymentStatus(orderId, PaymentStatus.failed);
  Future<void> markCancelled(String orderId) => updatePaymentStatus(orderId, PaymentStatus.cancelled);

  // ------------------------------------------------------------
  // Internal helpers
  // ------------------------------------------------------------

  OrderStatus _orderStatusFromPayment(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:
        return OrderStatus.paid;
      case PaymentStatus.failed:
        return OrderStatus.failed;
      case PaymentStatus.cancelled:
        return OrderStatus.cancelled;
      case PaymentStatus.cod:
        return OrderStatus.codPending;
      case PaymentStatus.init:
      case PaymentStatus.pending:
      default:
        return OrderStatus.pendingPayment;
    }
  }

  /// 把輸入 method 正規化為 PaymentMethod.name（或自訂字串）
  /// - 你 UI 可能傳：'cod'/'cash'/'linepay'/'credit' 等等
  String _normalizeMethod(String method) {
    final m = _s(method).toLowerCase();
    if (m.isEmpty) return PaymentMethod.creditCard.name;

    if (m == 'cod' || m == 'cash' || m.contains('貨到') || m.contains('cash')) {
      return PaymentMethod.cash.name;
    }
    if (m.contains('line')) return PaymentMethod.linePay.name;
    if (m.contains('card') || m.contains('credit') || m == 'cc') {
      return PaymentMethod.creditCard.name;
    }
    return m; // 允許自訂字串
  }

  PaymentProvider _providerFromMethod(String methodNorm) {
    final m = _s(methodNorm).toLowerCase();
    if (m.isEmpty) return PaymentProvider.stripe;
    if (m == 'cod' || m == 'cash' || m.contains('貨到')) return PaymentProvider.cod;
    if (m.contains('line')) return PaymentProvider.linepay;
    return PaymentProvider.stripe;
  }

  String _buildMockPaymentUrl({
    required PaymentProvider provider,
    required String orderId,
  }) {
    switch (provider) {
      case PaymentProvider.linepay:
        return 'https://pay.line.me/fake/txn/$orderId';
      case PaymentProvider.stripe:
        return 'https://checkout.stripe.com/pay/$orderId';
      case PaymentProvider.cod:
        return '';
    }
  }
}
