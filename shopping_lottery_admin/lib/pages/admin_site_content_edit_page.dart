// lib/pages/admin_site_content_edit_page.dart
//
// ✅ AdminSiteContentEditPage v4.7 Final
// ------------------------------------------------------------
// - 支援 Quill 富文本編輯、圖片上傳、多圖管理、Firestore 自動更新
// ------------------------------------------------------------

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class AdminSiteContentEditPage extends StatefulWidget {
  final String category;
  final String? contentId;
  const AdminSiteContentEditPage({super.key, required this.category, this.contentId});

  @override
  State<AdminSiteContentEditPage> createState() => _AdminSiteContentEditPageState();
}

class _AdminSiteContentEditPageState extends State<AdminSiteContentEditPage> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _quillCtrl = quill.QuillController.basic();
  List<String> _images = [];
  bool _active = true;
  bool _saving = false;
  bool _loading = false;

  late final _ref = _db.collection('site_contents').doc(widget.contentId ?? _db.collection('site_contents').doc().id);
  bool get _isEdit => widget.contentId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final doc = await _ref.get();
    if (doc.exists) {
      final d = doc.data()!;
      _titleCtrl.text = d['title'] ?? '';
      _active = d['isActive'] == true;
      _images = List<String>.from(d['imageUrls'] ?? []);
      final html = (d['bodyHtml'] ?? '').toString();
      _quillCtrl.document = quill.Document.fromDelta(
        quill.Delta()..insert(html.replaceAll(RegExp(r'<[^>]*>'), '') + '\n'),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<String?> _uploadImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;
    final path = 'site/${widget.category}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/${file.extension ?? 'jpg'}'));
    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = FieldValue.serverTimestamp();
    await _ref.set({
      'category': widget.category,
      'title': _titleCtrl.text.trim(),
      'bodyHtml': _quillCtrl.document.toPlainText(),
      'imageUrls': _images,
      'isActive': _active,
      'updatedAt': now,
      if (!_isEdit) 'createdAt': now,
    }, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已儲存')));
      Navigator.pop(context);
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? '編輯內容' : '新增內容';
    return Scaffold(
      appBar: AppBar(title: Text('$title - ${widget.category}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(labelText: '標題', border: OutlineInputBorder()),
                      validator: (v) => (v ?? '').trim().isEmpty ? '請輸入標題' : null,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('前台上架'),
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
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
                            height: 300,
                            padding: const EdgeInsets.all(8),
                            child: quill.QuillEditor.basic(controller: _quillCtrl, readOnly: false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_images.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _images
                            .map((url) => Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(url, width: 100, height: 100, fit: BoxFit.cover),
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: InkWell(
                                        onTap: () async {
                                          setState(() => _images.remove(url));
                                          try {
                                            await FirebaseStorage.instance.refFromURL(url).delete();
                                          } catch (_) {}
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                          padding: const EdgeInsets.all(2),
                                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 20),
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
