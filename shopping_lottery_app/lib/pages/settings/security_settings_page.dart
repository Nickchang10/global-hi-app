import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth/auth_service.dart' as app_auth;

class SecuritySettingsPage extends StatelessWidget {
  const SecuritySettingsPage({super.key});

  Future<void> _sendVerifyEmail(BuildContext context) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    if (u.email == null || u.email!.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此帳號沒有 Email')));
      return;
    }
    if (u.emailVerified) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Email 已驗證')));
      return;
    }
    try {
      await u.sendEmailVerification();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已寄出驗證信：${u.email}')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('寄送失敗：$e')));
    }
  }

  Future<void> _sendResetEmail(BuildContext context) async {
    final email = FirebaseAuth.instance.currentUser?.email?.trim() ?? '';
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此帳號沒有 Email')));
      return;
    }
    try {
      await app_auth.AuthService.instance.sendPasswordReset(email);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已寄出重設密碼信：$email')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(app_auth.AuthService.formatAuthError(e))),
      );
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除帳號'),
        content: const Text('此操作不可復原，確定要刪除帳號嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await u.delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除帳號')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e（可能需要重新登入再刪除）')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('帳號與安全')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.mark_email_read_outlined),
                  title: const Text('Email 驗證'),
                  subtitle: Text(u?.emailVerified == true ? '已驗證' : '未驗證'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _sendVerifyEmail(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_reset_outlined),
                  title: const Text('寄送重設密碼信'),
                  subtitle: Text(
                    (u?.email ?? '').isEmpty ? '此帳號沒有 Email' : '寄到：${u!.email}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _sendResetEmail(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined),
                  title: const Text('刪除帳號'),
                  subtitle: const Text('此操作不可復原'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _deleteAccount(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
