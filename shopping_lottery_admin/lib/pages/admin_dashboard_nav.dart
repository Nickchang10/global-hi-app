import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/admin_gate.dart';

// 各子頁面
import 'dashboard_page.dart';
import 'admin_orders_page.dart';
import 'admin_users_page.dart';
import 'admin_announcements_page.dart';
import 'admin_notifications_page.dart';
import 'reports_page.dart';
import 'admin_app_config_page.dart';

class AdminDashboardNav extends StatefulWidget {
  const AdminDashboardNav({super.key});

  @override
  State<AdminDashboardNav> createState() => _AdminDashboardNavState();
}

class _AdminDashboardNavState extends State<AdminDashboardNav> {
  int _selectedIndex = 0;
  String _role = 'unknown';
  String _vendorId = '';

  final List<Widget> _adminPages = const [
    DashboardPage(),
    AdminOrdersPage(),
    AdminUsersPage(),
    AdminAnnouncementsPage(),
    AdminNotificationsPage(),
    ReportsPage(),
    AdminAppConfigPage(), // 新增設定中心
  ];

  final List<Widget> _vendorPages = const [
    DashboardPage(),
    AdminOrdersPage(),
    ReportsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final gate = context.read<AdminGate>();
    final user = await context.read<AuthService>().currentUser;
    if (user == null) return;
    final roleInfo = await gate.ensureAndGetRole(user);
    setState(() {
      _role = roleInfo.role.toLowerCase();
      _vendorId = roleInfo.vendorId ?? '';
    });
  }

  List<_NavItem> _menuItems() {
    if (_role == 'admin') {
      return [
        _NavItem('首頁', Icons.dashboard_outlined),
        _NavItem('訂單', Icons.receipt_long_outlined),
        _NavItem('使用者', Icons.people_alt_outlined),
        _NavItem('公告', Icons.campaign_outlined),
        _NavItem('通知', Icons.notifications_outlined),
        _NavItem('報表', Icons.bar_chart_outlined),
        _NavItem('設定', Icons.settings_outlined),
      ];
    } else {
      return [
        _NavItem('首頁', Icons.dashboard_outlined),
        _NavItem('訂單', Icons.receipt_long_outlined),
        _NavItem('報表', Icons.bar_chart_outlined),
      ];
    }
  }

  Widget _buildPage() {
    final isAdmin = _role == 'admin';
    final list = isAdmin ? _adminPages : _vendorPages;
    final index = _selectedIndex.clamp(0, list.length - 1);
    return list[index];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final gate = context.read<AdminGate>();
    final cs = Theme.of(context).colorScheme;
    final items = _menuItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Osmile 後台系統'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '登出',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              gate.clearCache();
              await auth.signOut();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            extended: MediaQuery.of(context).size.width > 1000,
            backgroundColor: cs.surfaceVariant.withOpacity(0.25),
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            destinations: [
              for (final item in items)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.icon, color: cs.primary),
                  label: Text(item.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: _buildPage()),
        ],
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width < 800
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (i) => setState(() => _selectedIndex = i),
              type: BottomNavigationBarType.fixed,
              items: [
                for (final item in items)
                  BottomNavigationBarItem(
                    icon: Icon(item.icon),
                    label: item.label,
                  ),
              ],
            )
          : null,
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}
