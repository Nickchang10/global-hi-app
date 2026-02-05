// lib/pages/admin/internal/admin_internal_announcements_page.dart
//
// ✅ AdminInternalAnnouncementsPage（最終完整版｜可編譯｜Web/Chrome OK）
// ------------------------------------------------------------------
// Firestore 結構（建議）
// - announcements/{announcementId}
//    - title: string
//    - content: string
//    - published: bool
//    - pinned: bool
//    - createdAt: Timestamp
//    - updatedAt: Timestamp
//    - notifiedAt: Timestamp?  // 用來避免重複通知（可選）
//    - notifyCount: number?    // 通知次數（可選）
//
// - announcements/{announcementId}/reads/{uid}
//    - uid: string
//    - role: string?
//    - readAt: Timestamp
//
// 通知寫入（你現有 NotificationsPage 讀的結構）
// - notifications/{uid}/items/{notificationId}
//    - type: 'announcement'
//    - title: string
//    - body: string
//    - route: '/admin/internal/announcements'（你可改）
//    - isRead: false
//    - extra: { announcementId: ... }
//    - createdAt: Timestamp
//
// 注意：批次寫入每次最多 500 筆，本檔已自動分批 commit。
// ------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminInternalAnnouncementsPage extends StatefulWidget {
  const AdminInternalAnnouncementsPage({super.key});

  @override
  State<AdminInternalAnnouncementsPage> createState() =>
      _AdminInternalAnnouncementsPageState();
}

class _AdminInternalAnnouncementsPageState
    extends State<AdminInternalAnnouncementsPage> {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('announcements');

  final _dtFmt = DateFormat('yyyy/MM/dd HH:mm');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '內部公告管理',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '新增公告',
            icon: const Icon(Icons.add),
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _col
            .orderBy('pinned', descending: true)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              title: '讀取失敗',
              message: snap.error.toString(),
              hint: '請確認 announcements 每筆都有 createdAt / pinned 欄位（或至少建立後會寫入）。',
              onRetry: () => setState(() {}),
            );
          }

          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('尚無內部公告'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = docs[i];
              final data = d.data();

              final published = data['published'] == true;
              final pinned = data['pinned'] == true;

              final createdAt = _toDateTime(data['createdAt']);
              final updatedAt = _toDateTime(data['updatedAt']);
              final timeText = _formatTime(createdAt, updatedAt);

              return Card(
                elevation: 0,
                child: ExpansionTile(
                  leading: Icon(
                    pinned ? Icons.push_pin : Icons.campaign_outlined,
                    color: pinned ? Colors.orange : (published ? Colors.green : Colors.grey),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          (data['title'] ?? '(未命名公告)').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (pinned) ...[
                        const SizedBox(width: 6),
                        _pill('置頂', enabled: true, cs: cs),
                      ],
                      const SizedBox(width: 6),
                      _pill(published ? '已上架' : '草稿', enabled: published, cs: cs),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (data['content'] ?? '').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            timeText,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _ReadCount(announcementId: d.id),
                        ],
                      ),
                    ],
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: '編輯',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openEditor(id: d.id, initial: data),
                      ),
                      IconButton(
                        tooltip: published ? '下架' : '上架',
                        icon: Icon(
                          published ? Icons.unpublished_outlined : Icons.publish_outlined,
                        ),
                        onPressed: () => _togglePublish(d.id, !published),
                      ),
                      IconButton(
                        tooltip: '刪除',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(d.id),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _ReadList(announcementId: d.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ===========================================================
  // Actions
  // ===========================================================

  Future<void> _togglePublish(String id, bool value) async {
    try {
      // 先更新公告狀態
      await _col.doc(id).update({
        'published': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ✅ 上架才發通知
      if (value) {
        await _sendAnnouncementNotification(announcementId: id);
      }

      if (!mounted) return;
      _toast(value ? '已上架（已發送通知）' : '已下架');
    } catch (e) {
      if (!mounted) return;
      _toast('更新失敗：$e');
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除公告'),
        content: const Text('確定要刪除這則公告嗎？此操作無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _col.doc(id).delete();
      if (!mounted) return;
      _toast('已刪除');
    } catch (e) {
      if (!mounted) return;
      _toast('刪除失敗：$e');
    }
  }

  // ===========================================================
  // Editor
  // ===========================================================

  Future<void> _openEditor({
    String? id,
    Map<String, dynamic>? initial,
  }) async {
    final titleCtrl = TextEditingController(text: (initial?['title'] ?? '').toString());
    final contentCtrl = TextEditingController(text: (initial?['content'] ?? '').toString());

    bool published = initial?['published'] == true;
    bool pinned = initial?['pinned'] == true;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(id == null ? '新增公告' : '編輯公告'),
          content: SizedBox(
            width: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  controller: contentCtrl,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: '內容',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: pinned,
                  onChanged: (v) => setLocal(() => pinned = v),
                  title: const Text('置頂公告'),
                  subtitle: Text(
                    '置頂會排序在最上方',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: published,
                  onChanged: (v) => setLocal(() => published = v),
                  title: const Text('立即上架'),
                  subtitle: Text(
                    published ? '儲存後會顯示給前台（且可發通知）' : '儲存為草稿',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('儲存'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final title = titleCtrl.text.trim();
    final content = contentCtrl.text.trim();

    if (title.isEmpty) {
      _toast('請填寫標題');
      return;
    }

    try {
      final payload = <String, dynamic>{
        'title': title,
        'content': content,
        'published': published,
        'pinned': pinned,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (id == null) {
        await _col.add({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        _toast('已新增公告');
      } else {
        await _col.doc(id).update(payload);
        if (!mounted) return;
        _toast('已更新公告');
      }
    } catch (e) {
      if (!mounted) return;
      _toast('儲存失敗：$e');
    }
  }

  // ===========================================================
  // Notification (公告上架 → 全體通知)
  // ===========================================================

  Future<void> _sendAnnouncementNotification({
    required String announcementId,
  }) async {
    // 讀公告內容
    final snap = await _col.doc(announcementId).get();
    final data = snap.data();
    if (data == null) return;

    // （可選）避免重複發送：若你希望「每次上架都發」就把這段移除
    // final notifiedAt = data['notifiedAt'];
    // if (notifiedAt is Timestamp) return;

    final title = (data['title'] ?? '內部公告').toString();
    final body = (data['content'] ?? '').toString();

    // 取得所有 user（你目前 users collection）
    final usersSnap = await _db.collection('users').get();
    if (usersSnap.docs.isEmpty) return;

    const maxBatchWrites = 450; // 留點安全空間（Firestore 上限 500）
    WriteBatch batch = _db.batch();
    int op = 0;
    int notifyCount = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (op == 0) return;
      if (!force && op < maxBatchWrites) return;
      await batch.commit();
      batch = _db.batch();
      op = 0;
    }

    for (final u in usersSnap.docs) {
      final uid = u.id.trim();
      if (uid.isEmpty) continue;

      final ref = _db
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .doc();

      batch.set(ref, {
        'type': 'announcement',
        'title': title,
        'body': body,
        // ✅ 點擊通知要跳公告頁：請把這個 route 對應到你路由表
        // 你若公告頁本身就是 AdminShell 內嵌頁，也可改成 '/admin' 然後帶 args selectedKey
        'route': '/admin/internal/announcements',
        'isRead': false,
        'extra': {
          'announcementId': announcementId,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      op += 1;
      notifyCount += 1;

      if (op >= maxBatchWrites) {
        await commitIfNeeded(force: true);
      }
    }

    await commitIfNeeded(force: true);

    // 回寫公告（可選：記錄通知時間與次數）
    await _col.doc(announcementId).set({
      'notifiedAt': FieldValue.serverTimestamp(),
      'notifyCount': FieldValue.increment(notifyCount),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ===========================================================
  // Helpers
  // ===========================================================

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(v);
      } catch (_) {}
    }
    return null;
  }

  String _formatTime(DateTime? c, DateTime? u) {
    if (u != null) return '更新：${_dtFmt.format(u)}';
    if (c != null) return '建立：${_dtFmt.format(c)}';
    return '時間：—';
  }

  Widget _pill(String text, {required bool enabled, required ColorScheme cs}) {
    final bg = enabled ? Colors.green.shade100 : Colors.grey.shade200;
    final fg = enabled ? Colors.green.shade900 : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: fg,
        ),
      ),
    );
  }
}

// ===================================================================
// 已讀人數
// ===================================================================

class _ReadCount extends StatelessWidget {
  final String announcementId;
  const _ReadCount({required this.announcementId});

  @override
  Widget build(BuildContext context) {
    final readsCol = FirebaseFirestore.instance
        .collection('announcements')
        .doc(announcementId)
        .collection('reads');

    return StreamBuilder<int>(
      stream: readsCol.snapshots().map((s) => s.size),
      builder: (_, snap) {
        final count = snap.data ?? 0;
        return Text(
          '已讀 $count 人',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        );
      },
    );
  }
}

// ===================================================================
// 已讀名單
// ===================================================================

class _ReadList extends StatelessWidget {
  final String announcementId;
  const _ReadList({required this.announcementId});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy/MM/dd HH:mm');

    final readsQuery = FirebaseFirestore.instance
        .collection('announcements')
        .doc(announcementId)
        .collection('reads')
        .orderBy('readAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: readsQuery.snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          );
        }
        if (snap.hasError) {
          return Text('讀取已讀名單失敗：${snap.error}');
        }

        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Text('尚無人閱讀'),
          );
        }

        return Column(
          children: docs.map((d) {
            final data = d.data();
            final uid = (data['uid'] ?? d.id).toString();
            final role = (data['role'] ?? '').toString();

            DateTime? readAt;
            final raw = data['readAt'];
            if (raw is Timestamp) readAt = raw.toDate();
            if (raw is int) {
              try {
                readAt = DateTime.fromMillisecondsSinceEpoch(raw);
              } catch (_) {}
            }

            final readAtText = readAt == null ? '—' : fmt.format(readAt);

            return ListTile(
              dense: true,
              leading: const Icon(Icons.person_outline, size: 18),
              title: Text(uid, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${role.isEmpty ? '—' : role} ｜ $readAtText'),
            );
          }).toList(),
        );
      },
    );
  }
}

// ===================================================================
// Error View
// ===================================================================

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final String? hint;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 44, color: cs.error),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                  if (hint != null) ...[
                    const SizedBox(height: 10),
                    Text(hint!, style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重試'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
