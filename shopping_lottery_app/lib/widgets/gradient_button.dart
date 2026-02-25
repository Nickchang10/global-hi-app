// lib/widgets/gradient_button.dart
import 'package:flutter/material.dart';

class GradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final double borderRadius;
  final EdgeInsets padding;
  final double elevation;

  const GradientButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.gradient = const LinearGradient(
      colors: [Color(0xFF2F80ED), Color(0xFF56CCF2)],
    ),
    this.borderRadius = 12,
    this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
    this.elevation = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: elevation,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding,
          decoration:
              BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: const [
                  BoxShadow(
                    // ✅ withOpacity(0.12) -> alpha 31 (0.12 * 255 ≈ 31)
                    color: Colors.black, // base color (alpha applied below)
                    blurRadius: 10,
                    offset: Offset(0, 6),
                  ),
                ],
              ).copyWith(
                // 這段是為了保持 boxShadow const 結構，同時套 alpha
                boxShadow: [
                  const BoxShadow(
                    blurRadius: 10,
                    offset: Offset(0, 6),
                  ).copyWith(color: Colors.black.withValues(alpha: 31)),
                ],
              ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
