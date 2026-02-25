// lib/pages/admin/content/admin_announcements_page.dart
//
// ✅ AdminAnnouncementsPage（announcements 管理｜單檔完整版｜可編譯）
// ------------------------------------------------------------
// Firestore: collection 'announcements'
// 欄位建議：title, body, isPublished, pinned, createdAt, updatedAt
//

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});

  static const String routeName = '/admin-content/announcements';

  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  String _keyword = '';

  Query<Map<String, dynamic>> _query() {
    // ✅ 只 orderBy(updatedAt)，其餘本地過濾，避免索引
    return _db
        .collection('announcements')
        .orderBy('updatedAt', descending: true)
        .limit(200);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }
      setState(() => _keyword = v.trim().toLowerCase());
    });
  }

  bool _hit(Map<String, dynamic> m, String id) {
    if (_keyword.isEmpty) {
      return true;
    }
    final t = (m['title'] ?? '').toString().toLowerCase();
    final b = (m['body'] ?? '').toString().toLowerCase();
    final pid = id.toLowerCase();
    return t.contains(_keyword) ||
        b.contains(_keyword) ||
        pid.contains(_keyword);
  }

  Future<void> _openEditor({String? docId, Map<String, dynamic>? data}) async {
    final isNew = docId == null;
    final titleCtrl = TextEditingController(
      text: (data?['title'] ?? '').toString(),
    );
    final bodyCtrl = TextEditingController(
      text: (data?['body'] ?? '').toString(),
    );
    bool published = (data?['isPublished'] ?? false) == true;
    bool pinned = (data?['pinned'] ?? false) == true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isNew ? '新增公告' : '編輯公告'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: '標題'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bodyCtrl,
                    minLines: 6,
                    maxLines: 16,
                    decoration: const InputDecoration(labelText: '內容'),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: published,
                    onChanged: (v) {
                      published = v;
                      (ctx as Element).markNeedsBuild();
                    },
                    title: const Text('上架（isPublished）'),
                  ),
                  SwitchListTile(
                    value: pinned,
                    onChanged: (v) {
                      pinned = v;
                      (ctx as Element).markNeedsBuild();
                    },
                    title: const Text('置頂（pinned）'),
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
        );
      },
    );

    if (ok != true) {
      return;
    }

    final payload = <String, dynamic>{
      'title': titleCtrl.text.trim(),
      'body': bodyCtrl.text.trim(),
      'isPublished': published,
      'pinned': pinned,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (isNew) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        await _db.collection('announcements').add(payload);
      } else {
        await _db
            .collection('announcements')
            .doc(docId)
            .set(payload, SetOptions(merge: true));
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(isNew ? '已新增公告' : '已更新公告')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    }
  }

  Future<void> _delete(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除確認'),
        content: Text('確定要刪除這筆公告？\n$docId'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) {
      return;
    }

    try {
      await _db.collection('announcements').doc(docId).delete();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '公告（announcements）',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '新增',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋標題/內容/docId（本地過濾）',
                isDense: true,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchCtrl.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除',
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _keyword = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('讀取失敗：${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs
                    .where((d) => _hit(d.data(), d.id))
                    .toList(growable: false);

                if (docs.isEmpty) {
                  return const Center(child: Text('沒有資料'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final m = d.data();
                    final title = (m['title'] ?? '').toString().trim();
                    final body = (m['body'] ?? '').toString().trim();
                    final pub = (m['isPublished'] ?? false) == true;
                    final pinned = (m['pinned'] ?? false) == true;

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
                            Row(
                              children: [
                                if (pinned) ...[
                                  Icon(
                                    Icons.push_pin,
                                    size: 18,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    title.isEmpty ? '(未命名)' : title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: pub
                                        ? cs.primaryContainer
                                        : cs.surfaceContainerHighest,
                                  ),
                                  child: Text(
                                    pub ? 'published' : 'draft',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: pub
                                          ? cs.onPrimaryContainer
                                          : cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              body.isEmpty ? '-' : body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: () =>
                                      _openEditor(docId: d.id, data: m),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('編輯'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _delete(d.id),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('刪除'),
                                ),
                              ],
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
