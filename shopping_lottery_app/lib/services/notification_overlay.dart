import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

/// 🔔 動態推播顯示（滑入 + 聲音提示）
class NotificationOverlay {
  static final NotificationOverlay _instance = NotificationOverlay._internal();
  factory NotificationOverlay() => _instance;
  NotificationOverlay._internal();

  OverlayEntry? _overlay;
  final AudioPlayer _player = AudioPlayer();

  /// 顯示推播通知
  void show({
    required BuildContext context,
    required String title,
    required String message,
    IconData icon = Icons.notifications,
    Duration duration = const Duration(seconds: 3),
  }) async {
    // 若已有通知，先移除
    _overlay?.remove();

    final overlay = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 20,
        right: 20,
        child: _AnimatedNotificationCard(
          title: title,
          message: message,
          icon: icon,
          onClose: () => _overlay?.remove(),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);
    _overlay = overlay;

    // 🔊 播放提示音
    try {
      await _player.play(AssetSource('sounds/notify.mp3'));
    } catch (_) {}

    // ⏳ 自動關閉
    Future.delayed(duration, () {
      overlay.remove();
      _overlay = null;
    });
  }
}

/// 動畫通知卡元件
class _AnimatedNotificationCard extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback onClose;

  const _AnimatedNotificationCard({
    required this.title,
    required this.message,
    required this.icon,
    required this.onClose,
  });

  @override
  State<_AnimatedNotificationCard> createState() =>
      _AnimatedNotificationCardState();
}

class _AnimatedNotificationCardState extends State<_AnimatedNotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1.0), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fadeAnimation =
        Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          child: ListTile(
            leading: Icon(widget.icon, color: const Color(0xFF007BFF), size: 36),
            title: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF007BFF),
              ),
            ),
            subtitle: Text(widget.message),
            trailing: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: widget.onClose,
            ),
          ),
        ),
      ),
    );
  }
}
