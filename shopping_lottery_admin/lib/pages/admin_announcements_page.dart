// lib/pages/admin_announcements_page.dart
//
// ✅ AdminAnnouncementsPage（公告管理｜可編譯完整版）
// - 讀取 announcements 集合
// - 新增 / 編輯 / 刪除
//
// ✅ 修正：ColorScheme.surfaceVariant deprecated
// - surfaceVariant → surfaceContainerHighest（Material 3 新版）
//
// Firestore 建議欄位（可缺少也不會炸）：
// title (String)
// content (String)
// pinned (bool)
// status (String) 例如 "published" / "draft"
// createdAt (Timestamp)
// updatedAt (Timestamp)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});

  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  final _db = FirebaseFirestore.instance;

  bool _fallbackOrder = false; // 避免某些專案沒有 pinned/createdAt 或需要索引時卡住

  Query<Map<String, dynamic>> _query() {
    final base = _db.collection('announcements');

    if (_fallbackOrder) {
      return base.orderBy(FieldPath.documentId, descending: true).limit(80);
    }

    // 常見公告排序：置頂 -> 新到舊
    return base
        .orderBy('pinned', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(80);
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  DateTime? _dt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  Future<void> _openEditor({String? docId, Map<String, dynamic>? init}) async {
    final titleCtrl = TextEditingController(text: _s(init?['title']));
    final contentCtrl = TextEditingController(text: _s(init?['content']));
    bool pinned = (init?['pinned'] == true);
    String status = _s(init?['status']).isEmpty
        ? 'published'
        : _s(init?['status']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          docId == null ? '新增公告' : '編輯公告',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: '標題 title',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: '內容 content',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: pinned,
                      onChanged: (v) => setState(() => pinned = (v == true)),
                    ),
                    const Text('置頂 pinned'),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: status,
                      items: const [
                        DropdownMenuItem(
                          value: 'published',
                          child: Text('published'),
                        ),
                        DropdownMenuItem(value: 'draft', child: Text('draft')),
                      ],
                      onChanged: (v) =>
                          setState(() => status = v ?? 'published'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final payload = <String, dynamic>{
        'title': titleCtrl.text.trim(),
        'content': contentCtrl.text.trim(),
        'pinned': pinned,
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (docId == null) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        await _db.collection('announcements').add(payload);
      } else {
        await _db
            .collection('announcements')
            .doc(docId)
            .set(payload, SetOptions(merge: true));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(docId == null ? '已新增公告' : '已更新公告')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失敗：$e')));
    }
  }

  Future<void> _delete(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          '刪除公告',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text('確定要刪除公告：$docId ？此動作不可復原。'),
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
      await _db.collection('announcements').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dtFmt = DateFormat('yyyy/MM/dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '公告管理',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: _fallbackOrder
                ? '目前：fallback 排序（docId）'
                : '目前：pinned + createdAt 排序',
            onPressed: () => setState(() => _fallbackOrder = !_fallbackOrder),
            icon: Icon(
              _fallbackOrder ? Icons.sort_by_alpha : Icons.push_pin_outlined,
            ),
          ),
          IconButton(
            tooltip: '新增公告',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _query().snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '讀取失敗：${snap.error}',
                        style: TextStyle(color: cs.error),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '可嘗試：右上角切換到 fallback 排序（docId）。\n'
                        '或確認 announcements 欄位 pinned/createdAt 是否存在、是否需要索引。',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text(
                '目前沒有公告',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();

              final title = _s(d['title']).isEmpty ? '(未命名公告)' : _s(d['title']);
              final status = _s(d['status']).isEmpty ? '-' : _s(d['status']);
              final pinned = (d['pinned'] == true);
              final createdAt = _dt(d['createdAt']);
              final updatedAt = _dt(d['updatedAt']);

              final timeText = (updatedAt ?? createdAt) == null
                  ? ''
                  : dtFmt.format((updatedAt ?? createdAt)!);

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: pinned
                        ? cs.primaryContainer
                        : cs.surfaceContainerHighest, // ✅ 修正 deprecated
                    child: Icon(
                      pinned ? Icons.push_pin : Icons.campaign_outlined,
                    ),
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      'id: ${doc.id}',
                      if (timeText.isNotEmpty) timeText,
                      'status: $status',
                    ].join('  •  '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      IconButton(
                        tooltip: '編輯',
                        onPressed: () => _openEditor(docId: doc.id, init: d),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: '刪除',
                        onPressed: () => _delete(doc.id),
                        icon: Icon(Icons.delete_outline, color: cs.error),
                      ),
                    ],
                  ),
                  onTap: () => _openEditor(docId: doc.id, init: d),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
