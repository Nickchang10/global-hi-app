// lib/pages/admin_footer_page.dart
//
// ✅ AdminFooterPage v7.5 Final（網站底部 Footer 管理｜最終完整版）
// ------------------------------------------------------------
// Firestore 結構：footer_blocks/{id}
// fields:
// - section: String (例：about / links / social / contact)
// - title: String
// - content: String (可為 HTML / 純文字)
// - icon: String? (FontAwesome / Material icon name，用於社群連結)
// - link: String? (外部連結)
// - isActive: bool
// - order: int
// - createdAt, updatedAt
//
// ------------------------------------------------------------
// 依賴：cloud_firestore, intl
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminFooterPage extends StatefulWidget {
  const AdminFooterPage({super.key});

  @override
  State<AdminFooterPage> createState() => _AdminFooterPageState();
}

class _AdminFooterPageState extends State<AdminFooterPage> {
  final _db = FirebaseFirestore.instance;
  bool _busyReorder = false;

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _fmt(dynamic v) =>
      v is Timestamp ? DateFormat('yyyy/MM/dd HH:mm').format(v.toDate()) : '-';

  Query<Map<String, dynamic>> _query() =>
      _db.collection('footer_blocks').orderBy('order').limit(300);

  Future<void> _create() async {
    final ref = _db.collection('footer_blocks').doc();
    final now = FieldValue.serverTimestamp();
    await ref.set({
      'section': 'about',
      'title': '新區塊',
      'content': '這是新的 Footer 內容',
      'icon': '',
      'link': '',
      'isActive': true,
      'order': DateTime.now().millisecondsSinceEpoch,
      'createdAt': now,
      'updatedAt': now,
    });
    await _edit(ref.id);
  }

  Future<void> _edit(String id) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FooterEditSheet(id: id),
    );
  }

  Future<void> _toggleActive(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final cur = doc.data()?['isActive'] == true;
    await doc.reference.update({'isActive': !cur});
  }

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final title = (doc.data()?['title'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除 Footer 區塊'),
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
        title: const Text('網站底部 Footer 管理'),
        actions: [
          IconButton(onPressed: _create, icon: const Icon(Icons.add_outlined), tooltip: '新增區塊'),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('尚無 Footer 區塊'));

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
                  final section = (d['section'] ?? '').toString();
                  final title = (d['title'] ?? '').toString();
                  final link = (d['link'] ?? '').toString();
                  final icon = (d['icon'] ?? '').toString();
                  final active = d['isActive'] == true;
                  final updated = _fmt(d['updatedAt']);

                  return Card(
                    key: ValueKey(docs[i].id),
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: ListTile(
                      leading: Icon(
                        icon.isNotEmpty ? Icons.link_outlined : Icons.article_outlined,
                        color: active ? Colors.blue : Colors.grey,
                      ),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text([
                        '區塊：$section',
                        if (link.isNotEmpty) '連結：$link',
                        '狀態：${active ? '上架' : '下架'}',
                        '更新：$updated'
                      ].join('｜')),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') await _edit(docs[i].id);
                          if (v == 'toggle') await _toggleActive(docs[i]);
                          if (v == 'delete') await _delete(docs[i]);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('編輯')),
                          PopupMenuItem(value: 'toggle', child: Text(active ? '下架' : '上架')),
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
                    elevation: 12,
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
// ✅ BottomSheet：編輯 Footer 區塊
// ------------------------------------------------------------
class _FooterEditSheet extends StatefulWidget {
  final String id;
  const _FooterEditSheet({required this.id});

  @override
  State<_FooterEditSheet> createState() => _FooterEditSheetState();
}

class _FooterEditSheetState extends State<_FooterEditSheet> {
  final _db = FirebaseFirestore.instance;

  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _iconCtrl = TextEditingController();

  bool _active = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await _db.collection('footer_blocks').doc(widget.id).get();
    if (doc.exists) {
      final d = doc.data()!;
      _titleCtrl.text = (d['title'] ?? '').toString();
      _contentCtrl.text = (d['content'] ?? '').toString();
      _sectionCtrl.text = (d['section'] ?? '').toString();
      _linkCtrl.text = (d['link'] ?? '').toString();
      _iconCtrl.text = (d['icon'] ?? '').toString();
      _active = d['isActive'] == true;
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _db.collection('footer_blocks').doc(widget.id).set({
        'title': _titleCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
        'section': _sectionCtrl.text.trim(),
        'link': _linkCtrl.text.trim(),
        'icon': _iconCtrl.text.trim(),
        'isActive': _active,
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
    if (_loading) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }

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
            children: [
              const Text('編輯 Footer 區塊',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 10),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: '標題', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '內容', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sectionCtrl,
                decoration: const InputDecoration(labelText: '區塊代號 (about / social / contact)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _linkCtrl,
                decoration: const InputDecoration(labelText: '連結（可空白）', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _iconCtrl,
                decoration: const InputDecoration(labelText: 'Icon 名稱（例：facebook / mail）', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('前台顯示（上架）'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('儲存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
