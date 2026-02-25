// lib/services/user_notifications_page.dart
//
// ✅ UserNotificationsPage（完整版｜可編譯｜修正 use_build_context_synchronously）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'notification_service.dart';

class UserNotificationsPage extends StatefulWidget {
  const UserNotificationsPage({super.key, this.limit = 200});
  final int limit;

  @override
  State<UserNotificationsPage> createState() => _UserNotificationsPageState();
}

class _UserNotificationsPageState extends State<UserNotificationsPage> {
  final _db = FirebaseFirestore.instance;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  Query<Map<String, dynamic>> _query(String uid) {
    return _db
        .collection('notifications')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(widget.limit);
  }

  Future<void> _markAllAsRead(String uid) async {
    // ✅ 先在 await 前把 service 拿出來（避免跨 async gap 用 context）
    final NotificationService service;
    try {
      service = context.read<NotificationService>();
    } catch (_) {
      // 沒有 provider 也能走 fallback
      return _markAllAsReadFallback(uid);
    }

    // 1) 優先走 service
    try {
      await service.markAllAsRead();
      if (!mounted) return;
      _snack('已全部標記已讀');
      return;
    } catch (_) {
      // 2) 失敗走 fallback
      return _markAllAsReadFallback(uid);
    }
  }

  Future<void> _markAllAsReadFallback(String uid) async {
    try {
      while (true) {
        final snap = await _query(
          uid,
        ).where('read', isEqualTo: false).limit(450).get();

        if (snap.docs.isEmpty) break;

        final batch = _db.batch();
        for (final d in snap.docs) {
          batch.update(d.reference, {
            'read': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      if (!mounted) return;
      _snack('已全部標記已讀（fallback）');
    } catch (e) {
      if (!mounted) return;
      _snack('全部已讀失敗：$e');
    }
  }

  Future<void> _markOneAsRead(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      await ref.set({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _open(
    Map<String, dynamic> d,
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final read = d['read'] == true;
    if (!read) {
      await _markOneAsRead(ref);
      if (!mounted) return;
    }

    final route = _s(d['route']);
    final title = _s(d['title']);
    final body = _s(d['body']);
    final deepLink = _s(d['deepLink']);

    if (route.isNotEmpty && route.startsWith('/')) {
      try {
        if (!mounted) return;
        Navigator.pushNamed(context, route);
        return;
      } catch (e) {
        if (!mounted) return;
        _snack('導頁失敗：$e');
      }
    }

    if (deepLink.isNotEmpty) {
      if (!mounted) return;
      _snack('deepLink：$deepLink');
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title.isEmpty ? '通知' : title),
        content: Text(body.isEmpty ? '(無內容)' : body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y/$m/$day $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('請先登入後再查看通知')));
    }

    final uid = user.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '我的通知',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '全部已讀',
            icon: const Icon(Icons.done_all),
            onPressed: () => _markAllAsRead(uid),
          ),
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _query(uid).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('載入失敗：${snap.error}'));
          }

          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('目前沒有通知'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();

              final title = _s(d['title']);
              final body = _s(d['body']);
              final type = _s(d['type']);
              final read = d['read'] == true;
              final createdAt = _toDate(d['createdAt']);

              final subtitle = [
                if (type.isNotEmpty) 'type: $type',
                if (createdAt != null) _fmt(createdAt),
              ].join('  •  ');

              final cs = Theme.of(context).colorScheme;

              return ListTile(
                leading: Icon(
                  read ? Icons.notifications_none : Icons.notifications_active,
                ),
                title: Text(
                  title.isEmpty ? '(無標題)' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: read ? FontWeight.w700 : FontWeight.w900,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (body.isNotEmpty)
                      Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
                trailing: read
                    ? null
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: cs.primaryContainer.withValues(alpha: 0.6),
                        ),
                        child: const Text(
                          '未讀',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                onTap: () => _open(d, doc.reference),
              );
            },
          );
        },
      ),
    );
  }
}
