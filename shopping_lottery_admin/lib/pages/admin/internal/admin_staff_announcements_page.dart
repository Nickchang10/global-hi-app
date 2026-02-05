import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminStaffAnnouncementsPage extends StatefulWidget {
  const AdminStaffAnnouncementsPage({super.key});

  @override
  State<AdminStaffAnnouncementsPage> createState() =>
      _AdminStaffAnnouncementsPageState();
}

class _AdminStaffAnnouncementsPageState
    extends State<AdminStaffAnnouncementsPage> {
  final _db = FirebaseFirestore.instance;
  final _fmt = DateFormat('yyyy/MM/dd HH:mm');

  String _statusFilter = 'all'; // all / draft / published
  String _search = '';

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    return _db
        .collection('staff_announcements')
        .orderBy('pinned', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('內部公告管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          DropdownButton<String>(
            value: _statusFilter,
            underline: const SizedBox(),
            onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('全部')),
              DropdownMenuItem(value: 'draft', child: Text('草稿')),
              DropdownMenuItem(value: 'published', child: Text('已發布')),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '新增公告',
            icon: const Icon(Icons.add),
            onPressed: () => _openEditDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          _searchBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('載入失敗：${snap.error}'));
                }

                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((d) {
                  final data = d.data();
                  final status = data['status'] ?? 'draft';
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final content =
                      (data['content'] ?? '').toString().toLowerCase();

                  if (_statusFilter != 'all' && status != _statusFilter) {
                    return false;
                  }
                  if (_search.isEmpty) return true;
                  final s = _search.toLowerCase();
                  return title.contains(s) || content.contains(s);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('目前沒有公告'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) =>
                      _buildCard(context, filtered[i], cs),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // UI
  // =========================================================

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        onChanged: (v) => setState(() => _search = v.trim()),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: '搜尋標題 / 內容',
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ColorScheme cs,
  ) {
    final d = doc.data();
    final title = d['title'] ?? '未命名公告';
    final content = d['content'] ?? '';
    final status = d['status'] ?? 'draft';
    final pinned = d['pinned'] == true;
    final readBy = (d['readBy'] as List?)?.length ?? 0;
    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          pinned ? Icons.push_pin : Icons.campaign,
          color: pinned ? cs.primary : cs.onSurfaceVariant,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            _chip(
              status == 'published' ? '已發布' : '草稿',
              status == 'published' ? Colors.green : Colors.grey,
            ),
          ],
        ),
        subtitle: Text(
          [
            if (createdAt != null) '建立：${_fmt.format(createdAt)}',
            '已讀：$readBy 人',
            if (content.toString().isNotEmpty) content,
          ].join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => _handleAction(v, doc),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('編輯')),
            PopupMenuItem(
                value: 'toggle',
                child: Text(status == 'published' ? '轉為草稿' : '發布')),
            PopupMenuItem(
                value: 'pin', child: Text(pinned ? '取消置頂' : '置頂')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'delete', child: Text('刪除')),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }

  // =========================================================
  // Actions
  // =========================================================

  Future<void> _handleAction(
    String action,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final ref = doc.reference;
    final d = doc.data();

    switch (action) {
      case 'edit':
        _openEditDialog(doc: doc);
        break;
      case 'toggle':
        await ref.update({
          'status': d['status'] == 'published' ? 'draft' : 'published',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        break;
      case 'pin':
        await ref.update({
          'pinned': !(d['pinned'] == true),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        break;
      case 'delete':
        await ref.delete();
        break;
    }
  }

  // =========================================================
  // Create / Edit Dialog
  // =========================================================

  Future<void> _openEditDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final titleCtl = TextEditingController(text: doc?.data()['title'] ?? '');
    final contentCtl =
        TextEditingController(text: doc?.data()['content'] ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(doc == null ? '新增公告' : '編輯公告',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtl,
                decoration: const InputDecoration(labelText: '標題'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentCtl,
                maxLines: 6,
                decoration: const InputDecoration(labelText: '內容'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('儲存')),
        ],
      ),
    );

    if (ok != true) return;

    final data = {
      'title': titleCtl.text.trim(),
      'content': contentCtl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (doc == null) {
      await _db.collection('staff_announcements').add({
        ...data,
        'status': 'draft',
        'pinned': false,
        'readBy': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await doc.reference.update(data);
    }
  }
}
