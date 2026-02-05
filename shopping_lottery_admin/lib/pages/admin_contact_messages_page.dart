// lib/pages/admin_contact_messages_page.dart
//
// ✅ AdminContactMessagesPage v5.0 Final
// ------------------------------------------------------------
// 功能：聯絡我們留言管理
// - Firestore 即時監聽 contact_messages
// - 搜尋 / 分類 / 狀態標記 / 刪除 / 展開查看
// - 與前台表單相容
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminContactMessagesPage extends StatefulWidget {
  const AdminContactMessagesPage({super.key});

  @override
  State<AdminContactMessagesPage> createState() =>
      _AdminContactMessagesPageState();
}

class _AdminContactMessagesPageState extends State<AdminContactMessagesPage> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _keyword = '';
  String _category = '全部';
  String _status = '全部';

  Query<Map<String, dynamic>> get _query =>
      _db.collection('contact_messages').orderBy('createdAt', descending: true);

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatTime(dynamic v) {
    if (v is Timestamp) {
      return DateFormat('yyyy/MM/dd HH:mm').format(v.toDate());
    }
    return '-';
  }

  Future<void> _updateStatus(DocumentSnapshot doc, String newStatus) async {
    await doc.reference.set({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _delete(DocumentSnapshot doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除確認'),
        content: Text('確定要刪除「${doc['subject'] ?? '(無主旨)'}」留言？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('刪除')),
        ],
      ),
    );
    if (ok == true) await doc.reference.delete();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聯絡我們留言管理'),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query.snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snap.data!.docs;

                final cats = <String>{};
                for (final d in all) {
                  final c = (d.data()['category'] ?? '').toString().trim();
                  if (c.isNotEmpty) cats.add(c);
                }
                final categoryItems = ['全部', ...cats.toList()..sort()];

                if (!categoryItems.contains(_category)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _category = '全部');
                  });
                }

                final filtered = all.where((d) {
                  final data = d.data();
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final subject = (data['subject'] ?? '').toString().toLowerCase();
                  final msg = (data['message'] ?? '').toString().toLowerCase();
                  final cat = (data['category'] ?? '').toString();
                  final status = (data['status'] ?? '').toString();

                  final kw = _keyword.toLowerCase();
                  final okKw = kw.isEmpty ||
                      name.contains(kw) ||
                      email.contains(kw) ||
                      subject.contains(kw) ||
                      msg.contains(kw);

                  final okCat = _category == '全部' || cat == _category;
                  final okStatus =
                      _status == '全部' || status == _status.toLowerCase();

                  return okKw && okCat && okStatus;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('目前沒有留言'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final d = filtered[i];
                    final data = d.data();
                    final name = (data['name'] ?? '').toString();
                    final email = (data['email'] ?? '').toString();
                    final subject = (data['subject'] ?? '').toString();
                    final msg = (data['message'] ?? '').toString();
                    final phone = (data['phone'] ?? '').toString();
                    final category = (data['category'] ?? '').toString();
                    final status = (data['status'] ?? 'new').toString();
                    final created = _formatTime(data['createdAt']);

                    Color statusColor = Colors.blueGrey;
                    if (status == 'new') statusColor = Colors.orange;
                    if (status == 'processing') statusColor = Colors.blue;
                    if (status == 'done') statusColor = Colors.green;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: ExpansionTile(
                        key: ValueKey(d.id),
                        leading: Icon(Icons.email_outlined, color: statusColor),
                        title: Text(subject.isEmpty ? '(無主旨)' : subject,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('分類：$category ｜ 狀態：$status ｜ 時間：$created'),
                        children: [
                          ListTile(
                            title: Text(name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (email.isNotEmpty) Text('Email：$email'),
                                if (phone.isNotEmpty) Text('電話：$phone'),
                                const SizedBox(height: 8),
                                Text('訊息內容：'),
                                Text(msg),
                              ],
                            ),
                          ),
                          const Divider(),
                          ButtonBar(
                            alignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _updateStatus(d, 'new'),
                                child: const Text('標為新'),
                              ),
                              TextButton(
                                onPressed: () => _updateStatus(d, 'processing'),
                                child: const Text('處理中'),
                              ),
                              TextButton(
                                onPressed: () => _updateStatus(d, 'done'),
                                child: const Text('已完成'),
                              ),
                              TextButton(
                                onPressed: () => _delete(d),
                                child: const Text('刪除'),
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 250,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋姓名 / 主旨 / 內容',
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: _keyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _keyword = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _keyword = v.trim()),
            ),
          ),
          DropdownButton<String>(
            value: _category,
            items: ['全部', _category]
                .toSet()
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? '全部'),
          ),
          DropdownButton<String>(
            value: _status,
            items: const ['全部', 'new', 'processing', 'done']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? '全部'),
          ),
          IconButton(
            tooltip: '清除搜尋',
            onPressed: () {
              _searchCtrl.clear();
              setState(() {
                _keyword = '';
                _category = '全部';
                _status = '全部';
              });
            },
            icon: const Icon(Icons.clear_all),
          ),
        ],
      ),
    );
  }
}
