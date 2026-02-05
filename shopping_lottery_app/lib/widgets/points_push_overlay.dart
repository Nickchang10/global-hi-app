// lib/widgets/points_push_overlay.dart

import 'package:flutter/material.dart';
import '../utils/haptic_audio_feedback.dart';

/// 💬 積分推播模擬小元件（動畫提示）
///
/// 在任何頁面呼叫：
///
/// PointsPushOverlay.show(
///   context,
///   title: "任務完成 🎯",
///   message: "您獲得了 50 積分！",
///   icon: Icons.star,
///   color: Colors.blueAccent,
/// );
///
class PointsPushOverlay {
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.notifications_active,
    Color color = Colors.blueAccent,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _PushBubble(
        title: title,
        message: message,
        icon: icon,
        color: color,
        duration: duration,
        onClose: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _PushBubble extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final Duration duration;
  final VoidCallback onClose;

  const _PushBubble({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.duration,
    required this.onClose,
  });

  @override
  State<_PushBubble> createState() => _PushBubbleState();
}

class _PushBubbleState extends State<_PushBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offset;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offset =
        Tween(begin: const Offset(0, -1.2), end: const Offset(0, 0)).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacity = Tween(begin: 0.0, end: 1.0).animate(_controller);

    // 一出現就給觸覺 + 音效回饋
    HapticAudioFeedback.feedback();

    _controller.forward();

    Future.delayed(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      widget.onClose();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _offset,
        child: FadeTransition(
          opacity: _opacity,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.color.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: widget.color,
                    child: Icon(widget.icon, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
