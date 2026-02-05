import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// 付款成功完成頁
/// 支援動畫展示、倒數自動回首頁、查看訂單明細等互動。
class PaymentSuccessPage extends StatefulWidget {
  final String orderId;
  final double amount;
  final String method;

  const PaymentSuccessPage({
    super.key,
    required this.orderId,
    required this.amount,
    required this.method,
  });

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  static const _brand = Colors.blueAccent;
  static const _accent = Colors.orangeAccent;

  int _countdown = 6;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        _timer?.cancel();
        if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---------------------- UI ----------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 動畫展示
                Lottie.asset(
                  'assets/animations/success.json',
                  repeat: false,
                  width: 200,
                  height: 200,
                ),
                const SizedBox(height: 16),
                const Text(
                  '付款成功！',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '感謝您的購買，我們已收到您的訂單',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 30),

                // 訂單摘要卡片
                _buildSummaryCard(),

                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.popUntil(context, (r) => r.isFirst),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('返回首頁'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/orders');
                  },
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('查看訂單明細'),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                ),

                const SizedBox(height: 40),
                Text(
                  '$_countdown 秒後自動返回首頁',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------- 訂單摘要卡片 ----------------------
  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('訂單資訊',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          _row('訂單編號', widget.orderId),
          _row('付款金額', 'NT\$${widget.amount.toStringAsFixed(0)}'),
          _row('付款方式', widget.method),
          _row('交易時間',
              '${DateTime.now().toLocal().toString().substring(0, 16)}'),
          const Divider(height: 20),
          const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
              SizedBox(width: 6),
              Text('付款已完成，系統將自動發送出貨通知',
                  style: TextStyle(color: Colors.black54, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }
}
