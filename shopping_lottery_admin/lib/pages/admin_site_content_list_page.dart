// lib/pages/admin_site_content_list_page.dart
//
// ✅ AdminSiteContentListPage v4.7 Final
// ------------------------------------------------------------
// 功能：
// - Firestore 即時監聽 site_contents
// - 搜尋 + 分類過濾 + 上下架切換 + 排序拖拉 + 新增/編輯/刪除
// - 點擊項目開啟編輯頁（SiteContentEditPage）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'admin_site_content_edit_page.dart';

class AdminSiteContentListPage extends StatefulWidget {
  final String category;
  const AdminSiteContentListPage({super.key, required this.category});

  @override
  State<AdminSiteContentListPage> createState() => _AdminSiteContentListPageState();
}

class _AdminSiteContentListPageState extends State<AdminSiteContentListPage> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _keyword = '';
  bool _busyReorder = false;

  Query<Map<String, dynamic>> get _query => _db
      .collection('site_contents')
      .where('category', isEqualTo: widget.category)
      .orderBy('order');

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _create() async {
    final ref = _db.collection('site_contents').doc();
    await ref.set({
      'category': widget.category,
      'title': '新內容',
      'bodyHtml': '',
      'imageUrls': [],
      'isActive': true,
      'order': DateTime.now().millisecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _delete(DocumentSnapshot doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除確認'),
        content: Text('確定要刪除「${doc['title'] ?? ''}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok == true) await doc.reference.delete();
  }

  Future<void> _toggle(DocumentSnapshot doc) async {
    await doc.reference.set({
      'isActive': !(doc['isActive'] == true),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _applyReorder(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (_busyReorder) return;
    setState(() => _busyReorder = true);
    try {
      final batch = _db.batch();
      for (int i = 0; i < docs.length; i++) {
        batch.set(docs[i].reference, {
          'order': i + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } finally {
      if (mounted) setState(() => _busyReorder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category} 管理'),
        actions: [
          IconButton(icon: const Icon(Icons.add_outlined), onPressed: _create),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋標題...',
                border: const OutlineInputBorder(),
                suffixIcon: _keyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _keyword = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _keyword = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query.snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs
                    .where((d) => _keyword.isEmpty ||
                        (d['title'] ?? '').toString().toLowerCase().contains(_keyword))
                    .toList();

                if (docs.isEmpty) return const Center(child: Text('尚無內容'));

                return ReorderableListView.builder(
                  itemCount: docs.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex--;
                    final moved = docs.removeAt(oldIndex);
                    docs.insert(newIndex, moved);
                    await _applyReorder(docs);
                  },
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data();
                    final title = (data['title'] ?? '').toString();
                    final active = data['isActive'] == true;
                    final updated = data['updatedAt'] is Timestamp
                        ? DateFormat('MM/dd HH:mm').format(data['updatedAt'].toDate())
                        : '';

                    return Card(
                      key: ValueKey(d.id),
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          active ? Icons.check_circle_outline : Icons.remove_circle_outline,
                          color: active ? Colors.green : Colors.grey,
                        ),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('更新：$updated'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminSiteContentEditPage(
                                    contentId: d.id,
                                    category: widget.category,
                                  ),
                                ),
                              );
                            } else if (v == 'toggle') {
                              await _toggle(d);
                            } else if (v == 'delete') {
                              await _delete(d);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('編輯')),
                            PopupMenuItem(value: 'toggle', child: Text(active ? '下架' : '上架')),
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'delete', child: Text('刪除')),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
