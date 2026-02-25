// lib/widgets/points_push_overlay.dart
import 'dart:async';
import 'package:flutter/material.dart';

/// ======================================================
/// ✅ PointsPushOverlay（點數彈出提示 Overlay）
/// ------------------------------------------------------
/// 使用方式：
/// MaterialApp(
///   builder: (context, child) => PointsPushOverlay(
///     child: child ?? const SizedBox.shrink(),
///   ),
/// )
///
/// 任何地方呼叫：
/// PointsPushOverlay.show(
///   context,
///   points: 50,
///   title: '任務完成',
///   message: '每日簽到 +50',
/// );
/// ======================================================
class PointsPushOverlay extends StatefulWidget {
  final Widget child;

  const PointsPushOverlay({super.key, required this.child});

  /// ✅ 全域呼叫入口
  static void show(
    BuildContext context, {
    required int points,
    String? title,
    String? message,
    Duration duration = const Duration(seconds: 2),
    VoidCallback? onTap,
  }) {
    final state = context.findAncestorStateOfType<_PointsPushOverlayState>();
    state?._show(
      points: points,
      title: title,
      message: message,
      duration: duration,
      onTap: onTap,
    );
  }

  @override
  State<PointsPushOverlay> createState() => _PointsPushOverlayState();
}

class _PointsPushOverlayState extends State<PointsPushOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  OverlayEntry? _entry;
  Timer? _timer;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _removeEntry();
    _ctrl.dispose();
    super.dispose();
  }

  void _show({
    required int points,
    String? title,
    String? message,
    required Duration duration,
    VoidCallback? onTap,
  }) {
    // 若已顯示就先關掉（避免重疊）
    if (_showing) _hide(immediate: true);

    _showing = true;
    _timer?.cancel();

    _entry = OverlayEntry(
      builder: (context) {
        final topPadding = MediaQuery.of(context).padding.top;
        return Positioned(
          top: topPadding + 12,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _fade,
                child: _PointsToastCard(
                  points: points,
                  title: title,
                  message: message,
                  onTap: () {
                    onTap?.call();
                    _hide();
                  },
                  onClose: _hide,
                ),
              ),
            ),
          ),
        );
      },
    );

    // ✅ 用 maybeOf（nullable），避免 overlay 取不到時噴錯
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      _showing = false;
      _entry = null;
      return;
    }

    overlay.insert(_entry!);
    _ctrl.forward(from: 0);

    _timer = Timer(duration, _hide);
  }

  void _hide({bool immediate = false}) {
    if (!_showing) return;

    _timer?.cancel();
    _timer = null;

    if (immediate) {
      _ctrl.stop();
      _removeEntry();
      _showing = false;
      return;
    }

    _ctrl.reverse().whenComplete(() {
      _removeEntry();
      _showing = false;
    });
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _PointsToastCard extends StatelessWidget {
  final int points;
  final String? title;
  final String? message;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _PointsToastCard({
    required this.points,
    required this.title,
    required this.message,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = (title ?? '').trim();
    final m = (message ?? '').trim();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: const [
            BoxShadow(
              // ✅ 0.18 -> alpha=46
              color: Color.fromARGB(46, 0, 0, 0),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左側點數徽章
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                // ✅ 0.12 -> alpha=31
                color: cs.primary.withAlpha(31),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '+$points',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (t.isNotEmpty)
                    Text(
                      t,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    )
                  else
                    const Text(
                      '點數入帳',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  if (m.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      m,
                      style: TextStyle(color: cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              visualDensity: VisualDensity.compact,
              tooltip: '關閉',
            ),
          ],
        ),
      ),
    );
  }
}
