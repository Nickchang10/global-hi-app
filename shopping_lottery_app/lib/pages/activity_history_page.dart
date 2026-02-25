// lib/pages/activity_history_page.dart
//
// ✅ ActivityHistoryPage（修正版｜可編譯｜不依賴 AppNotification 型別）
// ------------------------------------------------------------
// - 直接用 Firestore 讀取通知紀錄
// - 預設路徑：users/{uid}/notifications
// - 搜尋 / 類型篩選 / 只看未讀
// - 點擊導頁：deepLink(若為 /xxx) -> Navigator.pushNamed；否則用 route
// - 單筆刪除、標記已讀/未讀、全部已讀（batch）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ActivityHistoryPage extends StatefulWidget {
  const ActivityHistoryPage({
    super.key,
    this.limit = 200,
    this.useRootNotificationsCollection = false,
  });

  /// 最多顯示幾筆
  final int limit;

  /// 若你的通知是放在頂層 notifications（並且有 uid 欄位），就改成 true
  final bool useRootNotificationsCollection;

  @override
  State<ActivityHistoryPage> createState() => _ActivityHistoryPageState();
}

class _ActivityHistoryPageState extends State<ActivityHistoryPage> {
  final _db = FirebaseFirestore.instance;

  final TextEditingController _searchCtrl = TextEditingController();
  String _typeFilter =
      'all'; // all/general/promo/system/order/sos/support_task...
  bool _showUnreadOnly = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  // -------------------------
  // Firestore refs
  // -------------------------
  Query<Map<String, dynamic>> _queryForUser(String uid) {
    if (widget.useRootNotificationsCollection) {
      // notifications (root) 必須有 uid 欄位
      return _db
          .collection('notifications')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(widget.limit);
    }

    // users/{uid}/notifications
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(widget.limit);
  }

  // -------------------------
  // UI helpers
  // -------------------------
  IconData _iconForType(String type) {
    switch (type) {
      case 'order':
        return Icons.receipt_long;
      case 'promo':
        return Icons.local_offer;
      case 'system':
        return Icons.campaign;
      case 'sos':
        return Icons.sos;
      case 'support_task':
        return Icons.support_agent;
      default:
        return Icons.notifications_none;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'order':
        return '訂單';
      case 'promo':
        return '促銷';
      case 'system':
        return '系統';
      case 'sos':
        return 'SOS';
      case 'support_task':
        return '客服任務';
      case 'general':
        return '一般';
      default:
        return type;
    }
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '-';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $hh:$mm';
  }

  // -------------------------
  // Actions
  // -------------------------
  Future<void> _confirmDelete(NotificationItem n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          '刪除通知',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text('確定要刪除這則通知嗎？\n\n${n.title.isEmpty ? '(無標題)' : n.title}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await n.ref.delete();
      _snack('已刪除');
    } catch (e) {
      _snack('刪除失敗：$e');
    }
  }

  Future<void> _toggleRead(NotificationItem n) async {
    try {
      await n.ref.set(<String, dynamic>{
        'read': !n.read,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _snack('更新已讀狀態失敗：$e');
    }
  }

  Future<void> _markAllRead(String uid) async {
    try {
      // 分批更新（每批 <= 450）
      while (true) {
        final snap = await _queryForUser(
          uid,
        ).where('read', isEqualTo: false).limit(450).get();
        if (snap.docs.isEmpty) break;

        final batch = _db.batch();
        for (final d in snap.docs) {
          batch.set(d.reference, <String, dynamic>{
            'read': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        await batch.commit();
      }
      _snack('已全部標記為已讀');
    } catch (e) {
      _snack('操作失敗：$e');
    }
  }

  void _openNotification(NotificationItem n) {
    // 先標記已讀（不阻塞）
    if (!n.read) {
      n.ref.set(<String, dynamic>{
        'read': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final deepLink = _s(n.deepLink);
    final route = _s(n.route);

    // deepLink 若是 /xxx：當成 named route
    if (deepLink.isNotEmpty && deepLink.startsWith('/')) {
      Navigator.pushNamed(context, deepLink);
      return;
    }

    // route
    if (route.isNotEmpty) {
      Navigator.pushNamed(context, route);
      return;
    }

    // fallback：顯示詳情
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          n.title.isEmpty ? '(無標題)' : n.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('類型：${_typeLabel(n.type)}'),
              const SizedBox(height: 6),
              Text('時間：${_fmtTime(n.createdAt)}'),
              const Divider(height: 22),
              Text(n.body.isEmpty ? '(無內容)' : n.body),
              if (_s(n.deepLink).isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'deepLink：${n.deepLink}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
              if (_s(n.route).isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'route：${n.route}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  // -------------------------
  // Filtering
  // -------------------------
  List<NotificationItem> _applyFilters(List<NotificationItem> list) {
    final q = _searchCtrl.text.trim().toLowerCase();

    return list.where((n) {
      if (_showUnreadOnly && n.read == true) return false;
      if (_typeFilter != 'all' && n.type != _typeFilter) return false;

      if (q.isEmpty) return true;

      final hay = [
        n.title,
        n.body,
        n.type,
        n.deepLink ?? '',
        n.route ?? '',
      ].join(' ').toLowerCase();

      return hay.contains(q);
    }).toList();
  }

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('請先登入')));
    }

    final stream = _queryForUser(user.uid).snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '活動紀錄',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '全部已讀',
            onPressed: () => _markAllRead(user.uid),
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('載入失敗：${snap.error}'));
          }

          final docs =
              snap.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final list = docs.map((d) => NotificationItem.fromDoc(d)).toList();
          final filtered = _applyFilters(list);

          return Column(
            children: [
              _filterBar(cs),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? _empty(cs, isOriginalEmpty: list.isEmpty)
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final n = filtered[i];
                          return ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: cs.surfaceContainerHighest
                                      // ✅ FIX: withOpacity -> withValues(alpha: ...)
                                      .withValues(alpha: 0.6),
                                  child: Icon(
                                    _iconForType(n.type),
                                    color: cs.onSurface,
                                  ),
                                ),
                                if (!n.read)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: cs.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              n.title.isEmpty ? '(無標題)' : n.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: n.read
                                    ? FontWeight.w700
                                    : FontWeight.w900,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  n.body.isEmpty ? '(無內容)' : n.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _pill(cs, _typeLabel(n.type)),
                                    _pill(cs, _fmtTime(n.createdAt)),
                                    if (_s(n.deepLink).isNotEmpty)
                                      _pill(cs, 'deepLink'),
                                    if (_s(n.route).isNotEmpty)
                                      _pill(cs, 'route'),
                                  ],
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            onTap: () => _openNotification(n),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'delete') _confirmDelete(n);
                                if (v == 'toggle_read') _toggleRead(n);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'toggle_read',
                                  child: Text(n.read ? '標記未讀' : '標記已讀'),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('刪除'),
                                ),
                              ],
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
  }

  Widget _filterBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '搜尋（標題 / 內容 / 類型）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip('全部', 'all'),
                      _chip('一般', 'general'),
                      _chip('促銷', 'promo'),
                      _chip('系統', 'system'),
                      _chip('訂單', 'order'),
                      _chip('SOS', 'sos'),
                      _chip('客服任務', 'support_task'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text('只看未讀'),
                selected: _showUnreadOnly,
                onSelected: (v) => setState(() => _showUnreadOnly = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String key) {
    final selected = _typeFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _typeFilter = key),
      ),
    );
  }

  Widget _pill(ColorScheme cs, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // ✅ FIX: withOpacity -> withValues(alpha: ...)
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _empty(ColorScheme cs, {required bool isOriginalEmpty}) {
    final title = isOriginalEmpty ? '目前沒有活動紀錄' : '沒有符合條件的紀錄';
    final sub = isOriginalEmpty ? '當你收到通知或系統事件時會出現在這裡。' : '請調整搜尋或篩選條件後再試一次。';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 44, color: cs.primary),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(sub, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Local model (避免 AppNotification 不存在)
// ------------------------------------------------------------
class NotificationItem {
  final String id;
  final DocumentReference<Map<String, dynamic>> ref;

  final String title;
  final String body;
  final String type;
  final bool read;

  final DateTime? createdAt;
  final String? deepLink;
  final String? route;

  NotificationItem({
    required this.id,
    required this.ref,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    required this.createdAt,
    required this.deepLink,
    required this.route,
  });

  static DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static String _s(dynamic v) => (v ?? '').toString().trim();

  factory NotificationItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();

    // 兼容不同欄位命名
    final title = _s(d['title']);
    final body = _s(d['body']);
    final type = _s(d['type']).isEmpty ? 'general' : _s(d['type']);
    final read = d['read'] == true;

    // deepLink 可能叫 link / deepLink
    final deepLink = _s(d['deepLink']).isNotEmpty
        ? _s(d['deepLink'])
        : (_s(d['link']).isNotEmpty ? _s(d['link']) : null);

    // route
    final route = _s(d['route']).isNotEmpty ? _s(d['route']) : null;

    // createdAt
    final createdAt = _toDate(d['createdAt']);

    return NotificationItem(
      id: doc.id,
      ref: doc.reference,
      title: title,
      body: body,
      type: type,
      read: read,
      createdAt: createdAt,
      deepLink: deepLink,
      route: route,
    );
  }
}
