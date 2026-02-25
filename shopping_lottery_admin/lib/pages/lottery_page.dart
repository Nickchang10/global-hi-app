// lib/pages/lottery_page.dart
//
// ✅ LotteryPage（完整版・最終可編譯強化版 v2）
//
// 路由：/lottery
// - 參數：arguments 可為 String(orderId) 或 {orderId: ...}
// - 監聽 orders/{orderId} + LotteryService.streamLottery(orderId)
// - 若符合資格（已付款 paid 或貨到付款 cod/codPending），可抽獎（每單一次）
// - 抽獎結果可從：
//   A) LotteryService 回傳/串流 LotteryResult
//   B) orders/{orderId}.lottery（容錯讀取不同 schema）
// - 中獎顯示優惠碼 + 一次性彩帶效果（不依賴第三方套件）
//
// 依賴：cloud_firestore, provider, flutter/services, services/lottery_service.dart

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/lottery_service.dart'; // ✅ 包含 LotteryResult class

class LotteryPage extends StatefulWidget {
  const LotteryPage({super.key});

  @override
  State<LotteryPage> createState() => _LotteryPageState();
}

class _LotteryPageState extends State<LotteryPage>
    with TickerProviderStateMixin {
  bool _drawing = false;
  String? _error;
  AnimationController? _confettiCtrl;
  bool _celebrated = false;

  // --------------------------------------------------------
  // Helpers
  // --------------------------------------------------------
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

  Future<void> _copy(String text, {String? done}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    _snack(done ?? '已複製');
  }

  @override
  void dispose() {
    _confettiCtrl?.dispose();
    super.dispose();
  }

  void _playConfetti() {
    _confettiCtrl?.dispose();

    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // ✅ setState 讓彩帶層一定重建出現
    if (mounted) {
      setState(() => _confettiCtrl = ctrl);
    } else {
      _confettiCtrl = ctrl;
    }

    ctrl.forward();

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _confettiCtrl?.stop();
    });
  }

  Future<void> _draw(String orderId) async {
    if (_drawing) return;
    setState(() {
      _drawing = true;
      _error = null;
    });

    try {
      final svc = context.read<LotteryService>();
      final r = await svc.drawOnce(orderId);
      if (!mounted) return;

      setState(() => _drawing = false);

      final status = (r.status).toString().toLowerCase();
      if (status == 'won') {
        _celebrated = true;
        _playConfetti();
        _snack('恭喜中獎！');
      } else {
        _snack('已完成抽獎（未中獎）');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _drawing = false;
        _error = '$e';
      });
    }
  }

  // --------------------------------------------------------
  // Firestore helpers
  // --------------------------------------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();

  Map<String, dynamic> _asMap(dynamic v) => (v is Map<String, dynamic>)
      ? v
      : (v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{});

  bool _isEligibleByOrder(Map<String, dynamic> order) {
    final status = _s(order['status']).toLowerCase();
    final payment = _asMap(order['payment']);
    final pStatus = _s(payment['status']).toLowerCase();
    final provider = _s(payment['provider']).toLowerCase();
    final method = _s(payment['method']).toLowerCase();

    final isPaid =
        ['paid', 'success', 'succeeded'].contains(pStatus) || status == 'paid';
    final isCod =
        pStatus == 'cod' ||
        provider == 'cod' ||
        method == 'cash' ||
        status.contains('cod');

    return isPaid || isCod;
  }

  // --------------------------------------------------------
  // UI
  // --------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final orderId = _orderIdFromArgs(context);
    if (orderId.isEmpty) {
      return const Scaffold(body: Center(child: Text('缺少 orderId')));
    }

    final svc = context.read<LotteryService>();
    final err = _error; // ✅ 避免 _error! 與 field promotion 問題
    final confetti = _confettiCtrl; // ✅ 避免 _confettiCtrl! 的多餘 `!`

    return Scaffold(
      appBar: AppBar(
        title: const Text('抽獎'),
        actions: [
          IconButton(
            tooltip: '複製訂單號',
            onPressed: () => _copy(orderId, done: '已複製訂單號'),
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .doc(orderId)
                .snapshots(),
            builder: (context, orderSnap) {
              final order = orderSnap.data?.data() ?? <String, dynamic>{};
              final eligible = _isEligibleByOrder(order);

              return StreamBuilder<LotteryResult?>(
                stream: svc.streamLottery(orderId),
                builder: (context, snap) {
                  final result = snap.data;

                  if (result?.status.toLowerCase() == 'won' && !_celebrated) {
                    _celebrated = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _playConfetti();
                    });
                  }

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView(
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          '訂單：$orderId',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),

                        if (err != null)
                          Text(err, style: const TextStyle(color: Colors.red)),

                        if (!eligible)
                          const Text(
                            '⚠️ 尚未付款或貨到付款未生效，暫不可抽獎。',
                            style: TextStyle(color: Colors.redAccent),
                          )
                        else if (result == null)
                          FilledButton.icon(
                            onPressed: _drawing ? null : () => _draw(orderId),
                            icon: _drawing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.casino_outlined),
                            label: Text(_drawing ? '抽獎中...' : '立即抽獎'),
                          )
                        else
                          _ResultCard(result: result, onCopy: _copy),

                        const SizedBox(height: 20),

                        FilledButton.icon(
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            '/order_complete',
                            arguments: {'orderId': orderId},
                          ),
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('回訂單完成頁'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            '/dashboard',
                          ),
                          icon: const Icon(Icons.home_outlined),
                          label: const Text('回首頁'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          if (confetti != null)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: confetti,
                builder: (_, __) => CustomPaint(
                  painter: _ConfettiPainter(progress: confetti.value),
                  size: Size.infinite,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------
// 子元件：結果卡片 + 彩帶
// --------------------------------------------------------
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onCopy});
  final LotteryResult result;
  final Future<void> Function(String text, {String? done}) onCopy;

  @override
  Widget build(BuildContext context) {
    final won = result.status.toLowerCase() == 'won';
    final code = (result.couponCode ?? '').trim();

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  won
                      ? Icons.emoji_events_outlined
                      : Icons.sentiment_neutral_outlined,
                  color: won ? Colors.orange : Colors.grey,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  won ? '恭喜中獎！' : '銘謝惠顧',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('結果：${result.prizeName}'),
            if (won && code.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black12),
                        // ✅ FIX: withOpacity(0.03) -> withValues(alpha: 8)
                        // 0.03 * 255 = 7.65 ≈ 8
                        color: Colors.black.withValues(alpha: 8),
                      ),
                      child: Text(
                        code,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => onCopy(code, done: '已複製優惠碼'),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('複製'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------
// 彩帶動畫（無第三方套件）
// --------------------------------------------------------
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final t = Curves.easeOut.transform(progress);
    const n = 100;
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.pink,
      Colors.purple,
    ];

    for (var i = 0; i < n; i++) {
      final r = Random(i * 991);
      final x = r.nextDouble() * size.width;
      final y = (r.nextDouble() * size.height * t) - 100;
      final w = 4 + r.nextDouble() * 6;
      final h = 8 + r.nextDouble() * 12;

      // ✅ FIX: withOpacity(0.85) -> withValues(alpha: 217)
      // 0.85 * 255 = 216.75 ≈ 217
      final c = colors[r.nextInt(colors.length)].withValues(alpha: 217);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((r.nextDouble() - 0.5) * 1.6);
      final paint = Paint()..color = c;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-w / 2, -h / 2, w, h),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
