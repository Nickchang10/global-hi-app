// lib/pages/about_company_page.dart
//
// ✅ AboutCompanyPage（最終完整版｜可直接使用｜可編譯｜已移除 withOpacity）
// ------------------------------------------------------------
// - Flutter 3.27+：Color.withOpacity() 已 deprecated → 改用 withValues(alpha: ...)
// - 提供公司簡介 / 聯絡資訊 / 服務時間 / 版本資訊 / 授權資訊
// - 內建一鍵複製（電話/Email/地址）
//
// 若你專案已有共用的 AdminAppBar / AdminScaffold，可自行替換 Scaffold/AppBar。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AboutCompanyPage extends StatelessWidget {
  const AboutCompanyPage({super.key});

  static const String routeName = '/about-company';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final surface = cs.surface;
    final border = cs.outlineVariant.withValues(alpha: 0.35);
    final subtle = cs.onSurface.withValues(alpha: 0.08);
    final textSubtle = cs.onSurface.withValues(alpha: 0.72);

    return Scaffold(
      appBar: AppBar(title: const Text('關於公司'), centerTitle: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderCard(
                surface: surface,
                border: border,
                subtle: subtle,
                title: 'Osmile',
                subtitle: '智慧穿戴｜關懷服務｜雲端平台',
                badge: 'Admin',
              ),
              const SizedBox(height: 12),

              _SectionCard(
                border: border,
                title: '公司簡介',
                icon: Icons.apartment_rounded,
                child: Text(
                  'Osmile 致力於提供智慧穿戴與照護整合服務，包含 SOS 求助通知、定位追蹤、'
                  '健康數據整合與會員系統，協助家庭與機構更安心地守護重要的人。',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              ),
              const SizedBox(height: 12),

              _SectionCard(
                border: border,
                title: '聯絡資訊',
                icon: Icons.support_agent_rounded,
                child: Column(
                  children: [
                    _CopyRow(
                      label: '客服電話',
                      value: '02-1234-5678',
                      hint: '點擊複製',
                      valueStyle: theme.textTheme.titleSmall,
                      hintStyle: theme.textTheme.bodySmall?.copyWith(
                        color: textSubtle,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _CopyRow(
                      label: '客服信箱',
                      value: 'support@osmile.com.tw',
                      hint: '點擊複製',
                      valueStyle: theme.textTheme.titleSmall,
                      hintStyle: theme.textTheme.bodySmall?.copyWith(
                        color: textSubtle,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _CopyRow(
                      label: '公司地址',
                      value: '台北市（請替換成你們正式地址）',
                      hint: '點擊複製',
                      valueStyle: theme.textTheme.titleSmall,
                      hintStyle: theme.textTheme.bodySmall?.copyWith(
                        color: textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _SectionCard(
                border: border,
                title: '服務時間',
                icon: Icons.schedule_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bullet(text: '週一至週五：09:00 - 18:00', color: textSubtle),
                    const SizedBox(height: 6),
                    _Bullet(text: '例假日：依公告與客服值班為準', color: textSubtle),
                    const SizedBox(height: 6),
                    _Bullet(text: '緊急事件：依產品/合約支援方案', color: textSubtle),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _SectionCard(
                border: border,
                title: '版本資訊',
                icon: Icons.info_outline_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KeyValue(
                      k: 'App',
                      v: 'shopping_lottery_admin',
                      vColor: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(height: 6),
                    _KeyValue(
                      k: '環境',
                      v: 'Flutter 3.27+（Color API wide-gamut）',
                      vColor: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(height: 6),
                    _KeyValue(
                      k: '備註',
                      v: '已將 withOpacity 全面替換為 withValues(alpha: ...)',
                      vColor: theme.colorScheme.onSurface,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _SectionCard(
                border: border,
                title: '授權資訊',
                icon: Icons.article_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '此頁面提供快速查看與複製資訊；授權清單可在系統授權頁查看。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textSubtle,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => showLicensePage(context: context),
                      child: const Text('查看 Licenses'),
                    ),
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

class _HeaderCard extends StatelessWidget {
  final Color surface;
  final Color border;
  final Color subtle;
  final String title;
  final String subtitle;
  final String badge;

  const _HeaderCard({
    required this.surface,
    required this.border,
    required this.subtle,
    required this.title,
    required this.subtitle,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: subtle,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.health_and_safety_rounded, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.75),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
            ),
            child: Text(
              badge,
              style: theme.textTheme.labelMedium?.copyWith(color: cs.primary),
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

class _CopyRow extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final TextStyle? valueStyle;
  final TextStyle? hintStyle;

  const _CopyRow({
    required this.label,
    required this.value,
    required this.hint,
    this.valueStyle,
    this.hintStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已複製：$label'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 88,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.70),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: valueStyle ?? theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(hint, style: hintStyle ?? theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.copy_rounded,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ],
        ),
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

class _KeyValue extends StatelessWidget {
  final String k;
  final String v;
  final Color vColor;

  const _KeyValue({required this.k, required this.v, required this.vColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            k,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.70),
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: vColor,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
