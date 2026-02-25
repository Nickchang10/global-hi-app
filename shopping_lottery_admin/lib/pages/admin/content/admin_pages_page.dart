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
///   content: `<html or markdown>`,
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
  late final CollectionReference<Map<String, dynamic>> _col = _db.collection(
    'site_contents',
  );

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

  Future<void> _createPage() async => _openEditor();
  Future<void> _editPage(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async => _openEditor(doc: doc);

  Future<void> _openEditor({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? <String, dynamic>{};

    final titleCtrl = TextEditingController(
      text: (data['title'] ?? '').toString(),
    );
    final keyCtrl = TextEditingController(text: (data['key'] ?? '').toString());
    final contentCtrl = TextEditingController(
      text: (data['content'] ?? '').toString(),
    );

    String status = (data['status'] ?? 'draft').toString();
    bool isPublic = data['isPublic'] == true;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        final nav = Navigator.of(
          dialogCtx,
        ); // ✅ 先拿 Navigator，避免 await 後直接用 context
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
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

                      // ✅ DropdownButtonFormField：value 已 deprecated → initialValue
                      DropdownButtonFormField<String>(
                        key: ValueKey('status_$status'),
                        initialValue: status,
                        items: const [
                          DropdownMenuItem(value: 'draft', child: Text('草稿')),
                          DropdownMenuItem(
                            value: 'published',
                            child: Text('已上架'),
                          ),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => status = v ?? status),
                        decoration: const InputDecoration(
                          labelText: '狀態',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('前台公開'),
                        value: isPublic,
                        onChanged: (v) => setDialogState(() => isPublic = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => nav.pop(), child: const Text('取消')),
                FilledButton(
                  onPressed: () async {
                    final payload = {
                      'title': titleCtrl.text.trim(),
                      'key': keyCtrl.text.trim(),
                      'content': contentCtrl.text,
                      'status': status,
                      'isPublic': isPublic,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };

                    try {
                      if (doc == null) {
                        await _col.add(payload);
                      } else {
                        await _col
                            .doc(doc.id)
                            .set(payload, SetOptions(merge: true));
                      }
                      if (!mounted) return;
                      nav.pop(); // ✅ 不用 await 後再直接用 context
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
                    }
                  },
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    keyCtrl.dispose();
    contentCtrl.dispose();
  }
}
