import 'dart:async';
import 'package:flutter/material.dart';

/// ✅ OrderSuccessPage（下單成功頁｜最終完整版｜已修正 curly_braces_in_flow_control_structures）
/// ------------------------------------------------------------
/// - 支援帶入：orderId / amount / autoBackSeconds
/// - 按鈕：查看訂單 / 回首頁
/// - 可選：倒數自動回首頁（autoBackSeconds > 0）
///
/// 你可以在下單完成後：
/// Navigator.pushReplacement(
///   context,
///   MaterialPageRoute(builder: (_) => const OrderSuccessPage(orderId: 'xxx')),
/// );
class OrderSuccessPage extends StatefulWidget {
  final String? orderId;
  final num? amount;
  final int autoBackSeconds;

  const OrderSuccessPage({
    super.key,
    this.orderId,
    this.amount,
    this.autoBackSeconds = 0, // 0 = 不自動返回
  });

  @override
  State<OrderSuccessPage> createState() => _OrderSuccessPageState();
}

class _OrderSuccessPageState extends State<OrderSuccessPage> {
  Timer? _timer;
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();

    _secondsLeft = widget.autoBackSeconds;
    if (_secondsLeft > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }

        setState(() {
          _secondsLeft -= 1;
        });

        if (_secondsLeft <= 0) {
          t.cancel();
          _goHome();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmtMoney(num v) {
    // 不依賴 intl，簡易顯示
    final s = v.round().toString();
    final withComma = s.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return 'NT\$ $withComma';
  }

  void _goHome() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
  }

  void _goOrders() {
    if (!mounted) {
      return;
    }
    // 你若有訂單詳情頁，也可改成帶 orderId 進去
    Navigator.of(context).pushNamed('/orders');
  }

  @override
  Widget build(BuildContext context) {
    final orderId = (widget.orderId ?? '').trim();
    final amount = widget.amount;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('下單成功'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '付款 / 下單完成 🎉',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '感謝您的購買，我們已收到您的訂單。',
                      style: TextStyle(color: Colors.grey.shade700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),

                    if (orderId.isNotEmpty) ...[
                      _kv('訂單編號', orderId),
                      const SizedBox(height: 6),
                    ] else ...[
                      _kv('訂單編號', '（未提供）'),
                      const SizedBox(height: 6),
                    ],

                    if (amount != null && amount > 0) ...[
                      _kv('付款金額', _fmtMoney(amount)),
                      const SizedBox(height: 6),
                    ] else ...[
                      _kv('付款金額', '-'),
                      const SizedBox(height: 6),
                    ],

                    if (widget.autoBackSeconds > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        '$_secondsLeft 秒後自動返回首頁',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _goHome,
                            icon: const Icon(Icons.home_outlined),
                            label: const Text('回首頁'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _goOrders,
                            icon: const Icon(Icons.receipt_long),
                            label: const Text('查看訂單'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        if (!mounted) {
                          return;
                        }
                        Navigator.of(context).maybePop();
                      },
                      child: const Text('返回上一頁'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            k,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
