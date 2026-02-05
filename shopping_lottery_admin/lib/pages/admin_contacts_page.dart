// lib/pages/admin_contacts_page.dart
//
// ✅ AdminContactsPage（最終完整版｜聯絡我們紀錄管理）
// ------------------------------------------------------------
// Firestore 結構：contacts/{id}
//   - name: String
//   - email: String
//   - phone: String
//   - subject: String
//   - message: String
//   - status: String ('new' / 'in_progress' / 'resolved')
//   - handler: String? （處理人）
//   - reply: String?
//   - createdAt: Timestamp
//   - updatedAt: Timestamp
//   - isActive: bool
// ------------------------------------------------------------
// 功能：
// - 即時 Firestore 監聽（新聯絡表單）
// - 狀態更新：未處理 / 處理中 / 已完成
// - 回覆備註功能
// - 搜尋 + 篩選
// - 通知系統整合 (sendToUsers)
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart'; // ✅ 整合通知服務
import 'package:provider/provider.dart';

class AdminContactsPage extends StatefulWidget {
  const AdminContactsPage({super.key});

  @override
  State<AdminContactsPage> createState() => _AdminContactsPageState();
}

class _AdminContactsPageState extends State<AdminContactsPage> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filterStatus = 'all';
  bool _showOnlyActive = true;

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamContacts() {
    Query<Map<String, dynamic>> q = _db.collection('contacts');

    if (_showOnlyActive) q = q.where('isActive', isEqualTo: true);
    if (_filterStatus != 'all') q = q.where('status', isEqualTo: _filterStatus);

    q = q.orderBy('createdAt', descending: true).limit(200);
    return q.snapshots();
  }

  Future<void> _updateStatus(
      DocumentSnapshot<Map<String, dynamic>> doc, String newStatus) async {
    await _db.collection('contacts').doc(doc.id).set(
      {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (!mounted) return;
    final notif = context.read<NotificationService>();
    await notif.sendToUsers(
      uids: ['admin'], // 可替換成管理員群組UID列表
      title: '聯絡我們狀態更新',
      body:
          '聯絡單「${doc['subject'] ?? ''}」狀態已更新為 ${_statusLabel(newStatus)}。',
      type: 'contact_update',
      route: '/admin_contacts',
    );
  }

  Future<void> _deleteContact(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除紀錄'),
        content: Text('確定要刪除「${doc['subject'] ?? ''}」嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok != true) return;
    await _db.collection('contacts').doc(doc.id).delete();
  }

  Future<void> _replyContact(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final replyCtrl = TextEditingController(text: data['reply'] ?? '');

    final reply = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('回覆聯絡單：${data['name'] ?? ''}'),
        content: TextField(
          controller: replyCtrl,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: '回覆內容（僅內部備註）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, replyCtrl.text.trim()),
            child: const Text('儲存回覆'),
          ),
        ],
      ),
    );

    if (reply == null || reply.isEmpty) return;

    await _db.collection('contacts').doc(doc.id).set(
      {
        'reply': reply,
        'status': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'new':
        return '未處理';
      case 'in_progress':
        return '處理中';
      case 'resolved':
        return '已完成';
      default:
        return '未知';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'new':
        return Colors.orange;
      case 'in_progress':
        return Colors.blueAccent;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
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
        title: const Text('聯絡我們紀錄管理'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => setState(() => _filterStatus = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'all', child: Text('全部')),
              PopupMenuItem(value: 'new', child: Text('未處理')),
              PopupMenuItem(value: 'in_progress', child: Text('處理中')),
              PopupMenuItem(value: 'resolved', child: Text('已完成')),
            ],
            icon: const Icon(Icons.filter_alt),
          ),
          IconButton(
            tooltip: _showOnlyActive ? '顯示全部' : '僅顯示啟用',
            icon: Icon(_showOnlyActive ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _showOnlyActive = !_showOnlyActive),
          ),
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
                hintText: '搜尋聯絡人姓名 / 主題',
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _streamContacts(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('載入錯誤：${snap.error}'));
                }

                final docs = snap.data?.docs ?? [];
                final filtered = _query.isEmpty
                    ? docs
                    : docs.where((d) {
                        final data = d.data();
                        final name = (data['name'] ?? '').toString().toLowerCase();
                        final subject = (data['subject'] ?? '').toString().toLowerCase();
                        return name.contains(_query.toLowerCase()) ||
                            subject.contains(_query.toLowerCase());
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('目前沒有聯絡紀錄'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final doc = filtered[i];
                    final d = doc.data();
                    final name = d['name'] ?? '';
                    final email = d['email'] ?? '';
                    final phone = d['phone'] ?? '';
                    final subject = d['subject'] ?? '';
                    final message = d['message'] ?? '';
                    final reply = d['reply'] ?? '';
                    final status = (d['status'] ?? 'new').toString();
                    final isActive = d['isActive'] == true;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: ExpansionTile(
                        leading: Icon(Icons.person, color: _statusColor(status)),
                        title: Text(subject,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$name · ${_statusLabel(status)}',
                            style: const TextStyle(color: Colors.black54)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('姓名：$name'),
                                Text('Email：$email'),
                                Text('電話：$phone'),
                                const Divider(),
                                const Text('留言內容：',
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(message.isEmpty ? '(無內容)' : message),
                                const Divider(),
                                const Text('回覆備註：',
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(reply.isEmpty ? '(尚未備註)' : reply),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 6,
                                  children: [
                                    FilledButton.icon(
                                      icon: const Icon(Icons.reply),
                                      label: const Text('回覆/備註'),
                                      onPressed: () => _replyContact(doc),
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.task_alt),
                                      label: const Text('設為完成'),
                                      onPressed: status == 'resolved'
                                          ? null
                                          : () => _updateStatus(doc, 'resolved'),
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.playlist_add_check),
                                      label: const Text('處理中'),
                                      onPressed: status == 'in_progress'
                                          ? null
                                          : () => _updateStatus(doc, 'in_progress'),
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      label: const Text('刪除',
                                          style: TextStyle(color: Colors.red)),
                                      onPressed: () => _deleteContact(doc),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
}
