import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_member_orders_management_page.dart';
import 'admin_points_tasks_management_page.dart';

class AdminMembersListPage extends StatefulWidget {
  const AdminMembersListPage({super.key});

  @override
  State<AdminMembersListPage> createState() => _AdminMembersListPageState();
}

class _AdminMembersListPageState extends State<AdminMembersListPage> {
  final _db = FirebaseFirestore.instance;
  final TextEditingController _search = TextEditingController();

  bool _loading = true;
  String? _error;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

  String _statusKey = 'all';
  String _roleKey = 'all';
  String _sortKey = 'createdAt';
  bool _sortDesc = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    Query<Map<String, dynamic>> q = _db.collection('users');
    try {
      final snap = await q.orderBy(_sortKey, descending: _sortDesc).limit(500).get();
      setState(() {
        _docs = snap.docs;
        _loading = false;
      });
    } catch (e) {
      // fallback 若沒有排序欄位，改用 docId
      try {
        final snap = await q.orderBy(FieldPath.documentId, descending: true).get();
        setState(() {
          _docs = snap.docs;
          _sortKey = 'docId';
          _loading = false;
          _error = '排序欄位不存在，已改用 docId。錯誤：$e';
        });
      } catch (e2) {
        setState(() {
          _loading = false;
          _error = e2.toString();
        });
      }
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _filtered {
    final query = _search.text.trim().toLowerCase();
    return _docs.where((doc) {
      final d = doc.data();
      final name = (d['displayName'] ?? d['name'] ?? '').toString().toLowerCase();
      final email = (d['email'] ?? '').toString().toLowerCase();
      final phone = (d['phone'] ?? '').toString().toLowerCase();
      final uid = doc.id.toLowerCase();

      final matchSearch = query.isEmpty ||
          name.contains(query) ||
          email.contains(query) ||
          phone.contains(query) ||
          uid.contains(query);

      final role = (d['role'] ?? 'user').toString().toLowerCase();
      final status = (d['status'] ?? '').toString().toLowerCase();
      final disabled = (d['disabled'] ?? false) == true;

      final matchStatus = _statusKey == 'all' ||
          (_statusKey == 'active' && !disabled && status != 'disabled') ||
          (_statusKey == 'disabled' && (disabled || status == 'disabled'));

      final matchRole = _roleKey == 'all' || role == _roleKey;

      return matchSearch && matchStatus && matchRole;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('會員列表'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null && _docs.isEmpty)
              ? Center(child: Text('載入失敗：$_error'))
              : Column(
                  children: [
                    _filterBar(),
                    const Divider(height: 1),
                    Expanded(
                      child: _filtered.isEmpty
                          ? const Center(child: Text('無符合條件的會員'))
                          : ListView.builder(
                              itemCount: _filtered.length,
                              itemBuilder: (context, i) {
                                final doc = _filtered[i];
                                final d = doc.data();
                                final name = (d['displayName'] ?? d['name'] ?? '未命名').toString();
                                final email = (d['email'] ?? '').toString();
                                final role = (d['role'] ?? 'user').toString();
                                final points = (d['points'] ?? 0).toString();
                                final disabled = (d['disabled'] ?? false) == true;
                                final createdAt = (d['createdAt'] is Timestamp)
                                    ? DateFormat('yyyy/MM/dd')
                                        .format((d['createdAt'] as Timestamp).toDate())
                                    : '';

                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      child: Text(name.substring(0, 1)),
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      [
                                        if (email.isNotEmpty) email,
                                        if (createdAt.isNotEmpty) '註冊：$createdAt',
                                      ].join('  •  '),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('積分 $points'),
                                        Text(role, style: const TextStyle(fontSize: 12)),
                                        if (disabled)
                                          const Text('停用',
                                              style: TextStyle(color: Colors.red, fontSize: 12)),
                                      ],
                                    ),
                                    onTap: () => _showDetail(doc),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜尋會員（姓名 / Email / UID）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _statusKey,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('全部')),
              DropdownMenuItem(value: 'active', child: Text('啟用')),
              DropdownMenuItem(value: 'disabled', child: Text('停用')),
            ],
            onChanged: (v) => setState(() => _statusKey = v ?? 'all'),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _roleKey,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('全部角色')),
              DropdownMenuItem(value: 'user', child: Text('user')),
              DropdownMenuItem(value: 'vendor', child: Text('vendor')),
              DropdownMenuItem(value: 'admin', child: Text('admin')),
            ],
            onChanged: (v) => setState(() => _roleKey = v ?? 'all'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetail(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data();
    final uid = doc.id;
    final name = (d['displayName'] ?? d['name'] ?? '未命名會員').toString();
    final email = (d['email'] ?? '').toString();
    final phone = (d['phone'] ?? '').toString();
    final role = (d['role'] ?? 'user').toString();
    final points = (d['points'] ?? 0).toString();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('會員詳情：$name'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('UID：$uid'),
              Text('Email：$email'),
              if (phone.isNotEmpty) Text('電話：$phone'),
              Text('角色：$role'),
              Text('積分：$points'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminMemberOrdersManagementPage(initialQuery: uid),
                ),
              );
            },
            child: const Text('查看訂單'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminPointsTasksManagementPage(initialUserId: uid),
                ),
              );
            },
            child: const Text('積分 / 任務'),
          ),
        ],
      ),
    );
  }
}
