// lib/pages/admin/content/admin_site_contents_page.dart
//
// ✅ AdminSiteContentsPage（網站靜態頁管理｜完整版）
// ------------------------------------------------------------
// - Firestore: site_contents
// - 頁面鍵值固定（home, about, privacy, support...）
// - 支援 Markdown / HTML 編輯 + 預覽
// - 儲存版本記錄（subcollection: versions）
// ------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AdminSiteContentsPage extends StatefulWidget {
  const AdminSiteContentsPage({super.key});

  @override
  State<AdminSiteContentsPage> createState() => _AdminSiteContentsPageState();
}

class _AdminSiteContentsPageState extends State<AdminSiteContentsPage> {
  final _db = FirebaseFirestore.instance;
  final _pages = const {
    'home': '首頁介紹',
    'about': '關於我們',
    'privacy': '隱私政策',
    'support': '客服資訊',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('網站內容管理', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db.collection('site_contents').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('載入錯誤：${snap.error}'));

          final docs = {for (var d in snap.data?.docs ?? []) d.id: d};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: _pages.entries.map((e) {
              final doc = docs[e.key];
              final data = doc?.data() ?? {};
              final updatedAt = data['updatedAt'] is Timestamp
                  ? (data['updatedAt'] as Timestamp).toDate().toString().split('.')[0]
                  : '尚未編輯';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('更新時間：$updatedAt'),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _openEditor(e.key, e.value, doc),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Future<void> _openEditor(String pageKey, String pageTitle,
      QueryDocumentSnapshot<Map<String, dynamic>>? doc) async {
    await showDialog(
      context: context,
      builder: (_) => _ContentEditorDialog(
        pageKey: pageKey,
        pageTitle: pageTitle,
        initial: doc?.data(),
        docRef: doc?.reference,
      ),
    );
  }
}

// ======================================================
// 編輯 Dialog
// ======================================================

class _ContentEditorDialog extends StatefulWidget {
  final String pageKey;
  final String pageTitle;
  final Map<String, dynamic>? initial;
  final DocumentReference<Map<String, dynamic>>? docRef;

  const _ContentEditorDialog({
    required this.pageKey,
    required this.pageTitle,
    this.initial,
    this.docRef,
  });

  @override
  State<_ContentEditorDialog> createState() => _ContentEditorDialogState();
}

class _ContentEditorDialogState extends State<_ContentEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  String _contentType = 'html';
  bool _previewMode = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initial ?? {};
    _title.text = d['title'] ?? widget.pageTitle;
    _content.text = d['content'] ?? '';
    _contentType = (d['contentType'] ?? 'html').toString();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text('編輯：${widget.pageTitle}',
          style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 860,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: '標題'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  DropdownButton<String>(
                    value: _contentType,
                    items: const [
                      DropdownMenuItem(value: 'html', child: Text('HTML 模式')),
                      DropdownMenuItem(value: 'markdown', child: Text('Markdown 模式')),
                    ],
                    onChanged: (v) => setState(() => _contentType = v ?? 'html'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: Icon(_previewMode ? Icons.visibility_off : Icons.visibility),
                    label: Text(_previewMode ? '隱藏預覽' : '預覽'),
                    onPressed: () => setState(() => _previewMode = !_previewMode),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _previewMode
                  ? Container(
                      padding: const EdgeInsets.all(10),
                      height: 320,
                      decoration: BoxDecoration(
                        border: Border.all(color: cs.outlineVariant),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _contentType == 'markdown'
                          ? Markdown(data: _content.text)
                          : SingleChildScrollView(child: Text(_content.text)),
                    )
                  : TextFormField(
                      controller: _content,
                      decoration: InputDecoration(
                        labelText:
                            _contentType == 'markdown' ? '內容（Markdown）' : '內容（HTML）',
                        border: const OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 15,
                    ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton.icon(
          icon: _saving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                )
              : const Icon(Icons.save),
          label: Text(_saving ? '儲存中...' : '儲存'),
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final ref = widget.docRef ??
          FirebaseFirestore.instance.collection('site_contents').doc(widget.pageKey);

      final payload = {
        'pageKey': widget.pageKey,
        'title': _title.text.trim(),
        'content': _content.text.trim(),
        'contentType': _contentType,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'admin',
      };

      await ref.set(payload, SetOptions(merge: true));

      // 儲存版本記錄
      await ref.collection('versions').add({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('內容已儲存並建立版本記錄')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
