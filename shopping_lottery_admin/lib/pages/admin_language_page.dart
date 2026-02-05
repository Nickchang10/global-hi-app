// lib/pages/admin_language_page.dart
//
// ✅ AdminLanguagePage v6.4 Final（多語系管理｜最終完整版）
// ------------------------------------------------------------
// Firestore: languages/{id}
// fields:
// - code: String (例: zh-TW, en, ja)
// - name: String (例: 中文、English)
// - flagUrl: String
// - isActive: bool
// - isDefault: bool (僅允許一個)
// - order: number
// - createdAt: Timestamp
// - updatedAt: Timestamp
//
// Storage: languages/{code}/{flag.png}
// ------------------------------------------------------------
// 依賴：cloud_firestore, firebase_storage, file_picker, intl
// ------------------------------------------------------------

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminLanguagePage extends StatefulWidget {
  const AdminLanguagePage({super.key});

  @override
  State<AdminLanguagePage> createState() => _AdminLanguagePageState();
}

class _AdminLanguagePageState extends State<AdminLanguagePage> {
  final _db = FirebaseFirestore.instance;
  bool _busyReorder = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmt(dynamic v) {
    if (v is Timestamp) return DateFormat('yyyy/MM/dd HH:mm').format(v.toDate());
    return '-';
  }

  Query<Map<String, dynamic>> _query() {
    return _db.collection('languages').orderBy('order');
  }

  Future<void> _create() async {
    final ref = _db.collection('languages').doc();
    final now = FieldValue.serverTimestamp();
    await ref.set({
      'code': 'xx',
      'name': '新語系',
      'flagUrl': '',
      'isActive': true,
      'isDefault': false,
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
      builder: (_) => _LanguageEditSheet(id: id),
    );
  }

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final code = (data['code'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除語系'),
        content: Text('確定要刪除 $code？'),
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
      if (mounted) setState(() => _busyReorder = false);
    }
  }

  Future<void> _toggleActive(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final cur = doc.data()?['isActive'] == true;
    await doc.reference.update({'isActive': !cur});
  }

  Future<void> _setDefault(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final all = await _db.collection('languages').get();
    final batch = _db.batch();
    for (final d in all.docs) {
      batch.update(d.reference, {'isDefault': d.id == doc.id});
    }
    await batch.commit();
    _snack('已設定為預設語系');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('多語系管理'),
        actions: [
          IconButton(
            tooltip: '新增語系',
            onPressed: _create,
            icon: const Icon(Icons.add_outlined),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _query().snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('尚無語系'));

          return Stack(
            children: [
              ReorderableListView.builder(
                itemCount: docs.length,
                onReorder: (oldIndex, newIndex) async {
                  if (_busyReorder) return;
                  if (newIndex > oldIndex) newIndex--;
                  final moved = docs.removeAt(oldIndex);
                  docs.insert(newIndex, moved);
                  await _applyReorder(docs);
                },
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  final code = (d['code'] ?? '').toString();
                  final name = (d['name'] ?? '').toString();
                  final flag = (d['flagUrl'] ?? '').toString();
                  final active = d['isActive'] == true;
                  final isDefault = d['isDefault'] == true;

                  return Card(
                    key: ValueKey(docs[i].id),
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: ListTile(
                      leading: flag.isEmpty
                          ? const CircleAvatar(child: Icon(Icons.flag_outlined))
                          : CircleAvatar(backgroundImage: NetworkImage(flag)),
                      title: Text('$name ($code)',
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(
                        [
                          '狀態：${active ? '啟用' : '停用'}',
                          if (isDefault) '預設語系',
                          '更新：${_fmt(d['updatedAt'])}',
                        ].join('｜'),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') await _edit(docs[i].id);
                          if (v == 'toggle') await _toggleActive(docs[i]);
                          if (v == 'default') await _setDefault(docs[i]);
                          if (v == 'delete') await _delete(docs[i]);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('編輯')),
                          PopupMenuItem(value: 'toggle', child: Text(active ? '停用' : '啟用')),
                          const PopupMenuItem(value: 'default', child: Text('設為預設')),
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
                      padding: EdgeInsets.all(10),
                      child: Row(
                        children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 10),
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
// ✅ 編輯語系 BottomSheet
// ------------------------------------------------------------
class _LanguageEditSheet extends StatefulWidget {
  final String id;
  const _LanguageEditSheet({required this.id});

  @override
  State<_LanguageEditSheet> createState() => _LanguageEditSheetState();
}

class _LanguageEditSheetState extends State<_LanguageEditSheet> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _active = true;
  bool _default = false;
  bool _saving = false;
  bool _loading = true;

  String _flagUrl = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await _db.collection('languages').doc(widget.id).get();
    if (doc.exists) {
      final d = doc.data()!;
      _codeCtrl.text = (d['code'] ?? '').toString();
      _nameCtrl.text = (d['name'] ?? '').toString();
      _active = d['isActive'] == true;
      _default = d['isDefault'] == true;
      _flagUrl = (d['flagUrl'] ?? '').toString();
    }
    setState(() => _loading = false);
  }

  Future<void> _pickAndUploadFlag() async {
    if (_saving) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;

    setState(() => _saving = true);
    try {
      if (_flagUrl.isNotEmpty) {
        try {
          await _storage.refFromURL(_flagUrl).delete();
        } catch (_) {}
      }

      final safeName = f.name.replaceAll(' ', '_');
      final path = 'languages/${_codeCtrl.text.trim()}/$safeName';
      final ref = _storage.ref().child(path);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
      final url = await ref.getDownloadURL();
      setState(() => _flagUrl = url);
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入代碼')));
      return;
    }

    setState(() => _saving = true);
    try {
      await _db.collection('languages').doc(widget.id).set({
        'code': code,
        'name': _nameCtrl.text.trim(),
        'flagUrl': _flagUrl,
        'isActive': _active,
        'isDefault': _default,
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
              const Text('編輯語系', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              TextField(
                controller: _codeCtrl,
                decoration: const InputDecoration(labelText: '語系代碼 (zh-TW, en...)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '名稱', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('旗幟', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickAndUploadFlag,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(_flagUrl.isEmpty ? '上傳' : '替換'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_flagUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(_flagUrl, height: 60),
                ),
              const SizedBox(height: 10),
              SwitchListTile(
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: const Text('啟用'),
              ),
              SwitchListTile(
                value: _default,
                onChanged: (v) => setState(() => _default = v),
                title: const Text('預設語系'),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: const Text('儲存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
