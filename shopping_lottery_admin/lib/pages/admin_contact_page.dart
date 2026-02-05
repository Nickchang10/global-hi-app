// lib/pages/admin_contact_page.dart
//
// ✅ AdminContactPage v4.3 Final
// ------------------------------------------------------------
// - Firestore 聯絡我們管理：搜尋 / 標記 / 刪除 / 詳細檢視
// - 欄位：name, email, subject, message, status
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminContactPage extends StatefulWidget {
  const AdminContactPage({super.key});

  @override
  State<AdminContactPage> createState() => _AdminContactPageState();
}

class _AdminContactPageState extends State<AdminContactPage> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _keyword = '';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聯絡我們管理'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_outlined),
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'all', child: Text('全部')),
              PopupMenuItem(value: 'pending', child: Text('未處理')),
              PopupMenuItem(value: 'replied', child: Text('已回覆')),
              PopupMenuItem(value: 'archived', child: Text('已封存')),
            ],
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
                prefixIcon: const Icon(Icons.search_outlined),
                hintText: '搜尋姓名、主旨或內容...',
                suffixIcon: _keyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _keyword = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) => setState(() => _keyword = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db.collection('contacts').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snap.data!.docs.where((d) {
                  final data = d.data();
                  final s = (data['status'] ?? 'pending').toString();
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final subj = (data['subject'] ?? '').toString().toLowerCase();
                  final msg = (data['message'] ?? '').toString().toLowerCase();

                  final matchFilter = _filter == 'all' || s == _filter;
                  final matchKeyword = _keyword.isEmpty ||
                      name.contains(_keyword) ||
                      subj.contains(_keyword) ||
                      msg.contains(_keyword);
                  return matchFilter && matchKeyword;
                }).toList();

                if (docs.isEmpty) return const Center(child: Text('目前沒有聯絡紀錄'));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data();
                    final name = (data['name'] ?? '').toString();
                    final email = (data['email'] ?? '').toString();
                    final subject = (data['subject'] ?? '').toString();
                    final message = (data['message'] ?? '').toString();
                    final status = (data['status'] ?? 'pending').toString();
                    final created = (data['createdAt'] is Timestamp)
                        ? DateFormat('MM/dd HH:mm').format(data['createdAt'].toDate())
                        : '';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          _iconForStatus(status),
                          color: _colorForStatus(status),
                        ),
                        title: Text(subject.isEmpty ? '(無主旨)' : subject,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$name <$email>\n$message'),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (v) => _handleAction(v, d),
                          itemBuilder: (context) => [
                            if (status != 'pending')
                              const PopupMenuItem(value: 'pending', child: Text('標記為未處理')),
                            if (status != 'replied')
                              const PopupMenuItem(value: 'replied', child: Text('標記為已回覆')),
                            if (status != 'archived')
                              const PopupMenuItem(value: 'archived', child: Text('封存')),
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'delete', child: Text('刪除')),
                          ],
                        ),
                        onTap: () => _showDetail(context, d),
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

  // ------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------

  Future<void> _handleAction(String action, DocumentSnapshot d) async {
    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('刪除確認'),
          content: Text('確定要刪除「${d['subject'] ?? ''}」嗎？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
          ],
        ),
      );
      if (ok == true) await d.reference.delete();
      return;
    }

    await d.reference.set({
      'status': action,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _showDetail(BuildContext context, DocumentSnapshot d) {
    final data = d.data() as Map<String, dynamic>;
    final name = (data['name'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final subject = (data['subject'] ?? '').toString();
    final message = (data['message'] ?? '').toString();
    final status = (data['status'] ?? '').toString();
    final created = (data['createdAt'] is Timestamp)
        ? DateFormat('yyyy/MM/dd HH:mm').format(data['createdAt'].toDate())
        : '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(subject.isEmpty ? '(無主旨)' : subject),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text('姓名：$name'),
              Text('Email：$email'),
              Text('狀態：$status'),
              Text('時間：$created'),
              const Divider(),
              Text(message),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------

  IconData _iconForStatus(String s) {
    switch (s) {
      case 'replied':
        return Icons.mark_email_read_outlined;
      case 'archived':
        return Icons.archive_outlined;
      default:
        return Icons.mail_outline;
    }
  }

  Color _colorForStatus(String s) {
    switch (s) {
      case 'replied':
        return Colors.green;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }
}
