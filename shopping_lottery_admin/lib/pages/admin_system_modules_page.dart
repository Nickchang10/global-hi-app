// lib/pages/admin_system_modules_page.dart
//
// ✅ AdminSystemModulesPage（最終完整版｜系統功能群組入口頁）
// ------------------------------------------------------------
// - 使用 ExpansionTile 呈現五大功能群組
// - 點擊子項導向對應管理頁（routeName）
// - 長按顯示 route（方便你 debug）
// ------------------------------------------------------------

import 'package:flutter/material.dart';

class AdminSystemModulesPage extends StatelessWidget {
  const AdminSystemModulesPage({super.key});

  void _go(BuildContext context, String routeName) {
    Navigator.pushNamed(context, routeName);
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('系統功能管理'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        children: [
          _buildGroup(
            context,
            title: '客戶服務',
            icon: Icons.support_agent_outlined,
            items: const [
              _NavItem('FAQ 常見問題', '/admin_faqs'),
              _NavItem('下載區', '/admin_downloads'),
              _NavItem('留言板', '/admin_messages'),
              _NavItem('聯絡我們紀錄', '/admin_contacts'),
              _NavItem('聯絡方式設定', '/admin_contact_info'),
              _NavItem('好站連結', '/admin_links'),
            ],
          ),
          _buildGroup(
            context,
            title: '網站其他功能',
            icon: Icons.web_outlined,
            items: const [
              _NavItem('首頁中間自訂區塊', '/admin_home_middle'),
              _NavItem('側欄自訂區塊', '/admin_sidebar_blocks'),
              _NavItem('右側浮動廣告', '/admin_floating_ads'),
              _NavItem('上方導覽列', '/admin_navbars'),
              _NavItem('通知信設定（聯絡我們）', '/admin_contact_notifications'),
            ],
          ),
          _buildGroup(
            context,
            title: '會員與行銷管理',
            icon: Icons.people_alt_outlined,
            items: const [
              _NavItem('會員名單', '/admin_users'),
              _NavItem('跑馬燈公告', '/admin_marquees'),
              // ✅ 你 main.dart 有 /admin_campaigns，這裡用一致的路由（避免 Unknown route）
              _NavItem('活動管理', '/admin_campaigns'),
            ],
          ),
          _buildGroup(
            context,
            title: '網頁自訂',
            icon: Icons.edit_note_outlined,
            items: const [
              _NavItem('首頁自訂區塊', '/admin_home_blocks'),
              _NavItem('頁尾編輯', '/admin_footer_blocks'),
            ],
          ),
          _buildGroup(
            context,
            title: '購物設定',
            icon: Icons.shopping_cart_outlined,
            items: const [
              _NavItem('購物車設定', '/admin_cart_settings'),
              _NavItem('購物訂單管理', '/admin_orders'),
              _NavItem('購物完成通知', '/admin_order_notifications'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<_NavItem> items,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      elevation: 1,
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        children: [
          for (final item in items)
            ListTile(
              dense: true,
              leading: const Icon(Icons.arrow_right),
              title: Text(item.title),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),

              // ✅ 修正：只保留一個 onTap，直接導頁
              onTap: () => _go(context, item.route),

              // ✅ ListTile 支援 onLongPress（用來 debug）
              onLongPress: () => _toast(context, 'route: ${item.route}'),
            ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String title;
  final String route;
  const _NavItem(this.title, this.route);
}
