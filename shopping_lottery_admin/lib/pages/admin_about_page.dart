// lib/pages/admin_about_page.dart
//
// ✅ AdminAboutPage v3.0 Final
// ------------------------------------------------------------
// - 公司簡介與願景內容管理
// - Firestore + Firebase Storage 整合
// - 圖片上傳、排序、上下架、編輯
// - type: 'company' / 'vision'
// ------------------------------------------------------------

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class AdminAboutPage extends StatefulWidget {
  final String type; // company / vision
  const AdminAboutPage({super.key, required this.type});

  @override
  State<AdminAboutPage> createState() => _AdminAboutPageState();
}

class _AdminAboutPageState extends State<AdminAboutPage> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  bool _loading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

  String get _title => widget.type == 'vision' ? '願景與理念管理' : '公司簡介管理';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = await _db
          .collection('about_sections')
          .where('type', isEqualTo: widget.type)
          .orderBy('order')
          .get();
      setState(() => _docs = q.docs);
    } catch (e) {
      _snack('載入失敗：$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _createNew() async {
    final ref = await _db.collection('about_sections').add({
      'type': widget.type,
      'title': '新段落',
      'body': '',
      'imageUrl': '',
      'order': _docs.length + 1,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _snack('已新增段落');
    _load();
    _edit(ref.id);
  }

  Future<void> _delete(DocumentSnapshot d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除確認'),
        content: Text('確定要刪除「${d['title'] ?? ''}」嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final img = (d['imageUrl'] ?? '').toString();
      if (img.isNotEmpty) {
        try {
          await _storage.refFromURL(img).delete();
        } catch (_) {}
      }
      await d.reference.delete();
      _snack('已刪除');
      _load();
    } catch (e) {
      _snack('刪除失敗：$e');
    }
  }

  Future<void> _toggleActive(DocumentSnapshot d) async {
    await d.reference.set({
      'isActive': !(d['isActive'] == true),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _load();
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final items = List.of(_docs);
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    setState(() => _docs = items);

    for (int i = 0; i < items.length; i++) {
      await items[i].reference.set({'order': i + 1}, SetOptions(merge: true));
    }
  }

  Future<void> _edit(String id) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AboutEditSheet(id: id),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(icon: const Icon(Icons.add_outlined), onPressed: _createNew),
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _docs.isEmpty
              ? const Center(child: Text('目前沒有段落內容'))
              : ReorderableListView.builder(
                  itemCount: _docs.length,
                  onReorder: _reorder,
                  itemBuilder: (context, i) {
                    final d = _docs[i];
                    final active = d['isActive'] == true;
                    final title = (d['title'] ?? '').toString();
                    final body = (d['body'] ?? '').toString();
                    final img = (d['imageUrl'] ?? '').toString();

                    return Card(
                      key: ValueKey(d.id),
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: img.isEmpty
                            ? const Icon(Icons.image_outlined, size: 40)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(img, width: 50, height: 50, fit: BoxFit.cover),
                              ),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          body.isEmpty ? '(尚無內容)' : body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            switch (v) {
                              case 'toggle':
                                _toggleActive(d);
                                break;
                              case 'edit':
                                _edit(d.id);
                                break;
                              case 'delete':
                                _delete(d);
                                break;
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(active ? '下架' : '上架'),
                            ),
                            const PopupMenuItem(value: 'edit', child: Text('編輯')),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('刪除', style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                        onTap: () => _edit(d.id),
                      ),
                    );
                  },
                ),
    );
  }
}

// ------------------------------------------------------------
// ✅ 編輯 BottomSheet：標題 / 內文 / 圖片
// ------------------------------------------------------------
class _AboutEditSheet extends StatefulWidget {
  final String id;
  const _AboutEditSheet({required this.id});

  @override
  State<_AboutEditSheet> createState() => _AboutEditSheetState();
}

class _AboutEditSheetState extends State<_AboutEditSheet> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String? _imageUrl;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await _db.collection('about_sections').doc(widget.id).get();
    if (doc.exists) {
      final d = doc.data()!;
      _titleCtrl.text = (d['title'] ?? '').toString();
      _bodyCtrl.text = (d['body'] ?? '').toString();
      _imageUrl = (d['imageUrl'] ?? '').toString().isEmpty ? null : d['imageUrl'];
    }
    setState(() => _loading = false);
  }

  Future<void> _uploadImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null) return;
    final file = result.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _saving = true);
    try {
      final path = 'about/${widget.id}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = _storage.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/${file.extension ?? 'jpg'}'));
      final url = await ref.getDownloadURL();
      await _db.collection('about_sections').doc(widget.id).set({
        'imageUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      setState(() => _imageUrl = url);
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _db.collection('about_sections').doc(widget.id).set({
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('編輯段落', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: '標題', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _bodyCtrl,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: '內文', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  if (_imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(_imageUrl!, height: 150, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _uploadImage,
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('上傳圖片'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('儲存'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
