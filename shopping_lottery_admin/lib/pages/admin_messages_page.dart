// lib/pages/admin_messages_page.dart
//
// ✅ AdminMessagesPage（最終完整版｜留言板管理）
// ------------------------------------------------------------
// Firestore 結構：messages/{id}
//   - name: String
//   - email: String
//   - subject: String
//   - message: String
//   - reply: String?
//   - status: String ('pending' / 'replied')
//   - isActive: bool
//   - createdAt: Timestamp
//   - updatedAt: Timestamp
// ------------------------------------------------------------
// 功能：
// - 即時監聽留言列表
// - 搜尋留言（subject / name）
// - 管理員回覆（更新 reply, status）
// - 啟用／停用留言顯示
// - 支援刪除留言與狀態標記
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminMessagesPage extends StatefulWidget {
  const AdminMessagesPage({super.key});

  @override
  State<AdminMessagesPage> createState() => _AdminMessagesPageState();
}

class _AdminMessagesPageState extends State<AdminMessagesPage> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _showOnlyPending = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamMessages() {
    Query<Map<String, dynamic>> q = _db.collection('messages');

    if (_showOnlyPending) {
      q = q.where('status', isEqualTo: 'pending');
    }

    q = q.orderBy('createdAt', descending: true);

    return q.snapshots();
  }

  Future<void> _deleteMessage(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除留言'),
        content: Text('確定要刪除「${doc['subject'] ?? ''}」嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok != true) return;
    await _db.collection('messages').doc(doc.id).delete();
  }

  Future<void> _toggleActive(String id, bool toActive) async {
    await _db.collection('messages').doc(id).set(
      {'isActive': toActive, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> _openReplyDialog(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final replyCtrl = TextEditingController(text: data['reply'] ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('回覆留言：${data['name'] ?? ''}'),
        content: TextField(
          controller: replyCtrl,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: '回覆內容',
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

    if (result == null) return;
    await _db.collection('messages').doc(doc.id).set(
      {
        'reply': result,
        'status': 'replied',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('留言板管理'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          IconButton(
            tooltip: _showOnlyPending ? '顯示全部' : '僅顯示待回覆',
            icon: Icon(_showOnlyPending ? Icons.mark_email_read : Icons.mark_email_unread),
            onPressed: () => setState(() => _showOnlyPending = !_showOnlyPending),
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
                hintText: '搜尋留言標題 / 姓名',
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
              stream: _streamMessages(),
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
                  return const Center(child: Text('目前沒有留言'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final doc = filtered[i];
                    final d = doc.data();
                    final name = d['name'] ?? '';
                    final email = d['email'] ?? '';
                    final subject = d['subject'] ?? '';
                    final message = d['message'] ?? '';
                    final reply = d['reply'] ?? '';
                    final status = (d['status'] ?? 'pending').toString();
                    final isActive = d['isActive'] == true;
                    final isPending = status == 'pending';
                    final color = isPending ? Colors.orange : Colors.green;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: ExpansionTile(
                        leading: Icon(
                          isPending ? Icons.mark_email_unread : Icons.mark_email_read,
                          color: color,
                        ),
                        title: Text(subject, style: textTheme.titleMedium),
                        subtitle: Text('$name · $email',
                            style: textTheme.bodySmall?.copyWith(color: Colors.black54)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('留言內容：', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(message.isEmpty ? '(無內容)' : message),
                                const Divider(),
                                const Text('管理員回覆：',
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                reply.isEmpty
                                    ? const Text('(尚未回覆)')
                                    : Text(reply, style: const TextStyle(color: Colors.blue)),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    FilledButton.icon(
                                      icon: const Icon(Icons.reply),
                                      label: const Text('回覆'),
                                      onPressed: () => _openReplyDialog(doc),
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton.icon(
                                      icon: Icon(
                                          isActive
                                              ? Icons.visibility_off
                                              : Icons.visibility_outlined,
                                          size: 18),
                                      label: Text(isActive ? '停用' : '啟用'),
                                      onPressed: () => _toggleActive(doc.id, !isActive),
                                    ),
                                    const SizedBox(width: 10),
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      label: const Text('刪除',
                                          style: TextStyle(color: Colors.red)),
                                      onPressed: () => _deleteMessage(doc),
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
