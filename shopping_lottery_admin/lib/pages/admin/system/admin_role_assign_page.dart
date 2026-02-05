// lib/pages/admin/system/admin_user_role_assign_page.dart
//
// ✅ AdminUserRoleAssignPage（最終完整版｜使用者套角色）
// ------------------------------------------------------------
// Firestore：
// - users/{uid}.roleId
// - users/{uid}.role
// - roles/{id}
//
// 功能：
// - 使用者列表
// - 搜尋（email / name / uid）
// - 指派角色（roles）
// - 防止自我降權
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminUserRoleAssignPage extends StatefulWidget {
  const AdminUserRoleAssignPage({super.key});

  @override
  State<AdminUserRoleAssignPage> createState() =>
      _AdminUserRoleAssignPageState();
}

class _AdminUserRoleAssignPageState extends State<AdminUserRoleAssignPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _searchCtl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream() {
    return _db.collection('users').limit(1000).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _rolesStream() {
    return _db.collection('roles').orderBy('name').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _auth.currentUser?.uid;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '使用者角色指派',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          _searchBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder(
              stream: _rolesStream(),
              builder: (context,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> roleSnap) {
                if (!roleSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final roles = {
                  for (final d in roleSnap.data!.docs)
                    d.id: d.data()['name'] ?? '未命名角色'
                };

                return StreamBuilder(
                  stream: _usersStream(),
                  builder: (context,
                      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(child: Text('載入失敗：${snap.error}'));
                    }

                    final users = snap.data?.docs
                            .map((d) => _UserDoc.fromDoc(d))
                            .where((u) => _matchSearch(u))
                            .toList() ??
                        [];

                    if (users.isEmpty) {
                      return const Center(child: Text('沒有符合條件的使用者'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                      itemCount: users.length,
                      itemBuilder: (_, i) =>
                          _buildTile(users[i], roles, myUid, cs),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchCtl,
        onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: '搜尋：email / 名稱 / uid',
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: _searchCtl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _searchCtl.clear();
                      _search = '';
                    });
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildTile(
    _UserDoc u,
    Map<String, String> roles,
    String? myUid,
    ColorScheme cs,
  ) {
    final isMe = u.uid == myUid;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Text(
            u.displayName.isNotEmpty
                ? u.displayName.characters.first.toUpperCase()
                : '?',
            style: TextStyle(color: cs.onPrimaryContainer),
          ),
        ),
        title: Text(
          u.displayName.isNotEmpty ? u.displayName : '(未填名稱)',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          [
            if (u.email.isNotEmpty) u.email,
            'uid: ${u.uid}',
            '目前角色：${roles[u.roleId] ?? u.role}',
          ].join('\n'),
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        trailing: DropdownButton<String>(
          value: u.roleId.isEmpty ? null : u.roleId,
          hint: const Text('選擇角色'),
          onChanged: isMe ? null : (v) => _assignRole(u, v!, roles),
          items: roles.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // ============================================================
  // Logic
  // ============================================================

  bool _matchSearch(_UserDoc u) {
    if (_search.isEmpty) return true;
    return [
      u.uid,
      u.email,
      u.displayName,
    ].join(' ').toLowerCase().contains(_search);
  }

  Future<void> _assignRole(
    _UserDoc u,
    String roleId,
    Map<String, String> roles,
  ) async {
    try {
      await _db.collection('users').doc(u.uid).set({
        'roleId': roleId,
        'role': roles[roleId], // 兼容你既有 rules
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _toast('已指派角色：${roles[roleId]}');
    } catch (e) {
      _toast('更新失敗：$e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ============================================================
// Model
// ============================================================

class _UserDoc {
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final String roleId;

  const _UserDoc({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.roleId,
  });

  factory _UserDoc.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return _UserDoc(
      uid: doc.id,
      email: (d['email'] ?? '').toString(),
      displayName: (d['displayName'] ?? '').toString(),
      role: (d['role'] ?? '').toString(),
      roleId: (d['roleId'] ?? '').toString(),
    );
  }
}
