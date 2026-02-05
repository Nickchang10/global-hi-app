import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';
import '../services/auth_service.dart';
import '../widgets/user_info_badge.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.route,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final String route;
  final Widget child;

  void _go(BuildContext context, String r) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == r) return;
    Navigator.pushReplacementNamed(context, r);
  }

  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();
    final authSvc = context.read<AuthService>();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;

        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (user == null) {
          return Scaffold(
            body: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('尚未登入'),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                        child: const Text('前往登入'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return FutureBuilder<RoleInfo>(
          future: gate.ensureAndGetRole(user, forceRefresh: false),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final info = roleSnap.data;
            final role = (info?.role ?? 'unknown').trim().toLowerCase();
            final vendorId = (info?.vendorId ?? '').trim();

            final isAdmin = role == 'admin';
            final isVendor = role == 'vendor';

            final items = <_NavItem>[
              const _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, route: '/dashboard'),
              const _NavItem(label: '訂單', icon: Icons.receipt_long_outlined, route: '/orders'),
              const _NavItem(label: '公告', icon: Icons.campaign_outlined, route: '/announcements'),
              const _NavItem(label: '設定', icon: Icons.settings_outlined, route: '/app_config'),
              const _NavItem(label: '任務範本', icon: Icons.task_alt_outlined, route: '/task_templates'),
              if (isAdmin) const _NavItem(label: '商品', icon: Icons.inventory_2_outlined, route: '/products'),
              if (isAdmin) const _NavItem(label: '分類', icon: Icons.category_outlined, route: '/categories'),
              if (isAdmin) const _NavItem(label: '廠商', icon: Icons.apartment_outlined, route: '/vendors'),
              if (isVendor) const _NavItem(label: '我的商品', icon: Icons.inventory_2_outlined, route: '/vendor_products'),
            ];

            return LayoutBuilder(
              builder: (context, c) {
                final isWide = c.maxWidth >= 980;

                Future<void> logout() async {
                  gate.clearCache();
                  await authSvc.signOut();
                  if (!context.mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                }

                final drawer = Drawer(
                  child: SafeArea(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        DrawerHeader(
                          margin: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAdmin ? 'Osmile 後台（Admin）' : (isVendor ? 'Osmile 後台（Vendor）' : 'Osmile 後台'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text('role：$role', style: const TextStyle(color: Colors.black54)),
                              if (isVendor)
                                Text('vendorId：$vendorId', style: const TextStyle(color: Colors.black54)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      gate.clearCache();
                                      await gate.ensureAndGetRole(user, forceRefresh: true);
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('刷新'),
                                  ),
                                  const SizedBox(width: 10),
                                  FilledButton.icon(
                                    onPressed: logout,
                                    icon: const Icon(Icons.logout),
                                    label: const Text('登出'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        for (final it in items)
                          ListTile(
                            leading: Icon(it.icon),
                            title: Text(it.label),
                            selected: route == it.route,
                            onTap: () {
                              Navigator.pop(context);
                              _go(context, it.route);
                            },
                          ),
                      ],
                    ),
                  ),
                );

                final selectedIndex = () {
                  final idx = items.indexWhere((e) => e.route == route);
                  return (idx < 0 ? 0 : idx).clamp(0, items.length - 1);
                }();

                return Scaffold(
                  backgroundColor: const Color(0xFFF6F7FB),
                  drawer: isWide ? null : drawer,
                  appBar: AppBar(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        if ((subtitle ?? '').trim().isNotEmpty)
                          Text(subtitle!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                    backgroundColor: Colors.white,
                    elevation: 0.5,
                    leading: isWide
                        ? null
                        : Builder(
                            builder: (context) => IconButton(
                              tooltip: '開啟選單',
                              icon: const Icon(Icons.menu),
                              onPressed: () => Scaffold.of(context).openDrawer(),
                            ),
                          ),
                    actions: [
                      const UserInfoBadge(),
                      IconButton(
                        tooltip: '登出',
                        onPressed: logout,
                        icon: const Icon(Icons.logout),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                  body: isWide
                      ? Row(
                          children: [
                            NavigationRail(
                              selectedIndex: selectedIndex,
                              labelType: NavigationRailLabelType.all,
                              onDestinationSelected: (i) => _go(context, items[i].route),
                              trailing: Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      tooltip: '登出',
                                      onPressed: logout,
                                      icon: const Icon(Icons.logout),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                              destinations: [
                                for (final it in items)
                                  NavigationRailDestination(
                                    icon: Icon(it.icon),
                                    label: Text(it.label),
                                  ),
                              ],
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Card(
                                  elevation: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: child,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: Card(
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: child,
                            ),
                          ),
                        ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem({required this.label, required this.icon, required this.route});
}
