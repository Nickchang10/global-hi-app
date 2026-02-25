// lib/pages/app_config_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import '../services/admin_gate.dart';
import '../services/app_config_service.dart';
import '../widgets/user_info_badge.dart';

import 'login_page.dart';

class AppConfigPage extends StatefulWidget {
  const AppConfigPage({super.key});

  @override
  State<AppConfigPage> createState() => _AppConfigPageState();
}

class _AppConfigPageState extends State<AppConfigPage> {
  Future<RoleInfo>? _roleFuture;
  String? _lastUid;

  final _versionCtrl = TextEditingController();
  final _updateNoteCtrl = TextEditingController();
  final _supportUrlCtrl = TextEditingController();
  final _bannerTextCtrl = TextEditingController();

  bool _maintenanceMode = false;
  bool _filledOnce = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await context.read<AppConfigService>().ensureDefaultConfig();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _versionCtrl.dispose();
    _updateNoteCtrl.dispose();
    _supportUrlCtrl.dispose();
    _bannerTextCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _go(String route) {
    if (!mounted) return;
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return;
    Navigator.pushReplacementNamed(context, route);
  }

  Future<void> _logout() async {
    final gate = context.read<AdminGate>();
    final auth = context.read<AuthService>();
    gate.clearCache();
    await auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _fillControllersFromConfig(Map<String, dynamic> cfg) {
    // 只在第一次載入填入，避免你編輯到一半被 stream 覆蓋
    if (_filledOnce) return;
    _filledOnce = true;

    _versionCtrl.text = (cfg['version'] ?? '').toString();
    _updateNoteCtrl.text = (cfg['updateNote'] ?? '').toString();
    _supportUrlCtrl.text = (cfg['supportUrl'] ?? '').toString();
    _bannerTextCtrl.text = (cfg['bannerText'] ?? '').toString();

    // ✅ 避免在 build 當下直接改 state：改成 frame 後 setState
    final mm = (cfg['maintenanceMode'] ?? false) == true;
    if (mm != _maintenanceMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _maintenanceMode = mm);
      });
    } else {
      _maintenanceMode = mm;
    }
  }

  String _fmtLastUpdate(dynamic v) {
    if (v is Timestamp) {
      final d = v.toDate();
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  Future<void> _save() async {
    final svc = context.read<AppConfigService>();

    setState(() => _saving = true);
    try {
      await svc.updateConfig({
        'version': _versionCtrl.text.trim(),
        'updateNote': _updateNoteCtrl.text.trim(),
        'supportUrl': _supportUrlCtrl.text.trim(),
        'bannerText': _bannerTextCtrl.text.trim(),
        'maintenanceMode': _maintenanceMode,
      });
      _snack('已儲存 App Config');
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<_NavItem> _buildNavItems(String role) {
    final isAdmin = role == 'admin';
    final isVendor = role == 'vendor';

    return <_NavItem>[
      const _NavItem(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        route: '/dashboard',
      ),
      if (isAdmin)
        const _NavItem(
          label: '商品',
          icon: Icons.inventory_2_outlined,
          route: '/products',
        ),
      if (isAdmin)
        const _NavItem(
          label: '分類',
          icon: Icons.category_outlined,
          route: '/categories',
        ),
      if (isAdmin)
        const _NavItem(
          label: '廠商',
          icon: Icons.apartment_outlined,
          route: '/vendors',
        ),
      if (isVendor)
        const _NavItem(
          label: '我的商品',
          icon: Icons.inventory_2_outlined,
          route: '/vendor_products',
        ),
      const _NavItem(
        label: 'App Config',
        icon: Icons.tune_outlined,
        route: '/app_config',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();
    final authSvc = context.read<AuthService>();
    final cfgSvc = context.read<AppConfigService>();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnap.data;
        if (user == null) {
          gate.clearCache();
          return const LoginPage();
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
              return _FatalPage(
                title: '讀取角色失敗',
                message: '${roleSnap.error}',
                onRetry: () {
                  setState(() {
                    gate.clearCache();
                    _roleFuture = gate.ensureAndGetRole(
                      user,
                      forceRefresh: true,
                    );
                  });
                },
                onLogout: _logout,
              );
            }

            final info = roleSnap.data;
            final role = (info?.role ?? 'unknown').trim().toLowerCase();
            final vendorId = (info?.vendorId ?? '').trim();

            if (role != 'admin' && role != 'vendor') {
              return _FatalPage(
                title: '無後台權限',
                message: '目前 role="$role"。\n此頁面僅提供 admin/vendor。',
                onRetry: () {
                  setState(() {
                    gate.clearCache();
                    _roleFuture = gate.ensureAndGetRole(
                      user,
                      forceRefresh: true,
                    );
                  });
                },
                onLogout: _logout,
              );
            }

            final isAdmin = role == 'admin';
            final items = _buildNavItems(role);

            final badgeTitle = (user.displayName ?? '').trim().isNotEmpty
                ? user.displayName!.trim()
                : ((user.email ?? '').trim().isNotEmpty
                      ? user.email!.trim()
                      : user.uid);

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;

                final drawer = _AppDrawer(
                  role: role,
                  vendorId: vendorId,
                  items: items,
                  onGo: (r) {
                    Navigator.pop(context);
                    _go(r);
                  },
                  onLogout: _logout,
                );

                const selectedRoute = '/app_config';

                return Scaffold(
                  backgroundColor: const Color(0xFFF6F7FB),
                  drawer: isWide ? null : drawer,
                  appBar: AppBar(
                    title: const Text(
                      'App Config',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.white,
                    elevation: 0.5,
                    leading: isWide
                        ? null
                        : Builder(
                            builder: (context) => IconButton(
                              tooltip: '開啟選單',
                              icon: const Icon(Icons.menu),
                              onPressed: () =>
                                  Scaffold.of(context).openDrawer(),
                            ),
                          ),
                    actions: [
                      IconButton(
                        tooltip: '回 Dashboard',
                        onPressed: () => _go('/dashboard'),
                        icon: const Icon(Icons.dashboard_outlined),
                      ),
                      UserInfoBadge(
                        title: badgeTitle,
                        subtitle: (user.email ?? '').trim(),
                        role: role,
                        uid: user.uid,
                      ),
                      IconButton(
                        tooltip: '登出',
                        onPressed: () async {
                          gate.clearCache();
                          await authSvc.signOut();
                          if (!context.mounted) return;
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        icon: const Icon(Icons.logout),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                  body: isWide
                      ? Row(
                          children: [
                            _LeftRail(
                              items: items,
                              selectedRoute: selectedRoute,
                              onGo: _go,
                              onLogout: _logout,
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: _ConfigBody(
                                cfgSvc: cfgSvc,
                                isAdmin: isAdmin,
                                onFill: _fillControllersFromConfig,
                                versionCtrl: _versionCtrl,
                                updateNoteCtrl: _updateNoteCtrl,
                                supportUrlCtrl: _supportUrlCtrl,
                                bannerTextCtrl: _bannerTextCtrl,
                                maintenanceMode: _maintenanceMode,
                                onMaintenanceChanged: (v) {
                                  setState(() => _maintenanceMode = v);
                                },
                                saving: _saving,
                                onSave: isAdmin ? _save : null,
                                fmtLastUpdate: _fmtLastUpdate,
                              ),
                            ),
                          ],
                        )
                      : _ConfigBody(
                          cfgSvc: cfgSvc,
                          isAdmin: isAdmin,
                          onFill: _fillControllersFromConfig,
                          versionCtrl: _versionCtrl,
                          updateNoteCtrl: _updateNoteCtrl,
                          supportUrlCtrl: _supportUrlCtrl,
                          bannerTextCtrl: _bannerTextCtrl,
                          maintenanceMode: _maintenanceMode,
                          onMaintenanceChanged: (v) {
                            setState(() => _maintenanceMode = v);
                          },
                          saving: _saving,
                          onSave: isAdmin ? _save : null,
                          fmtLastUpdate: _fmtLastUpdate,
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

class _ConfigBody extends StatelessWidget {
  const _ConfigBody({
    required this.cfgSvc,
    required this.isAdmin,
    required this.onFill,
    required this.versionCtrl,
    required this.updateNoteCtrl,
    required this.supportUrlCtrl,
    required this.bannerTextCtrl,
    required this.maintenanceMode,
    required this.onMaintenanceChanged,
    required this.saving,
    required this.onSave,
    required this.fmtLastUpdate,
  });

  final AppConfigService cfgSvc;
  final bool isAdmin;

  final void Function(Map<String, dynamic> cfg) onFill;

  final TextEditingController versionCtrl;
  final TextEditingController updateNoteCtrl;
  final TextEditingController supportUrlCtrl;
  final TextEditingController bannerTextCtrl;

  final bool maintenanceMode;
  final void Function(bool v) onMaintenanceChanged;

  final bool saving;
  final Future<void> Function()? onSave;

  final String Function(dynamic v) fmtLastUpdate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: StreamBuilder<Map<String, dynamic>?>(
            stream: cfgSvc.streamConfig(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    '讀取失敗：${snap.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final cfg = snap.data;
              if (cfg == null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        '目前沒有 app_config/global 資料',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '請確認 Firestore 是否建立 app_config/global',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                );
              }

              onFill(cfg);

              final lastUpdate = fmtLastUpdate(cfg['lastUpdate']);

              return ListView(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_outlined),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '全域設定（app_config/global）',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'lastUpdate：$lastUpdate',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  TextField(
                    controller: versionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'version',
                      border: OutlineInputBorder(),
                      isDense: true,
                      helperText: '例如 1.0.3（可作為 App 顯示或版本檢查）',
                    ),
                    enabled: isAdmin && !saving,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: updateNoteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'updateNote',
                      border: OutlineInputBorder(),
                      isDense: true,
                      helperText: '更新說明（可在 App 內顯示）',
                    ),
                    minLines: 2,
                    maxLines: 5,
                    enabled: isAdmin && !saving,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: supportUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'supportUrl',
                      border: OutlineInputBorder(),
                      isDense: true,
                      helperText: '客服/支援連結（https://...）',
                    ),
                    enabled: isAdmin && !saving,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bannerTextCtrl,
                    decoration: const InputDecoration(
                      labelText: 'bannerText',
                      border: OutlineInputBorder(),
                      isDense: true,
                      helperText: '首頁 Banner 文案（可留空）',
                    ),
                    enabled: isAdmin && !saving,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('maintenanceMode'),
                    subtitle: const Text('維護模式（你可以在 App 前台讀取此欄位，顯示維護頁）'),
                    value: maintenanceMode,
                    onChanged: (!isAdmin || saving)
                        ? null
                        : onMaintenanceChanged,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: (onSave == null || saving)
                            ? null
                            : () async => onSave!.call(),
                        icon: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(isAdmin ? '儲存' : '僅可檢視'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await cfgSvc.ensureDefaultConfig();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已確認預設設定存在')),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('操作失敗：$e')));
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('確認預設設定'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    color: const Color(0xFFF3F5FA),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        '下一步（第三步）建議：Announcements（公告）\n'
                        '做法會類似：announcements collection + 後台 CRUD + 前台顯示。',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
  });
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.role,
    required this.vendorId,
    required this.items,
    required this.onGo,
    required this.onLogout,
  });

  final String role;
  final String vendorId;
  final List<_NavItem> items;
  final void Function(String route) onGo;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final isVendor = role == 'vendor';

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Osmile 後台',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'role：$role',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  if (isVendor)
                    Text(
                      'vendorId：$vendorId',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () async => onLogout(),
                    icon: const Icon(Icons.logout),
                    label: const Text('登出'),
                  ),
                ],
              ),
            ),
            for (final it in items)
              ListTile(
                leading: Icon(it.icon),
                title: Text(it.label),
                onTap: () => onGo(it.route),
              ),
          ],
        ),
      ),
    );
  }
}

class _LeftRail extends StatelessWidget {
  const _LeftRail({
    required this.items,
    required this.selectedRoute,
    required this.onGo,
    required this.onLogout,
  });

  final List<_NavItem> items;
  final String selectedRoute;
  final void Function(String route) onGo;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = items
        .indexWhere((e) => e.route == selectedRoute)
        .clamp(0, items.length - 1);

    return NavigationRail(
      selectedIndex: selectedIndex,
      labelType: NavigationRailLabelType.all,
      onDestinationSelected: (i) => onGo(items[i].route),
      trailing: Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: '登出',
              onPressed: () async => onLogout(),
              icon: const Icon(Icons.logout),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      destinations: [
        for (final it in items)
          NavigationRailDestination(icon: Icon(it.icon), label: Text(it.label)),
      ],
    );
  }
}

class _FatalPage extends StatelessWidget {
  const _FatalPage({
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新整理'),
                      ),
                      FilledButton.icon(
                        onPressed: () async => onLogout(),
                        icon: const Icon(Icons.logout),
                        label: const Text('登出'),
                      ),
                    ],
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
