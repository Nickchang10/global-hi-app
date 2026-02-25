// lib/pages/my_page.dart
//
// ✅ MyPage（最終可編譯版）
// ------------------------------------------------------------
// 修正重點：
// - 移除不存在的 import：coupon_page.dart
// - 改用 Navigator.pushNamed('/coupons')（由 main.dart 統一路由管理）
// - 未登入：顯示登入引導
// - 已登入：顯示基本會員資訊 + 常用入口（訂單/優惠券/通知/設定）
// - ✅ 修正：withOpacity(deprecated) → withValues(alpha: ...)
// ------------------------------------------------------------

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  User? get _user => FirebaseAuth.instance.currentUser;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _pushNamed(String route, {Object? arguments}) {
    try {
      Navigator.pushNamed(context, route, arguments: arguments);
    } catch (_) {
      _snack('無法前往：$route（請確認 main.dart 已註冊路由）');
    }
  }

  Future<void> _goLogin() async {
    _pushNamed('/login');
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) setState(() {});
    _snack('已登出');
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: u == null ? _needLoginView() : _profileView(u),
    );
  }

  Widget _needLoginView() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 44, color: cs.primary),
                  const SizedBox(height: 10),
                  const Text(
                    '請先登入才能查看個人中心',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _goLogin,
                    icon: const Icon(Icons.login),
                    label: const Text('前往登入'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileView(User u) {
    final cs = Theme.of(context).colorScheme;

    final name = (u.displayName ?? '').trim();
    final email = (u.email ?? '').trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  // ✅ 修正：withOpacity(deprecated) → withValues(alpha: ...)
                  backgroundColor: cs.primaryContainer.withValues(alpha: 0.6),
                  child: Icon(Icons.person, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? '會員' : name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email.isEmpty
                            ? 'uid: ${u.uid}'
                            : '$email\nuid: ${u.uid}',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('登出'),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),
        Text(
          '常用功能',
          style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface),
        ),
        const SizedBox(height: 8),

        _tile(
          icon: Icons.receipt_long,
          title: '我的訂單',
          subtitle: '查看訂單、物流、付款狀態',
          onTap: () => _pushNamed('/orders', arguments: {'uid': u.uid}),
        ),
        _tile(
          icon: Icons.confirmation_number_outlined,
          title: '我的優惠券',
          subtitle: '查看可用優惠券 / 折扣碼',
          // ✅ 取代 coupon_page.dart：走路由
          onTap: () => _pushNamed('/coupons', arguments: {'uid': u.uid}),
        ),
        _tile(
          icon: Icons.notifications_none,
          title: '通知中心',
          subtitle: '查看推播與系統通知',
          onTap: () => _pushNamed('/notifications', arguments: {'uid': u.uid}),
        ),
        _tile(
          icon: Icons.settings_outlined,
          title: '設定',
          subtitle: '帳號設定、偏好設定',
          onTap: () => _pushNamed('/settings', arguments: {'uid': u.uid}),
        ),

        const SizedBox(height: 16),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '✅ 已修正：不再 import coupon_page.dart（檔案不存在）。\n'
              '目前改由 /coupons 路由承接（請到 main.dart routes 註冊對應頁面）。',
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
