import 'package:flutter/material.dart';
import 'dart:math';

/// 🎉 金幣飄散動畫 + 成就提示
class CoinRewardPopup extends StatefulWidget {
  final int points;
  final String message;
  const CoinRewardPopup({super.key, required this.points, required this.message});

  @override
  State<CoinRewardPopup> createState() => _CoinRewardPopupState();
}

class _CoinRewardPopupState extends State<CoinRewardPopup>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<_CoinParticle> _coins = [];

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..addListener(() => setState(() {}))
          ..forward();

    // 建立金幣粒子
    final random = Random();
    for (int i = 0; i < 20; i++) {
      _coins.add(_CoinParticle(
        dx: random.nextDouble() * 200 - 100,
        dy: random.nextDouble() * 100 - 50,
        scale: 0.5 + random.nextDouble(),
      ));
    }

    // 自動關閉
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 半透明背景
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(color: Colors.black54),
        ),

        // 中間彈窗
        ScaleTransition(
          scale: CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.emoji_events,
                  color: Colors.amber, size: 60),
              const SizedBox(height: 12),
              Text(
                "恭喜獲得 ${widget.points} 積分！",
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.pinkAccent),
              ),
              const SizedBox(height: 6),
              Text(widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ]),
          ),
        ),

        // 金幣飄散特效
        ..._coins.map((c) {
          final progress = Curves.easeOut.transform(_controller.value);
          return Transform.translate(
            offset: Offset(c.dx * progress, c.dy * progress - progress * 100),
            child: Transform.scale(
              scale: 1.0 - progress * 0.5,
              child: const Icon(Icons.circle, color: Colors.amber, size: 16),
            ),
          );
        }),
      ],
    );
  }
}

class _CoinParticle {
  final double dx;
  final double dy;
  final double scale;
  _CoinParticle({required this.dx, required this.dy, required this.scale});
}
