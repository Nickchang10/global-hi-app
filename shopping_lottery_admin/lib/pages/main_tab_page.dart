// lib/pages/main_tab_page.dart
//
// ✅ MainTabPage（可編譯完整版｜修正 use_build_context_synchronously）
// ------------------------------------------------------------
// - admin: Dashboard / Products / Orders / Notifications / Reports
// - vendor: Dashboard / Orders / Notifications / Reports
//
// 依賴：
// - services/admin_gate.dart（AdminGate, RoleInfo）
// - services/auth_service.dart（AuthService）
// - pages/dashboard_page.dart
// - pages/admin/products/admin_products_page.dart
// - pages/admin/orders/admin_orders_page.dart
// - pages/notifications_page.dart
// - pages/admin/reports/admin_reports_dashboard_page.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';
import '../services/auth/auth_service.dart';

// pages
import 'dashboard_page.dart';
import 'notifications_page.dart';

// ✅ 修正：商品管理頁不在同一層
import 'admin/products/admin_products_page.dart';

// ✅ 你的訂單頁已確認在這個位置
import 'admin/orders/admin_orders_page.dart';

// 報表（依你 main.dart 的 import 結構）
import 'admin/reports/admin_reports_dashboard_page.dart';

class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _index = 0;

  Future<RoleInfo>? _roleFuture;
  String? _lastUid;

  String _s(dynamic v) => (v ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();
    final authSvc = context.read<AuthService>();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data;
        if (user == null) {
          return const Scaffold(body: Center(child: Text('請先登入')));
        }

        if (_roleFuture == null || _lastUid != user.uid) {
          _lastUid = user.uid;
          _roleFuture = gate.ensureAndGetRole(user, forceRefresh: false);
        }

        return FutureBuilder<RoleInfo>(
          future: _roleFuture,
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (roleSnap.hasError) {
              return _ErrorView(
                title: '讀取角色失敗',
                message: '${roleSnap.error}',
                onRetry: () => setState(() {
                  _roleFuture = gate.ensureAndGetRole(user, forceRefresh: true);
                }),
              );
            }

            final info = roleSnap.data;
            final role = _s(info?.role).toLowerCase();
            final isAdmin = role == 'admin';
            final isVendor = role == 'vendor';

            if (!isAdmin && !isVendor) {
              return const Scaffold(
                body: Center(child: Text('此帳號無後台權限，請聯繫管理員')),
              );
            }

            final pages = isAdmin ? _adminPages() : _vendorPages();
            final items = isAdmin ? _adminNavItems() : _vendorNavItems();

            // ✅ 防呆：角色切換或 items 變短時 clamp index
            if (_index >= pages.length) _index = 0;

            return Scaffold(
              appBar: AppBar(
                title: Text(isAdmin ? 'Osmile 後台（Admin）' : 'Osmile 後台（Vendor）'),
                centerTitle: true,
                actions: [
                  IconButton(
                    tooltip: '登出',
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      // ✅ FIX: 避免跨 async gap 使用 context
                      final nav = Navigator.of(context);

                      gate.clearCache();
                      await authSvc.signOut();

                      if (!mounted) return;
                      nav.pushReplacementNamed('/login');
                    },
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              body: pages[_index],
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: _index,
                onTap: (i) => setState(() => _index = i),
                type: BottomNavigationBarType.fixed,
                items: [
                  for (final it in items)
                    BottomNavigationBarItem(
                      icon: Icon(it.icon),
                      label: it.label,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------
  // Admin tabs
  // ---------------------------
  List<Widget> _adminPages() => const [
    DashboardPage(),
    AdminProductsPage(),
    AdminOrdersPage(),
    NotificationsPage(),
    AdminReportsDashboardPage(),
  ];

  List<_NavItem> _adminNavItems() => const [
    _NavItem('總覽', Icons.dashboard_outlined),
    _NavItem('商品', Icons.inventory_2_outlined),
    _NavItem('訂單', Icons.receipt_long_outlined),
    _NavItem('通知', Icons.notifications_outlined),
    _NavItem('報表', Icons.bar_chart_outlined),
  ];

  // ---------------------------
  // Vendor tabs
  // ---------------------------
  List<Widget> _vendorPages() => const [
    DashboardPage(),
    AdminOrdersPage(),
    NotificationsPage(),
    AdminReportsDashboardPage(),
  ];

  List<_NavItem> _vendorNavItems() => const [
    _NavItem('總覽', Icons.dashboard_outlined),
    _NavItem('訂單', Icons.receipt_long_outlined),
    _NavItem('通知', Icons.notifications_outlined),
    _NavItem('報表', Icons.bar_chart_outlined),
  ];
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 44, color: cs.error),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重試'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
