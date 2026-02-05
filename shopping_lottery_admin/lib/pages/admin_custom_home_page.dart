// lib/pages/admin_custom_home_page.dart
//
// ✅ AdminCustomHomePage v6.6 Final（首頁自訂區塊管理｜最終完整版）
// ------------------------------------------------------------
// Firestore 結構：custom_home/{id}
// fields:
// - group: String (分組，例如 banner / promo / news)
// - title: String
// - subtitle: String
// - link: String
// - imageUrl: String
// - isActive: bool
// - order: int
// - createdAt, updatedAt
//
// Storage 路徑: custom_home/{group}/{timestamp}_{filename}
//
// ------------------------------------------------------------
// 依賴：cloud_firestore, firebase_storage, file_picker, intl
// ------------------------------------------------------------

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminCustomHomePage extends StatefulWidget {
  const AdminCustomHomePage({super.key});

  @override
  State<AdminCustomHomePage> createState() => _AdminCustomHomePageState();
}

class _AdminCustomHomePageState extends State<AdminCustomHomePage> {
  final _db = FirebaseFirestore.instance;
  bool _busyReorder = false;

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _fmt(dynamic v) =>
      v is Timestamp ? DateFormat('yyyy/MM/dd HH:mm').format(v.toDate()) : '-';

  Query<Map<String, dynamic>> _query() =>
      _db.collection('custom_home').orderBy('order').limit(300);

  Future<void> _create() async {
    final ref = _db.collection('custom_home').doc();
    final now = FieldValue.serverTimestamp();
    await ref.set({
      'group': 'main',
      'title': '新區塊',
      'subtitle': '',
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
      builder: (_) => _CustomHomeEditSheet(id: id),
    );
  }

  Future<void> _toggleActive(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final cur = doc.data()?['isActive'] == true;
    await doc.reference.update({'isActive': !cur});
  }

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final title = (doc.data()?['title'] ?? '').toString();
    final image = (doc.data()?['imageUrl'] ?? '').toString();
    bool deleteImage = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('刪除區塊'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('確定刪除「$title」嗎？'),
              if (image.isNotEmpty)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: deleteImage,
                  onChanged: (v) => setState(() => deleteImage = v ?? false),
                  title: const Text('同步刪除圖片'),
                  subtitle: const Text('會嘗試刪除 Storage 上的圖片'),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
          ],
        ),
      ),
    );
    if (ok == true) {
      if (deleteImage && image.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(image).delete();
        } catch (_) {}
      }
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
      if (mounted) setState(() => _busyReorder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = _query().snapshots();
    return Scaffold(
      appBar: AppBar(
        title: const Text('首頁自訂區塊管理'),
        actions: [
          IconButton(onPressed: _create, icon: const Icon(Icons.add_outlined), tooltip: '新增'),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('尚無區塊'));

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
                  final group = (d['group'] ?? '').toString();
                  final title = (d['title'] ?? '').toString();
                  final sub = (d['subtitle'] ?? '').toString();
                  final link = (d['link'] ?? '').toString();
                  final image = (d['imageUrl'] ?? '').toString();
                  final active = d['isActive'] == true;
                  final updated = _fmt(d['updatedAt']);

                  return Card(
                    key: ValueKey(docs[i].id),
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: ListTile(
                      leading: image.isEmpty
                          ? const CircleAvatar(child: Icon(Icons.image_outlined))
                          : CircleAvatar(backgroundImage: NetworkImage(image)),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text([
                        if (group.isNotEmpty) '群組：$group',
                        if (sub.isNotEmpty) sub,
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
// ✅ 編輯自訂區塊 BottomSheet
// ------------------------------------------------------------
class _CustomHomeEditSheet extends StatefulWidget {
  final String id;
  const _CustomHomeEditSheet({required this.id});

  @override
  State<_CustomHomeEditSheet> createState() => _CustomHomeEditSheetState();
}

class _CustomHomeEditSheetState extends State<_CustomHomeEditSheet> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final _titleCtrl = TextEditingController();
  final _subCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();

  bool _active = true;
  String _imageUrl = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await _db.collection('custom_home').doc(widget.id).get();
    if (doc.exists) {
      final d = doc.data()!;
      _titleCtrl.text = (d['title'] ?? '').toString();
      _subCtrl.text = (d['subtitle'] ?? '').toString();
      _linkCtrl.text = (d['link'] ?? '').toString();
      _groupCtrl.text = (d['group'] ?? '').toString();
      _active = d['isActive'] == true;
      _imageUrl = (d['imageUrl'] ?? '').toString();
    }
    setState(() => _loading = false);
  }

  Future<void> _pickAndUploadImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;

    setState(() => _saving = true);
    try {
      if (_imageUrl.isNotEmpty) {
        try {
          await _storage.refFromURL(_imageUrl).delete();
        } catch (_) {}
      }
      final safeName = f.name.replaceAll(' ', '_');
      final path = 'custom_home/${_groupCtrl.text.trim()}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final ref = _storage.ref().child(path);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
      final url = await ref.getDownloadURL();
      setState(() => _imageUrl = url);
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _db.collection('custom_home').doc(widget.id).set({
        'title': _titleCtrl.text.trim(),
        'subtitle': _subCtrl.text.trim(),
        'link': _linkCtrl.text.trim(),
        'group': _groupCtrl.text.trim(),
        'imageUrl': _imageUrl.trim(),
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
              const Text('編輯自訂區塊',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 10),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: '標題', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _subCtrl,
                decoration: const InputDecoration(labelText: '副標題（可空白）', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _linkCtrl,
                decoration: const InputDecoration(labelText: '連結（可空白）', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _groupCtrl,
                decoration: const InputDecoration(labelText: '群組（例：banner, promo）', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('圖片', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _pickAndUploadImage,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(_imageUrl.isEmpty ? '上傳' : '替換'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(_imageUrl, height: 100, fit: BoxFit.cover),
                ),
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
