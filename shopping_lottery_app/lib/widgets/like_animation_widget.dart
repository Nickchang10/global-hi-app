import 'package:flutter/material.dart';

/// ❤️ 按讚縮放動畫小元件
///
/// 用法：
/// LikeAnimation(
///   isAnimating: isLiked,
///   child: IconButton(
///     icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
///     onPressed: onTap,
///   ),
/// )
class LikeAnimation extends StatefulWidget {
  /// 是否啟動動畫（從 false -> true 時會播放一次）
  final bool isAnimating;

  /// 要被套用動畫的子元件（通常是 Icon 或 Button）
  final Widget child;

  /// 動畫時間（預設 250ms）
  final Duration duration;

  /// 動畫結束時的回呼（可選）
  final VoidCallback? onEnd;

  const LikeAnimation({
    super.key,
    required this.isAnimating,
    required this.child,
    this.duration = const Duration(milliseconds: 250),
    this.onEnd,
  });

  @override
  State<LikeAnimation> createState() => _LikeAnimationState();
}

class _LikeAnimationState extends State<LikeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scale = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant LikeAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 只有在 isAnimating 從 false -> true 時才觸發動畫
    if (widget.isAnimating && !oldWidget.isAnimating) {
      _controller.forward().then((_) async {
        await _controller.reverse();
        if (widget.onEnd != null) {
          widget.onEnd!();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
