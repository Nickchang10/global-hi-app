// lib/pages/root_nav_page.dart
import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'admin_products_page.dart';
import 'admin_orders_page.dart';
import 'notifications_page.dart';

class RootNavPage extends StatefulWidget {
  const RootNavPage({super.key});

  @override
  State<RootNavPage> createState() => _RootNavPageState();
}

class _RootNavPageState extends State<RootNavPage> {
  int _current = 0;
  final _pages = const [
    DashboardPage(),
    AdminProductsPage(),
    AdminOrdersPage(),
    NotificationsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 800;

    // 桌機／平板轉為側邊 Rail
    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _current,
              onDestinationSelected: (i) => setState(() => _current = i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Icon(Icons.admin_panel_settings, color: cs.primary),
                    const SizedBox(height: 4),
                    const Text('Osmile', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('首頁'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory),
                  label: Text('商品'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: Text('訂單'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.notifications_outlined),
                  selectedIcon: Icon(Icons.notifications),
                  label: Text('通知'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _pages[_current]),
          ],
        ),
      );
    }

    // 手機版 - BottomNavigationBar
    return Scaffold(
      body: IndexedStack(
        index: _current,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _current,
        onDestinationSelected: (i) => setState(() => _current = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '首頁'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory),
              label: '商品'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: '訂單'),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications),
              label: '通知'),
        ],
      ),
    );
  }
}
