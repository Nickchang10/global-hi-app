// lib/layouts/scaffold_with_drawer.dart
//
// ScaffoldWithDrawer（完整版）
// - 統一後台頁面框架與導覽邏輯
// - 根據角色（admin/vendor）顯示不同選單
// - 支援登出、切換頁面、通知快捷鍵
//
// 依賴：
// - services/admin_gate.dart
// - services/auth_service.dart
// - services/notification_service.dart
// - pages 下的各功能頁

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/admin_gate.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class ScaffoldWithDrawer extends StatefulWidget {
  final Widget body;
  final String title;
  final String currentRoute;

  const ScaffoldWithDrawer({
    super.key,
    required this.body,
    required this.title,
    required this.currentRoute,
  });

  @override
  State<ScaffoldWithDrawer> createState() => _ScaffoldWithDrawerState();
}

class _ScaffoldWithDrawerState extends State<ScaffoldWithDrawer> {
  String _role = '';
  String _vendorId = '';

  @override
  void initState() {
    super.initState();
    _initRole();
  }

  Future<void> _initRole() async {
    final gate = context.read<AdminGate>();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final info = await gate.ensureAndGetRole(user, forceRefresh: false);
    setState(() {
      _role = info.role;
      _vendorId = info.vendorId;
    });
  }

  void _navigate(String route) {
    if (route == widget.currentRoute) {
      Navigator.pop(context); // 關閉 drawer
      return;
    }
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final authSvc = context.read<AuthService>();
    final notiSvc = context.read<NotificationService>();
    final user = FirebaseAuth.instance.currentUser;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        actions: [
          if (user != null)
            StreamBuilder<int>(
              stream: notiSvc.streamUnreadCount(user.uid),
              builder: (_, snap) {
                final unread = snap.data ?? 0;
                return Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications),
                      tooltip: '通知中心',
                      onPressed: () => Navigator.pushNamed(context, '/user-notifications'),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            unread.toString(),
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          IconButton(
            tooltip: '登出',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final gate = context.read<AdminGate>();
              gate.clearCache();
              await authSvc.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildDrawerHeader(cs),
              const Divider(),
              if (_role == 'admin') ..._adminItems(),
              if (_role == 'vendor') ..._vendorItems(),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('通知中心'),
                selected: widget.currentRoute == '/user-notifications',
                onTap: () => _navigate('/user-notifications'),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('登出'),
                onTap: () async {
                  final gate = context.read<AdminGate>();
                  gate.clearCache();
                  await authSvc.signOut();
                  if (!context.mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ],
          ),
        ),
      ),
      body: widget.body,
    );
  }

  Widget _buildDrawerHeader(ColorScheme cs) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    return UserAccountsDrawerHeader(
      accountName: Text(
        _role.isEmpty ? '讀取中...' : _role.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      accountEmail: Text(email.isEmpty ? '未登入' : email),
      currentAccountPicture: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child: Text(
          _role.isEmpty ? '?' : _role.substring(0, 1).toUpperCase(),
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cs.primary),
        ),
      ),
    );
  }

  List<Widget> _adminItems() {
    return [
      ListTile(
        leading: const Icon(Icons.dashboard_outlined),
        title: const Text('管理總覽'),
        selected: widget.currentRoute == '/admin-dashboard',
        onTap: () => _navigate('/admin-dashboard'),
      ),
      ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: const Text('商品管理'),
        selected: widget.currentRoute == '/admin-products',
        onTap: () => _navigate('/admin-products'),
      ),
      ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: const Text('訂單管理'),
        selected: widget.currentRoute == '/admin-orders',
        onTap: () => _navigate('/admin-orders'),
      ),
      ListTile(
        leading: const Icon(Icons.announcement_outlined),
        title: const Text('公告管理'),
        selected: widget.currentRoute == '/admin-announcements',
        onTap: () => _navigate('/admin-announcements'),
      ),
      ListTile(
        leading: const Icon(Icons.bar_chart_outlined),
        title: const Text('報表統計'),
        selected: widget.currentRoute == '/reports',
        onTap: () => _navigate('/reports'),
      ),
    ];
  }

  List<Widget> _vendorItems() {
    return [
      ListTile(
        leading: const Icon(Icons.storefront_outlined),
        title: const Text('商家主控台'),
        selected: widget.currentRoute == '/vendor-dashboard',
        onTap: () => _navigate('/vendor-dashboard'),
      ),
      ListTile(
        leading: const Icon(Icons.receipt_long),
        title: const Text('我的訂單'),
        selected: widget.currentRoute == '/vendor-orders',
        onTap: () => _navigate('/vendor-orders'),
      ),
      ListTile(
        leading: const Icon(Icons.bar_chart_outlined),
        title: const Text('我的報表'),
        selected: widget.currentRoute == '/reports',
        onTap: () => _navigate('/reports'),
      ),
    ];
  }
}
