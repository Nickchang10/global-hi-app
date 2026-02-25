// lib/pages/user_info_badge.dart
//
// ✅ UserInfoBadge（可編譯完整版｜不依賴 RoleInfo.raw）
// ------------------------------------------------------------
// 顯示目前登入者資訊：email / uid / role / vendorId（若有）
// 依賴：firebase_auth、provider、services/admin_gate.dart（AdminGate, RoleInfo）

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';

class UserInfoBadge extends StatelessWidget {
  const UserInfoBadge({super.key});

  String _s(dynamic v) => (v ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: '使用者資訊',
      icon: const Icon(Icons.account_circle_outlined),
      onPressed: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('尚未登入')));
          return;
        }

        final gate = context.read<AdminGate>();

        RoleInfo? info;
        Object? err;
        try {
          info = await gate.ensureAndGetRole(user, forceRefresh: false);
        } catch (e) {
          err = e;
        }

        if (!context.mounted) return;

        final role = _s(info?.role);
        final vendorId = _s(info?.vendorId);

        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('目前登入者'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv('email', user.email ?? '-'),
                  _kv('uid', user.uid),
                  _kv('role', role.isEmpty ? '-' : role),
                  if (vendorId.isNotEmpty) _kv('vendorId', vendorId),
                  if (err != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      '讀取角色失敗：$err',
                      style: TextStyle(color: cs.error, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('關閉'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              k,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: SelectableText(
              v,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
