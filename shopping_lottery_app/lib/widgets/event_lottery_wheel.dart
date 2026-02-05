import 'dart:math';
import 'package:flutter/material.dart';

class EventLotteryWheel extends StatefulWidget {
  final List<String> prizes;
  final VoidCallback? onStart;
  final Function(String prize)? onEnd;

  const EventLotteryWheel({
    super.key,
    required this.prizes,
    this.onStart,
    this.onEnd,
  });

  @override
  State<EventLotteryWheel> createState() => _EventLotteryWheelState();
}

class _EventLotteryWheelState extends State<EventLotteryWheel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _angle = 0.0;
  double _target = 0.0;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..addListener(() {
        setState(() {
          _angle = _controller.value * _target;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 🌀 開始轉盤動畫
  void _spin() {
    if (_spinning) return;

    widget.onStart?.call();

    final random = Random();
    final prizeIndex = random.nextInt(widget.prizes.length);
    final perSegment = 2 * pi / widget.prizes.length;
    final stopAngle = (widget.prizes.length - prizeIndex) * perSegment;

    _target = (12 * 2 * pi) + stopAngle + random.nextDouble() * 0.1;

    _controller
      ..reset()
      ..forward().then((_) {
        setState(() => _spinning = false);
        widget.onEnd?.call(widget.prizes[prizeIndex]);
      });

    setState(() => _spinning = true);
  }

  @override
  Widget build(BuildContext context) {
    final prizeCount = widget.prizes.length;
    final sweep = 2 * pi / prizeCount;

    return Stack(
      alignment: Alignment.center,
      children: [
        // 🎡 彩色轉盤
        CustomPaint(
          size: const Size(300, 300),
          painter: _WheelPainter(prizeCount: prizeCount, sweep: sweep),
          child: Transform.rotate(
            angle: _angle,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (int i = 0; i < prizeCount; i++)
                  Transform.rotate(
                    angle: i * sweep + sweep / 2,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(
                          widget.prizes[i],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 🎯 指針
        Positioned(
          top: 8,
          child: Icon(Icons.arrow_drop_down, size: 40, color: Colors.red[700]),
        ),

        // ▶️ 抽獎按鈕
        GestureDetector(
          onTap: _spinning ? null : _spin,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _spinning ? Colors.grey : Colors.redAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ],
            ),
            child: const Center(
              child: Text(
                "抽獎",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  final int prizeCount;
  final double sweep;

  _WheelPainter({required this.prizeCount, required this.sweep});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final paint = Paint()..style = PaintingStyle.fill;

    final colors = [
      Colors.orange,
      Colors.pink,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.amber,
    ];

    for (int i = 0; i < prizeCount; i++) {
      paint.color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep,
        sweep,
        true,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
