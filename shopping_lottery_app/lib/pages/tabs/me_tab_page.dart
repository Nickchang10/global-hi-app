// lib/pages/tabs/me_tab_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MeTabPage extends StatelessWidget {
  const MeTabPage({super.key});

  void _safeNav(BuildContext context, String routeName) {
    try {
      Navigator.of(context).pushNamed(routeName);
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('尚未設定路由：$routeName')));
    }
  }

  Future<void> _signOut(BuildContext context) async {
    // ✅ 先把 messenger 抓出來，避免 await 後再用 context（解掉 use_build_context_synchronously）
    final messenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseAuth.instance.signOut();
      messenger.showSnackBar(const SnackBar(content: Text('已登出')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('登出失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('我的'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    child: Icon(
                      user == null
                          ? Icons.person_outline
                          : Icons.verified_user_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName?.trim().isNotEmpty == true
                              ? user!.displayName!
                              : (user == null ? '未登入' : '已登入'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '請先登入以使用完整功能',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (user == null)
                    ElevatedButton(
                      onPressed: () => _safeNav(context, '/login'),
                      child: const Text('登入'),
                    )
                  else
                    OutlinedButton(
                      // ✅ 修正：不在 await 之後直接用 context
                      onPressed: () => _signOut(context),
                      child: const Text('登出'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _tile(
            context,
            icon: Icons.receipt_long_outlined,
            title: '我的訂單',
            route: '/orders',
          ),
          _tile(
            context,
            icon: Icons.discount_outlined,
            title: '我的優惠券',
            route: '/coupons',
          ),
          _tile(
            context,
            icon: Icons.settings_outlined,
            title: '設定',
            route: '/settings',
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _safeNav(context, route),
      ),
    );
  }
}
