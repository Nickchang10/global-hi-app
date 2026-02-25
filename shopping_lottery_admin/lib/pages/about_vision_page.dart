// lib/pages/about_vision_page.dart
//
// ✅ AboutVisionPage（最終完整版｜可直接使用｜可編譯｜已移除 withOpacity）
// ------------------------------------------------------------
// - Flutter 3.27+：Color.withOpacity() 已 deprecated → 改用 withValues(alpha: ...)
// - 願景/使命/價值/里程碑/產品方向 的簡介頁
//

import 'package:flutter/material.dart';

class AboutVisionPage extends StatelessWidget {
  const AboutVisionPage({super.key});

  static const String routeName = '/about-vision';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final border = cs.outlineVariant.withValues(alpha: 0.35);
    final subtle = cs.onSurface.withValues(alpha: 0.08);
    final shadow = cs.shadow.withValues(alpha: 0.08);
    final subText = cs.onSurface.withValues(alpha: 0.72);

    return Scaffold(
      appBar: AppBar(title: const Text('品牌願景'), centerTitle: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroCard(
                border: border,
                shadow: shadow,
                subtle: subtle,
                title: 'Osmile Vision',
                subtitle: '用科技把「安心」變成日常',
                chips: const ['智慧穿戴', '照護整合', '雲端平台'],
              ),
              const SizedBox(height: 12),

              _SectionCard(
                border: border,
                title: '願景 Vision',
                icon: Icons.visibility_outlined,
                child: Text(
                  '建立一個以人為核心的照護生態系，讓每個家庭與機構都能即時掌握狀態、'
                  '快速求助、有效溝通，並用資料驅動更好的照護決策。',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              ),
              const SizedBox(height: 12),

              _SectionCard(
                border: border,
                title: '使命 Mission',
                icon: Icons.flag_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bullet(text: '以可靠的 SOS 求助與通知，縮短風險反應時間', color: subText),
                    const SizedBox(height: 6),
                    _Bullet(text: '整合定位、健康與行為資料，讓照護更有依據', color: subText),
                    const SizedBox(height: 6),
                    _Bullet(text: '提供透明的服務流程與可追溯紀錄，提升信任', color: subText),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _SectionCard(
                border: border,
                title: '核心價值 Values',
                icon: Icons.favorite_outline_rounded,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ValuePill(
                      text: '安全 Safety',
                      bg: cs.primary.withValues(alpha: 0.10),
                      fg: cs.primary,
                      bd: cs.primary.withValues(alpha: 0.22),
                    ),
                    _ValuePill(
                      text: '可信賴 Reliability',
                      bg: cs.tertiary.withValues(alpha: 0.10),
                      fg: cs.tertiary,
                      bd: cs.tertiary.withValues(alpha: 0.22),
                    ),
                    _ValuePill(
                      text: '同理 Empathy',
                      bg: cs.secondary.withValues(alpha: 0.10),
                      fg: cs.secondary,
                      bd: cs.secondary.withValues(alpha: 0.22),
                    ),
                    _ValuePill(
                      text: '效率 Efficiency',
                      bg: cs.error.withValues(alpha: 0.08),
                      fg: cs.error,
                      bd: cs.error.withValues(alpha: 0.20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _SectionCard(
                border: border,
                title: '產品方向 Product Direction',
                icon: Icons.route_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DirItem(
                      title: '即時求助與通知',
                      desc: '手錶一鍵 SOS、家長/管理端即時通知、事件追蹤閉環。',
                      icon: Icons.sos_rounded,
                    ),
                    const SizedBox(height: 10),
                    _DirItem(
                      title: '定位與軌跡',
                      desc: '地理圍欄、歷史軌跡、異常停留提醒。',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 10),
                    _DirItem(
                      title: '健康與行為資料',
                      desc: '以資料為基礎的照護洞察，支援報表與趨勢觀察。',
                      icon: Icons.monitor_heart_outlined,
                    ),
                    const SizedBox(height: 10),
                    _DirItem(
                      title: '服務與工單流程',
                      desc: '從問題回報到處理結案，透明、可追溯。',
                      icon: Icons.support_agent_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _SectionCard(
                border: border,
                title: '里程碑 Milestones',
                icon: Icons.timeline_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _Milestone(year: '2024', text: '完成核心照護模組整合（SOS/通知/定位）'),
                    _Milestone(year: '2025', text: '導入管理後台與活動/優惠券系統'),
                    _Milestone(year: '2026', text: '擴充機構端流程、報表與更完整的服務串接'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Color border;
  final Color shadow;
  final Color subtle;
  final String title;
  final String subtitle;
  final List<String> chips;

  const _HeroCard({
    required this.border,
    required this.shadow,
    required this.subtle,
    required this.title,
    required this.subtitle,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(color: shadow, blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: subtle,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.75),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chips
                      .map(
                        (c) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Text(
                            c,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: cs.primary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Color border;
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.border,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  final Color color;

  const _Bullet({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ValuePill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final Color bd;

  const _ValuePill({
    required this.text,
    required this.bg,
    required this.fg,
    required this.bd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bd),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(color: fg),
      ),
    );
  }
}

class _DirItem extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;

  const _DirItem({required this.title, required this.desc, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.75),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Milestone extends StatelessWidget {
  final String year;
  final String text;

  const _Milestone({required this.year, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
            ),
            child: Text(
              year,
              style: theme.textTheme.labelMedium?.copyWith(color: cs.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.78),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
