// lib/pages/site_content_edit_page.dart
//
// ✅ SiteContentEditPage（最終完整版｜可編譯｜已修正 use_build_context_synchronously）
// ------------------------------------------------------------
// 功能：
// - 編輯站台內容（About / Terms / Privacy...）
// - Firestore：site_contents/{key}
// - 支援：新增/編輯/刪除
// - async gap 後使用 context（SnackBar / Navigator）全部加 mounted guard
//
// 路由建議：
// - /site_content_edit
// - arguments 可傳：
//   - String(key)
//   - {key: 'about'} 或 {id: 'about'}
//   - {docId: 'about'} 也可
//
// Firestore schema（彈性容錯）：
// site_contents/{key} {
//   key: 'about',
//   title: '關於我們',
//   content: '...markdown/html/plain...',
//   isActive: true,
//   updatedAt: Timestamp,
//   createdAt: Timestamp,
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SiteContentEditPage extends StatefulWidget {
  const SiteContentEditPage({super.key});

  @override
  State<SiteContentEditPage> createState() => _SiteContentEditPageState();
}

class _SiteContentEditPageState extends State<SiteContentEditPage> {
  final _db = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  final _keyCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  bool _isActive = true;
  bool _loading = false;
  String? _error;

  String _s(dynamic v) => (v ?? '').toString().trim();

  String _keyFromArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) return args.trim();
    if (args is Map) {
      final v = args['key'] ?? args['id'] ?? args['docId'];
      if (v != null) return v.toString().trim();
    }
    return '';
  }

  DocumentReference<Map<String, dynamic>> _docRef(String key) =>
      _db.collection('site_contents').doc(key);

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIfNeeded(String key) async {
    if (key.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snap = await _docRef(key).get();
      if (!mounted) return;

      if (!snap.exists) {
        // 新增模式：帶入 key
        _keyCtrl.text = key;
        setState(() => _loading = false);
        return;
      }

      final data = snap.data() ?? <String, dynamic>{};
      _keyCtrl.text = _s(data['key']).isNotEmpty ? _s(data['key']) : key;
      _titleCtrl.text = _s(data['title']);
      _contentCtrl.text = _s(data['content']);
      _isActive = (data['isActive'] ?? true) == true;

      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _save() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    final key = _keyCtrl.text.trim();
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ref = _docRef(key);
      final now = FieldValue.serverTimestamp();

      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final exists = snap.exists;

        tx.set(ref, {
          'key': key,
          'title': title,
          'content': content,
          'isActive': _isActive,
          'updatedAt': now,
          if (!exists) 'createdAt': now,
        }, SetOptions(merge: true));
      });

      if (!mounted) return; // ✅ async gap guard
      setState(() => _loading = false);
      _snack('已儲存');
      Navigator.of(context).maybePop(true); // ✅ safe
    } catch (e) {
      if (!mounted) return; // ✅ async gap guard
      setState(() {
        _loading = false;
        _error = '$e';
      });
      _snack('儲存失敗：$e');
    }
  }

  Future<void> _delete() async {
    if (_loading) return;
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) return;

    final ok =
        await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('刪除內容？'),
            content: Text('將刪除：$key'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('刪除'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _docRef(key).delete();
      if (!mounted) return; // ✅ async gap guard
      setState(() => _loading = false);
      _snack('已刪除');
      Navigator.of(context).maybePop(true);
    } catch (e) {
      if (!mounted) return; // ✅ async gap guard
      setState(() {
        _loading = false;
        _error = '$e';
      });
      _snack('刪除失敗：$e');
    }
  }

  bool _inited = false;

  @override
  Widget build(BuildContext context) {
    // 第一次 build 時載入（避免在 initState 拿不到 ModalRoute args）
    if (!_inited) {
      _inited = true;
      final key = _keyFromArgs(context);
      // ignore: discarded_futures
      _loadIfNeeded(key);
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('編輯頁面內容'),
        actions: [
          IconButton(
            tooltip: '刪除',
            onPressed: _loading ? null : _delete,
            icon: const Icon(Icons.delete_outline),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 10),
                ],
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _keyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Key（doc id，例如 about / terms / privacy）',
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Key 不可空白' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(labelText: '標題'),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? '標題不可空白' : null,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        title: const Text('啟用（isActive）'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _contentCtrl,
                        minLines: 10,
                        maxLines: 18,
                        decoration: const InputDecoration(
                          labelText: '內容（可貼 HTML / Markdown / 純文字）',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('儲存'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '資料表：site_contents',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
