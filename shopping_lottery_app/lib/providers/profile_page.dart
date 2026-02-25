// lib/providers/profile_page.dart
//
// ✅ ProfilePage（完整版｜可直接編譯）
// - 修正找不到 order_history_page.dart：改用正確相對路徑 ../pages/order_history_page.dart
// - 提供：會員資訊 / 訂單歷史 / 登出
//

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/order_history_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已登出')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('登出失敗：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: user == null ? _needLogin(context) : _profileBody(context, user),
    );
  }

  Widget _needLogin(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('請先登入才能查看個人頁', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamed('/login'),
              child: const Text('前往登入'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileBody(BuildContext context, User user) {
    final email = user.email ?? '—';
    final name = user.displayName ?? 'Osmile 會員';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _headerCard(name: name, email: email),
        const SizedBox(height: 12),

        _sectionTitle('帳戶'),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.receipt_long,
          title: '訂單紀錄',
          subtitle: '查看我的歷史訂單',
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const OrderHistoryPage()));
          },
        ),

        const SizedBox(height: 12),
        _sectionTitle('其他'),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.help_outline,
          title: '客服 / 支援',
          subtitle: '常見問題與客服聯繫',
          onTap: () {
            // 你若有支援頁，改成 pushNamed('/support') 等
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('尚未接入客服頁')));
          },
        ),

        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => _signOut(context),
          icon: const Icon(Icons.logout),
          label: const Text('登出'),
        ),
      ],
    );
  }

  Widget _headerCard({required String name, required String email}) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(email, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
