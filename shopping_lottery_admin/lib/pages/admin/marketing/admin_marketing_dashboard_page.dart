// lib/pages/admin/marketing/admin_marketing_dashboard_page.dart
//
// ✅ AdminMarketingDashboardPage（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// ✅ 修正：移除未使用的 intl import（不再 unused_import）
// ✅ 功能：
//   - KPI（啟用中的自動活動數 / 抽獎活動數 / 未發放中獎數）
//   - 快速入口：
//       1) AI 活動洞察
//       2) 新增自動活動
//       3) 自動活動報表
//       4) 新增抽獎活動
//       5) 抽獎中獎名單
//
// 依賴：cloud_firestore, flutter/material
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// 這些頁面你前面已經在專案中建立（若路徑不同自行改）
import 'admin_ai_campaign_insight_page.dart';
import 'admin_auto_campaign_edit_page.dart';
import 'admin_auto_campaign_reports_page.dart';
import 'admin_lottery_edit_page.dart';
import 'admin_lottery_winners_page.dart';

class AdminMarketingDashboardPage extends StatelessWidget {
  const AdminMarketingDashboardPage({super.key});

  // 依你的 Firestore 命名調整
  static const String _colAutoCampaigns = 'auto_campaigns';
  static const String _colAutoReports = 'auto_campaign_reports';
  static const String _colLotteries = 'lotteries';
  static const String _colLotteryWinners = 'lottery_winners';
  static const String _colAiInsights = 'ai_campaign_insights';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('行銷儀表板')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'KPI',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _kpiRow(context),
          const SizedBox(height: 18),

          Text(
            '快速入口',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _quickActions(context),
          const SizedBox(height: 18),

          Text(
            '資料集合（debug）',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _collectionInfoCard(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _kpiRow(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final crossAxisCount = w >= 900
            ? 4
            : w >= 600
            ? 3
            : 2;

        final tiles = <Widget>[
          _KpiTile(
            title: '啟用中的自動活動',
            icon: Icons.auto_awesome,
            stream: FirebaseFirestore.instance
                .collection(_colAutoCampaigns)
                .where('enabled', isEqualTo: true)
                .snapshots(),
            valueBuilder: (snap) => snap.docs.length.toString(),
            subtitleBuilder: (_) => 'enabled=true',
          ),
          _KpiTile(
            title: '自動活動報表筆數',
            icon: Icons.analytics,
            stream: FirebaseFirestore.instance
                .collection(_colAutoReports)
                .snapshots(),
            valueBuilder: (snap) => snap.docs.length.toString(),
            subtitleBuilder: (_) => _colAutoReports,
          ),
          _KpiTile(
            title: '抽獎活動數',
            icon: Icons.casino,
            stream: FirebaseFirestore.instance
                .collection(_colLotteries)
                .snapshots(),
            valueBuilder: (snap) => snap.docs.length.toString(),
            subtitleBuilder: (_) => _colLotteries,
          ),
          _KpiTile(
            title: '未發放中獎數',
            icon: Icons.card_giftcard,
            stream: FirebaseFirestore.instance
                .collection(_colLotteryWinners)
                .where('fulfilled', isEqualTo: false)
                .snapshots(),
            valueBuilder: (snap) => snap.docs.length.toString(),
            subtitleBuilder: (_) => 'fulfilled=false',
          ),
        ];

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.6,
          children: tiles,
        );
      },
    );
  }

  Widget _quickActions(BuildContext context) {
    return Column(
      children: [
        _NavCard(
          title: 'AI 活動洞察',
          subtitle: '查看 AI 分眾洞察與指標彙總',
          icon: Icons.insights,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminAiCampaignInsightPage(
                collectionName: _colAiInsights,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _NavCard(
                title: '新增自動活動',
                subtitle: '建立 Auto Campaign',
                icon: Icons.add_circle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminAutoCampaignEditPage(
                      campaignId: null,
                      collectionName: _colAutoCampaigns,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NavCard(
                title: '自動活動報表',
                subtitle: '查看送達/開啟/點擊/轉換等指標',
                icon: Icons.bar_chart,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminAutoCampaignReportsPage(
                      collectionName: _colAutoReports,
                      campaignId: null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _NavCard(
                title: '新增抽獎活動',
                subtitle: '建立 Lottery 活動與獎品',
                icon: Icons.casino_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminLotteryEditPage(
                      lotteryId: null,
                      collectionName: _colLotteries,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NavCard(
                title: '抽獎中獎名單',
                subtitle: '查詢中獎紀錄 / 標記已發放',
                icon: Icons.emoji_events,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminLotteryWinnersPage(
                      lotteryId: null,
                      collectionName: _colLotteryWinners,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _collectionInfoCard(BuildContext context) {
    final now = DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    final stamp =
        '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}';

    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('更新時間：$stamp', style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 10),
            _kv('auto_campaigns', _colAutoCampaigns),
            _kv('auto_campaign_reports', _colAutoReports),
            _kv('lotteries', _colLotteries),
            _kv('lottery_winners', _colLotteryWinners),
            _kv('ai_campaign_insights', _colAiInsights),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 170,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 0.8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 26, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey[700])),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.title,
    required this.icon,
    required this.stream,
    required this.valueBuilder,
    required this.subtitleBuilder,
  });

  final String title;
  final IconData icon;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String Function(QuerySnapshot<Map<String, dynamic>> snap) valueBuilder;
  final String Function(QuerySnapshot<Map<String, dynamic>> snap)
  subtitleBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return _kpiContent(
                theme,
                value: '—',
                subtitle: '讀取失敗',
                icon: icon,
                title: title,
                isError: true,
              );
            }
            if (!snap.hasData) {
              return _kpiContent(
                theme,
                value: '…',
                subtitle: '載入中',
                icon: icon,
                title: title,
              );
            }
            final s = snap.data!;
            return _kpiContent(
              theme,
              value: valueBuilder(s),
              subtitle: subtitleBuilder(s),
              icon: icon,
              title: title,
            );
          },
        ),
      ),
    );
  }

  Widget _kpiContent(
    ThemeData theme, {
    required String value,
    required String subtitle,
    required IconData icon,
    required String title,
    bool isError = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: isError ? Colors.red : theme.colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
