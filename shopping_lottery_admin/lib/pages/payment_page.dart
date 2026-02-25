// lib/pages/payment_page.dart
//
// ✅ PaymentPage（最終完整版｜可編譯｜已移除 Radio groupValue deprecated｜改用 RadioGroup）
// ------------------------------------------------------------
// 功能：
// - 路由：/payment
// - args：String(orderId) 或 {orderId: ...}
// - 讀取 orders/{orderId}
// - 選擇付款方式（信用卡 / LINE Pay / 轉帳 / 貨到付款）
// - 按「建立付款」：
//   - 建立 payments/{paymentId}
//   - 更新 orders/{orderId}.payment（paymentId/method/provider/status）
// - 成功後導到 /payment_status（若你有該頁）
//
// Firestore 建議 schema（本檔容錯）：
// - orders/{orderId}
//    - total / grandTotal / amount
//    - status
//    - payment: { status, method, provider, paymentId, updatedAt }
//
// - payments/{paymentId}
//    - orderId, amount, currency, provider, method, status, createdAt, updatedAt

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

/// ✅ 你原本缺的 model：PaymentInitResult
class PaymentInitResult {
  final String paymentId;
  final String orderId;
  final String provider; // e.g. stripe/linepay/bank/cod
  final String method; // e.g. card/linepay/bank_transfer/cod
  final String status; // pending/paid/failed/cod
  final double amount;
  final String currency;
  final String message;
  final Map<String, dynamic> raw;

  const PaymentInitResult({
    required this.paymentId,
    required this.orderId,
    required this.provider,
    required this.method,
    required this.status,
    required this.amount,
    required this.currency,
    this.message = '',
    this.raw = const {},
  });

  Map<String, dynamic> toMap() => {
    'paymentId': paymentId,
    'orderId': orderId,
    'provider': provider,
    'method': method,
    'status': status,
    'amount': amount,
    'currency': currency,
    'message': message,
    'raw': raw,
  };
}

class _PaymentPageState extends State<PaymentPage> {
  bool _loading = false;
  String _error = '';

  // 預設付款方式
  PaymentMethod _method = PaymentMethod.card;

  String _orderIdFromArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) return args.trim();
    if (args is Map) {
      final v = args['orderId'] ?? args['id'];
      if (v != null) return v.toString().trim();
    }
    return '';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  double _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  /// 從 order doc 推估總金額
  double _pickOrderAmount(Map<String, dynamic> order) {
    // 常見欄位容錯
    final a1 = _asDouble(order['grandTotal']);
    if (a1 > 0) return a1;
    final a2 = _asDouble(order['total']);
    if (a2 > 0) return a2;
    final a3 = _asDouble(order['amount']);
    if (a3 > 0) return a3;

    final p = order['payment'];
    if (p is Map) {
      final a4 = _asDouble(p['amount']);
      if (a4 > 0) return a4;
    }
    return 0.0;
  }

  Future<PaymentInitResult> _initPayment({
    required String orderId,
    required Map<String, dynamic> order,
    required PaymentMethod method,
  }) async {
    final db = FirebaseFirestore.instance;
    final orderRef = db.collection('orders').doc(orderId);
    final paymentRef = db.collection('payments').doc(); // auto id

    final amount = _pickOrderAmount(order);
    final currency = _s(order['currency']).isNotEmpty
        ? _s(order['currency'])
        : 'TWD';

    final provider = method.provider;
    final status = method == PaymentMethod.cod ? 'cod' : 'pending';
    final now = FieldValue.serverTimestamp();

    await db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) {
        throw StateError('找不到訂單：$orderId');
      }

      tx.set(paymentRef, {
        'orderId': orderId,
        'amount': amount,
        'currency': currency,
        'provider': provider,
        'method': method.method,
        'status': status,
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      tx.set(orderRef, {
        'payment': {
          'paymentId': paymentRef.id,
          'provider': provider,
          'method': method.method,
          'status': status,
          'amount': amount,
          'currency': currency,
          'updatedAt': now,
        },
        'updatedAt': now,
      }, SetOptions(merge: true));
    });

    return PaymentInitResult(
      paymentId: paymentRef.id,
      orderId: orderId,
      provider: provider,
      method: method.method,
      status: status,
      amount: amount,
      currency: currency,
      message: method == PaymentMethod.cod ? '已建立貨到付款' : '已建立付款單（待付款）',
      raw: const {},
    );
  }

  Future<void> _onCreatePayment(
    String orderId,
    Map<String, dynamic> order,
  ) async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final result = await _initPayment(
        orderId: orderId,
        order: order,
        method: _method,
      );
      if (!mounted) return;

      _snack(result.message.isEmpty ? '付款已建立' : result.message);

      Navigator.pushReplacementNamed(
        context,
        '/payment_status',
        arguments: {
          'orderId': orderId,
          'paymentId': result.paymentId,
          'provider': result.provider,
          'method': result.method,
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderId = _orderIdFromArgs(context);
    if (orderId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('缺少 orderId（請用 arguments 傳入）')),
      );
    }

    final orderRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('付款'),
        actions: [
          IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: orderRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('讀取訂單失敗：${snap.error}'));
          }

          final order = snap.data?.data() ?? <String, dynamic>{};
          if (order.isEmpty) {
            return Center(child: Text('找不到訂單資料：$orderId'));
          }

          final amount = _pickOrderAmount(order);
          final currency = _s(order['currency']).isNotEmpty
              ? _s(order['currency'])
              : 'TWD';
          final orderStatus = _s(order['status']).isEmpty
              ? 'unknown'
              : _s(order['status']);

          final payment = order['payment'] is Map
              ? Map<String, dynamic>.from(order['payment'])
              : <String, dynamic>{};
          final payStatus = _s(payment['status']).isEmpty
              ? 'none'
              : _s(payment['status']);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _InfoCard(
                title: '訂單資訊',
                children: [
                  _kv('訂單號', orderId),
                  _kv('訂單狀態', orderStatus),
                  _kv('付款狀態', payStatus),
                  _kv('金額', '${amount.toStringAsFixed(0)} $currency'),
                ],
              ),
              const SizedBox(height: 12),

              _InfoCard(
                title: '選擇付款方式',
                children: [
                  // ✅ FIX: 移除 RadioListTile.groupValue deprecated
                  // ✅ 改用 RadioGroup 祖先管理選取值
                  RadioGroup<PaymentMethod>(
                    groupValue: _method,
                    onChanged: (v) {
                      if (v == null) return;
                      if (!mounted) return;
                      setState(() => _method = v);
                    },
                    child: Column(
                      children: const [
                        _PaymentMethodTile(
                          value: PaymentMethod.card,
                          title: '信用卡',
                          subtitle: '（示範）建立待付款單',
                          icon: Icons.credit_card,
                        ),
                        _PaymentMethodTile(
                          value: PaymentMethod.linepay,
                          title: 'LINE Pay',
                          subtitle: '（示範）建立待付款單',
                          icon: Icons.qr_code_2,
                        ),
                        _PaymentMethodTile(
                          value: PaymentMethod.bankTransfer,
                          title: '銀行轉帳',
                          subtitle: '（示範）建立待付款單',
                          icon: Icons.account_balance,
                        ),
                        _PaymentMethodTile(
                          value: PaymentMethod.cod,
                          title: '貨到付款',
                          subtitle: '建立 COD 訂單（不等於已付款）',
                          icon: Icons.local_shipping_outlined,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _error,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              FilledButton.icon(
                onPressed: _loading
                    ? null
                    : () => _onCreatePayment(orderId, order),
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.payments_outlined),
                label: Text(_loading ? '建立中...' : '建立付款'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  '/order_complete',
                  arguments: {'orderId': orderId},
                ),
                icon: const Icon(Icons.receipt_long),
                label: const Text('回訂單完成頁'),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(k, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final PaymentMethod value;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<PaymentMethod>(
      value: value,
      // ✅ 不要再寫 groupValue / onChanged（已由 RadioGroup 管理）
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
      subtitle: Text(subtitle),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

enum PaymentMethod { card, linepay, bankTransfer, cod }

extension PaymentMethodX on PaymentMethod {
  String get provider {
    switch (this) {
      case PaymentMethod.card:
        return 'stripe';
      case PaymentMethod.linepay:
        return 'linepay';
      case PaymentMethod.bankTransfer:
        return 'bank';
      case PaymentMethod.cod:
        return 'cod';
    }
  }

  String get method {
    switch (this) {
      case PaymentMethod.card:
        return 'card';
      case PaymentMethod.linepay:
        return 'linepay';
      case PaymentMethod.bankTransfer:
        return 'bank_transfer';
      case PaymentMethod.cod:
        return 'cod';
    }
  }
}
