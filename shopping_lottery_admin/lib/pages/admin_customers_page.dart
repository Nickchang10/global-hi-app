// lib/pages/admin_customers_page.dart
//
// ✅ AdminCustomersPage（顧客管理｜完整版）
// ------------------------------------------------------------
// Firestore: users/{uid}
// 支援：搜尋 / 啟用停用 / 角色顯示 / 最後登入 / 刪除帳號
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminCustomersPage extends StatefulWidget {
  const AdminCustomersPage({super.key});

  @override
  State<AdminCustomersPage> createState() => _AdminCustomersPageState();
}

class _AdminCustomersPageState extends State<AdminCustomersPage> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _kw = '';
  String _roleFilter = '全部';
  String _activeFilter = '全部';

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _fmt(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('yyyy/MM/dd HH:mm').format(ts.toDate());
    }
    return '-';
  }

  Future<void> _toggleActive(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final current = doc.data()?['isActive'] == true;
    await doc.reference.update({
      'isActive': !current,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final name = doc.data()?['displayName'] ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除帳號確認'),
        content: Text('確定要刪除「$name」的帳號？（此操作不可回復）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok != true) return;
    await doc.reference.delete();
    _snack('已刪除帳號');
  }

  bool _matchFilters(Map<String, dynamic> d) {
    final kw = _kw.trim().toLowerCase();
    final name = (d['displayName'] ?? '').toString().toLowerCase();
    final email = (d['email'] ?? '').toString().toLowerCase();
    final phone = (d['phone'] ?? '').toString().toLowerCase();
    final role = (d['role'] ?? '').toString().toLowerCase();
    final isActive = d['isActive'] == true;

    if (kw.isNotEmpty && !(name.contains(kw) || email.contains(kw) || phone.contains(kw))) {
      return false;
    }
    if (_roleFilter != '全部' && _roleFilter.toLowerCase() != role) return false;
    if (_activeFilter == '啟用' && !isActive) return false;
    if (_activeFilter == '停用' && isActive) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final usersRef = _db.collection('users').orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('顧客管理'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '搜尋名稱 / 電話 / 信箱',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _kw = v),
                  ),
                ),
                DropdownButton<String>(
                  value: _roleFilter,
                  items: const ['全部', 'user', 'vendor', 'admin']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _roleFilter = v ?? '全部'),
                ),
                DropdownButton<String>(
                  value: _activeFilter,
                  items: const ['全部', '啟用', '停用']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _activeFilter = v ?? '全部'),
                ),
                IconButton(
                  tooltip: '清除',
                  icon: const Icon(Icons.clear_all),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _kw = '';
                      _roleFilter = '全部';
                      _activeFilter = '全部';
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: usersRef.snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs.where((d) => _matchFilters(d.data())).toList();
                if (docs.isEmpty) return const Center(child: Text('目前沒有符合條件的使用者'));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    final name = d['displayName'] ?? '(未命名)';
                    final email = d['email'] ?? '';
                    final phone = d['phone'] ?? '';
                    final role = (d['role'] ?? 'user').toString();
                    final active = d['isActive'] == true;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          Icons.person_outline,
                          color: active ? Colors.green : Colors.grey,
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('角色：$role｜Email：$email｜電話：$phone｜建立：${_fmt(d['createdAt'])}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'toggle') _toggleActive(doc);
                            if (v == 'delete') _delete(doc);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(active ? '停用帳號' : '啟用帳號'),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'delete', child: Text('刪除帳號')),
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
