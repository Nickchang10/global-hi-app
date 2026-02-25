// lib/widgets/user_info_badge.dart
//
// ✅ UserInfoBadge（Lint Clean｜不使用 withOpacity｜title 必填）
// ------------------------------------------------------------
// 用途：AppBar 顯示目前登入者資訊（title / subtitle / role / uid 可選）
// ------------------------------------------------------------

import 'package:flutter/material.dart';

class UserInfoBadge extends StatelessWidget {
  const UserInfoBadge({
    super.key,
    required this.title,
    this.subtitle,
    this.role,
    this.uid,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? role;
  final String? uid;
  final VoidCallback? onTap;

  int _a(double opacity) => (opacity * 255).round().clamp(0, 255);

  String _s(String? v) => (v ?? '').trim();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final t = _s(title).isEmpty ? '—' : _s(title);
    final sub = _s(subtitle);
    final r = _s(role);
    final id = _s(uid);

    final bg = cs.surfaceContainerHighest;
    final border = cs.outlineVariant.withAlpha(_a(0.35));

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),

          // text
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              if (sub.isNotEmpty || id.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  sub.isNotEmpty ? sub : id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),

          if (r.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                r,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: content,
      );
    }

    // 限制 badge 寬度，避免 AppBar 被撐爆
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: content,
    );
  }
}
