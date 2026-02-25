// lib/widgets/num_badge.dart
import 'package:flutter/material.dart';

class NumBadge extends StatelessWidget {
  final Widget child;
  final int value;
  final Color color;
  final double size;

  const NumBadge({
    super.key,
    required this.child,
    required this.value,
    this.color = Colors.redAccent,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (value <= 0) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            height: size,
            constraints: BoxConstraints(minWidth: size),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(size / 2),
              boxShadow: const [
                // 0.15 * 255 = 38.25 -> 38
                BoxShadow(
                  color: Color.fromARGB(38, 0, 0, 0),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Text(
                value > 99 ? '99+' : '$value',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.6,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
