// lib/widgets/user_info_badge.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';

/// 顯示登入者資訊（email / role / vendorId）
/// - 自動從 Firestore 讀取 users/{uid}
/// - 支援重新整理（forceRefresh）
/// - 支援錯誤顯示與 raw 資料查看
class UserInfoBadge extends StatefulWidget {
  const UserInfoBadge({super.key});

  @override
  State<UserInfoBadge> createState() => _UserInfoBadgeState();
}

class _UserInfoBadgeState extends State<UserInfoBadge> {
  Future<RoleInfo>? _future;
  String? _lastUid;

  AdminGate get _gate => context.read<AdminGate>();

  Future<RoleInfo> _load(User user, {bool forceRefresh = false}) {
    if (forceRefresh) {
      _gate.clearCache();
    }
    return _gate.ensureAndGetRole(user, forceRefresh: forceRefresh);
  }

  void _resetAndReload(User user, {bool forceRefresh = false}) {
    if (!mounted) return;
    setState(() {
      _lastUid = user.uid;
      _future = _load(user, forceRefresh: forceRefresh);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _SmallLoadingChip(label: 'Auth...');
        }

        final user = snap.data;
        if (user == null) return const SizedBox.shrink();

        // 若首次或換帳號 → 重新載入
        if (_future == null || _lastUid != user.uid) {
          _lastUid = user.uid;
          _future = _load(user);
        }

        return FutureBuilder<RoleInfo>(
          future: _future,
          builder: (context, roleSnap) {
            final email = (user.email ?? '').trim();
            final uid = user.uid;

            // ===== Loading =====
            if (roleSnap.connectionState == ConnectionState.waiting) {
              final label = email.isEmpty ? '讀取中...' : '$email（讀取中...）';
              return _badge(
                label: label,
                tooltip: '正在讀取 users/$uid ...',
                icon: Icons.verified_user_outlined,
                onPressed: () => _showDetails(
                  context,
                  uid: uid,
                  email: email,
                  role: 'loading',
                  vendorId: '',
                  error: null,
                  raw: null,
                  user: user,
                ),
              );
            }

            // ===== Error =====
            if (roleSnap.hasError) {
              final msg = '讀取使用者資料失敗：${roleSnap.error}';
              final label = email.isEmpty ? '讀取失敗' : '$email（錯誤）';
              return _badge(
                label: label,
                tooltip: msg,
                icon: Icons.error_outline,
                onPressed: () => _showDetails(
                  context,
                  uid: uid,
                  email: email,
                  role: 'unknown',
                  vendorId: '',
                  error: msg,
                  raw: null,
                  user: user,
                ),
              );
            }

            // ===== Success =====
            final info = roleSnap.data!;
            final role = info.role.trim();
            final vendorId = (info.vendorId ?? '').trim();
            final err = info.error;

            final label = <String>[
              if (email.isNotEmpty) email,
              if (role.isNotEmpty) role,
              if (vendorId.isNotEmpty) '($vendorId)',
            ].join(' ');

            final tooltip = (err != null && err.trim().isNotEmpty)
                ? '錯誤：${err.trim()}'
                : (vendorId.isEmpty
                    ? '點擊查看登入者資訊'
                    : 'vendorId=$vendorId（點擊查看登入者資訊）');

            final icon = (err != null && err.trim().isNotEmpty)
                ? Icons.warning_amber_rounded
                : Icons.verified_user;

            return _badge(
              label: label.isEmpty ? '登入中' : label,
              tooltip: tooltip,
              icon: icon,
              onPressed: () => _showDetails(
                context,
                uid: uid,
                email: email,
                role: role,
                vendorId: vendorId,
                error: err,
                raw: info.raw,
                user: user,
              ),
            );
          },
        );
      },
    );
  }

  Widget _badge({
    required String label,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: ActionChip(
        avatar: Icon(icon, size: 18),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
        onPressed: onPressed,
      ),
    );
  }

  String _prettyMap(Map<String, dynamic> m) {
    // 簡易格式化，讓 dialog 比較好讀
    final keys = m.keys.toList()..sort();
    return keys.map((k) => '$k: ${m[k]}').join('\n');
  }

  void _showDetails(
    BuildContext context, {
    required String uid,
    required String email,
    required String role,
    required String vendorId,
    required String? error,
    required Map<String, dynamic>? raw,
    required User user,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('登入者資訊'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SelectableText(
            [
              'uid: $uid',
              'email: $email',
              'role: $role',
              'vendorId: $vendorId',
              if (error != null && error.trim().isNotEmpty) 'error: ${error.trim()}',
              if (raw != null) ...[
                '',
                '--- users/$uid ---',
                _prettyMap(raw),
              ],
            ].join('\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetAndReload(user, forceRefresh: true);
            },
            child: const Text('重新整理'),
          ),
        ],
      ),
    );
  }
}

class _SmallLoadingChip extends StatelessWidget {
  const _SmallLoadingChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      label: Text(label),
      onPressed: () {},
    );
  }
}
