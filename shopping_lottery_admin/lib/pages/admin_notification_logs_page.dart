// lib/pages/admin_notification_logs_page.dart
//
// ✅ AdminNotificationLogsPage（完整版｜可編譯｜通知發送紀錄｜可重送）
// ------------------------------------------------------------
// Firestore（建議）: notificationLogs/{logId}
// - title: String
// - body: String
// - type: String (required for resend) 例如: general/system/promo/order/support_task...
// - route: String?（點擊通知要導向的路由）
// - uids: List<String>?（多用戶推播）
// - uid: String?（單用戶推播）
// - vendorId: String?（可選）
// - createdAt: Timestamp
// - status: String? (success/fail/queued...)
// - error: String?（失敗訊息）
// - extra: Map<String, dynamic>?（額外 payload）
//
// 依賴：cloud_firestore, flutter/material, flutter/services, provider
//      services/notification_service.dart 需提供 sendToUsers(...)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';

class AdminNotificationLogsPage extends StatefulWidget {
  const AdminNotificationLogsPage({
    super.key,
    this.collection = 'notificationLogs',
    this.limit = 500,
  });

  final String collection;
  final int limit;

  @override
  State<AdminNotificationLogsPage> createState() =>
      _AdminNotificationLogsPageState();
}

class _AdminNotificationLogsPageState extends State<AdminNotificationLogsPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();

  // filters
  static const _typeAll = 'all';
  String _typeFilter = _typeAll;

  final List<String> _typeOptions = const [
    _typeAll,
    'general',
    'system',
    'promo',
    'order',
    'support_task',
    'sos',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  DateTime? _toDate(dynamic v) => v is Timestamp ? v.toDate() : null;

  String _fmtTime(DateTime? d) {
    if (d == null) return '-';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y/$m/$day $hh:$mm';
  }

  Query<Map<String, dynamic>> _query() {
    return _db
        .collection(widget.collection)
        .orderBy('createdAt', descending: true)
        .limit(widget.limit);
  }

  bool _matchSearch(Map<String, dynamic> d, String docId, String q) {
    if (q.isEmpty) return true;
    final hay = [
      docId,
      _s(d['title']),
      _s(d['body']),
      _s(d['type']),
      _s(d['route']),
      _s(d['status']),
      _s(d['uid']),
      _s(d['vendorId']),
      _s(d['error']),
    ].join(' ').toLowerCase();
    return hay.contains(q);
  }

  bool _matchType(Map<String, dynamic> d) {
    if (_typeFilter == _typeAll) return true;
    return _s(d['type']).toLowerCase() == _typeFilter.toLowerCase();
  }

  Future<void> _copyText(String text, {String okMsg = '已複製'}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okMsg)));
  }

  Future<void> _resend(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data() ?? {};
    final title = _s(d['title']);
    final body = _s(d['body']);
    final route = _s(d['route']);
    final type = _s(d['type']).isEmpty ? 'general' : _s(d['type']);

    // targets
    final uids = <String>[];
    final list = d['uids'];
    if (list is List) {
      for (final it in list) {
        final s = _s(it);
        if (s.isNotEmpty) uids.add(s);
      }
    }
    final singleUid = _s(d['uid']);
    if (uids.isEmpty && singleUid.isNotEmpty) uids.add(singleUid);

    if (uids.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此紀錄沒有 uid/uids，無法重送')));
      return;
    }
    if (title.isEmpty || body.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此紀錄缺少 title/body，無法重送')));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          '確認重送通知',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          '將重送給 ${uids.length} 位。\n\ntitle: $title\n'
          'type: $type\n'
          '${route.isEmpty ? '' : 'route: $route\n'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確認重送'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (ok != true) return;

    try {
      await context.read<NotificationService>().sendToUsers(
        uids: uids,
        title: title,
        body: body,
        type: type,
        route: route.isEmpty ? null : route,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已重送')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('重送失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = _searchCtrl.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '通知發送紀錄',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '搜尋 title/body/type/route/uid/status/error...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    // ✅ 修正：value deprecated -> initialValue
                    // ✅ 加 key 強制重建，避免 initialValue 只吃第一次造成 UI 不同步
                    key: ValueKey(_typeFilter),
                    initialValue: _typeFilter,
                    decoration: const InputDecoration(
                      labelText: 'type 篩選',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _typeOptions
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t == _typeAll ? '全部' : t),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _typeFilter = v ?? _typeAll),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('載入失敗：${snap.error}'));
                }

                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((d) {
                  final data = d.data();
                  return _matchType(data) && _matchSearch(data, d.id, q);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      docs.isEmpty ? '目前沒有紀錄' : '沒有符合條件的紀錄',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final doc = filtered[i];
                    final d = doc.data();

                    final title = _s(d['title']);
                    final body = _s(d['body']);
                    final type = _s(d['type']).isEmpty
                        ? 'general'
                        : _s(d['type']);
                    final route = _s(d['route']);
                    final status = _s(d['status']);
                    final err = _s(d['error']);
                    final createdAt = _fmtTime(_toDate(d['createdAt']));

                    int targets = 0;
                    final uids = d['uids'];
                    if (uids is List) targets = uids.length;
                    if (targets == 0 && _s(d['uid']).isNotEmpty) targets = 1;

                    return ListTile(
                      title: Text(
                        title.isEmpty ? '(no title)' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        [
                          'time: $createdAt',
                          'type: $type',
                          if (route.isNotEmpty) 'route: $route',
                          if (status.isNotEmpty) 'status: $status',
                          'targets: $targets',
                          if (err.isNotEmpty) 'error: $err',
                          if (body.isNotEmpty)
                            // ✅ 修正 prefer_interpolation_to_compose_strings：不要用 +
                            'body: ${body.length > 60 ? '${body.substring(0, 60)}…' : body}',
                        ].join('  •  '),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'copy_id') {
                            await _copyText(doc.id, okMsg: '已複製 logId');
                          } else if (v == 'copy_json') {
                            await _copyText(
                              d.toString(),
                              okMsg: '已複製內容（toString）',
                            );
                          } else if (v == 'resend') {
                            await _resend(doc);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'resend',
                            child: Text('重送（Resend）'),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'copy_id',
                            child: Text('複製 logId'),
                          ),
                          const PopupMenuItem(
                            value: 'copy_json',
                            child: Text('複製內容'),
                          ),
                        ],
                      ),
                      onTap: () => _openDetail(doc),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final title = _s(d['title']);
    final body = _s(d['body']);
    final type = _s(d['type']).isEmpty ? 'general' : _s(d['type']);
    final route = _s(d['route']);
    final status = _s(d['status']);
    final err = _s(d['error']);
    final createdAt = _fmtTime(_toDate(d['createdAt']));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title.isEmpty ? '通知詳情' : title),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('logId', doc.id),
                _kv('createdAt', createdAt),
                _kv('type', type),
                _kv('route', route.isEmpty ? '-' : route),
                _kv('status', status.isEmpty ? '-' : status),
                if (err.isNotEmpty) _kv('error', err),
                const SizedBox(height: 10),
                const Text(
                  'body',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                SelectableText(body.isEmpty ? '-' : body),
                const SizedBox(height: 10),
                const Text(
                  'raw',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                SelectableText(d.toString()),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _copyText(doc.id, okMsg: '已複製 logId'),
            child: const Text('複製 logId'),
          ),
          TextButton(
            onPressed: () => _copyText(d.toString(), okMsg: '已複製內容'),
            child: const Text('複製內容'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (!mounted) return;
              await _resend(doc);
            },
            child: const Text('重送'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Expanded(child: SelectableText(v)),
        ],
      ),
    );
  }
}
