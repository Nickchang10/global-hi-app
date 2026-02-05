// lib/pages/admin_topbar_page.dart
//
// ✅ AdminTopbarPage v3.0 Final（上方導覽列管理｜最終完整版）
// ------------------------------------------------------------
// Firestore 結構：topbar_items/{id}
// fields:
//   title: String
//   link: String
//   order: int
//   isActive: bool
//   createdAt, updatedAt: Timestamp
//
// 依賴：cloud_firestore, intl
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminTopbarPage extends StatefulWidget {
  const AdminTopbarPage({super.key});

  @override
  State<AdminTopbarPage> createState() => _AdminTopbarPageState();
}

class _AdminTopbarPageState extends State<AdminTopbarPage> {
  final _db = FirebaseFirestore.instance;
  bool _busyReorder = false;

  Query<Map<String, dynamic>> _query() =>
      _db.collection('topbar_items').orderBy('order').limit(200);

  String _fmt(dynamic v) =>
      v is Timestamp ? DateFormat('yyyy/MM/dd HH:mm').format(v.toDate()) : '-';

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _create() async {
    try {
      final ref = _db.collection('topbar_items').doc();
      final now = FieldValue.serverTimestamp();
      await ref.set({
        'title': '新導覽項目',
        'link': '/',
        'order': DateTime.now().millisecondsSinceEpoch,
        'isActive': true,
        'createdAt': now,
        'updatedAt': now,
      });
      await _edit(ref.id);
    } catch (e) {
      _snack('建立失敗：$e');
    }
  }

  Future<void> _edit(String id) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TopbarItemEditSheet(id: id),
    );
  }

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final title = (doc.data()?['title'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除確認'),
        content: Text('確定要刪除「$title」嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok == true) {
      await doc.reference.delete();
      _snack('已刪除');
    }
  }

  Future<void> _applyReorder(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (_busyReorder) return;
    setState(() => _busyReorder = true);
    try {
      final batch = _db.batch();
      for (int i = 0; i < docs.length; i++) {
        batch.update(docs[i].reference, {'order': i + 1});
      }
      await batch.commit();
    } finally {
      setState(() => _busyReorder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = _query().snapshots();
    return Scaffold(
      appBar: AppBar(
        title: const Text('上方導覽列管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_outlined),
            tooltip: '新增導覽項目',
            onPressed: _create,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('尚無導覽項目'));

          return Stack(
            children: [
              ReorderableListView.builder(
                itemCount: docs.length,
                onReorder: (oldIndex, newIndex) async {
                  if (newIndex > oldIndex) newIndex--;
                  final moved = docs.removeAt(oldIndex);
                  docs.insert(newIndex, moved);
                  await _applyReorder(docs);
                },
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  final title = (d['title'] ?? '').toString();
                  final link = (d['link'] ?? '').toString();
                  final isActive = d['isActive'] == true;
                  final updated = _fmt(d['updatedAt']);

                  return Card(
                    key: ValueKey(docs[i].id),
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: ListTile(
                      leading: Icon(
                        Icons.link,
                        color: isActive ? Colors.green : Colors.grey,
                      ),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('連結：$link\n狀態：${isActive ? '顯示' : '隱藏'}｜更新：$updated'),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') await _edit(docs[i].id);
                          if (v == 'toggle') {
                            await docs[i].reference
                                .update({'isActive': !isActive, 'updatedAt': FieldValue.serverTimestamp()});
                          }
                          if (v == 'delete') await _delete(docs[i]);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('編輯')),
                          PopupMenuItem(value: 'toggle', child: Text(isActive ? '隱藏' : '顯示')),
                          const PopupMenuDivider(),
                          const PopupMenuItem(value: 'delete', child: Text('刪除')),
                        ],
                      ),
                      onTap: () => _edit(docs[i].id),
                    ),
                  );
                },
              ),
              if (_busyReorder)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Material(
                    elevation: 10,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('更新排序中...', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// ✅ 導覽項目編輯底部面板
// ------------------------------------------------------------
class _TopbarItemEditSheet extends StatefulWidget {
  final String id;
  const _TopbarItemEditSheet({required this.id});

  @override
  State<_TopbarItemEditSheet> createState() => _TopbarItemEditSheetState();
}

class _TopbarItemEditSheetState extends State<_TopbarItemEditSheet> {
  final _db = FirebaseFirestore.instance;
  final _titleCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await _db.collection('topbar_items').doc(widget.id).get();
    if (doc.exists) {
      final d = doc.data()!;
      _titleCtrl.text = (d['title'] ?? '').toString();
      _linkCtrl.text = (d['link'] ?? '').toString();
      _isActive = d['isActive'] == true;
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _titleCtrl.text.trim();
    final link = _linkCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入標題')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _db.collection('topbar_items').doc(widget.id).set({
        'title': title,
        'link': link.isEmpty ? '/' : link,
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SafeArea(child: Center(child: CircularProgressIndicator()));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('編輯導覽項目', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: '標題', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _linkCtrl,
                decoration: const InputDecoration(
                  labelText: '連結（例如 /faq 或 https://example.com）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('顯示於前台'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('儲存'),
              ),
              if (_saving) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('儲存中...', style: TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
 