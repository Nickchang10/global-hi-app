// lib/widgets/notification_overlay.dart
import 'package:flutter/material.dart';
import 'package:osmile_shopping_app/utils/haptic_audio_feedback.dart';

/// 💬 即時推播浮動通知（全螢幕動畫）
///
/// 功能：
/// - 顯示於任何頁面頂端
/// - 支援自動消失、震動、動畫進出
/// - 點擊可觸發自訂事件
class NotificationOverlay {
  static OverlayEntry? _currentOverlay;

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.notifications,
    Color color = Colors.blueAccent,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    _remove(); // 移除舊通知
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (_) => _NotificationOverlayWidget(
        title: title,
        message: message,
        icon: icon,
        color: color,
        duration: duration,
        onTap: () {
          onTap?.call();
          _remove();
        },
        onDismiss: _remove,
      ),
    );

    _currentOverlay = entry;
    overlay.insert(entry);
    HapticAudioFeedback.success();
  }

  static void _remove() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

class _NotificationOverlayWidget extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final Duration duration;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationOverlayWidget({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.duration,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_NotificationOverlayWidget> createState() =>
      _NotificationOverlayWidgetState();
}

class _NotificationOverlayWidgetState
    extends State<_NotificationOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _offset = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
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
      top: 40,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _offset,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.color.withOpacity(0.95),
                    widget.color.withOpacity(0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(widget.icon, color: widget.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          widget.message,
                          style: const TextStyle(color: Colors.white70),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
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
