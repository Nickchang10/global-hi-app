// lib/pages/admin/marketing/admin_marketing_shell_page.dart
//
// ✅ AdminMarketingShellPage（行銷中心主頁｜最終完整可編譯版 v1.0.3）
// ------------------------------------------------------------
// - 左側導航：行銷儀表板 / 優惠券管理 / 抽獎管理 / 受眾分群 / 行銷報表 / 執行日誌
// - 導入：AdminCouponsPage / AdminLotteryPage / AdminMarketingReportsPage / AdminCampaignLogsPage
// - ✅ 為了「一定可編譯」：Dashboard / Segments 預設使用 Placeholder（不依賴額外檔案）
//   -> 你完成 AdminMarketingDashboardPage / AdminSegmentsPage 後，只要替換 pages Map 即可
// - Scaffold + Row Layout（Web/桌面後台常用）
// - 可與 main.dart 路由 `/admin/lottery/edit`、`/admin/coupons/edit`、`/admin/segments/edit`、`/admin/marketing/logs` 串接
// ------------------------------------------------------------

import 'package:flutter/material.dart';

import 'admin_coupons_page.dart';
import 'admin_lottery_page.dart';
import 'admin_marketing_reports_page.dart';
import 'admin_campaign_logs_page.dart';

class AdminMarketingShellPage extends StatefulWidget {
  const AdminMarketingShellPage({super.key});

  @override
  State<AdminMarketingShellPage> createState() => _AdminMarketingShellPageState();
}

class _AdminMarketingShellPageState extends State<AdminMarketingShellPage> {
  String _selected = 'coupons'; // ✅ 預設頁面：優惠券

  @override
  Widget build(BuildContext context) {
    // ✅ 子頁面對應表（保證可編譯）
    final pages = <String, Widget>{
      'dashboard': const _DashboardPlaceholderPage(),
      'coupons': const AdminCouponsPage(),
      'lottery': const AdminLotteryPage(),
      'segments': const _SegmentsPlaceholderPage(),
      'reports': const AdminMarketingReportsPage(),
      'logs': const AdminCampaignLogsPage(),
    };

    final currentPage = pages[_selected] ?? const AdminCouponsPage();

    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Material(
                  color: Colors.white,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: KeyedSubtree(
                      key: ValueKey<String>(_selected),
                      child: currentPage,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // Sidebar
  // =====================================================

  Widget _buildSidebar() {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 6),
            const Text(
              '行銷中心',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              'Marketing Center',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _sectionLabel('儀表板'),
                  _menuTile(
                    id: 'dashboard',
                    icon: Icons.dashboard_customize_outlined,
                    title: '行銷儀表板',
                  ),

                  const SizedBox(height: 10),
                  _sectionLabel('活動工具'),
                  _menuTile(
                    id: 'coupons',
                    icon: Icons.card_giftcard_outlined,
                    title: '優惠券管理',
                  ),
                  _menuTile(
                    id: 'lottery',
                    icon: Icons.emoji_events_outlined,
                    title: '抽獎管理',
                  ),
                  _menuTile(
                    id: 'segments',
                    icon: Icons.group_work_outlined,
                    title: '受眾分群',
                  ),

                  const SizedBox(height: 10),
                  _sectionLabel('分析與報表'),
                  _menuTile(
                    id: 'reports',
                    icon: Icons.bar_chart_outlined,
                    title: '行銷報表',
                  ),

                  const SizedBox(height: 10),
                  _sectionLabel('系統管理'),
                  _menuTile(
                    id: 'logs',
                    icon: Icons.list_alt_outlined,
                    title: '執行日誌',
                  ),
                ],
              ),
            ),

            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Osmile Admin v1.0.3',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
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

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _menuTile({
    required String id,
    required IconData icon,
    required String title,
  }) {
    final selected = _selected == id;

    return InkWell(
      onTap: () => setState(() => _selected = id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.blue.shade200 : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.blue : Colors.grey.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: selected ? Colors.blue : Colors.black87,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              Icon(
                Icons.chevron_right,
                color: Colors.blue.shade400,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// ✅ Dashboard Placeholder（你完成 AdminMarketingDashboardPage 後可替換）
/// ------------------------------------------------------------
class _DashboardPlaceholderPage extends StatelessWidget {
  const _DashboardPlaceholderPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('行銷儀表板', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '你已加入「行銷儀表板」入口。',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  '目前尚未接上真實儀表板頁（AdminMarketingDashboardPage）。\n'
                  '你可以先使用「優惠券 / 抽獎 / 分群 / 日誌」功能，完成後再替換此頁。',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/admin/marketing/logs'),
                      icon: const Icon(Icons.list_alt_outlined),
                      label: const Text('查看執行日誌'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/admin/marketing'),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新載入'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// ✅ 受眾分群 Placeholder（尚未連接真實 AdminSegmentsPage）
/// ------------------------------------------------------------
class _SegmentsPlaceholderPage extends StatelessWidget {
  const _SegmentsPlaceholderPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('受眾分群', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: '新增分群（進入 /admin/segments/edit）',
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/admin/segments/edit');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '你已在行銷中心加入「受眾分群」入口。',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  '目前尚未接上分群列表頁（AdminSegmentsPage）。\n'
                  '你可以先點右上角「＋」進入分群編輯頁建立資料。',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/admin/segments/edit'),
                      icon: const Icon(Icons.add),
                      label: const Text('新增分群'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/admin/marketing'),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('回行銷中心'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
