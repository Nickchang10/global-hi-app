// lib/pages/payment_status_page.dart
// =======================================================
// ✅ PaymentStatusPage - 最終整合完整版（Osmile Shopping Flow）
// -------------------------------------------------------
// 功能：
// - 與 OrderService 自動連動（更新狀態為 paid）
// - 支援 LotteryService 自動發放回饋
// - 通知中心自動推送付款結果
// - Confetti 動畫與倒數跳轉抽獎頁
// - 容錯處理：若部分服務不存在或方法缺失，不會掛掉
// =======================================================

import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/order_service.dart';
import '../services/lottery_service.dart';
import '../services/notification_service.dart';
import 'home_page.dart';
import 'lottery_page.dart';

class PaymentStatusPage extends StatefulWidget {
  final String orderId;
  final bool success;
  final int countdownSeconds;
  final double rewardAmount;
  final String userId;

  const PaymentStatusPage({
    super.key,
    required this.orderId,
    this.success = true,
    this.countdownSeconds = 5,
    this.rewardAmount = 500.0,
    this.userId = 'demo_user',
  });

  @override
  State<PaymentStatusPage> createState() => _PaymentStatusPageState();
}

class _PaymentStatusPageState extends State<PaymentStatusPage>
    with SingleTickerProviderStateMixin {
  late bool _success;
  bool _loading = true;

  late int _countdown;
  Timer? _timer;

  late final AnimationController _anim;
  late final Animation<double> _scale;
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _success = widget.success;
    _countdown = widget.countdownSeconds;

    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = Tween<double>(begin: 0.9, end: 1.0)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutBack));

    _confetti = ConfettiController(duration: const Duration(seconds: 3));

    _simulatePaymentResult();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    _confetti.dispose();
    super.dispose();
  }

  // =======================================================
  // 模擬付款結果（實際串 API 可替換）
  // =======================================================
  Future<void> _simulatePaymentResult() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _loading = false);

    if (_success) {
      await _handlePaymentSuccess();
    } else {
      await _handlePaymentFail();
    }
  }

  // =======================================================
  // 成功流程：更新訂單狀態、回饋、動畫、倒數
  // =======================================================
  Future<void> _handlePaymentSuccess() async {
    HapticFeedback.lightImpact();

    // ✅ 更新訂單狀態為 paid
    try {
      await OrderService.instance.markPaid(widget.orderId);
    } catch (e) {
      debugPrint('[PaymentStatusPage] markPaid() failed: $e');
    }

    // ✅ 發放抽獎回饋
    try {
      await LotteryService.instance.rewardFromShop(
        userId: widget.userId,
        amount: widget.rewardAmount,
      );
    } catch (_) {}

    // ✅ 通知中心：付款成功
    try {
      NotificationService.instance.addNotification(
        type: 'order',
        title: '付款成功',
        message: '訂單 ${widget.orderId} 已付款成功，您獲得一次抽獎機會！',
        icon: Icons.verified_rounded,
      );
    } catch (_) {}

    _anim.forward();
    _confetti.play();
    _startCountdownToLottery();
  }

  // =======================================================
  // 失敗流程
  // =======================================================
  Future<void> _handlePaymentFail() async {
    HapticFeedback.mediumImpact();
    try {
      NotificationService.instance.addNotification(
        type: 'system',
        title: '付款失敗',
        message: '訂單 ${widget.orderId} 付款未成功，請重新嘗試。',
        icon: Icons.error_outline,
      );
    } catch (_) {}
  }

  void _startCountdownToLottery() {
    _timer?.cancel();
    _countdown = widget.countdownSeconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_countdown <= 1) {
        t.cancel();
        _goLottery(replace: true);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _goLottery({bool replace = false}) {
    _timer?.cancel();
    final route = MaterialPageRoute(builder: (_) => const LotteryPage());
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  void _goHome({bool replace = true}) {
    _timer?.cancel();
    final route = MaterialPageRoute(builder: (_) => const HomePage());
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  void _retryPay() {
    _timer?.cancel();
    Navigator.pop(context);
  }

  // =======================================================
  // UI
  // =======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('付款結果', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: '切換成功/失敗（Debug）',
              icon: const Icon(Icons.tune),
              onPressed: () {
                _timer?.cancel();
                setState(() {
                  _success = !_success;
                  _loading = true;
                });
                _simulatePaymentResult();
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _loading
                  ? _buildLoading()
                  : (_success ? _buildSuccess() : _buildFail()),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 18,
              maxBlastForce: 20,
              minBlastForce: 8,
              colors: const [
                Colors.orangeAccent,
                Colors.blueAccent,
                Colors.green,
                Colors.purple,
                Colors.yellow,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =======================================================
  // 子 UI 元件
  // =======================================================
  Widget _buildLoading() => const Center(
        key: ValueKey('loading'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blueAccent),
            SizedBox(height: 16),
            Text('正在確認付款狀態…', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );

  Widget _buildSuccess() {
    return Center(
      key: const ValueKey('success'),
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 90),
              const SizedBox(height: 14),
              const Text('付款成功', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                '訂單 ${widget.orderId} 已完成付款。',
                style: TextStyle(color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$_countdown 秒後自動前往抽獎頁',
                style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _goLottery(replace: true),
                icon: const Icon(Icons.casino_outlined),
                label: const Text('立即抽獎'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _goHome(replace: true),
                child: const Text('返回首頁'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFail() {
    return Center(
      key: const ValueKey('fail'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 90),
            const SizedBox(height: 14),
            const Text('付款失敗', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              '訂單 ${widget.orderId} 付款未成功，請重新嘗試。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _retryPay,
              icon: const Icon(Icons.refresh),
              label: const Text('重新付款'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _goHome(replace: true),
              child: const Text('返回首頁'),
            ),
          ],
        ),
      ),
    );
  }
}
