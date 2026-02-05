// lib/widgets/settings_menu.dart
//
// ✅ 後台設定選單（包含語言切換入口 + 登出）
// ------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:osmile_admin/l10n/gen/app_localizations.dart';

class SettingsMenu extends StatelessWidget {
  const SettingsMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(user?.email ?? t.noAccount ?? '未登入'),
          subtitle: Text(t.accountInfo ?? '帳號資訊'),
        ),
        const Divider(height: 20),

        // ✅ 語言設定
        ListTile(
          leading: const Icon(Icons.language_outlined),
          title: Text(t.languageSettingTitle ?? '語言設定'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, '/language_setting'),
        ),

        // ✅ 登出
        ListTile(
          leading: const Icon(Icons.logout_outlined, color: Colors.red),
          title: Text(t.logout ?? '登出'),
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(t.confirmLogout ?? '確認登出'),
                content: Text(t.logoutMessage ?? '確定要登出目前帳號嗎？'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(t.cancel ?? '取消')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(t.confirm ?? '確認')),
                ],
              ),
            );
            if (ok == true) {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
              }
            }
          },
        ),

        const SizedBox(height: 20),
        Center(
          child: Text(
            'Osmile Admin © 2026',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
