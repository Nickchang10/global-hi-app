import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ PointsNotificationPage（點數通知中心｜修改後完整版）
/// ------------------------------------------------------------
/// ✅ 修正重點：
/// - 不再把 AppNotification 當 Map 用（移除 n['title'] 這種寫法）
/// - 自帶 AppNotification model（避免外部 model 混亂）
/// - Firestore 來源：users/{uid}/notifications
///   - 建議欄位：
///     title: String
///     body: String
///     type: String (points/mission/lottery/coupon/order...)
///     createdAt: Timestamp
///     readAt: Timestamp? (未讀為 null)
///     data: Map<String,dynamic>? (可選)
/// ------------------------------------------------------------
class PointsNotificationPage extends StatefulWidget {
  const PointsNotificationPage({super.key});

  @override
  State<PointsNotificationPage> createState() => _PointsNotificationPageState();
}

class _PointsNotificationPageState extends State<PointsNotificationPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _onlyUnread = false;

  User? get _user => _auth.currentUser;

  void _goLogin() {
    Navigator.of(context, rootNavigator: true).pushNamed('/login');
  }

  CollectionReference<Map<String, dynamic>> _userNotiRef(String uid) =>
      _fs.collection('users').doc(uid).collection('notifications');

  Query<Map<String, dynamic>> _query(String uid) {
    Query<Map<String, dynamic>> q = _userNotiRef(uid);

    // 只顯示點數相關：type = points/mission/lottery/coupon 這類
    // 若你沒有 type 欄位，可以把 where 這段刪掉（不會影響編譯）
    q = q.where(
      'type',
      whereIn: const ['points', 'mission', 'lottery', 'coupon'],
    );

    if (_onlyUnread) {
      q = q.where('readAt', isNull: true);
    }

    q = q.orderBy('createdAt', descending: true);
    q = q.limit(200);
    return q;
  }

  Future<void> _markRead(String uid, String id) async {
    await _userNotiRef(uid).doc(id).set({
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _markAllRead(String uid) async {
    final snap = await _query(uid).get();
    final batch = _fs.batch();
    for (final d in snap.docs) {
      // 只把未讀的標記已讀
      if ((d.data()['readAt']) == null) {
        batch.set(d.reference, {
          'readAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('點數通知'),
        actions: [
          if (u != null)
            IconButton(
              tooltip: '全部標記已讀',
              onPressed: () => _markAllRead(u.uid),
              icon: const Icon(Icons.done_all),
            ),
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: u == null ? _needLogin() : _content(u.uid),
    );
  }

  Widget _needLogin() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    '請先登入才能查看點數通知',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _goLogin, child: const Text('前往登入')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(String uid) {
    return Column(
      children: [
        _filterBar(),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _query(uid).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _errorBox(
                  '讀取通知失敗：${snap.error}\n'
                  '若你沒有 type/readAt/createdAt 欄位或索引，請調整 query（把 where/orderBy 相關刪除或改掉）。',
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return _empty('目前沒有點數相關通知');
              }

              final items = docs
                  .map((d) => AppNotification.fromDoc(d))
                  .where((n) => n != null)
                  .cast<AppNotification>()
                  .toList();

              if (items.isEmpty) {
                return _empty('通知資料格式不正確（缺 title/body/createdAt 等欄位）');
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final n = items[i];
                  final unread = n.readAt == null;

                  return Card(
                    elevation: 1,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey.shade100,
                        child: Icon(
                          unread
                              ? Icons.notifications_active
                              : Icons.notifications,
                          color: unread ? Colors.orange : Colors.blueGrey,
                        ),
                      ),
                      title: Text(
                        n.title.isNotEmpty ? n.title : '（無標題）',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: unread ? Colors.black : Colors.blueGrey,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (n.body.isNotEmpty) n.body,
                          _fmt(n.createdAt),
                          if (n.type.isNotEmpty) 'type: ${n.type}',
                        ].join('\n'),
                      ),
                      trailing: unread
                          ? const Chip(
                              label: Text('未讀'),
                              visualDensity: VisualDensity.compact,
                            )
                          : null,
                      onTap: () async {
                        await _openDetail(uid, n);
                        if (unread) {
                          await _markRead(uid, n.id);
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          FilterChip(
            label: const Text('只看未讀'),
            selected: _onlyUnread,
            onSelected: (v) => setState(() => _onlyUnread = v),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '提示：通知來源為 users/{uid}/notifications',
              style: TextStyle(color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(String uid, AppNotification n) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '通知明細',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _detailRow('ID', n.id),
                if (n.type.isNotEmpty) _detailRow('type', n.type),
                _detailRow('title', n.title),
                if (n.body.isNotEmpty) _detailRow('body', n.body),
                _detailRow('createdAt', _fmt(n.createdAt)),
                _detailRow('readAt', n.readAt == null ? '未讀' : _fmt(n.readAt!)),
                const SizedBox(height: 10),
                const Text(
                  'data',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _pretty(n.data),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('關閉'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}/${two(dt.month)}/${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _pretty(Map<String, dynamic> m) {
    if (m.isEmpty) return '{}';
    final keys = m.keys.toList()..sort();
    return keys.map((k) => '$k: ${m[k]}').join('\n');
  }

  Widget _empty(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBox(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ✅ AppNotification（強型別 model；避免使用 n['title']）
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic> data;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.readAt,
    required this.data,
  });

  static AppNotification? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) return null;

    final title = (d['title'] ?? '').toString();
    final body = (d['body'] ?? '').toString();
    final type = (d['type'] ?? '').toString();

    final ts = d['createdAt'];
    DateTime createdAt;
    if (ts is Timestamp) {
      createdAt = ts.toDate();
    } else {
      // 沒 createdAt 就用現在（至少不會炸）
      createdAt = DateTime.now();
    }

    final r = d['readAt'];
    DateTime? readAt;
    if (r is Timestamp) readAt = r.toDate();

    final rawData = <String, dynamic>{};
    final extra = d['data'];
    if (extra is Map) {
      extra.forEach((k, v) {
        rawData[k.toString()] = v;
      });
    }

    return AppNotification(
      id: doc.id,
      title: title,
      body: body,
      type: type,
      createdAt: createdAt,
      readAt: readAt,
      data: rawData,
    );
  }
}
