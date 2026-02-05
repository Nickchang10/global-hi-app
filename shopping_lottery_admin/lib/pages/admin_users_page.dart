// lib/pages/admin_users_page.dart
//
// ✅ AdminUsersPage v6.0 Final（可編譯完整版）
// ------------------------------------------------------------
// - Firestore 結構：users/{uid}
// - 欄位：name, email, phone, isActive, role, createdAt, updatedAt
// - 功能：搜尋 / 啟用停用 / 刪除 / 編輯 / 新增（限 Admin）
// - Admin 可管理所有使用者，Vendor 僅可查看顧客
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/admin_gate.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(dynamic ts) {
    if (ts == null) return '-';
    final d = (ts is Timestamp) ? ts.toDate() : DateTime.tryParse(ts.toString());
    if (d == null) return '-';
    return DateFormat('yyyy/MM/dd HH:mm').format(d);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggle(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>?;
    final now = FieldValue.serverTimestamp();
    final active = !(data?['isActive'] == true);
    await doc.reference.update({'isActive': active, 'updatedAt': now});
  }

  Future<void> _edit(DocumentSnapshot? doc) async {
    final editing = doc != null;
    final data = editing ? doc.data() as Map<String, dynamic>? : {};
    final nameCtrl = TextEditingController(text: data?['name'] ?? '');
    final emailCtrl = TextEditingController(text: data?['email'] ?? '');
    final phoneCtrl = TextEditingController(text: data?['phone'] ?? '');
    final roleCtrl = TextEditingController(text: data?['role'] ?? 'user');
    bool isActive = data?['isActive'] ?? true;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(editing ? '編輯使用者' : '新增使用者'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '姓名')),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '電話')),
              TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: '角色（admin/vendor/user）')),
              SwitchListTile(title: const Text('啟用狀態'), value: isActive, onChanged: (v) => isActive = v),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final email = emailCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              final role = roleCtrl.text.trim().toLowerCase();
              final now = FieldValue.serverTimestamp();

              if (name.isEmpty || email.isEmpty) {
                _snack('請輸入姓名與 Email');
                return;
              }

              final update = {
                'name': name,
                'email': email,
                'phone': phone,
                'role': role,
                'isActive': isActive,
                'updatedAt': now,
                if (!editing) 'createdAt': now,
              };

              if (editing) {
                await doc!.reference.set(update, SetOptions(merge: true));
              } else {
                await _db.collection('users').add(update);
              }
              if (context.mounted) Navigator.pop(context);
              _snack('已儲存');
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(DocumentSnapshot doc) async {
    final name = (doc.data() as Map)['name'] ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除確認'),
        content: Text('確定要刪除使用者「$name」嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok != true) return;
    await doc.reference.delete();
    _snack('已刪除');
  }

  @override
  Widget build(BuildContext context) {
    final gate = context.watch<AdminGate>();
    final info = gate.cachedRoleInfo;
    final role = (info?.role ?? '').toLowerCase().trim();
    final isAdmin = role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('顧客管理'),
        actions: [
          if (isAdmin)
            IconButton(icon: const Icon(Icons.add_outlined), onPressed: () => _edit(null)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋姓名 / Email / 電話',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _keyword = '');
                  },
                ),
              ),
              onChanged: (v) => setState(() => _keyword = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('users').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                final filtered = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();
                  return _keyword.isEmpty || name.contains(_keyword) || email.contains(_keyword) || phone.contains(_keyword);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('目前沒有使用者資料'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final doc = filtered[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? '';
                    final email = data['email'] ?? '';
                    final phone = data['phone'] ?? '';
                    final isActive = data['isActive'] == true;
                    final role = (data['role'] ?? '').toString();

                    return Card(
                      child: ListTile(
                        leading: Icon(Icons.person, color: isActive ? Colors.green : Colors.grey),
                        title: Text(name),
                        subtitle: Text('Email: $email\n電話: $phone\n角色: $role'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _edit(doc);
                            if (v == 'toggle') _toggle(doc);
                            if (v == 'delete') _delete(doc);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('編輯')),
                            PopupMenuItem(value: 'toggle', child: Text(isActive ? '停用' : '啟用')),
                            if (isAdmin) const PopupMenuItem(value: 'delete', child: Text('刪除')),
                          ],
                        ),
                      ),
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
}
