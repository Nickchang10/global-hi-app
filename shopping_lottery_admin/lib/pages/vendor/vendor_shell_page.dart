// lib/pages/vendor/vendor_shell_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../gates/vendor_gate.dart';

class VendorShellPage extends StatefulWidget {
  const VendorShellPage({super.key});

  @override
  State<VendorShellPage> createState() => _VendorShellPageState();
}

class _VendorShellPageState extends State<VendorShellPage> {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final gate = context.watch<VendorGate>();

    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;

        if (user == null) {
          // 也可以改成直接顯示 LoginPage
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Navigator.of(context).pushReplacementNamed('/login');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (gate.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!gate.isVendor) {
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

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Osmile Vendor',
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
          body: const Center(
            child: Text(
              'Vendor Dashboard（Placeholder）',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        );
      },
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
                    '目前登入：$emailOrUid\n此帳號沒有 Vendor 權限，無法進入廠商後台。',
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
