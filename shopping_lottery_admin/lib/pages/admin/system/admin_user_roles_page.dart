import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminUserRolesPage extends StatefulWidget {
  const AdminUserRolesPage({super.key});

  @override
  State<AdminUserRolesPage> createState() => _AdminUserRolesPageState();
}

class _AdminUserRolesPageState extends State<AdminUserRolesPage> {
  final _db = FirebaseFirestore.instance;

  final _roles = const [
    'user',
    'vendor',
    'admin',
    'super_admin',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '使用者角色指派',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db.collection('users').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('載入失敗：${snap.error}'));
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('尚無使用者資料'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc = docs[i];
              final data = doc.data();

              final uid = doc.id;
              final name = data['name'] ?? data['email'] ?? uid;
              final role = (data['role'] ?? 'user').toString();

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('UID: $uid'),
                  trailing: DropdownButton<String>(
                    value: role,
                    onChanged: (v) => _updateRole(uid, role, v),
                    items: _roles
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r),
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _updateRole(String uid, String oldRole, String? newRole) async {
    if (newRole == null || newRole == oldRole) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認變更角色'),
        content: Text('確定要將角色由「$oldRole」改為「$newRole」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確認'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final batch = _db.batch();

      batch.update(
        _db.collection('users').doc(uid),
        {
          'role': newRole,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      // 可選：角色異動紀錄
      batch.set(
        _db.collection('role_logs').doc(),
        {
          'uid': uid,
          'from': oldRole,
          'to': newRole,
          'changedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('角色已更新')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }
}
