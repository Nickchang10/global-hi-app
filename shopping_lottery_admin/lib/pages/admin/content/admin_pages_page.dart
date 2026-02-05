import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// =============================================================
/// AdminPagesPage（頁面內容 CMS｜site_contents）
/// 最終完整版｜可直接使用｜可編譯
///
/// Firestore collection：site_contents
/// 建議結構：
/// {
///   key: "about" | "terms" | "privacy",
///   title: "關於我們",
///   content: "<html or markdown>",
///   status: "draft" | "published",
///   isPublic: true,
///   updatedAt: Timestamp,
/// }
/// =============================================================
class AdminPagesPage extends StatefulWidget {
  const AdminPagesPage({super.key});

  @override
  State<AdminPagesPage> createState() => _AdminPagesPageState();
}

class _AdminPagesPageState extends State<AdminPagesPage> {
  final _db = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _col =
      _db.collection('site_contents');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '頁面內容管理（CMS）',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '新增頁面',
            icon: const Icon(Icons.add),
            onPressed: _createPage,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _col.orderBy('updatedAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('讀取失敗：${snap.error}'));
          }

          final docs = snap.data?.docs ?? const [];

          if (docs.isEmpty) {
            return const Center(child: Text('尚未建立任何頁面內容'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) => _buildTile(docs[i]),
          );
        },
      ),
    );
  }

  Widget _buildTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final title = (d['title'] ?? '').toString();
    final key = (d['key'] ?? doc.id).toString();
    final status = (d['status'] ?? 'draft').toString();
    final isPublic = d['isPublic'] == true;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListTile(
        title: Text(
          title.isEmpty ? '(未命名頁面)' : title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          'key: $key\n'
          '狀態: $status ｜ ${isPublic ? "公開" : "不公開"}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _editPage(doc),
        ),
      ),
    );
  }

  Future<void> _createPage() async {
    await _openEditor();
  }

  Future<void> _editPage(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await _openEditor(doc: doc);
  }

  Future<void> _openEditor({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final titleCtrl =
        TextEditingController(text: doc?.data()['title'] ?? '');
    final keyCtrl =
        TextEditingController(text: doc?.data()['key'] ?? '');
    final contentCtrl =
        TextEditingController(text: doc?.data()['content'] ?? '');

    String status = doc?.data()['status'] ?? 'draft';
    bool isPublic = doc?.data()['isPublic'] == true;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(doc == null ? '新增頁面' : '編輯頁面'),
        content: SizedBox(
          width: 900,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: '標題',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: keyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Key（about / terms / privacy）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentCtrl,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: '內容',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: status,
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('草稿')),
                    DropdownMenuItem(value: 'published', child: Text('已上架')),
                  ],
                  onChanged: (v) => status = v ?? status,
                  decoration: const InputDecoration(
                    labelText: '狀態',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  title: const Text('前台公開'),
                  value: isPublic,
                  onChanged: (v) => isPublic = v,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final data = {
                'title': titleCtrl.text.trim(),
                'key': keyCtrl.text.trim(),
                'content': contentCtrl.text,
                'status': status,
                'isPublic': isPublic,
                'updatedAt': FieldValue.serverTimestamp(),
              };

              if (doc == null) {
                await _col.add(data);
              } else {
                await _col.doc(doc.id).set(data, SetOptions(merge: true));
              }

              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }
}
