import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ NotificationTimelinePage（通知時間軸｜最終完整版｜可直接使用｜可編譯）
/// ------------------------------------------------------------
/// - Firestore 結構建議：users/{uid}/notifications/{docId}
///   - title: String
///   - body: String
///   - type: String (system/order/promo/health/sos)
///   - read: bool
///   - createdAt: Timestamp (serverTimestamp)
///
/// - ✅ 修正：unnecessary_null_in_if_null_operators
///   任何 `xx ?? null` 都不需要，直接用 `xx` 即可。
class NotificationTimelinePage extends StatefulWidget {
  const NotificationTimelinePage({super.key});

  static const routeName = '/notifications';

  @override
  State<NotificationTimelinePage> createState() =>
      _NotificationTimelinePageState();
}

class _NotificationTimelinePageState extends State<NotificationTimelinePage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  User? get _user => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> _notiRef(String uid) =>
      _fs.collection('users').doc(uid).collection('notifications');

  Query<Map<String, dynamic>> _query(String uid) {
    // 依 createdAt 由新到舊
    return _notiRef(uid).orderBy('createdAt', descending: true).limit(100);
  }

  Future<void> _seedDemoIfEmpty(String uid) async {
    final snap = await _notiRef(uid).limit(1).get();
    if (snap.docs.isNotEmpty) {
      return;
    }

    final now = DateTime.now();
    final batch = _fs.batch();

    final demo = <Map<String, dynamic>>[
      {
        'title': '歡迎加入 Osmile',
        'body': '開始探索商城、抽獎、健康追蹤與 SOS 守護功能。',
        'type': 'system',
        'read': false,
        'createdAt': Timestamp.fromDate(
          now.subtract(const Duration(minutes: 5)),
        ),
      },
      {
        'title': '訂單已成立',
        'body': '你的訂單已成立，稍後可在「我的訂單」查看物流狀態。',
        'type': 'order',
        'read': false,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
      },
      {
        'title': '活動通知',
        'body': '你有一張新的優惠券可使用，結帳時記得套用！',
        'type': 'promo',
        'read': true,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
      },
    ];

    for (final n in demo) {
      final doc = _notiRef(uid).doc();
      batch.set(doc, n, SetOptions(merge: true));
    }
    await batch.commit();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已建立通知示範資料（原本為空）')));
  }

  Future<void> _markAllRead(String uid) async {
    final snap = await _notiRef(uid).where('read', isEqualTo: false).get();
    if (snap.docs.isEmpty) {
      return;
    }

    final batch = _fs.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已標記已讀：${snap.docs.length} 則')));
  }

  Future<void> _toggleRead(
    String uid,
    DocumentSnapshot<Map<String, dynamic>> d,
  ) async {
    final data = d.data() ?? const <String, dynamic>{};
    final cur = (data['read'] == true);
    await d.reference.update({
      'read': !cur,
      if (!cur) 'readAt': FieldValue.serverTimestamp(),
      if (cur) 'readAt': FieldValue.delete(),
    });
  }

  Future<void> _deleteOne(DocumentSnapshot<Map<String, dynamic>> d) async {
    await d.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知中心'),
        actions: [
          IconButton(
            tooltip: '建立示範資料（空集合時）',
            onPressed: u == null ? null : () => _seedDemoIfEmpty(u.uid),
            icon: const Icon(Icons.auto_awesome),
          ),
          IconButton(
            tooltip: '全部標記已讀',
            onPressed: u == null ? null : () => _markAllRead(u.uid),
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: u == null
          ? _needLogin(context)
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query(u.uid).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                }
                if (snap.hasError) {
                  return _empty('讀取失敗：${snap.error}');
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _empty('目前沒有通知');
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _notiCard(u.uid, docs[i]),
                );
              },
            ),
    );
  }

  Widget _needLogin(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 52, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    '請先登入才能查看通知',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed('/login'),
                    child: const Text('前往登入'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _notiCard(String uid, DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? const <String, dynamic>{};

    final title = (data['title'] ?? '').toString();
    final body = (data['body'] ?? '').toString();
    final type = (data['type'] ?? 'system').toString();
    final read = (data['read'] == true);

    // ✅ 不要寫：createdAt ?? null（lint 會噴）
    final ts = data['createdAt'];
    final createdAt = ts is Timestamp ? ts.toDate() : null;

    final icon = _typeIcon(type);
    final color = _typeColor(type);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _toggleRead(uid, d),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.isEmpty ? '(無標題)' : title,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: read ? Colors.black87 : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!read)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (body.isNotEmpty)
                      Text(
                        body,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _typeLabel(type),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          createdAt == null ? '' : _fmt(createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: read ? '改為未讀' : '標記已讀',
                          onPressed: () => _toggleRead(uid, d),
                          icon: Icon(
                            read ? Icons.mark_chat_unread : Icons.done,
                          ),
                        ),
                        IconButton(
                          tooltip: '刪除',
                          onPressed: () => _deleteOne(d),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none, size: 52, color: Colors.grey),
            const SizedBox(height: 10),
            Text(text, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $hh:$mm';
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'order':
        return '訂單';
      case 'promo':
        return '活動';
      case 'health':
        return '健康';
      case 'sos':
        return 'SOS';
      default:
        return '系統';
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.receipt_long;
      case 'promo':
        return Icons.local_offer_outlined;
      case 'health':
        return Icons.favorite_border;
      case 'sos':
        return Icons.sos;
      default:
        return Icons.notifications_none;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'order':
        return Colors.deepPurple;
      case 'promo':
        return Colors.orange;
      case 'health':
        return Colors.pink;
      case 'sos':
        return Colors.redAccent;
      default:
        return Colors.blue;
    }
  }
}
