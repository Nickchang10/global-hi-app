import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ NotificationDetailPage（通知詳情｜最終完整版｜已修正 curly_braces_in_flow_control_structures）
/// ------------------------------------------------------------
/// - 讀取：users/{uid}/notifications/{notificationId}
/// - 自動標記已讀：支援欄位 isRead 或 read（二擇一存在即可）
/// - 顯示：title / body / type / route / createdAt
class NotificationDetailPage extends StatefulWidget {
  final String notificationId;

  const NotificationDetailPage({super.key, required this.notificationId});

  @override
  State<NotificationDetailPage> createState() => _NotificationDetailPageState();
}

class _NotificationDetailPageState extends State<NotificationDetailPage> {
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _docRef(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(widget.notificationId);
  }

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  DateTime? _toDateTime(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is Timestamp) {
      return v.toDate();
    }
    if (v is DateTime) {
      return v;
    }
    return null;
  }

  String _fmtYmdHms(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    final ss = d.second.toString().padLeft(2, '0');
    return '$y/$m/$day $hh:$mm:$ss';
  }

  Future<void> _markReadIfNeeded(String uid, Map<String, dynamic> data) async {
    final bool isRead = (data['isRead'] ?? data['read'] ?? false) == true;

    if (isRead) {
      return;
    }

    try {
      // 兩種欄位都一起寫（你只用其中一個也沒問題）
      await _docRef(
        uid,
      ).set({'isRead': true, 'read': true}, SetOptions(merge: true));
    } catch (_) {
      // 靜默失敗即可（避免影響 UI）
    }
  }

  void _goRoute(String route) {
    if (route.trim().isEmpty) {
      return;
    }
    Navigator.of(context).pushNamed(route.trim());
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('通知詳情')),
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).pushNamed('/login'),
            child: const Text('請先登入'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('通知詳情')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _docRef(uid).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('讀取失敗：${snap.error}'));
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data();
          if (data == null) {
            return const Center(child: Text('找不到通知或已被刪除'));
          }

          // 進入頁面自動標記已讀（不阻塞 UI）
          _markReadIfNeeded(uid, data);

          final title = _s(data['title'], '');
          final body = _s(data['body'], '');
          final type = _s(data['type'], 'system');
          final route = _s(data['route'], '');
          final createdAt = _toDateTime(data['createdAt']);

          final bool isRead = (data['isRead'] ?? data['read'] ?? false) == true;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isRead
                                ? Icons.mark_email_read_outlined
                                : Icons.mark_email_unread_outlined,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title.isEmpty ? '(無標題)' : title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (body.isNotEmpty) ...[
                        Text(
                          body,
                          style: const TextStyle(fontSize: 15, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        const Text(
                          '（無內容）',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      _kv('type', type),
                      _kv('route', route.isEmpty ? '-' : route),
                      _kv(
                        'createdAt',
                        createdAt == null ? '-' : _fmtYmdHms(createdAt),
                      ),
                      _kv('id', widget.notificationId),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (route.trim().isNotEmpty) ...[
                FilledButton.icon(
                  onPressed: () => _goRoute(route),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('前往相關頁面'),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('返回'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              k,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
