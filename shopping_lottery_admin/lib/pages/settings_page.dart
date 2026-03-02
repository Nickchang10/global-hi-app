// lib/pages/settings_page.dart
//
// SettingsPage（極簡完整版）
// - Admin / Vendor 均可進入
// - 可編輯個人資料（name, vendorId）
// - 可重設密碼（Firebase Auth）
// - 可登出
//
// Firestore: users/{uid}
// fields: name, vendorId, role, email, updatedAt
//
// 依賴：
// - services/admin_gate.dart
// - services/auth_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';
import '../services/auth/auth_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _db = FirebaseFirestore.instance;
  final _nameCtrl = TextEditingController();
  final _vendorCtrl = TextEditingController();
  bool _saving = false;
  String _role = '';
  String _email = '';

  Future<void> _loadProfile(User user) async {
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return;

    final m = doc.data() ?? {};
    setState(() {
      _nameCtrl.text = (m['name'] ?? '').toString();
      _vendorCtrl.text = (m['vendorId'] ?? '').toString();
      _role = (m['role'] ?? '').toString();
      _email = user.email ?? '';
    });
  }

  Future<void> _saveProfile(User user) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      await _db.collection('users').doc(user.uid).set({
        'name': _nameCtrl.text.trim(),
        'vendorId': _vendorCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('資料已更新')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _changePassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('重設密碼信件已寄出：$email')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('寄送失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();
    final authSvc = context.read<AuthService>();
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (user == null) {
          return const Scaffold(body: Center(child: Text('請先登入')));
        }

        return FutureBuilder<RoleInfo>(
          future: gate.ensureAndGetRole(user),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (roleSnap.hasError) {
              return _SimpleErrorPage(
                title: '讀取角色失敗',
                message: '${roleSnap.error}',
                onRetry: () => setState(() {}),
                onLogout: () async {
                  await authSvc.signOut();
                  if (!context.mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                },
              );
            }

            final info = roleSnap.data!;
            _role = info.role;
            _email = user.email ?? '';

            if (_nameCtrl.text.isEmpty && _vendorCtrl.text.isEmpty) {
              _loadProfile(user);
            }

            return Scaffold(
              appBar: AppBar(
                title: const Text('設定中心'),
                centerTitle: true,
                actions: [
                  IconButton(
                    tooltip: '登出',
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      await authSvc.signOut();
                      if (!context.mounted) return;
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              body: RefreshIndicator(
                onRefresh: () async => setState(() {}),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: cs.primaryContainer,
                                  child: const Icon(
                                    Icons.person_outline,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _email,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '角色：$_role',
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                                labelText: '名稱（顯示用）',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _vendorCtrl,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                isDense: true,
                                labelText: 'vendorId（Vendor 請填入專屬代號）',
                                helperText: _role == 'admin'
                                    ? 'Admin 可留空或填入任意識別字'
                                    : 'Vendor 必須設定正確的 vendorId 才能讀取報表 / 訂單',
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _saving
                                        ? null
                                        : () => _saveProfile(user),
                                    icon: const Icon(Icons.save),
                                    label: const Text('儲存變更'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _changePassword(user.email ?? ''),
                                  icon: const Icon(Icons.lock_reset_outlined),
                                  label: const Text('重設密碼'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '帳號資訊會同步至 Firestore 的 users/{uid} 文件。',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// -------------------- Error Page --------------------

class _SimpleErrorPage extends StatelessWidget {
  const _SimpleErrorPage({
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(18),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  style: TextStyle(color: cs.error),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重試'),
                    ),
                    const SizedBox(width: 10),
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
    );
  }
}
