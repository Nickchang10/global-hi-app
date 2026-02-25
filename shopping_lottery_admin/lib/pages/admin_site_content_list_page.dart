// lib/pages/admin_site_content_list_page.dart
//
// ✅ AdminSiteContentListPage v4.8 Final（可編譯完整版｜修正 contentId/category 參數）
// ------------------------------------------------------------
// 功能：
// - Firestore 即時監聽 site_contents
// - 搜尋 + 上下架切換 + 排序拖拉 + 新增/編輯/刪除
// - 點擊項目開啟編輯頁（AdminSiteContentEditPage）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_site_content_edit_page.dart';

class AdminSiteContentListPage extends StatefulWidget {
  final String category;
  const AdminSiteContentListPage({super.key, required this.category});

  @override
  State<AdminSiteContentListPage> createState() =>
      _AdminSiteContentListPageState();
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    try {
      final ref = _db.collection('site_contents').doc();
      await ref.set({
        'category': widget.category,
        'title': '新內容',
        // 舊欄位保留（不影響你現在的 Quill 版本）
        'bodyHtml': '',
        'imageUrls': [],
        'isActive': true,
        'order': DateTime.now().millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack('✅ 已新增一筆內容');
    } catch (e) {
      _snack('新增失敗：$e');
    }
  }

  Future<void> _delete(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final title = (data['title'] ?? '').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除確認'),
        content: Text('確定要刪除「$title」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await doc.reference.delete();
      _snack('✅ 已刪除');
    } catch (e) {
      _snack('刪除失敗：$e');
    }
  }

  Future<void> _toggle(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final active = (data['isActive'] == true);

    try {
      await doc.reference.set({
        'isActive': !active,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack(active ? '已下架' : '已上架');
    } catch (e) {
      _snack('更新失敗：$e');
    }
  }

  Future<void> _applyReorder(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
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
      _snack('✅ 已更新排序');
    } catch (e) {
      _snack('排序更新失敗：$e');
    } finally {
      if (mounted) setState(() => _busyReorder = false);
    }
  }

  void _openEdit(String docId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminSiteContentEditPage(
          // ✅ 修正：統一改用 docId（不再使用 contentId/category）
          docId: docId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category} 管理'),
        actions: [
          if (_busyReorder)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add_outlined),
            tooltip: '新增',
            onPressed: _create,
          ),
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
                isDense: true,
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
              onChanged: (v) =>
                  setState(() => _keyword = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('載入失敗：${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs.where((d) {
                  if (_keyword.isEmpty) return true;
                  final title = (d.data()['title'] ?? '')
                      .toString()
                      .toLowerCase();
                  return title.contains(_keyword);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      '尚無內容',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  );
                }

                return ReorderableListView.builder(
                  itemCount: docs.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (_busyReorder) return;

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

                    final updatedAt = data['updatedAt'];
                    final updated = updatedAt is Timestamp
                        ? DateFormat('MM/dd HH:mm').format(updatedAt.toDate())
                        : '';

                    return Card(
                      key: ValueKey(d.id),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ListTile(
                        onTap: () => _openEdit(d.id),
                        leading: Icon(
                          active
                              ? Icons.check_circle_outline
                              : Icons.remove_circle_outline,
                          color: active ? Colors.green : Colors.grey,
                        ),
                        title: Text(
                          title.isEmpty ? '(未命名)' : title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(updated.isEmpty ? '' : '更新：$updated'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') {
                              _openEdit(d.id);
                            } else if (v == 'toggle') {
                              await _toggle(d);
                            } else if (v == 'delete') {
                              await _delete(d);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('編輯'),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(active ? '下架' : '上架'),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('刪除'),
                            ),
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
