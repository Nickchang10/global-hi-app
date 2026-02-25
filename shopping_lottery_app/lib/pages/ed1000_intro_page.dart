// lib/pages/ed1000_intro_page.dart
//
// ✅ ED1000 產品介紹頁（修正版｜完整版｜可編譯）
// - ✅ 修正：移除 withOpacity（deprecated）→ 改用 withValues(alpha: ...)
// - ✅ 修正：_Feature / _Scenario 列表改 const（解 prefer_const_constructors）
// - ✅ 保留：GoogleFonts.getFont('Noto Sans TC', ...) 相容寫法
//
// 依賴：flutter/material, google_fonts
//

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Ed1000IntroPage extends StatelessWidget {
  const Ed1000IntroPage({
    super.key,
    this.buyRoute = '/shop',
    this.moreRoute = '/products',
  });

  /// 點「立即選購」要去的路由（你可依專案調整）
  final String buyRoute;

  /// 點「查看更多商品」要去的路由（你可依專案調整）
  final String moreRoute;

  TextStyle _font({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.getFont(
      'Noto Sans TC',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('ED1000 介紹', style: _font(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _heroCard(context, cs),
          const SizedBox(height: 14),
          Text('核心亮點', style: _font(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _featureGrid(cs),
          const SizedBox(height: 14),
          Text('適用族群', style: _font(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _audienceCard(cs),
          const SizedBox(height: 14),
          Text(
            '常見使用情境',
            style: _font(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _scenarios(cs),
          const SizedBox(height: 18),
          _ctaBar(context, cs),
        ],
      ),
    );
  }

  Widget _heroCard(BuildContext context, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withValues(alpha: 0.95),
            cs.secondaryContainer.withValues(alpha: 0.85),
          ],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.watch, color: cs.primary, size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ED1000 智慧守護錶',
                  style: _font(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '主打 SOS 求助、定位守護與日常健康提醒，讓家人更安心。',
                  style: _font(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimaryContainer.withValues(alpha: 0.9),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill(cs, Icons.sos, '一鍵 SOS'),
                    _pill(cs, Icons.location_on_outlined, '定位守護'),
                    _pill(cs, Icons.favorite_border, '健康提醒'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(ColorScheme cs, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: _font(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureGrid(ColorScheme cs) {
    // ✅ const：解 prefer_const_constructors
    const items = <_Feature>[
      _Feature(Icons.sos, 'SOS 求助', '長按/按鍵快速求救\n通知家長端'),
      _Feature(Icons.location_searching, '定位追蹤', '即時定位\n安全範圍提醒'),
      _Feature(Icons.phone_in_talk_outlined, '通話/語音', '重要聯絡人\n一鍵撥打'),
      _Feature(Icons.notifications_active_outlined, '通知提醒', '系統公告/活動\n即時推播'),
      _Feature(Icons.shield_outlined, '守護設定', '家庭成員管理\n權限分流'),
      _Feature(Icons.health_and_safety_outlined, '健康管理', '日常提醒\n關懷更貼心'),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 720;
        final cross = isNarrow ? 2 : 3;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: isNarrow ? 1.25 : 1.45,
          ),
          itemBuilder: (_, i) {
            final it = items[i];
            return Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(it.icon, color: cs.primary, size: 26),
                  const SizedBox(height: 8),
                  Text(
                    it.title,
                    style: _font(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      it.desc,
                      style: _font(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _audienceCard(ColorScheme cs) {
    final bullets = <String>[
      '國小～國中：上下學、課後活動安全守護',
      '長輩：日常外出定位與緊急聯絡',
      '需要關懷的家人：健康提醒、即時通知',
    ];

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '誰最適合 ED1000？',
              style: _font(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            const SizedBox(height: 10),
            for (final b in bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        b,
                        style: _font(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _scenarios(ColorScheme cs) {
    // ✅ const：解 prefer_const_constructors（你報的第 284 行）
    const items = <_Scenario>[
      _Scenario(Icons.school_outlined, '上學下課', '孩子遇到陌生人或迷路，可快速 SOS'),
      _Scenario(Icons.directions_walk_outlined, '外出活動', '定位查看路線，家人即時掌握'),
      _Scenario(Icons.elderly_outlined, '長輩散步', '突發狀況能立即通知家人'),
    ];

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            ListTile(
              leading: Icon(items[i].icon, color: cs.primary),
              title: Text(
                items[i].title,
                style: _font(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                items[i].desc,
                style: _font(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            if (i != items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _ctaBar(BuildContext context, ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, buyRoute),
            icon: const Icon(Icons.shopping_cart_outlined),
            label: Text('立即選購', style: _font(fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, moreRoute),
          icon: const Icon(Icons.apps_outlined),
          label: Text('查看更多商品', style: _font(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String desc;
  const _Feature(this.icon, this.title, this.desc);
}

class _Scenario {
  final IconData icon;
  final String title;
  final String desc;
  const _Scenario(this.icon, this.title, this.desc);
}
