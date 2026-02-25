// lib/pages/notifications_page.dart
//
// ✅ NotificationsPage（後台通用通知中心｜可編譯｜即時監聽｜已讀/未讀｜搜尋｜批次已讀/未讀｜匯出CSV(複製)｜Web+App）
//
// Firestore 建議：notifications/{notificationId}
//   - title: String
//   - body: String
//   - type: String            // order/product/system...
//   - refId: String           // 例如 orderId / productId...
//   - level: String           // info/warn/error
//   - isRead: bool
//   - createdAt: Timestamp
//   - updatedAt: Timestamp
//   - readAt: Timestamp (選用)
//
// 注意：
// - where(isRead)+orderBy(createdAt) 可能需要複合索引；若遇錯誤 console 會提供索引建立連結。
// - 匯出CSV採「複製到剪貼簿」。

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.collection = 'notifications'});

  final String collection;

  static const String routeName = '/notifications';

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _q = '';

  bool? _isRead; // null=全部, true=已讀, false=未讀

  bool _busy = false;
  String _busyLabel = '';

  final Set<String> _selectedIds = <String>{};

  CollectionReference<Map<String, dynamic>> get _ncol =>
      _db.collection(widget.collection);

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Utils
  // -------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();
  bool _isTrue(dynamic v) => v == true;

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _copy(String text, {String done = '已複製'}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    if (!mounted) return;
    _snack(done);
  }

  void _setBusy(bool v, {String label = ''}) {
    if (!mounted) return;
    setState(() {
      _busy = v;
      _busyLabel = label;
    });
  }

  // -------------------------
  // Stream
  // -------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    Query<Map<String, dynamic>> q = _ncol
        .orderBy('createdAt', descending: true)
        .limit(800);

    if (_isRead != null) {
      q = _ncol
          .where('isRead', isEqualTo: _isRead)
          .orderBy('createdAt', descending: true)
          .limit(800);
    }

    return q.snapshots();
  }

  bool _matchLocal(_NotiRow r) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;

    final d = r.data;
    final id = r.id.toLowerCase();
    final title = _s(d['title']).toLowerCase();
    final body = _s(d['body']).toLowerCase();
    final type = _s(d['type']).toLowerCase();
    final refId = _s(d['refId']).toLowerCase();
    final level = _s(d['level']).toLowerCase();

    return id.contains(q) ||
        title.contains(q) ||
        body.contains(q) ||
        type.contains(q) ||
        refId.contains(q) ||
        level.contains(q);
  }

  // -------------------------
  // Actions
  // -------------------------
  Future<void> _markRead(String id, bool read) async {
    _setBusy(true, label: read ? '標記已讀...' : '標記未讀...');
    try {
      await _ncol.doc(id).set(<String, dynamic>{
        'isRead': read,
        if (read)
          'readAt': FieldValue.serverTimestamp()
        else
          'readAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      _snack(read ? '已讀' : '未讀');
    } catch (e) {
      if (!mounted) return;
      _snack('操作失敗：$e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _batchMarkRead(List<_NotiRow> rows, bool read) async {
    if (_selectedIds.isEmpty) {
      _snack('請先勾選通知');
      return;
    }
    final targets = rows.where((r) => _selectedIds.contains(r.id)).toList();
    if (targets.isEmpty) {
      _snack('選取清單為空');
      return;
    }

    _setBusy(true, label: read ? '批次已讀...' : '批次未讀...');
    try {
      final batch = _db.batch();
      for (final r in targets) {
        batch.set(_ncol.doc(r.id), <String, dynamic>{
          'isRead': read,
          if (read)
            'readAt': FieldValue.serverTimestamp()
          else
            'readAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
      if (!mounted) return;
      _snack('已批次${read ? '已讀' : '未讀'}（${targets.length}）');
    } catch (e) {
      if (!mounted) return;
      _snack('批次失敗：$e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _exportCsv(List<_NotiRow> rows) async {
    if (rows.isEmpty) return;

    final headers = <String>[
      'notificationId',
      'title',
      'body',
      'type',
      'refId',
      'level',
      'isRead',
      'createdAt',
      'updatedAt',
      'readAt',
    ];

    final buffer = StringBuffer()..writeln(headers.join(','));

    for (final r in rows) {
      final d = r.data;

      final line =
          <String>[
                r.id,
                _s(d['title']),
                _s(d['body']),
                _s(d['type']),
                _s(d['refId']),
                _s(d['level']),
                _isTrue(d['isRead']).toString(),
                (_toDate(d['createdAt'])?.toIso8601String() ?? ''),
                (_toDate(d['updatedAt'])?.toIso8601String() ?? ''),
                (_toDate(d['readAt'])?.toIso8601String() ?? ''),
              ]
              .map(
                (e) => e
                    .replaceAll(',', '，')
                    .replaceAll('\n', ' ')
                    .replaceAll('\r', ' '),
              )
              .toList();

      buffer.writeln(line.join(','));
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    _snack('已複製 CSV 到剪貼簿（可貼到 Excel）');
  }

  Future<void> _openDetail(_NotiRow row) async {
    final d = row.data;
    final title = _s(d['title']).isEmpty ? '（無標題）' : _s(d['title']);
    final body = _s(d['body']);
    final type = _s(d['type']);
    final refId = _s(d['refId']);
    final level = _s(d['level']);
    final read = _isTrue(d['isRead']);

    await showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: SizedBox(
          width: 680,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    _Pill(
                      label: read ? '已讀' : '未讀',
                      color: read
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '複製 notificationId',
                      onPressed: () =>
                          _copy(row.id, done: '已複製 notificationId'),
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _InfoRow(label: 'type', value: type),
                const SizedBox(height: 6),
                _InfoRow(label: 'refId', value: refId),
                const SizedBox(height: 6),
                _InfoRow(label: 'level', value: level),
                const SizedBox(height: 6),
                _InfoRow(
                  label: 'createdAt',
                  value: _fmt(_toDate(d['createdAt'])),
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  label: 'updatedAt',
                  value: _fmt(_toDate(d['updatedAt'])),
                ),
                const SizedBox(height: 6),
                _InfoRow(label: 'readAt', value: _fmt(_toDate(d['readAt']))),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '內容',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.18),
                    ),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.22),
                  ),
                  child: Text(body.isEmpty ? '（無內容）' : body),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await _markRead(row.id, !read);
                            },
                      icon: Icon(
                        read
                            ? Icons.mark_email_unread_outlined
                            : Icons.mark_email_read_outlined,
                      ),
                      label: Text(read ? '標記未讀' : '標記已讀'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _copy(jsonEncode(d), done: '已複製 JSON'),
                      icon: const Icon(Icons.code),
                      label: const Text('複製 JSON'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('關閉'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('通知中心')),
      body: Stack(
        children: [
          Column(
            children: [
              _Filters(
                searchCtrl: _searchCtrl,
                isRead: _isRead,
                onQueryChanged: (v) => setState(() => _q = v),
                onClearQuery: () {
                  _searchCtrl.clear();
                  setState(() => _q = '');
                },
                onReadChanged: (v) => setState(() => _isRead = v),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _stream(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(child: Text('讀取失敗：${snap.error}'));
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final rows = snap.data!.docs
                        .map((d) => _NotiRow(id: d.id, data: d.data()))
                        .where(_matchLocal)
                        .toList();

                    // 清除不存在的選取
                    final ids = rows.map((e) => e.id).toSet();
                    _selectedIds.removeWhere((id) => !ids.contains(id));

                    return Column(
                      children: [
                        _BatchBar(
                          count: rows.length,
                          selectedCount: _selectedIds.length,
                          onSelectAll: rows.isEmpty
                              ? null
                              : () {
                                  setState(() {
                                    if (_selectedIds.length == rows.length) {
                                      _selectedIds.clear();
                                    } else {
                                      _selectedIds
                                        ..clear()
                                        ..addAll(rows.map((e) => e.id));
                                    }
                                  });
                                },
                          onExport: rows.isEmpty || _busy
                              ? null
                              : () => _exportCsv(rows),
                          onBatchRead: (_busy || _selectedIds.isEmpty)
                              ? null
                              : () => _batchMarkRead(rows, true),
                          onBatchUnread: (_busy || _selectedIds.isEmpty)
                              ? null
                              : () => _batchMarkRead(rows, false),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: rows.isEmpty
                              ? Center(
                                  child: Text(
                                    '沒有通知',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: rows.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (_, i) {
                                    final r = rows[i];
                                    final d = r.data;

                                    final title = _s(d['title']).isEmpty
                                        ? '（無標題）'
                                        : _s(d['title']);
                                    final body = _s(d['body']);
                                    final type = _s(d['type']);
                                    final refId = _s(d['refId']);
                                    final level = _s(d['level']);
                                    final read = _isTrue(d['isRead']);
                                    final createdAt = _toDate(d['createdAt']);

                                    final selected = _selectedIds.contains(
                                      r.id,
                                    );

                                    return ListTile(
                                      leading: Checkbox(
                                        value: selected,
                                        onChanged: _busy
                                            ? null
                                            : (v) {
                                                setState(() {
                                                  if (v == true) {
                                                    _selectedIds.add(r.id);
                                                  } else {
                                                    _selectedIds.remove(r.id);
                                                  }
                                                });
                                              },
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: read
                                                    ? FontWeight.w800
                                                    : FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _Pill(
                                            label: read ? '已讀' : '未讀',
                                            color: read ? cs.primary : cs.error,
                                          ),
                                        ],
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (body.isNotEmpty)
                                              Text(
                                                body,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: cs.onSurfaceVariant,
                                                ),
                                              ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 4,
                                              children: [
                                                if (type.isNotEmpty)
                                                  Text(
                                                    'type：$type',
                                                    style: TextStyle(
                                                      color:
                                                          cs.onSurfaceVariant,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                if (refId.isNotEmpty)
                                                  Text(
                                                    'ref：$refId',
                                                    style: TextStyle(
                                                      color:
                                                          cs.onSurfaceVariant,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                if (level.isNotEmpty)
                                                  Text(
                                                    'level：$level',
                                                    style: TextStyle(
                                                      color:
                                                          cs.onSurfaceVariant,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                Text(
                                                  '時間：${_fmt(createdAt)}',
                                                  style: TextStyle(
                                                    color: cs.onSurfaceVariant,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      trailing: PopupMenuButton<String>(
                                        tooltip: '更多',
                                        onSelected: _busy
                                            ? null
                                            : (v) async {
                                                if (v == 'detail') {
                                                  await _openDetail(r);
                                                } else if (v == 'toggle') {
                                                  await _markRead(r.id, !read);
                                                } else if (v == 'copy_id') {
                                                  await _copy(
                                                    r.id,
                                                    done: '已複製 notificationId',
                                                  );
                                                } else if (v == 'copy_json') {
                                                  await _copy(
                                                    jsonEncode(d),
                                                    done: '已複製 JSON',
                                                  );
                                                }
                                              },
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(
                                            value: 'detail',
                                            child: Text('查看詳情'),
                                          ),
                                          PopupMenuItem(
                                            value: 'toggle',
                                            child: Text(read ? '標記未讀' : '標記已讀'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'copy_id',
                                            child: Text('複製 notificationId'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'copy_json',
                                            child: Text('複製 JSON'),
                                          ),
                                        ],
                                      ),
                                      onTap: () => _openDetail(r),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          if (_busy)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BusyBar(
                label: _busyLabel.isEmpty ? '處理中...' : _busyLabel,
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Models
// ------------------------------------------------------------
class _NotiRow {
  final String id;
  final Map<String, dynamic> data;
  _NotiRow({required this.id, required this.data});
}

// ------------------------------------------------------------
// Filters / Batch
// ------------------------------------------------------------
class _Filters extends StatelessWidget {
  const _Filters({
    required this.searchCtrl,
    required this.isRead,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onReadChanged,
  });

  final TextEditingController searchCtrl;
  final bool? isRead;

  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<bool?> onReadChanged;

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      controller: searchCtrl,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        hintText: '搜尋：標題 / 內容 / type / refId / level / id',
        suffixIcon: searchCtrl.text.trim().isEmpty
            ? null
            : IconButton(
                tooltip: '清除',
                onPressed: onClearQuery,
                icon: const Icon(Icons.clear),
              ),
      ),
      onChanged: onQueryChanged,
    );

    // ✅ 避免 DropdownButtonFormField.value 的新版本 deprecated：改用 DropdownMenu
    final dd = DropdownMenu<bool?>(
      key: ValueKey(isRead),
      initialSelection: isRead,
      expandedInsets: EdgeInsets.zero,
      label: const Text('已讀狀態'),
      dropdownMenuEntries: const [
        DropdownMenuEntry(value: null, label: '全部'),
        DropdownMenuEntry(value: false, label: '未讀'),
        DropdownMenuEntry(value: true, label: '已讀'),
      ],
      onSelected: onReadChanged,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 980;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [search, const SizedBox(height: 10), dd],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: search),
              const SizedBox(width: 10),
              SizedBox(width: 240, child: dd),
            ],
          );
        },
      ),
    );
  }
}

class _BatchBar extends StatelessWidget {
  const _BatchBar({
    required this.count,
    required this.selectedCount,
    required this.onSelectAll,
    required this.onExport,
    required this.onBatchRead,
    required this.onBatchUnread,
  });

  final int count;
  final int selectedCount;

  final VoidCallback? onSelectAll;
  final VoidCallback? onExport;
  final VoidCallback? onBatchRead;
  final VoidCallback? onBatchUnread;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Text(
            '共 $count 筆',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '已選 $selectedCount 筆',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onSelectAll,
            icon: const Icon(Icons.select_all),
            label: const Text('全選/取消'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.download_outlined),
            label: const Text('匯出CSV'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onBatchUnread,
            icon: const Icon(Icons.mark_email_unread_outlined),
            label: const Text('批次未讀'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onBatchRead,
            icon: const Icon(Icons.mark_email_read_outlined),
            label: const Text('批次已讀'),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Shared Widgets
// ------------------------------------------------------------
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _BusyBar extends StatelessWidget {
  const _BusyBar({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
