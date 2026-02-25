import 'dart:math';

import 'package:flutter/material.dart';

/// ✅ PaymentCreditcardPage（信用卡付款頁｜最終完整版｜已修正 totalAmount named parameter）
/// ------------------------------------------------------------
/// - 建構子支援 totalAmount: （也相容 amount:）
/// - await 後使用 context 前皆先檢查 mounted
/// - 透明度使用 withValues(alpha: ...)
/// - 付款完成後預設導到 /payment_status（可自行改 nextRoute）
class PaymentCreditcardPage extends StatefulWidget {
  /// ✅ 呼叫端可傳 totalAmount:
  final num totalAmount;

  /// 相容舊寫法：amount:
  final num? amount;

  /// 可選：訂單編號
  final String? orderId;

  /// 可選：付款成功後導向 route（預設 /payment_status）
  final String nextRoute;

  const PaymentCreditcardPage({
    super.key,
    num? totalAmount,
    this.amount,
    this.orderId,
    this.nextRoute = '/payment_status',
  }) : totalAmount = totalAmount ?? amount ?? 0;

  @override
  State<PaymentCreditcardPage> createState() => _PaymentCreditcardPageState();
}

class _PaymentCreditcardPageState extends State<PaymentCreditcardPage> {
  final _cardNoCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _mmCtrl = TextEditingController();
  final _yyCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();

  bool _busy = false;

  double _a(double v) => v.clamp(0.0, 1.0);

  @override
  void dispose() {
    _cardNoCtrl.dispose();
    _nameCtrl.dispose();
    _mmCtrl.dispose();
    _yyCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  String _fmtMoney(num v) {
    final s = v.round().toString();
    final withComma = s.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return 'NT\$ $withComma';
  }

  bool _validate() {
    final no = _cardNoCtrl.text.replaceAll(' ', '').trim();
    final name = _nameCtrl.text.trim();
    final mm = _mmCtrl.text.trim();
    final yy = _yyCtrl.text.trim();
    final cvv = _cvvCtrl.text.trim();

    if (no.length < 12) return false;
    if (name.isEmpty) return false;

    final m = int.tryParse(mm);
    final y = int.tryParse(yy);
    if (m == null || m < 1 || m > 12) return false;
    if (y == null || y < 0) return false;

    if (cvv.length < 3) return false;
    return true;
  }

  Future<void> _pay() async {
    if (_busy) return;

    if (!_validate()) {
      _toast('請確認卡號/姓名/到期/安全碼是否正確');
      return;
    }

    setState(() => _busy = true);

    try {
      // 模擬刷卡處理時間
      await Future<void>.delayed(const Duration(milliseconds: 900));

      // Demo：90% 成功
      final ok = Random().nextInt(100) >= 10;

      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed(
        widget.nextRoute,
        arguments: {
          'orderId': widget.orderId,
          'amount': widget.totalAmount,
          'success': ok,
          'method': 'creditcard',
        },
      );
    } catch (e) {
      if (!mounted) return;
      _toast('付款失敗：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.totalAmount;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(title: const Text('信用卡付款')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCard(amount),
          const SizedBox(height: 12),
          _formCard(),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _pay,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_outline),
            label: Text(_busy ? '處理中...' : '確認付款'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '※ 此頁為示範刷卡流程；正式串接請改成金流 SDK / WebView / 後端交易。',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(num amount) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.blueAccent.withValues(alpha: _a(0.12)),
              child: const Icon(Icons.credit_card, color: Colors.blueAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '應付金額',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fmtMoney(amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  if ((widget.orderId ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '訂單：${widget.orderId}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('卡片資訊', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            TextField(
              controller: _cardNoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '卡號',
                hintText: '4242 4242 4242 4242',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '持卡人姓名',
                hintText: 'NAME',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mmCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'MM',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _yyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'YY',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _cvvCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    obscureText: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
