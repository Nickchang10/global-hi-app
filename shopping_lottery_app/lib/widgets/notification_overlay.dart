// lib/widgets/notification_overlay.dart
import 'dart:async';
import 'package:flutter/material.dart';

/// ✅ NotificationOverlay（浮動通知 Overlay｜完整版｜可編譯）
/// ------------------------------------------------------------
/// 用法：
/// NotificationOverlay.instance.show(
///   context,
///   title: '成功',
///   message: '已加入購物車',
///   type: NotificationType.success,
/// );
///
/// - 使用 Overlay.maybeOf(context) 取得 overlay（可為 null）
/// - 避免不必要的 null 比較（不會再出現 unnecessary_null_comparison）
/// - withOpacity → withValues(alpha: ...)
enum NotificationType { info, success, warning, error }

class NotificationOverlay {
  NotificationOverlay._();
  static final NotificationOverlay instance = NotificationOverlay._();

  OverlayEntry? _entry;
  Timer? _timer;

  bool get isShowing => _entry != null;

  void show(
    BuildContext context, {
    String? title,
    required String message,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 2),
    bool dismissible = true,
    bool top = true,
  }) {
    // ✅ 用 maybeOf：overlay 可能拿不到（例如沒有 Overlay 的 context）
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // 若已有通知，先關掉
    hide();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final style = _styleFor(type, scheme);

    _entry = OverlayEntry(
      builder: (ctx) {
        return _ToastHost(
          top: top,
          dismissible: dismissible,
          onClose: hide,
          child: _ToastCard(
            title: title,
            message: message,
            icon: style.icon,
            background: style.background,
            border: style.border,
            iconColor: style.iconColor,
          ),
        );
      },
    );

    overlay.insert(_entry!);

    _timer?.cancel();
    _timer = Timer(duration, hide);
  }

  void hide() {
    _timer?.cancel();
    _timer = null;

    final entry = _entry;
    _entry = null;

    entry?.remove();
  }

  _ToastStyle _styleFor(NotificationType type, ColorScheme scheme) {
    switch (type) {
      case NotificationType.success:
        return _ToastStyle(
          icon: Icons.check_circle_rounded,
          iconColor: scheme.primary,
          background: scheme.surface,
          border: scheme.primary.withValues(alpha: 0.22),
        );

      case NotificationType.warning:
        return _ToastStyle(
          icon: Icons.warning_amber_rounded,
          iconColor: scheme.tertiary,
          background: scheme.surface,
          border: scheme.tertiary.withValues(alpha: 0.22),
        );

      case NotificationType.error:
        return _ToastStyle(
          icon: Icons.error_rounded,
          iconColor: scheme.error,
          background: scheme.surface,
          border: scheme.error.withValues(alpha: 0.22),
        );

      // ✅ enum 已完整覆蓋，所以不要 default（避免 unreachable_switch_default）
      case NotificationType.info:
        return _ToastStyle(
          icon: Icons.info_rounded,
          iconColor: scheme.secondary,
          background: scheme.surface,
          border: scheme.secondary.withValues(alpha: 0.22),
        );
    }
  }
}

class _ToastStyle {
  const _ToastStyle({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.border,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
  final Color border;
}

class _ToastHost extends StatefulWidget {
  const _ToastHost({
    required this.child,
    required this.onClose,
    required this.top,
    required this.dismissible,
  });

  final Widget child;
  final VoidCallback onClose;
  final bool top;
  final bool dismissible;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final align = widget.top ? Alignment.topCenter : Alignment.bottomCenter;

    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        child: Align(
          alignment: align,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: widget.top
                          ? const Offset(0, -0.15)
                          : const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
                    ),
                child: widget.dismissible
                    ? GestureDetector(
                        onTap: widget.onClose,
                        child: widget.child,
                      )
                    : widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.message,
    required this.icon,
    required this.background,
    required this.border,
    required this.iconColor,
    this.title,
  });

  final String? title;
  final String message;

  final IconData icon;
  final Color background;
  final Color border;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null && title!.trim().isNotEmpty) ...[
                        Text(
                          title!,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
