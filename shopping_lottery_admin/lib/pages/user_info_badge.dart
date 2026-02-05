// lib/pages/user_info_badge.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';

class UserInfoBadge extends StatelessWidget {
  const UserInfoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final gate = context.watch<AdminGate>();
    final info = gate.cachedRoleInfo;

    final display = user?.email ?? user?.uid ?? '未登入';
    final role = info?.role ?? 'unknown';

    return InkWell(
      onTap: () => _showDialog(context, user, info),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.account_circle_outlined),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(display, style: const TextStyle(fontSize: 12)),
                Text(role, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showDialog(BuildContext context, User? user, RoleInfo? info) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('使用者資訊'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('uid: ${user?.uid ?? '-'}'),
                Text('email: ${user?.email ?? '-'}'),
                const SizedBox(height: 10),
                Text('role: ${info?.role ?? 'unknown'}'),
                Text('vendorId: ${info?.vendorId ?? '-'}'),
                const SizedBox(height: 10),
                const Text('Raw user doc:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(info?.raw?.toString() ?? '-', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('關閉')),
          ],
        );
      },
    );
  }
}
