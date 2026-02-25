// lib/layouts/admin_shell.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../gates/admin_gate.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final gate = context.read<AdminGate>();
      gate.bindAuth(_auth);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gate = context.watch<AdminGate>();

    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;

        if (user == null) return const _NeedLogin();

        if (gate.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!gate.isAdmin) {
          return _Forbidden(
            emailOrUid: user.email ?? user.uid,
            onLogout: () async {
              await _auth.signOut();
              if (!context.mounted) return;
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (_) => false);
            },
          );
        }

        final pages = <Widget>[
          const _PlaceholderPage(title: 'Dashboard'),
          const _PlaceholderPage(title: '公告管理'),
          const _PlaceholderPage(title: '商品管理'),
          const _PlaceholderPage(title: '訂單管理'),
          const _PlaceholderPage(title: '會員管理'),
          const _PlaceholderPage(title: '系統設定'),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Osmile Admin',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            actions: [
              IconButton(
                tooltip: '刷新權限',
                onPressed: () => gate.refresh(),
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: '登出',
                onPressed: () async {
                  await _auth.signOut();
                  if (!context.mounted) return;
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (_) => false);
                },
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          drawer: Drawer(
            child: SafeArea(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings),
                    title: Text(
                      gate.isSuperAdmin ? 'Super Admin' : 'Admin',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(user.email ?? user.uid),
                  ),
                  const Divider(height: 1),

                  _navTile(
                    context,
                    icon: Icons.dashboard,
                    title: 'Dashboard',
                    i: 0,
                  ),
                  _navTile(context, icon: Icons.campaign, title: '公告管理', i: 1),
                  _navTile(
                    context,
                    icon: Icons.inventory_2,
                    title: '商品管理',
                    i: 2,
                  ),
                  _navTile(
                    context,
                    icon: Icons.receipt_long,
                    title: '訂單管理',
                    i: 3,
                  ),
                  _navTile(context, icon: Icons.group, title: '會員管理', i: 4),
                  _navTile(context, icon: Icons.settings, title: '系統設定', i: 5),

                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('登出'),
                    onTap: () async {
                      Navigator.pop(context);
                      await _auth.signOut();
                      if (!context.mounted) return;
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/login', (_) => false);
                    },
                  ),
                ],
              ),
            ),
          ),
          body: pages[_index],
        );
      },
    );
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int i,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: _index == i,
      onTap: () {
        Navigator.pop(context);
        setState(() => _index = i);
      },
    );
  }
}

class _NeedLogin extends StatelessWidget {
  const _NeedLogin();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 54, color: Colors.grey),
                  const SizedBox(height: 10),
                  const Text(
                    '請先登入後台',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pushReplacementNamed('/login'),
                    child: const Text('前往登入'),
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

class _Forbidden extends StatelessWidget {
  const _Forbidden({required this.emailOrUid, required this.onLogout});

  final String emailOrUid;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block, size: 56, color: cs.error),
                  const SizedBox(height: 12),
                  const Text(
                    '權限不足',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '目前登入：$emailOrUid\n此帳號沒有 Admin 權限，無法進入後台。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () async => onLogout(),
                    icon: const Icon(Icons.logout),
                    label: const Text('登出並切換帳號'),
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

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
    );
  }
}
