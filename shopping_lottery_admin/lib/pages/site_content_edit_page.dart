// lib/pages/site_content_edit_page.dart
//
// ✅ SiteContentEditPage v1.3 Final
// ------------------------------------------------------------
// - 富文字編輯 (flutter_quill)
// - Firebase Storage 圖片上傳
// - Firestore CRUD 儲存
// - Delta JSON 格式保存
// ------------------------------------------------------------

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class SiteContentEditPage extends StatefulWidget {
  final String category;
  final String? contentId;
  const SiteContentEditPage({
    super.key,
    required this.category,
    this.contentId,
  });

  @override
  State<SiteContentEditPage> createState() => _SiteContentEditPageState();
}

class _SiteContentEditPageState extends State<SiteContentEditPage> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _titleCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _quillCtrl = quill.QuillController.basic();

  bool _loading = false;
  bool _saving = false;
  List<String> _images = [];

  bool get _isEdit => widget.contentId != null;
  late final String _docId =
      widget.contentId ?? _db.collection('site_contents').doc().id;
  late final DocumentReference<Map<String, dynamic>> _ref =
      _db.collection('site_contents').doc(_docId);

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final doc = await _ref.get();
      if (doc.exists) {
        final d = doc.data()!;
        _titleCtrl.text = (d['title'] ?? '').toString();
        final body = d['body'];
        if (body is List) {
          // 以 Delta 儲存的 JSON
          _quillCtrl.document = quill.Document.fromJson(body);
        } else if (body is String) {
          _quillCtrl.document =
              quill.Document()..insert(0, body.replaceAll(RegExp(r'<[^>]*>'), ''));
        }
        _images = List<String>.from(d['images'] ?? []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('讀取失敗：$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _uploadImage() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.image, allowMultiple: false, withData: true);
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;

    final path =
        'site/${widget.category}/${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(' ', '_')}';
    final ref = _storage.ref(path);
    await ref.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(contentType: 'image/${file.extension ?? 'png'}'));
    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final now = FieldValue.serverTimestamp();
      final body = _quillCtrl.document.toDelta().toJson();
      await _ref.set({
        'category': widget.category,
        'title': _titleCtrl.text.trim(),
        'body': body,
        'images': _images,
        'updatedAt': now,
        if (!_isEdit) 'createdAt': now,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('內容已儲存')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEdit || _saving) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除確認'),
        content: const Text('確定要刪除此內容？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('刪除')),
        ],
      ),
    );
    if (ok != true) return;
    await _ref.delete();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? '編輯內容' : '新增內容';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_isEdit)
            IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _saving ? null : _delete),
          IconButton(
              icon: const Icon(Icons.save_outlined),
              onPressed: _saving ? null : _save),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          labelText: '標題',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? '請輸入標題' : null,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            quill.QuillToolbar.basic(
                              controller: _quillCtrl,
                              showVideoButton: false,
                              showCameraButton: false,
                              onImagePickCallback: (_) async {
                                final url = await _uploadImage();
                                if (url != null) {
                                  setState(() => _images.add(url));
                                  return url;
                                }
                                return null;
                              },
                            ),
                            Container(
                              height: 350,
                              padding: const EdgeInsets.all(8),
                              child: quill.QuillEditor.basic(
                                controller: _quillCtrl,
                                readOnly: false,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_images.isNotEmpty) ...[
                        const Text('已上傳圖片：',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _images.map((url) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(url,
                                      height: 100,
                                      width: 100,
                                      fit: BoxFit.cover),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: InkWell(
                                    onTap: _saving
                                        ? null
                                        : () async {
                                            setState(
                                                () => _images.remove(url));
                                            try {
                                              await FirebaseStorage.instance
                                                  .refFromURL(url)
                                                  .delete();
                                            } catch (_) {}
                                          },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: const Icon(Icons.close,
                                          size: 16, color: Colors.white),
                                    ),
                                  ),
                                )
                              ],
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: const Text('儲存內容'),
                      ),
                    ],
                  ),
                ),

                // 處理中浮層
                if (_saving)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black26,
                      child: const Center(
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(strokeWidth: 4),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
