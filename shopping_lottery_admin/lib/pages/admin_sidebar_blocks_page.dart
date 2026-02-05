// lib/pages/admin_sidebar_blocks_page.dart
//
// ✅ AdminSidebarBlocksPage v8.2 Final（側欄自訂區塊管理｜最終完整版）
// ------------------------------------------------------------
// Firestore 結構：sidebar_blocks/{id}
// fields:
// - title: String
// - subtitle: String
// - content: String
// - link: String
// - imageUrl: String
// - isActive: bool
// - order: int
// - createdAt, updatedAt: Timestamp
//
// Storage：/sidebar_blocks/{id}/{timestamp_filename}
// ------------------------------------------------------------
// 依賴：cloud_firestore, firebase_storage, file_picker, intl
// ------------------------------------------------------------

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminSidebarBlocksPage extends StatefulWidget {
  const AdminSidebarBlocksPage({super.key});

  @override
  State<AdminSidebarBlocksPage> createState() => _AdminSidebarBlocksPageState();
}

class _AdminSidebarBlocksPageState extends State<AdminSidebarBlocksPage> {
  final _db = FirebaseFirestore.instance;
  bool _busyReorder = false;

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Query<Map<String, dynamic>> _query() =>
      _db.collection('sidebar_blocks').orderBy('order').limit(200);

  String _fmt(dynamic v) =>
      v is Timestamp ? DateFormat('yyyy/MM/dd HH:mm').format(v.toDate()) : '-';

  Future<void> _create() async {
    final ref = _db.collection('sidebar_blocks').doc();
    final now = FieldValue.serverTimestamp();
    await ref.set({
      'title': '新側欄區塊',
      'subtitle': '',
      'content': '',
      'link': '',
      'imageUrl': '',
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
      builder: (_) => _SidebarBlockEditSheet(id: id),
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
        title: const Text('側欄自訂區塊管理'),
        actions: [
          IconButton(onPressed: _create, icon: const Icon(Icons.add_outlined)),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('尚無資料'));

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
                  final subtitle = (d['subtitle'] ?? '').toString();
                  final imageUrl = (d['imageUrl'] ?? '').toString();
                  final active = d['isActive'] == true;
                  final updated = _fmt(d['updatedAt']);

                  return Card(
                    key: ValueKey(docs[i].id),
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: ListTile(
                      leading: imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover),
                            )
                          : const Icon(Icons.widgets_outlined),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text([
                        if (subtitle.isNotEmpty) subtitle,
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
// ✅ 編輯側欄區塊 BottomSheet
// ------------------------------------------------------------
class _SidebarBlockEditSheet extends StatefulWidget {
  final String id;
  const _SidebarBlockEditSheet({required this.id});

  @override
  State<_SidebarBlockEditSheet> createState() => _SidebarBlockEditSheetState();
}

class _SidebarBlockEditSheetState extends State<_SidebarBlockEditSheet> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();

  String _imageUrl = '';
  bool _active = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await _db.collection('sidebar_blocks').doc(widget.id).get();
    if (doc.exists) {
      final d = doc.data()!;
      _titleCtrl.text = (d['title'] ?? '').toString();
      _subtitleCtrl.text = (d['subtitle'] ?? '').toString();
      _contentCtrl.text = (d['content'] ?? '').toString();
      _linkCtrl.text = (d['link'] ?? '').toString();
      _imageUrl = (d['imageUrl'] ?? '').toString();
      _active = d['isActive'] == true;
    }
    setState(() => _loading = false);
  }

  Future<void> _uploadImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final ref = _storage
        .ref('sidebar_blocks/${widget.id}/${DateTime.now().millisecondsSinceEpoch}_${file.name}');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/${file.extension ?? 'png'}'));
    final url = await ref.getDownloadURL();
    setState(() => _imageUrl = url);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _db.collection('sidebar_blocks').doc(widget.id).set({
        'title': _titleCtrl.text.trim(),
        'subtitle': _subtitleCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
        'link': _linkCtrl.text.trim(),
        'imageUrl': _imageUrl,
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
            children: [
              const Text('編輯側欄區塊', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: '標題', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _subtitleCtrl,
                decoration: const InputDecoration(labelText: '副標題', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '內文（可空白）', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _linkCtrl,
                decoration: const InputDecoration(labelText: '連結（可空白）', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              if (_imageUrl.isNotEmpty)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(_imageUrl, height: 150, width: double.infinity, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: InkWell(
                        onTap: () => setState(() => _imageUrl = ''),
                        child: Container(
                          color: Colors.black45,
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _uploadImage,
                icon: const Icon(Icons.upload_outlined),
                label: const Text('上傳圖片'),
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
