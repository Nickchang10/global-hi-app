// lib/pages/notification_center_page.dart
//
// ✅ NotificationCenterPage（最終完整版｜已修正 non_constant_identifier_names）
// ------------------------------------------------------------
// - Provider NotificationService（本地/記憶體通知）
// - 可選 Firestore users/{uid}/notifications（雲端通知）
// - ✅ 修正：use_build_context_synchronously（Dialog 一律用 builder ctx）
// - ✅ 修正：Undefined class 'AppNotification'（完全不引用該類別）
// - ✅ 修正：unnecessary_cast（d.data() 不再強轉 Map）
// - ✅ 修正：non_constant_identifier_names（方法改 lowerCamelCase）
//
// 你只要覆蓋本檔即可編譯。
// 若你要啟用 Firestore 通知，將 _useFirestore 預設改 true 即可。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  static const Color _brand = Color(0xFF3B82F6);

  String _filter = '未讀'; // 未讀 / 全部
  bool _useFirestore = false; // ✅ 需要雲端通知就改 true

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('通知中心'),
        actions: [
          IconButton(
            tooltip: _useFirestore ? '切換：本地通知' : '切換：Firestore 通知',
            onPressed: () => setState(() => _useFirestore = !_useFirestore),
            icon: Icon(
              _useFirestore ? Icons.cloud_done_outlined : Icons.memory,
            ),
          ),
          const SizedBox(width: 2),
          _filterMenu(),
          const SizedBox(width: 6),
          IconButton(
            tooltip: '全部已讀',
            onPressed: () => _markAllRead(uid: user?.uid),
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      body: _useFirestore
          ? (user == null ? _needLogin() : _firestoreBody(uid: user.uid))
          : _providerBody(),
    );
  }

  Widget _filterMenu() {
    return PopupMenuButton<String>(
      tooltip: '篩選',
      initialValue: _filter,
      onSelected: (v) => setState(() => _filter = v),
      itemBuilder: (_) => const [
        PopupMenuItem(value: '未讀', child: Text('未讀')),
        PopupMenuItem(value: '全部', child: Text('全部')),
      ],
      icon: const Icon(Icons.filter_list_rounded),
    );
  }

  Widget _needLogin() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('請先登入才能查看通知', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamed('/login'),
              child: const Text('前往登入'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // A) Provider NotificationService（本地通知）
  // ============================================================
  Widget _providerBody() {
    return Consumer<NotificationService>(
      builder: (context, svc, _) {
        final list = _getNotificationsList(svc);

        final filtered = list.where((n) {
          final read = _dynIsRead(n);
          if (_filter == '未讀') return !read;
          return true;
        }).toList();

        if (filtered.isEmpty) {
          return _empty('目前沒有通知', '有新通知時會顯示在這裡。');
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _noticeCardProvider(svc, filtered[i]),
        );
      },
    );
  }

  List<dynamic> _getNotificationsList(NotificationService svc) {
    // 兼容 notifications / items / list
    try {
      final v = (svc as dynamic).notifications;
      if (v is List) return v.cast<dynamic>();
    } catch (_) {}
    try {
      final v = (svc as dynamic).items;
      if (v is List) return v.cast<dynamic>();
    } catch (_) {}
    try {
      final v = (svc as dynamic).list;
      if (v is List) return v.cast<dynamic>();
    } catch (_) {}
    return const <dynamic>[];
  }

  Widget _noticeCardProvider(NotificationService svc, dynamic n) {
    final id = _dynString(n, const ['id', 'docId', 'key'], fallback: '');
    final title = _dynString(n, const [
      'title',
      'subject',
      'name',
    ], fallback: '通知');
    final message = _dynString(n, const [
      'message',
      'body',
      'content',
    ], fallback: '');
    final route = _dynString(n, const [
      'route',
      'path',
      'link',
    ], fallback: '').trim();
    final timeText = _dynString(n, const [
      'timeText',
      'time',
      'createdText',
    ], fallback: '');

    final isRead = _dynIsRead(n);
    final isUnread = !isRead;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openNotice(
        title: title,
        message: message,
        route: route.isEmpty ? null : route,
        onMarkRead: () => _svcMarkRead(svc, id, n),
        onDelete: () async => _svcDelete(svc, id, n),
      ),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dot(isUnread),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: isUnread ? Colors.black : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message.isEmpty ? '（無內容）' : message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                  ),
                  if (timeText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      timeText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '刪除',
              onPressed: () async {
                final ok = await _confirmDelete();
                if (!ok) return;
                await _svcDelete(svc, id, n);
              },
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }

  bool _dynIsRead(dynamic n) {
    // 支援：read / isRead / seen / status == read / readAt != null
    try {
      final v = (n as dynamic).read;
      if (v is bool) return v;
    } catch (_) {}
    try {
      final v = (n as dynamic).isRead;
      if (v is bool) return v;
    } catch (_) {}
    try {
      final v = (n as dynamic).seen;
      if (v is bool) return v;
    } catch (_) {}
    try {
      final v = (n as dynamic).status;
      final s = (v ?? '').toString().toLowerCase().trim();
      if (s == 'read' || s == 'seen' || s == 'done') return true;
    } catch (_) {}
    try {
      final v = (n as dynamic).readAt;
      if (v != null) return true;
    } catch (_) {}
    return false;
  }

  String _dynString(dynamic n, List<String> keys, {required String fallback}) {
    for (final k in keys) {
      try {
        final v = _dynProp(n, k);
        if (v != null) return v.toString();
      } catch (_) {}
    }
    return fallback;
  }

  dynamic _dynProp(dynamic n, String key) {
    // 用 switch 避免 reflect：compiler 不會要求 property 存在
    switch (key) {
      case 'id':
        try {
          return (n as dynamic).id;
        } catch (_) {
          return null;
        }
      case 'docId':
        try {
          return (n as dynamic).docId;
        } catch (_) {
          return null;
        }
      case 'key':
        try {
          return (n as dynamic).key;
        } catch (_) {
          return null;
        }
      case 'title':
        try {
          return (n as dynamic).title;
        } catch (_) {
          return null;
        }
      case 'subject':
        try {
          return (n as dynamic).subject;
        } catch (_) {
          return null;
        }
      case 'name':
        try {
          return (n as dynamic).name;
        } catch (_) {
          return null;
        }
      case 'message':
        try {
          return (n as dynamic).message;
        } catch (_) {
          return null;
        }
      case 'body':
        try {
          return (n as dynamic).body;
        } catch (_) {
          return null;
        }
      case 'content':
        try {
          return (n as dynamic).content;
        } catch (_) {
          return null;
        }
      case 'route':
        try {
          return (n as dynamic).route;
        } catch (_) {
          return null;
        }
      case 'path':
        try {
          return (n as dynamic).path;
        } catch (_) {
          return null;
        }
      case 'link':
        try {
          return (n as dynamic).link;
        } catch (_) {
          return null;
        }
      case 'timeText':
        try {
          return (n as dynamic).timeText;
        } catch (_) {
          return null;
        }
      case 'time':
        try {
          return (n as dynamic).time;
        } catch (_) {
          return null;
        }
      case 'createdText':
        try {
          return (n as dynamic).createdText;
        } catch (_) {
          return null;
        }
      default:
        return null;
    }
  }

  void _svcMarkRead(NotificationService svc, String id, dynamic n) {
    try {
      (svc as dynamic).markRead(id);
      return;
    } catch (_) {}
    try {
      (svc as dynamic).markAsRead(id);
      return;
    } catch (_) {}
    try {
      (svc as dynamic).setRead(id, true);
      return;
    } catch (_) {}
    try {
      (svc as dynamic).updateRead(id: id, read: true);
      return;
    } catch (_) {}
    try {
      (svc as dynamic).markReadByItem(n);
    } catch (_) {}
  }

  Future<void> _svcDelete(NotificationService svc, String id, dynamic n) async {
    try {
      (svc as dynamic).removeNotification(id);
      _toast('已刪除');
      return;
    } catch (_) {}
    try {
      (svc as dynamic).deleteNotification(id);
      _toast('已刪除');
      return;
    } catch (_) {}
    try {
      (svc as dynamic).remove(id);
      _toast('已刪除');
      return;
    } catch (_) {}
    try {
      (svc as dynamic).removeItem(n);
      _toast('已刪除');
      return;
    } catch (_) {}

    _toast('刪除失敗：NotificationService 未提供刪除方法');
  }

  // ============================================================
  // B) Firestore 模式（users/{uid}/notifications）
  // ============================================================
  Widget _firestoreBody({required String uid}) {
    final q = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(200);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _empty('讀取失敗', snap.error.toString());
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final docs = snap.data!.docs;

        final filtered = docs.where((d) {
          final m = d.data();
          final read = _readOfMap(m);
          if (_filter == '未讀') return !read;
          return true;
        }).toList();

        if (filtered.isEmpty) {
          return _empty('目前沒有通知', '有新通知時會顯示在這裡。');
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _noticeCardFirestore(uid, filtered[i]),
        );
      },
    );
  }

  bool _readOfMap(Map<String, dynamic> m) {
    final read = m['read'];
    if (read is bool) return read;

    final isRead = m['isRead'];
    if (isRead is bool) return isRead;

    final seen = m['seen'];
    if (seen is bool) return seen;

    final status = (m['status'] ?? '').toString().toLowerCase().trim();
    if (status == 'read' || status == 'done' || status == 'seen') return true;

    if (m['readAt'] != null) return true;
    if (m['seenAt'] != null) return true;

    return false;
  }

  Widget _noticeCardFirestore(
    String uid,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final m = doc.data();
    final title = (m['title'] ?? '通知').toString();
    final message = (m['message'] ?? '').toString();
    final route = (m['route'] ?? '').toString().trim();
    final isRead = _readOfMap(m);
    final isUnread = !isRead;

    final timeText = _timeText(m['createdAt']);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openNotice(
        title: title,
        message: message,
        route: route.isEmpty ? null : route,
        onMarkRead: () => _markReadFirestore(uid, doc.id),
        onDelete: () async {
          final ok = await _confirmDelete();
          if (!ok) return;
          await _deleteFirestore(uid, doc.id);
        },
      ),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dot(isUnread),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: isUnread ? Colors.black : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message.isEmpty ? '（無內容）' : message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                  ),
                  if (timeText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      timeText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '刪除',
              onPressed: () async {
                final ok = await _confirmDelete();
                if (!ok) return;
                await _deleteFirestore(uid, doc.id);
              },
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Open notice (Dialog) + Routing (ctx safe)
  // ============================================================
  void _openNotice({
    required String title,
    required String message,
    String? route,
    required VoidCallback onMarkRead,
    required Future<void> Function() onDelete,
  }) {
    onMarkRead();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(message.isEmpty ? '（無內容）' : message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('關閉'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await onDelete();
              },
              child: const Text('刪除'),
            ),
            if (route != null && route.trim().isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _tryGo(route);
                },
                child: const Text('前往'),
              ),
          ],
        );
      },
    );
  }

  void _tryGo(String route) {
    if (!mounted) return;
    try {
      Navigator.pushNamed(context, route);
    } catch (_) {
      _toast('此 route 未註冊：$route');
    }
  }

  // ============================================================
  // Mark all read
  // ============================================================
  Future<void> _markAllRead({required String? uid}) async {
    if (_useFirestore) {
      if (uid == null) {
        _toast('請先登入');
        return;
      }
      await _markAllReadFirestore(uid);
      return;
    }

    try {
      (context.read<NotificationService>() as dynamic).markAllRead();
      _toast('已全部已讀');
      return;
    } catch (_) {}
    try {
      (context.read<NotificationService>() as dynamic).readAll();
      _toast('已全部已讀');
      return;
    } catch (_) {}
    _toast('你的 NotificationService 未提供 markAllRead/readAll');
  }

  Future<void> _markAllReadFirestore(String uid) async {
    try {
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications');

      final qs = await col.limit(300).get();
      if (qs.docs.isEmpty) {
        _toast('沒有通知');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      int changed = 0;

      for (final d in qs.docs) {
        final m = d.data(); // ✅ 不強轉
        final read = _readOfMap(m);
        if (read) continue;

        batch.update(d.reference, {
          'isRead': true,
          'read': true,
          'seen': true,
          'readAt': FieldValue.serverTimestamp(),
        });
        changed++;
      }

      if (changed == 0) {
        _toast('沒有未讀通知');
        return;
      }

      await batch.commit();
      _toast('已全部已讀');
    } catch (e) {
      _toast('操作失敗：$e');
    }
  }

  Future<void> _markReadFirestore(String uid, String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(docId)
          .set({
            'isRead': true,
            'read': true,
            'seen': true,
            'readAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _deleteFirestore(String uid, String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(docId)
          .delete();
      _toast('已刪除');
    } catch (e) {
      _toast('刪除失敗：$e');
    }
  }

  // ============================================================
  // Confirm delete (Dialog) - ctx safe
  // ============================================================
  Future<bool> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('刪除通知'),
          content: const Text('確定要刪除這則通知嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    return ok == true;
  }

  // ============================================================
  // UI helpers
  // ============================================================
  Widget _dot(bool unread) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: unread ? _brand : Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: unread ? _brand : Colors.grey.shade300),
      ),
    );
  }

  Widget _empty(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none, size: 52, color: Colors.grey),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _timeText(dynamic v) {
    DateTime? d;
    if (v is Timestamp) d = v.toDate();
    if (v is DateTime) d = v;
    if (d == null) return '';
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y/$m/$day $hh:$mm';
  }
}
