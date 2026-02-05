// lib/pages/main_tab_page.dart
import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'admin_products_page.dart';
import 'admin_orders_page.dart';
import 'notifications_page.dart';

// 更多頁面
import 'admin_announcements_page.dart';
import 'admin_vendors_page.dart';
import 'admin_categories_page.dart';
import 'admin_app_config_page.dart';

class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardPage(),
    AdminProductsPage(),
    AdminOrdersPage(),
    NotificationsPage(),
    _MorePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: cs.primaryContainer.withOpacity(0.4),
          labelTextStyle: MaterialStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '首頁',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: '商品',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: '訂單',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications),
              label: '通知',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz),
              selectedIcon: Icon(Icons.more),
              label: '更多',
            ),
          ],
        ),
      ),
    );
  }
}

/// 「更多」頁面
class _MorePage extends StatelessWidget {
  const _MorePage();

  @override
  Widget build(BuildContext context) {
    final List<_MoreItem> items = [
      _MoreItem('公告管理', Icons.campaign_outlined, '/announcements'),
      _MoreItem('廠商管理', Icons.apartment_outlined, '/vendors'),
      _MoreItem('分類管理', Icons.category_outlined, '/categories'),
      _MoreItem('系統設定', Icons.settings_outlined, '/app_config'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('更多功能')),
      body: ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final m = items[i];
          return ListTile(
            leading: Icon(m.icon, color: Colors.blue),
            title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, m.route),
          );
        },
      ),
    );
  }
}

class _MoreItem {
  final String title;
  final IconData icon;
  final String route;
  _MoreItem(this.title, this.icon, this.route);
}
