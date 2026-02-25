// lib/pages/admin/content/admin_site_pages_page.dart
//
// ✅ AdminSitePagesPage（site_contents｜About/Terms/Privacy｜單檔完整版｜可編譯）
// ------------------------------------------------------------
// Firestore: collection 'site_contents'
// docs: about / terms / privacy
// 欄位建議：title, content, updatedAt
//

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSitePagesPage extends StatelessWidget {
  const AdminSitePagesPage({super.key});

  static const String routeName = '/admin-content/pages';

  static const _items = <_SiteDoc>[
    _SiteDoc(id: 'about', label: 'About（關於我們）'),
    _SiteDoc(id: 'terms', label: 'Terms（服務條款）'),
    _SiteDoc(id: 'privacy', label: 'Privacy（隱私權政策）'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '頁面內容（site_contents）',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._items.map((e) => _DocCard(doc: e)),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final _SiteDoc doc;
  const _DocCard({required this.doc});

  Future<Map<String, dynamic>?> _load() async {
    final snap = await FirebaseFirestore.instance
        .collection('site_contents')
        .doc(doc.id)
        .get();
    return snap.data();
  }

  Future<void> _edit(BuildContext context, Map<String, dynamic>? data) async {
    final titleCtrl = TextEditingController(
      text: (data?['title'] ?? doc.label).toString(),
    );
    final contentCtrl = TextEditingController(
      text: (data?['content'] ?? '').toString(),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('編輯：${doc.label}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: '標題 title'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentCtrl,
                  minLines: 10,
                  maxLines: 24,
                  decoration: const InputDecoration(
                    labelText: '內容 content',
                    helperText: '可先用純文字；之後若要 Markdown/HTML 再擴充欄位即可',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('儲存'),
          ),
        ],
      ),
    );

    if (ok != true) {
      return;
    }

    final payload = <String, dynamic>{
      'title': titleCtrl.text.trim(),
      'content': contentCtrl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('site_contents')
          .doc(doc.id)
          .set(payload, SetOptions(merge: true));

      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已更新')));
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _load(),
      builder: (context, snap) {
        final data = snap.data;
        final title = (data?['title'] ?? doc.label).toString().trim();
        final content = (data?['content'] ?? '').toString().trim();

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content.isEmpty ? '(尚未設定內容)' : content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () => _edit(context, data),
                  icon: const Icon(Icons.edit),
                  label: const Text('編輯'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SiteDoc {
  final String id;
  final String label;
  const _SiteDoc({required this.id, required this.label});
}
