// lib/pages/user_notifications_page.dart
//
// 使用者通知中心（完整版）
// - 對接 notification_service.dart
// - 功能：查看通知、標已讀、刪除、一鍵全讀
// - Firestore: notifications/{uid}/items/{notifId}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';

class UserNotificationsPage extends StatefulWidget {
  const UserNotificationsPage({super.key});

  @override
  State<UserNotificationsPage> createState() => _UserNotificationsPageState();
}

class _UserNotificationsPageState extends State<UserNotificationsPage> {
  late final NotificationService _notiSvc;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _notiSvc = context.read<NotificationService>();
  }

  Future<void> _confirmMarkAllRead(String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('全部標為已讀'),
        content: const Text('確定將所有通知標為已讀？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('確定')),
        ],
      ),
    );

    if (ok == true) {
      await _notiSvc.markAllAsRead(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已標為已讀')),
      );
    }
  }

  Future<void> _showNotificationDetail(String uid, Map<String, dynamic> n) async {
    final id = n['id'] ?? '';
    final title = (n['title'] ?? '').toString();
    final body = (n['body'] ?? '').toString();
    final type = (n['type'] ?? '').toString();
    final createdAt = _toDate(n['createdAt']);
    final extra = n['extra'] ?? {};

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title.isEmpty ? '通知詳情' : title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body),
              const SizedBox(height: 10),
              Text('類型：$type', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text('時間：${_fmtDate(createdAt)}', style: const TextStyle(fontSize: 12)),
              if (extra is Map && extra.isNotEmpty) ...[
                const Divider(),
                Text('附加資訊：', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(extra.toString(), style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
        ],
      ),
    );

    // 自動標為已讀
    await _notiSvc.markAsRead(uid, id);
  }

  DateTime _toDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return DateTime.now();
  }

  String _fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('請先登入')));
    }

    final uid = user.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的通知'),
        centerTitle: true,
        actions: [
          StreamBuilder<int>(
            stream: _notiSvc.streamUnreadCount(uid),
            builder: (_, snap) {
              final unread = snap.data ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    unread > 0 ? '未讀：$unread' : '',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: '全部標為已讀',
            icon: const Icon(Icons.done_all),
            onPressed: () => _confirmMarkAllRead(uid),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _notiSvc.streamNotifications(uid, limit: 100),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.isEmpty) {
            return const Center(child: Text('目前沒有通知'));
          }

          final list = snap.data!;

          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final n = list[i];
              final id = n['id'] ?? '';
              final title = (n['title'] ?? '').toString();
              final body = (n['body'] ?? '').toString();
              final read = (n['read'] ?? false) == true;
              final createdAt = _toDate(n['createdAt']);

              return Dismissible(
                key: ValueKey(id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.redAccent,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) async {
                  await _notiSvc.deleteNotification(uid, id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已刪除：$title')),
                  );
                },
                child: ListTile(
                  leading: Icon(
                    read ? Icons.mark_email_read : Icons.mark_email_unread,
                    color: read ? Colors.grey : Colors.blueAccent,
                  ),
                  title: Text(
                    title.isEmpty ? '(無標題)' : title,
                    style: TextStyle(
                      fontWeight: read ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '$body\n${_fmtDate(createdAt)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _showNotificationDetail(uid, n),
                  onLongPress: () async {
                    await _notiSvc.markAsRead(uid, id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已標為已讀：$title')),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
