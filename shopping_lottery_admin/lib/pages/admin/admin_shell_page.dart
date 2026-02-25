// lib/pages/admin/admin_shell_page.dart
//
// ✅ AdminShellPage（管理總覽｜修正版｜避免 Unknown route）
// ------------------------------------------------------------
// - 用 ScaffoldWithDrawer 統一後台 Layout
// - 以「快捷入口」方式導到各管理模組（用 Named Routes）
// - ✅ 已把容易 Unknown 的路由改成你 main.dart 已註冊的路由：
//   - 行銷中心：/admin/coupons（原 /admin-marketing）
//   - 報表統計：/admin_reports_dashboard（原 /reports）
//   - 通知中心：/notifications（原 /user-notifications）
// - 其餘若你尚未建立（/admin-content、/admin-settings），先留著，下一步再補 main.dart 路由
// ------------------------------------------------------------

import 'package:flutter/material.dart';
import '../../layouts/scaffold_with_drawer.dart';

class AdminShellPage extends StatelessWidget {
  const AdminShellPage({super.key});

  /// ✅ 與 main.dart 登入後導入的路由一致（你是 pushReplacementNamed('/dashboard')）
  static const String routeName = '/dashboard';

  @override
  Widget build(BuildContext context) {
    return ScaffoldWithDrawer(
      title: '管理總覽',

      // ✅ FIX: 你的 ScaffoldWithDrawer 需要 currentRoute（required）
      currentRoute: routeName,

      // ✅ FIX: 你的 ScaffoldWithDrawer 需要 body（required）
      body: const _Body(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final items = <_AdminEntry>[
      _AdminEntry(
        title: '商品管理',
        subtitle: '新增/編輯/上架/庫存',
        icon: Icons.inventory_2_outlined,
        route: '/admin-products',
      ),
      _AdminEntry(
        title: '訂單管理',
        subtitle: '查詢/出貨/退款/批次',
        icon: Icons.receipt_long_outlined,
        route: '/admin-orders',
      ),
      _AdminEntry(
        title: '會員管理',
        subtitle: '會員列表/積分/任務',
        icon: Icons.people_alt_outlined,
        route: '/admin-members',
      ),

      // ✅ 直接導到優惠券（你 main.dart 已有 /admin/coupons）
      _AdminEntry(
        title: '行銷中心',
        subtitle: '優惠券/抽獎/分群/自動派發',
        icon: Icons.campaign_outlined,
        route: '/admin/coupons',
      ),

      // ⚠️ 你若還沒在 main.dart 補 /admin-content，點了會 Unknown
      _AdminEntry(
        title: '公告/內容',
        subtitle: '公告/FAQ/頁面內容',
        icon: Icons.announcement_outlined,
        route: '/admin-content',
      ),

      // ✅ 你 main.dart 已有 /admin_reports_dashboard
      _AdminEntry(
        title: '報表統計',
        subtitle: '營運/轉換/成效',
        icon: Icons.bar_chart_outlined,
        route: '/admin_reports_dashboard',
      ),

      // ⚠️ 你若還沒在 main.dart 補 /admin-settings，點了會 Unknown
      _AdminEntry(
        title: '系統設定',
        subtitle: '角色/權限/設定',
        icon: Icons.settings_outlined,
        route: '/admin-settings',
      ),

      // ✅ 你 main.dart 已有 /notifications
      _AdminEntry(
        title: '通知中心',
        subtitle: '推播/站內通知',
        icon: Icons.notifications_outlined,
        route: '/notifications',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(context),
        const SizedBox(height: 12),
        _buildGrid(context, items),
        const SizedBox(height: 16),
        _buildTipsCard(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.dashboard_outlined, color: cs.primary, size: 28),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Osmile 後台管理',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text('從這裡快速進入各功能模組'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<_AdminEntry> items) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final crossAxisCount = w >= 980 ? 4 : (w >= 680 ? 3 : 2);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (_, i) => _EntryCard(entry: items[i]),
        );
      },
    );
  }

  Widget _buildTipsCard(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('小提醒', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• 如果某路由尚未建立，點擊會跳轉失敗：請先在 main.dart onGenerateRoute 補上對應頁面。'),
            Text('• Dead code 多半是 non-nullable + `??`：把 `??` 移掉或改成 nullable。'),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final _AdminEntry entry;
  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pushNamed(context, entry.route),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(entry.icon, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _AdminEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  const _AdminEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });
}
