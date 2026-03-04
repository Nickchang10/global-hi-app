import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../router_adapter.dart';

class LotteryRevealPage extends StatefulWidget {
  const LotteryRevealPage({
    super.key,
    required this.id,
  });

  final String id;

  @override
  State<LotteryRevealPage> createState() => _LotteryRevealPageState();
}

enum _RevealResult { won, lost }

class _LotteryRevealPageState extends State<LotteryRevealPage> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  _RevealResult? _result;
  Timer? _startTimer;
  Timer? _finishTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _startTimer = Timer(const Duration(milliseconds: 500), () {
      _finishTimer = Timer(const Duration(seconds: 3), () {
        final state = context.read<AppState>();
        final status = state.revealLottery(widget.id, winRate: 0.1);

        final won = status == LotteryStatus.won;
        setState(() => _result = won ? _RevealResult.won : _RevealResult.lost);

        _controller?.stop();
      });
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _finishTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lottery = lotteries.where((l) => l.id == widget.id).cast<Lottery?>().firstWhere((e) => e != null, orElse: () => null);

    if (lottery == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('抽獎活動不存在'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('返回首頁'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _result == null
                    ? _RevealingView(controller: _controller!, lotteryName: lottery.name)
                    : _ResultView(lottery: lottery, result: _result!),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RevealingView extends StatelessWidget {
  const _RevealingView({
    required this.controller,
    required this.lotteryName,
  });

  final AnimationController controller;
  final String lotteryName;

  @override
  Widget build(BuildContext context) {
    final rotation = Tween<double>(begin: 0, end: 2 * pi).animate(CurvedAnimation(parent: controller, curve: Curves.linear));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final t = controller.value;
            final scale = 1 + 0.2 * sin(t * 2 * pi);
            return Transform.rotate(
              angle: rotation.value,
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            );
          },
          child: const Icon(Icons.emoji_events, size: 96, color: Colors.white),
        ),
        const SizedBox(height: 16),
        const Text('開獎中...', style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(lotteryName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.white70)),
        const SizedBox(height: 24),
        const _DotLoading(),
      ],
    );
  }
}

class _DotLoading extends StatefulWidget {
  const _DotLoading();

  @override
  State<_DotLoading> createState() => _DotLoadingState();
}

class _DotLoadingState extends State<_DotLoading> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = (t + i * 0.2) % 1.0;
            final y = -12 * sin(phase * 2 * pi);
            final opacity = 0.5 + 0.5 * sin(phase * 2 * pi).abs();
            return Opacity(
              opacity: opacity.clamp(0.3, 1.0),
              child: Transform.translate(
                offset: Offset(0, y),
                child: Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.lottery,
    required this.result,
  });

  final Lottery lottery;
  final _RevealResult result;

  @override
  Widget build(BuildContext context) {
    final won = result == _RevealResult.won;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (won) ...[
              const Icon(Icons.emoji_events, size: 120, color: Colors.amber),
              const SizedBox(height: 10),
              const Text('🎉 恭喜中獎！', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.green)),
              const SizedBox(height: 8),
              Text(lottery.prize, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('價值 ${formatTwd(lottery.prizeValue)}', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 10),
              const Text('我們會盡快與您聯繫領獎事宜', style: TextStyle(color: Colors.black45, fontSize: 12)),
            ] else ...[
              const Text('😔', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 10),
              const Text('很遺憾', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black54)),
              const SizedBox(height: 8),
              const Text('這次沒有中獎，下次再接再厲！', style: TextStyle(color: Colors.black54)),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => context.go('/store_lottery_history/${lottery.id}'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
              child: const SizedBox(
                width: double.infinity,
                height: 44,
                child: Center(child: Text('查看抽獎記錄', style: TextStyle(fontWeight: FontWeight.w700))),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.go('/'),
              child: const SizedBox(
                width: double.infinity,
                height: 44,
                child: Center(child: Text('返回首頁', style: TextStyle(fontWeight: FontWeight.w700))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
