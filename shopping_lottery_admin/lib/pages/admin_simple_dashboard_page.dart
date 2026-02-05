// lib/pages/admin_simple_dashboard_page.dart
//
// ✅ AdminSimpleDashboardPage（最終完整版｜可編譯 + Drawer + 模式切換 + i18n 一致 + 可接收 role）
// ------------------------------------------------------------
// - 新增 role 參數（解決 admin_shell_page 傳 role 編譯錯誤）
// - 移除 const AdminModeSwitcher() → AdminModeSwitcher()
// - Drawer 改 ListView 結構（防 overflow）
// ------------------------------------------------------------

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Controllers
import '../controllers/admin_mode_controller.dart';
import '../controllers/locale_controller.dart';

// Services
import '../services/admin_gate.dart';
import '../services/auth_service.dart';

// Localization
import '../l10n/app_localizations.dart';

// Widgets
import '../widgets/admin_mode_switcher.dart';

// Pages
import 'admin_products_page.dart';
import 'notifications_page.dart';
import 'reports_page.dart';

class AdminSimpleDashboardPage extends StatefulWidget {
  /// ✅ 新增可選 role 參數（避免 admin_shell_page 傳 role 編譯錯誤）
  final String role;
  const AdminSimpleDashboardPage({super.key, this.role = 'admin'});

  @override
  State<AdminSimpleDashboardPage> createState() =>
      _AdminSimpleDashboardPageState();
}

class _AdminSimpleDashboardPageState extends State<AdminSimpleDashboardPage> {
  int _selectedIndex = 0;
  Future<RoleInfo>? _roleFuture;
  String? _lastUid;

  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();
    final authSvc = context.read<AuthService>();
    final modeCtrl = context.watch<AdminModeController>();
    final localeCtrl = context.watch<LocaleController>();
    final t = AppLocalizations.of(context);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snap.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: Text(t.appTitle)),
            body: Center(child: Text(t.notLoggedIn)),
          );
        }

        if (_roleFuture == null || _lastUid != user.uid) {
          _lastUid = user.uid;
          _roleFuture = gate.ensureAndGetRole(user, forceRefresh: false);
        }

        return FutureBuilder<RoleInfo>(
          future: _roleFuture,
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (roleSnap.hasError) {
              return Scaffold(
                body: Center(
                  child: Text('讀取角色失敗：${roleSnap.error}'),
                ),
              );
            }

            final info = roleSnap.data;
            final role = (info?.role ?? widget.role).toLowerCase().trim();
            final isAdmin = role == 'admin';
            final isVendor = role == 'vendor';

            if (!isAdmin && !isVendor) {
              return const Scaffold(body: Center(child: Text('此帳號無後台存取權限')));
            }

            final items = <_SimpleNavItem>[
              _SimpleNavItem(
                title: t.products,
                icon: Icons.shopping_bag_outlined,
                page: const AdminProductsPage(),
              ),
              _SimpleNavItem(
                title: t.notifications,
                icon: Icons.notifications_outlined,
                page: const NotificationsPage(),
              ),
              if (isAdmin)
                _SimpleNavItem(
                  title: t.reports,
                  icon: Icons.bar_chart_outlined,
                  page: const ReportsPage(),
                ),
            ];

            final safeIndex = _selectedIndex.clamp(0, items.length - 1);
            if (safeIndex != _selectedIndex) _selectedIndex = safeIndex;
            final current = items[safeIndex];

            return Scaffold(
              appBar: AppBar(
                title: Text(current.title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                actions: [
                  IconButton(
                    tooltip: t.logout,
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      gate.clearCache();
                      modeCtrl.clearPersisted();
                      await authSvc.signOut();
                      if (!context.mounted) return;
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                ],
              ),

              // ✅ Drawer 改 ListView 結構防 overflow
              drawer: Drawer(
                child: SafeArea(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      DrawerHeader(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.admin_panel_settings,
                                size: 40,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(height: 10),
                            Text(
                              t.appTitle,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text('${t.role}：$role',
                                style: const TextStyle(fontSize: 13)),
                            Text('模式：${modeCtrl.isSimpleMode ? '簡潔' : '完整'}',
                                style: const TextStyle(fontSize: 13)),
                            Text('${t.language}：${localeCtrl.currentLocaleLabel}',
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      for (int i = 0; i < items.length; i++)
                        ListTile(
                          leading: Icon(items[i].icon),
                          title: Text(items[i].title),
                          selected: safeIndex == i,
                          onTap: () {
                            setState(() => _selectedIndex = i);
                            Navigator.pop(context);
                          },
                        ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: Text(t.logout),
                        onTap: () async {
                          Navigator.pop(context);
                          gate.clearCache();
                          modeCtrl.clearPersisted();
                          await authSvc.signOut();
                          if (!context.mounted) return;
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              body: SafeArea(child: current.page),

              // ✅ 移除 const，確保可編譯
              floatingActionButton: AdminModeSwitcher(),
            );
          },
        );
      },
    );
  }
}

class _SimpleNavItem {
  final String title;
  final IconData icon;
  final Widget page;
  const _SimpleNavItem({
    required this.title,
    required this.icon,
    required this.page,
  });
}
