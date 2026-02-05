// lib/pages/users_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/admin_gate.dart';
import '../widgets/notification_bell_button.dart';
import '../widgets/user_info_badge.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String _search = '';
  bool _loading = true;
  List<_UserDoc> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final snap = await FirebaseFirestore.instance.collection('users').get();
    final list = snap.docs.map((d) => _UserDoc.fromFirestore(d)).toList();
    list.sort((a, b) => a.email.compareTo(b.email));
    setState(() {
      _users = list;
      _loading = false;
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _updateField(_UserDoc u, String field, String value) async {
    await FirebaseFirestore.instance.collection('users').doc(u.uid).update({field: value});
    _snack('已更新 ${u.email} 的 $field');
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, s) {
        final user = s.data;
        if (user == null) {
          return const Center(child: Text('請登入後查看使用者管理'));
        }
        return FutureBuilder<RoleInfo>(
          future: gate.ensureAndGetRole(user),
          builder: (context, r) {
            if (!r.hasData) return const Center(child: CircularProgressIndicator());
            final role = (r.data?.role ?? '').toLowerCase();
            if (role != 'admin') {
              return const Center(child: Text('非管理員帳號，無法進入此頁'));
            }

            return Scaffold(
              backgroundColor: const Color(0xFFF7F8FA),
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0.5,
                title: const Text('使用者管理', style: TextStyle(fontWeight: FontWeight.bold)),
                actions: const [NotificationBellButton(), SizedBox(width: 8), UserInfoBadge()],
              ),
              body: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: '搜尋 Email / Role / VendorId',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _usersFiltered.isEmpty
                              ? const Center(child: Text('無符合條件的使用者'))
                              : SingleChildScrollView(
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('Email')),
                                      DataColumn(label: Text('Role')),
                                      DataColumn(label: Text('Vendor ID')),
                                      DataColumn(label: Text('UID')),
                                      DataColumn(label: Text('動作')),
                                    ],
                                    rows: _usersFiltered.map((u) {
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(u.email)),
                                          DataCell(Text(u.role)),
                                          DataCell(Text(u.vendorId ?? '')),
                                          DataCell(Text(u.uid.substring(0, 8))),
                                          DataCell(Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit),
                                                tooltip: '編輯 Role/VendorId',
                                                onPressed: () => _editUserDialog(u),
                                              ),
                                            ],
                                          )),
                                        ],
                                      );
                                    }).toList(),
                                  ),
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

  List<_UserDoc> get _usersFiltered {
    if (_search.isEmpty) return _users;
    return _users.where((u) {
      return u.email.toLowerCase().contains(_search) ||
          u.role.toLowerCase().contains(_search) ||
          (u.vendorId ?? '').toLowerCase().contains(_search);
    }).toList();
  }

  Future<void> _editUserDialog(_UserDoc u) async {
    final roleCtrl = TextEditingController(text: u.role);
    final vendorCtrl = TextEditingController(text: u.vendorId ?? '');
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('編輯使用者：${u.email}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: 'Role')),
            const SizedBox(height: 8),
            TextField(controller: vendorCtrl, decoration: const InputDecoration(labelText: 'VendorId')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateField(u, 'role', roleCtrl.text.trim());
              await _updateField(u, 'vendorId', vendorCtrl.text.trim());
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }
}

class _UserDoc {
  final String uid;
  final String email;
  final String role;
  final String? vendorId;
  _UserDoc({required this.uid, required this.email, required this.role, this.vendorId});

  factory _UserDoc.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return _UserDoc(
      uid: doc.id,
      email: (d['email'] ?? '').toString(),
      role: (d['role'] ?? 'user').toString(),
      vendorId: (d['vendorId'] ?? '').toString(),
    );
  }
}
