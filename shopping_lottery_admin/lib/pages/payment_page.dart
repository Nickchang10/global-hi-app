// lib/pages/payment_page.dart
//
// ✅ PaymentPage（完整版・可編譯）
// - 接收 arguments: { orderId, id, method }（可選）
// - 讓使用者選擇付款方式 -> 呼叫 PaymentService.initPayment
// - 成功後：
//   - COD：直接導到 /payment_status
//   - Stripe/LinePay：顯示 paymentUrl + 提供複製 + 前往 /payment_status
//
// 依賴：provider, payment_service.dart, order_enums.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/order_enums.dart';
import '../services/payment_service.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _orderIdCtrl = TextEditingController();

  bool _loading = false;
  bool _inited = false;

  String _method = PaymentMethod.creditCard.name; // 預設信用卡
  PaymentInitResult? _result;
  String? _error;

  @override
  void dispose() {
    _orderIdCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _args(BuildContext context) {
    final a = ModalRoute.of(context)?.settings.arguments;
    if (a is Map) return Map<String, dynamic>.from(a);
    return <String, dynamic>{};
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_inited) return;
    _inited = true;

    final a = _args(context);
    final orderId = _s(a['orderId'] ?? a['id']);
    final methodRaw = a['method'];

    if (orderId.isNotEmpty) _orderIdCtrl.text = orderId;

    if (_s(methodRaw).isNotEmpty) {
      // ✅ 相容 method 可能是 linepay/LINE_PAY/credit_card... 等
      _method = paymentMethodFromAny(methodRaw, fallback: PaymentMethod.creditCard).name;
    }
  }

  Future<void> _initPayment() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final oid = _orderIdCtrl.text.trim();
      if (oid.isEmpty) {
        throw PaymentException('invalid_order_id', '請輸入 orderId');
      }

      final svc = context.read<PaymentService>();
      final res = await svc.initPayment(oid, method: _method);

      if (!mounted) return;
      setState(() => _result = res);

      // ✅ COD：直接跳付款狀態頁
      if (res.provider == PaymentProvider.cod) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          '/payment_status',
          arguments: {'orderId': res.orderId},
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _goStatus() {
    final oid = (_result?.orderId ?? _orderIdCtrl.text).trim();
    if (oid.isEmpty) {
      _snack('orderId 不可為空');
      return;
    }

    Navigator.pushNamed(
      context,
      '/payment_status',
      arguments: {'orderId': oid},
    );
  }

  Future<void> _copyUrl() async {
    final url = (_result?.paymentUrl ?? '').trim();
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    _snack('已複製付款連結');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('付款')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '初始化付款',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _orderIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Order ID',
                          hintText: '例如：訂單文件 ID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _method,
                        decoration: const InputDecoration(
                          labelText: '付款方式',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: PaymentMethod.creditCard.name,
                            child: Text(PaymentMethod.creditCard.label),
                          ),
                          DropdownMenuItem(
                            value: PaymentMethod.linePay.name,
                            child: Text(PaymentMethod.linePay.label),
                          ),
                          DropdownMenuItem(
                            value: PaymentMethod.cash.name,
                            child: Text(PaymentMethod.cash.label),
                          ),
                        ],
                        onChanged: _loading
                            ? null
                            : (v) => setState(() => _method = v ?? PaymentMethod.creditCard.name),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _loading ? null : _initPayment,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.payments),
                        label: Text(_loading ? '處理中...' : '建立付款'),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: cs.error)),
                      ],
                    ],
                  ),
                ),
              ),

              if (_result != null) ...[
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '初始化結果',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        _kv('Order ID', _result!.orderId),
                        _kv('Provider', _result!.provider.label),
                        _kv('Payment Status', _result!.status.label),

                        const SizedBox(height: 12),

                        if ((_result!.paymentUrl ?? '').trim().isNotEmpty) ...[
                          const Text('Payment URL（示意）'),
                          const SizedBox(height: 6),
                          SelectableText(
                            _result!.paymentUrl!,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _copyUrl,
                                icon: const Icon(Icons.copy),
                                label: const Text('複製連結'),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed: _goStatus,
                                icon: const Icon(Icons.receipt_long),
                                label: const Text('前往付款狀態'),
                              ),
                            ],
                          ),
                        ] else ...[
                          FilledButton.icon(
                            onPressed: _goStatus,
                            icon: const Icon(Icons.receipt_long),
                            label: const Text('前往付款狀態'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
