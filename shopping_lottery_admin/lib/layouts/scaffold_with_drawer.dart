import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

class ScaffoldWithDrawer extends StatelessWidget {
  const ScaffoldWithDrawer({
    super.key,
    required this.title,
    required this.currentRoute,
    required this.body,
  });

  final String title;

  /// 用來標記 Drawer 目前所在頁（可高亮/避免重複跳轉）
  final String currentRoute;

  /// 主內容
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final User? user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              _drawerHeader(user),
              const Divider(height: 1),

              _navItem(
                context,
                icon: Icons.dashboard_outlined,
                label: '儀表板',
                route: '/admin',
              ),
              _navItem(
                context,
                icon: Icons.inventory_2_outlined,
                label: '商品管理',
                route: '/admin/products',
              ),
              _navItem(
                context,
                icon: Icons.receipt_long_outlined,
                label: '訂單管理',
                route: '/admin/orders',
              ),
              _navItem(
                context,
                icon: Icons.campaign_outlined,
                label: '活動管理',
                route: '/admin/campaigns',
              ),

              const Spacer(),

              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('登出'),
                onTap: () async {
                  Navigator.of(context).pop(); // close drawer
                  await auth.signOut();
                  if (context.mounted) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/login', (r) => false);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: body,
    );
  }

  Widget _navItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) {
    final isActive = route == currentRoute;

    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: isActive,
      onTap: isActive
          ? () => Navigator.of(context)
                .pop() // 已在此頁 → 只關 drawer
          : () {
              Navigator.of(context).pop(); // close drawer
              Navigator.of(context).pushReplacementNamed(route);
            },
    );
  }

  Widget _drawerHeader(User? user) {
    final email = user?.email ?? '未登入';
    final uid = user?.uid ?? '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Osmile Admin',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(email, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            'UID: $uid',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
