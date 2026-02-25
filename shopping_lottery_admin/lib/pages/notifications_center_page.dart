// lib/pages/notifications_center_page.dart
//
// ✅ NotificationsCenterPage（最終完整版・相容 NotificationService・穩定可編譯）
// ------------------------------------------------------------
// 功能：
// - 讀取個人通知：notifications/{uid}/items/{notificationId}
// - 篩選：全部 / 未讀 / 已讀、type 篩選、關鍵字搜尋
// - 操作：標記已讀 / 未讀、刪除、批次標記 / 刪除
// - 詳細檢視：顯示 title/body/type/time/extra(JSON)、一鍵複製
// - 查詢策略：單一 orderBy(createdAt)，所有篩選在前端完成（避免索引錯誤）
// ------------------------------------------------------------
//
// Firestore 欄位結構建議：
// - title: String
// - body: String
// - type: String (announcement / order / coupon / system ...)
// - isRead: bool
// - createdAt: Timestamp
// - updatedAt: Timestamp
// - extra: Map<String, dynamic>
//
// 相容：NotificationService.sendNotificationToUser()（使用 isRead）
// ------------------------------------------------------------

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationsCenterPage extends StatefulWidget {
  const NotificationsCenterPage({super.key});

  @override
  State<NotificationsCenterPage> createState() =>
      _NotificationsCenterPageState();
}

class _NotificationsCenterPageState extends State<NotificationsCenterPage> {
  final _db = FirebaseFirestore.instance;

  String _q = '';
  bool? _isRead; // null=全部, false=未讀, true=已讀
  String _type = 'all'; // all / announcement / order / ...
  bool _working = false;

  // ------------------------------------------------------------
  // 🔹 Utilities
  // ------------------------------------------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();
  bool _b(dynamic v) => v == true;

  DateTime? _toDate(dynamic v) {
    try {
      if (v is Timestamp) {
        return v.toDate();
      }
      if (v is DateTime) {
        return v;
      }
      if (v is int) {
        if (v < 10000000000) {
          return DateTime.fromMillisecondsSinceEpoch(v * 1000);
        }
        return DateTime.fromMillisecondsSinceEpoch(v);
      }
    } catch (_) {}
    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) {
      return '-';
    }
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  void _snack(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _copy(String text, {String done = '已複製'}) async {
    final t = text.trim();
    if (t.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: t));
    _snack(done);
  }

  // ------------------------------------------------------------
  // 🔹 Firestore Query（index-safe）
  // ------------------------------------------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _itemsStream(String uid) {
    return _db
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .limit(800)
        .snapshots();
  }

  bool _match(String id, Map<String, dynamic> d) {
    if (_isRead != null && _b(d['isRead']) != _isRead) {
      return false;
    }

    final t = _type.trim().toLowerCase();
    if (t.isNotEmpty && t != 'all') {
      final docType = _s(d['type']).toLowerCase();
      if (docType != t) {
        return false;
      }
    }

    final q = _q.trim().toLowerCase();
    if (q.isEmpty) {
      return true;
    }

    final title = _s(d['title']).toLowerCase();
    final body = _s(d['body']).toLowerCase();
    final type = _s(d['type']).toLowerCase();
    final extra = d['extra'];
    final extraStr = () {
      try {
        if (extra is Map<String, dynamic>) {
          return jsonEncode(extra).toLowerCase();
        }
        return _s(extra).toLowerCase();
      } catch (_) {
        return '';
      }
    }();

    return id.toLowerCase().contains(q) ||
        title.contains(q) ||
        body.contains(q) ||
        type.contains(q) ||
        extraStr.contains(q);
  }

  // ------------------------------------------------------------
  // 🔹 Actions
  // ------------------------------------------------------------
  Future<void> _setRead({
    required String uid,
    required String id,
    required bool isRead,
  }) async {
    try {
      await _db
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .doc(id)
          .set(<String, dynamic>{
            'isRead': isRead,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      _snack('操作失敗：$e');
    }
  }

  Future<void> _deleteOne({required String uid, required String id}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('刪除通知'),
        content: const Text('確定要刪除此通知嗎？（不可復原）'),
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
    );
    if (ok != true) {
      return;
    }

    try {
      await _db
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .doc(id)
          .delete();
      _snack('已刪除');
    } catch (e) {
      _snack('刪除失敗：$e');
    }
  }

  Future<void> _batchMarkAllRead({
    required String uid,
    required List<_NotifRow> rows,
  }) async {
    if (_working) {
      return;
    }
    setState(() => _working = true);
    try {
      final targets = rows.where((r) => !_b(r.data['isRead'])).toList();
      if (targets.isEmpty) {
        _snack('沒有未讀通知');
        return;
      }

      const page = 450;
      int idx = 0;
      while (idx < targets.length) {
        final chunk = targets.skip(idx).take(page).toList();
        final batch = _db.batch();

        for (final r in chunk) {
          final ref = _db
              .collection('notifications')
              .doc(uid)
              .collection('items')
              .doc(r.id);
          batch.set(ref, <String, dynamic>{
            'isRead': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        await batch.commit();
        idx += chunk.length;
      }

      _snack('已標記 ${targets.length} 則為已讀');
    } catch (e) {
      _snack('批次操作失敗：$e');
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _batchDeleteRead({
    required String uid,
    required List<_NotifRow> rows,
  }) async {
    if (_working) {
      return;
    }

    final targets = rows.where((r) => _b(r.data['isRead'])).toList();
    if (targets.isEmpty) {
      _snack('沒有已讀通知可刪除');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('刪除已讀通知'),
        content: Text('確定要刪除 ${targets.length} 則已讀通知嗎？'),
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
    );
    if (ok != true) {
      return;
    }

    setState(() => _working = true);
    try {
      const page = 450;
      int idx = 0;
      while (idx < targets.length) {
        final chunk = targets.skip(idx).take(page).toList();
        final batch = _db.batch();

        for (final r in chunk) {
          final ref = _db
              .collection('notifications')
              .doc(uid)
              .collection('items')
              .doc(r.id);
          batch.delete(ref);
        }

        await batch.commit();
        idx += chunk.length;
      }

      _snack('已刪除 ${targets.length} 則已讀通知');
    } catch (e) {
      _snack('批次刪除失敗：$e');
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  // ------------------------------------------------------------
  // 🔹 Build UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;

        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (user == null) {
          return const Scaffold(body: Center(child: Text('請先登入')));
        }

        final uid = user.uid;

        return Scaffold(
          appBar: AppBar(
            title: const Text('通知中心'),
            actions: [
              IconButton(
                tooltip: '全部標記為已讀',
                icon: const Icon(Icons.done_all_outlined),
                onPressed: _working
                    ? null
                    : () async {
                        final snap = await _db
                            .collection('notifications')
                            .doc(uid)
                            .collection('items')
                            .get();
                        final rows = snap.docs
                            .map((d) => _NotifRow(id: d.id, data: d.data()))
                            .toList();
                        await _batchMarkAllRead(uid: uid, rows: rows);
                      },
              ),
              IconButton(
                tooltip: '刪除全部已讀',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: _working
                    ? null
                    : () async {
                        final snap = await _db
                            .collection('notifications')
                            .doc(uid)
                            .collection('items')
                            .get();
                        final rows = snap.docs
                            .map((d) => _NotifRow(id: d.id, data: d.data()))
                            .toList();
                        await _batchDeleteRead(uid: uid, rows: rows);
                      },
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _itemsStream(uid),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;
              final rows = docs
                  .map((d) => _NotifRow(id: d.id, data: d.data()))
                  .where((r) => _match(r.id, r.data))
                  .toList();

              final unreadCount = rows
                  .where((r) => !_b(r.data['isRead']))
                  .length;

              final types = <String>{'all'};
              for (final r in docs) {
                final t = _s(r.data()['type']).toLowerCase();
                if (t.isNotEmpty) {
                  types.add(t);
                }
              }
              final typeList = types.toList()..sort();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 250,
                          child: TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              hintText: '搜尋（標題、內容、type、extra、ID）',
                              isDense: true,
                            ),
                            onChanged: (v) => setState(() => _q = v),
                          ),
                        ),
                        DropdownButton<String>(
                          value: _type,
                          items: typeList
                              .map(
                                (t) =>
                                    DropdownMenuItem(value: t, child: Text(t)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _type = v ?? 'all'),
                        ),
                        DropdownButton<bool?>(
                          value: _isRead,
                          items: const [
                            DropdownMenuItem(value: null, child: Text('全部')),
                            DropdownMenuItem(value: false, child: Text('未讀')),
                            DropdownMenuItem(value: true, child: Text('已讀')),
                          ],
                          onChanged: (v) => setState(() => _isRead = v),
                        ),
                        Text('未讀 $unreadCount'),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(child: Text('目前沒有通知'))
                        : ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final r = rows[i];
                              final d = r.data;

                              final title = _s(d['title']);
                              final body = _s(d['body']);
                              final type = _s(d['type']);
                              final isRead = _b(d['isRead']);
                              final createdAt = _fmt(_toDate(d['createdAt']));

                              return ListTile(
                                leading: Icon(
                                  isRead
                                      ? Icons.notifications_none
                                      : Icons.notifications_active,
                                  color: isRead ? Colors.grey : Colors.blue,
                                ),
                                title: Text(
                                  title.isEmpty ? '(未命名通知)' : title,
                                  style: TextStyle(
                                    fontWeight: isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '$type • $createdAt\n$body',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () async {
                                  await _setRead(
                                    uid: uid,
                                    id: r.id,
                                    isRead: true,
                                  );

                                  // ✅ 正解：用 context.mounted 來 guard BuildContext
                                  if (!context.mounted) {
                                    return;
                                  }

                                  await showDialog<void>(
                                    context: context,
                                    builder: (dialogCtx) => AlertDialog(
                                      title: Text(title.isEmpty ? '通知' : title),
                                      content: Text(
                                        body.isEmpty ? '(無內容)' : body,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialogCtx),
                                          child: const Text('關閉'),
                                        ),
                                        TextButton(
                                          onPressed: () => _copy(
                                            jsonEncode(d),
                                            done: 'JSON 已複製',
                                          ),
                                          child: const Text('複製 JSON'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () =>
                                      _deleteOne(uid: uid, id: r.id),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------
// Data Model
// ------------------------------------------------------------
class _NotifRow {
  final String id;
  final Map<String, dynamic> data;
  _NotifRow({required this.id, required this.data});
}
