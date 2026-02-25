// lib/pages/users_page.dart
//
// ✅ UsersPage（修正完整版｜可編譯｜修正 DropdownButtonFormField value deprecated → initialValue）
//
// 功能：
// - 後台使用者列表（Firestore: users collection）
// - 搜尋（uid / email / name）
// - Role 篩選（all/admin/vendor/user）
// - AdminGate 權限保護（僅 admin 可進）
// - AppBar 顯示 UserInfoBadge（✅ title 必填）
// - 可點擊檢視使用者資料 Dialog（可選擇更新 role/vendorId）
//
// 依賴：
// - firebase_auth
// - cloud_firestore
// - provider
// - services/auth_service.dart
// - services/admin_gate.dart
// - widgets/user_info_badge.dart
// - pages/login_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/admin_gate.dart';
import '../widgets/user_info_badge.dart';
import 'login_page.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _db = FirebaseFirestore.instance;

  Future<RoleInfo>? _roleFuture;
  String? _lastUid;

  final _searchCtrl = TextEditingController();
  String _q = '';
  String _roleFilter = '__all__'; // __all__/admin/vendor/user/unknown

  bool _saving = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _logout() async {
    final gate = context.read<AdminGate>();
    final auth = context.read<AuthService>();
    gate.clearCache();
    await auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  String _badgeTitle(User user) {
    final dn = (user.displayName ?? '').trim();
    if (dn.isNotEmpty) return dn;
    final em = (user.email ?? '').trim();
    if (em.isNotEmpty) return em;
    return user.uid;
  }

  bool _matchQuery(Map<String, dynamic> u) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;

    final uid = _s(u['uid']).toLowerCase();
    final email = _s(u['email']).toLowerCase();
    final name = _s(u['name']).toLowerCase();

    return uid.contains(q) || email.contains(q) || name.contains(q);
  }

  bool _matchRole(Map<String, dynamic> u) {
    if (_roleFilter == '__all__') return true;
    final role = _s(u['role']).toLowerCase();
    if (_roleFilter == 'unknown') return role.isEmpty || role == 'unknown';
    return role == _roleFilter;
  }

  Stream<List<Map<String, dynamic>>> _usersStream() {
    // users collection（若你實際是 members/profile，改這裡即可）
    return _db.collection('users').snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        return <String, dynamic>{'uid': d.id, ...data};
      }).toList();
    });
  }

  Future<void> _updateUser(String uid, Map<String, dynamic> patch) async {
    setState(() => _saving = true);
    try {
      await _db.collection('users').doc(uid).set({
        ...patch,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack('已更新 $uid');
    } catch (e) {
      _snack('更新失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openUserDialog(Map<String, dynamic> u) async {
    final uid = _s(u['uid']);
    final email = _s(u['email']);
    final name = _s(u['name']);
    final role = _s(u['role']).isEmpty ? 'unknown' : _s(u['role']);
    final vendorId = _s(u['vendorId']);
    final disabled = (u['disabled'] ?? false) == true;

    final roleCtrl = TextEditingController(text: role);
    final vendorCtrl = TextEditingController(text: vendorId);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(name.isNotEmpty ? name : (email.isNotEmpty ? email : uid)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText('uid: $uid'),
              if (email.isNotEmpty) SelectableText('email: $email'),
              const SizedBox(height: 12),
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(
                  labelText: 'role（admin/vendor/user/unknown）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                enabled: !_saving,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: vendorCtrl,
                decoration: const InputDecoration(
                  labelText: 'vendorId（可空）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                enabled: !_saving,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('disabled:'),
                  const SizedBox(width: 8),
                  Text(disabled ? 'true' : 'false'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(dialogCtx, false),
            child: const Text('關閉'),
          ),
          FilledButton(
            onPressed: _saving ? null : () => Navigator.pop(dialogCtx, true),
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('儲存'),
          ),
        ],
      ),
    );

    if (ok != true) {
      roleCtrl.dispose();
      vendorCtrl.dispose();
      return;
    }

    final newRole = roleCtrl.text.trim().toLowerCase();
    final newVendor = vendorCtrl.text.trim();

    roleCtrl.dispose();
    vendorCtrl.dispose();

    await _updateUser(uid, {'role': newRole, 'vendorId': newVendor});
  }

  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();
    final authSvc = context.read<AuthService>();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnap.data;
        if (user == null) {
          gate.clearCache();
          return const LoginPage();
        }

        if (_roleFuture == null || _lastUid != user.uid) {
          _lastUid = user.uid;
          _roleFuture = gate.ensureAndGetRole(user, forceRefresh: false);
        }

        return FutureBuilder<RoleInfo>(
          future: _roleFuture,
          builder: (context, roleSnap) {
            if (!roleSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final role = (roleSnap.data?.role ?? 'unknown')
                .trim()
                .toLowerCase();

            if (role != 'admin') {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Users'),
                  actions: [
                    UserInfoBadge(
                      title: _badgeTitle(user),
                      subtitle: (user.email ?? '').trim(),
                      role: role,
                      uid: user.uid,
                    ),
                    IconButton(
                      tooltip: '登出',
                      icon: const Icon(Icons.logout),
                      onPressed: _logout,
                    ),
                  ],
                ),
                body: const Center(child: Text('需要 Admin 權限')),
              );
            }

            final badgeTitle = _badgeTitle(user);

            return Scaffold(
              appBar: AppBar(
                title: const Text('使用者管理'),
                actions: [
                  UserInfoBadge(
                    title: badgeTitle,
                    subtitle: (user.email ?? '').trim(),
                    role: role,
                    uid: user.uid,
                  ),
                  IconButton(
                    tooltip: '登出',
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      gate.clearCache();
                      await authSvc.signOut();
                      if (!context.mounted) return;
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: '搜尋 uid / email / name',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => setState(() => _q = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            // ✅ FIX: `value:` deprecated → `initialValue:`
                            // 為了讓外部 _roleFilter 變動時 UI 也跟著刷新，補 key
                            key: ValueKey(_roleFilter),
                            initialValue: _roleFilter,
                            decoration: const InputDecoration(
                              labelText: 'Role',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: '__all__',
                                child: Text('全部'),
                              ),
                              DropdownMenuItem(
                                value: 'admin',
                                child: Text('admin'),
                              ),
                              DropdownMenuItem(
                                value: 'vendor',
                                child: Text('vendor'),
                              ),
                              DropdownMenuItem(
                                value: 'user',
                                child: Text('user'),
                              ),
                              DropdownMenuItem(
                                value: 'unknown',
                                child: Text('unknown/空'),
                              ),
                            ],
                            onChanged: (v) => setState(() {
                              _roleFilter = v ?? '__all__';
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _usersStream(),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final all = snap.data ?? [];
                          final list = all
                              .where(_matchQuery)
                              .where(_matchRole)
                              .toList();

                          if (list.isEmpty) {
                            return const Center(child: Text('沒有符合的使用者'));
                          }

                          final isWide =
                              MediaQuery.sizeOf(context).width >= 980;

                          if (isWide) {
                            return SingleChildScrollView(
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('uid')),
                                  DataColumn(label: Text('email')),
                                  DataColumn(label: Text('name')),
                                  DataColumn(label: Text('role')),
                                  DataColumn(label: Text('vendorId')),
                                  DataColumn(label: Text('操作')),
                                ],
                                rows: list.map((u) {
                                  final uid = _s(u['uid']);
                                  return DataRow(
                                    cells: [
                                      DataCell(SelectableText(uid)),
                                      DataCell(Text(_s(u['email']))),
                                      DataCell(Text(_s(u['name']))),
                                      DataCell(
                                        Text(
                                          _s(u['role']).isEmpty
                                              ? 'unknown'
                                              : _s(u['role']),
                                        ),
                                      ),
                                      DataCell(Text(_s(u['vendorId']))),
                                      DataCell(
                                        IconButton(
                                          tooltip: '檢視/編輯',
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () => _openUserDialog(u),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final u = list[i];
                              final uid = _s(u['uid']);
                              final email = _s(u['email']);
                              final name = _s(u['name']);
                              final role = _s(u['role']).isEmpty
                                  ? 'unknown'
                                  : _s(u['role']);

                              return Card(
                                child: ListTile(
                                  title: Text(
                                    name.isNotEmpty
                                        ? name
                                        : (email.isNotEmpty ? email : uid),
                                  ),
                                  subtitle: Text('uid: $uid\nrole: $role'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _openUserDialog(u),
                                ),
                              );
                            },
                          );
                        },
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
