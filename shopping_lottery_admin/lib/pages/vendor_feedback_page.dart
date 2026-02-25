// lib/pages/vendor_feedback_page.dart
//
// ✅ VendorFeedbackPage（完整版｜可編譯｜Vendor Only｜顧客回饋中心｜即時同步｜搜尋/篩選｜回覆與標記已處理｜匯出CSV(複製剪貼簿)）
//
// 依賴：cloud_firestore, flutter/material, flutter/services

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VendorFeedbackPage extends StatefulWidget {
  const VendorFeedbackPage({
    super.key,
    required this.vendorId,
    this.collection = 'feedbacks',
    this.replyBy,
  });

  final String vendorId;
  final String collection;
  final String? replyBy;

  @override
  State<VendorFeedbackPage> createState() => _VendorFeedbackPageState();
}

class _VendorFeedbackPageState extends State<VendorFeedbackPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _q = '';

  String? _status; // null=全部, open/replied/closed
  String? _type; // null=全部, review/question/issue/other
  int? _minRating; // null=全部, 1~5

  String? _selectedId;

  bool _busy = false;
  String _busyLabel = '';

  String get _vid => widget.vendorId.trim();
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(widget.collection);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Utils
  // -------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmtDateTime(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    final s = (v ?? '').toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
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

  Future<void> _setBusy(bool v, {String label = ''}) async {
    if (!mounted) return;
    setState(() {
      _busy = v;
      _busyLabel = label;
    });
  }

  // -------------------------
  // Stream (server-side 篩選 + 本地搜尋)
  // -------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    if (_vid.isEmpty) {
      return const Stream.empty();
    }

    Query<Map<String, dynamic>> q = _col
        .where('vendorId', isEqualTo: _vid)
        .orderBy('createdAt', descending: true)
        .limit(800);

    if (_status != null && _status!.isNotEmpty) {
      q = q.where('status', isEqualTo: _status);
    }

    if (_type != null && _type!.isNotEmpty) {
      q = q.where('type', isEqualTo: _type);
    }

    return q.snapshots();
  }

  bool _matchLocal(_FeedbackRow r) {
    final d = r.data;

    if (_minRating != null) {
      final rating = _toInt(d['rating']) ?? 0;
      if (rating < _minRating!) return false;
    }

    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;

    final id = r.id.toLowerCase();
    final userName = _s(d['userName']).toLowerCase();
    final userEmail = _s(d['userEmail']).toLowerCase();
    final productName = _s(d['productName']).toLowerCase();
    final title = _s(d['title']).toLowerCase();
    final msg = _s(d['message']).toLowerCase();
    final reply = _s(d['reply']).toLowerCase();
    final orderId = _s(d['orderId']).toLowerCase();
    final type = _s(d['type']).toLowerCase();
    final status = _s(d['status']).toLowerCase();

    return id.contains(q) ||
        userName.contains(q) ||
        userEmail.contains(q) ||
        productName.contains(q) ||
        title.contains(q) ||
        msg.contains(q) ||
        reply.contains(q) ||
        orderId.contains(q) ||
        type.contains(q) ||
        status.contains(q);
  }

  // -------------------------
  // Actions
  // -------------------------
  Future<void> _openReplyDialog({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final replyCtrl = TextEditingController(text: _s(data['reply']));
    String status = _s(data['status']).isEmpty ? 'open' : _s(data['status']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('回覆顧客回饋'),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv(
                    context,
                    'feedbackId',
                    id,
                    copy: () => _copy(id, done: '已複製 feedbackId'),
                  ),
                  const SizedBox(height: 6),
                  _kv(
                    context,
                    '狀態',
                    _s(data['status']).isEmpty ? 'open' : _s(data['status']),
                  ),
                  const SizedBox(height: 6),
                  _kv(
                    context,
                    '類型',
                    _s(data['type']).isEmpty ? '-' : _s(data['type']),
                  ),
                  const SizedBox(height: 6),
                  _kv(
                    context,
                    '評分',
                    _s(data['rating']).isEmpty ? '-' : _s(data['rating']),
                  ),
                  const Divider(height: 22),
                  Text(
                    _s(data['title']).isEmpty ? '（無標題）' : _s(data['title']),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _s(data['message']).isEmpty ? '（無內容）' : _s(data['message']),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status, // ✅ value -> initialValue
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      labelText: '更新狀態',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'open', child: Text('open')),
                      DropdownMenuItem(
                        value: 'replied',
                        child: Text('replied'),
                      ),
                      DropdownMenuItem(value: 'closed', child: Text('closed')),
                    ],
                    onChanged: (v) => setSt(() => status = v ?? 'open'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: replyCtrl,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: '回覆內容 reply',
                      border: OutlineInputBorder(),
                      isDense: true,
                      hintText: '輸入要回覆給顧客的內容…',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '提示：儲存後會寫入 reply / replyAt / replyBy 並更新 status。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) {
      replyCtrl.dispose();
      return;
    }

    if (ok == true) {
      final text = replyCtrl.text.trim();

      await _setBusy(true, label: '儲存回覆中...');
      try {
        await _col.doc(id).set(<String, dynamic>{
          'reply': text,
          'status': status,
          'replyAt': FieldValue.serverTimestamp(),
          if ((widget.replyBy ?? '').trim().isNotEmpty)
            'replyBy': widget.replyBy!.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (!mounted) return;
        _snack('已更新回覆');
      } catch (e) {
        if (!mounted) return;
        _snack('儲存失敗：$e');
      } finally {
        await _setBusy(false);
      }
    }

    replyCtrl.dispose();
  }

  Future<void> _setStatus(String id, String status) async {
    await _setBusy(true, label: '更新狀態中...');
    try {
      await _col.doc(id).set(<String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      _snack('已更新狀態：$status');
    } catch (e) {
      if (!mounted) return;
      _snack('更新失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除回饋'),
        content: Text('確定要刪除 feedback：$id 嗎？（不可復原）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (ok != true) return;

    await _setBusy(true, label: '刪除中...');
    try {
      await _col.doc(id).delete();
      if (!mounted) return;
      if (_selectedId == id) {
        setState(() => _selectedId = null);
      }
      _snack('已刪除');
    } catch (e) {
      if (!mounted) return;
      _snack('刪除失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _exportCsv(List<_FeedbackRow> rows) async {
    if (rows.isEmpty) return;

    final headers = <String>[
      'feedbackId',
      'status',
      'type',
      'rating',
      'title',
      'message',
      'reply',
      'userName',
      'userEmail',
      'orderId',
      'productId',
      'productName',
      'createdAt',
      'replyAt',
      'replyBy',
      'updatedAt',
    ];

    final buffer = StringBuffer()..writeln(headers.join(','));

    for (final r in rows) {
      final d = r.data;
      final line = <String>[
        r.id,
        _s(d['status']),
        _s(d['type']),
        _s(d['rating']),
        _s(d['title']),
        _s(d['message']),
        _s(d['reply']),
        _s(d['userName']),
        _s(d['userEmail']),
        _s(d['orderId']),
        _s(d['productId']),
        _s(d['productName']),
        (_toDate(d['createdAt'])?.toIso8601String() ?? ''),
        (_toDate(d['replyAt'])?.toIso8601String() ?? ''),
        _s(d['replyBy']),
        (_toDate(d['updatedAt'])?.toIso8601String() ?? ''),
      ].map((e) => e.replaceAll(',', '，')).toList();

      buffer.writeln(line.join(','));
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    _snack('已複製 CSV 到剪貼簿（可貼到 Excel）');
  }

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    if (_vid.isEmpty) {
      return const Scaffold(body: Center(child: Text('vendorId 不可為空')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '顧客回饋中心',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('讀取失敗：${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final rows = snap.data!.docs
                  .map((d) => _FeedbackRow(id: d.id, data: d.data()))
                  .where(_matchLocal)
                  .toList();

              final ids = rows.map((e) => e.id).toSet();
              if (_selectedId != null && !ids.contains(_selectedId)) {
                _selectedId = null;
              }

              return Column(
                children: [
                  _Filters(
                    searchCtrl: _searchCtrl,
                    status: _status,
                    type: _type,
                    minRating: _minRating,
                    countLabel: '${rows.length} 筆',
                    onQueryChanged: (v) => setState(() => _q = v),
                    onClearQuery: () {
                      _searchCtrl.clear();
                      setState(() => _q = '');
                    },
                    onStatusChanged: (v) => setState(() => _status = v),
                    onTypeChanged: (v) => setState(() => _type = v),
                    onMinRatingChanged: (v) => setState(() => _minRating = v),
                    onExport: rows.isEmpty || _busy
                        ? null
                        : () => _exportCsv(rows),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth >= 980;

                        final list = ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = rows[i];
                            final d = r.data;

                            final status = _s(d['status']).isEmpty
                                ? 'open'
                                : _s(d['status']);
                            final type = _s(d['type']).isEmpty
                                ? 'other'
                                : _s(d['type']);
                            final rating = _toInt(d['rating']);
                            final title = _s(d['title']).isEmpty
                                ? '（無標題）'
                                : _s(d['title']);
                            final msg = _s(d['message']).isEmpty
                                ? '（無內容）'
                                : _s(d['message']);
                            final user = _s(d['userName']).isNotEmpty
                                ? _s(d['userName'])
                                : (_s(d['userEmail']).isNotEmpty
                                      ? _s(d['userEmail'])
                                      : '（匿名）');
                            final createdAt = _toDate(d['createdAt']);

                            return ListTile(
                              selected: r.id == _selectedId,
                              leading: Icon(_statusIcon(status)),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _Pill(
                                    label: status,
                                    color: _statusColor(context, status),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 4,
                                      children: [
                                        _MiniTag(label: type),
                                        if (rating != null)
                                          _MiniTag(label: '★$rating'),
                                        _MiniTag(label: user),
                                        _MiniTag(
                                          label: _fmtDateTime(createdAt),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      msg,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                tooltip: '更多',
                                onSelected: _busy
                                    ? null
                                    : (v) async {
                                        if (v == 'reply') {
                                          await _openReplyDialog(
                                            id: r.id,
                                            data: d,
                                          );
                                        } else if (v == 'open') {
                                          await _setStatus(r.id, 'open');
                                        } else if (v == 'replied') {
                                          await _setStatus(r.id, 'replied');
                                        } else if (v == 'closed') {
                                          await _setStatus(r.id, 'closed');
                                        } else if (v == 'copy_id') {
                                          await _copy(
                                            r.id,
                                            done: '已複製 feedbackId',
                                          );
                                        } else if (v == 'json') {
                                          await _copy(
                                            jsonEncode(d),
                                            done: '已複製 JSON',
                                          );
                                        } else if (v == 'delete') {
                                          await _delete(r.id);
                                        }
                                      },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'reply',
                                    child: Text('回覆/處理'),
                                  ),
                                  PopupMenuDivider(),
                                  PopupMenuItem(
                                    value: 'open',
                                    child: Text('標記 open'),
                                  ),
                                  PopupMenuItem(
                                    value: 'replied',
                                    child: Text('標記 replied'),
                                  ),
                                  PopupMenuItem(
                                    value: 'closed',
                                    child: Text('標記 closed'),
                                  ),
                                  PopupMenuDivider(),
                                  PopupMenuItem(
                                    value: 'copy_id',
                                    child: Text('複製 feedbackId'),
                                  ),
                                  PopupMenuItem(
                                    value: 'json',
                                    child: Text('複製 JSON'),
                                  ),
                                  PopupMenuDivider(),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('刪除'),
                                  ),
                                ],
                              ),
                              onTap: () {
                                setState(() => _selectedId = r.id);
                                if (!wide) {
                                  showDialog(
                                    context: context,
                                    builder: (_) => _DetailDialog(
                                      id: r.id,
                                      data: d,
                                      fmt: _fmtDateTime,
                                      toDate: _toDate,
                                      onCopy: _copy,
                                      onReply: () =>
                                          _openReplyDialog(id: r.id, data: d),
                                      onSetStatus: (s) => _setStatus(r.id, s),
                                      onDelete: () => _delete(r.id),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        );

                        if (!wide) {
                          return list;
                        }

                        final selected = _selectedId == null
                            ? null
                            : rows
                                  .where((e) => e.id == _selectedId)
                                  .firstOrNull;

                        return Row(
                          children: [
                            Expanded(flex: 3, child: list),
                            const VerticalDivider(width: 1),
                            Expanded(
                              flex: 2,
                              child: selected == null
                                  ? Center(
                                      child: Text(
                                        '請選擇一筆回饋查看詳情',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    )
                                  : _DetailPanel(
                                      id: selected.id,
                                      data: selected.data,
                                      fmt: _fmtDateTime,
                                      toDate: _toDate,
                                      onCopy: _copy,
                                      onReply: () => _openReplyDialog(
                                        id: selected.id,
                                        data: selected.data,
                                      ),
                                      onSetStatus: (s) =>
                                          _setStatus(selected.id, s),
                                      onDelete: () => _delete(selected.id),
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
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
// Models / Extensions
// ------------------------------------------------------------
class _FeedbackRow {
  final String id;
  final Map<String, dynamic> data;
  _FeedbackRow({required this.id, required this.data});
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ------------------------------------------------------------
// Filters
// ------------------------------------------------------------
class _Filters extends StatelessWidget {
  const _Filters({
    required this.searchCtrl,
    required this.status,
    required this.type,
    required this.minRating,
    required this.countLabel,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onStatusChanged,
    required this.onTypeChanged,
    required this.onMinRatingChanged,
    required this.onExport,
  });

  final TextEditingController searchCtrl;

  final String? status;
  final String? type;
  final int? minRating;

  final String countLabel;

  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;

  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<int?> onMinRatingChanged;

  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final search = TextField(
      controller: searchCtrl,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        hintText: '搜尋：標題/內容/商品/顧客/訂單/回覆/狀態…',
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

    final ddStatus = DropdownButtonFormField<String?>(
      initialValue: status,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        labelText: '狀態',
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('全部')),
        DropdownMenuItem(value: 'open', child: Text('open')),
        DropdownMenuItem(value: 'replied', child: Text('replied')),
        DropdownMenuItem(value: 'closed', child: Text('closed')),
      ],
      onChanged: onStatusChanged,
    );

    final ddType = DropdownButtonFormField<String?>(
      initialValue: type,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        labelText: '類型',
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('全部')),
        DropdownMenuItem(value: 'review', child: Text('review')),
        DropdownMenuItem(value: 'question', child: Text('question')),
        DropdownMenuItem(value: 'issue', child: Text('issue')),
        DropdownMenuItem(value: 'other', child: Text('other')),
      ],
      onChanged: onTypeChanged,
    );

    final ddMinRating = DropdownButtonFormField<int?>(
      initialValue: minRating,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        labelText: '最低評分',
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('全部')),
        DropdownMenuItem(value: 5, child: Text('★5 以上')),
        DropdownMenuItem(value: 4, child: Text('★4 以上')),
        DropdownMenuItem(value: 3, child: Text('★3 以上')),
        DropdownMenuItem(value: 2, child: Text('★2 以上')),
        DropdownMenuItem(value: 1, child: Text('★1 以上')),
      ],
      onChanged: onMinRatingChanged,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 980;

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: ddStatus),
                    const SizedBox(width: 10),
                    Expanded(child: ddType),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: ddMinRating),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: onExport,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('匯出CSV'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '共 $countLabel',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: search),
              const SizedBox(width: 10),
              SizedBox(width: 180, child: ddStatus),
              const SizedBox(width: 10),
              SizedBox(width: 180, child: ddType),
              const SizedBox(width: 10),
              SizedBox(width: 180, child: ddMinRating),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_outlined),
                label: const Text('匯出CSV'),
              ),
              const SizedBox(width: 10),
              Text(
                '共 $countLabel',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// Detail Panel / Dialog
// ------------------------------------------------------------
class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.id,
    required this.data,
    required this.fmt,
    required this.toDate,
    required this.onCopy,
    required this.onReply,
    required this.onSetStatus,
    required this.onDelete,
  });

  final String id;
  final Map<String, dynamic> data;

  final String Function(DateTime?) fmt;
  final DateTime? Function(dynamic) toDate;

  final Future<void> Function(String text, {String done}) onCopy;

  final VoidCallback onReply;
  final Future<void> Function(String status) onSetStatus;
  final VoidCallback onDelete;

  String _s(dynamic v) => (v ?? '').toString().trim();
  int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final status = _s(data['status']).isEmpty ? 'open' : _s(data['status']);
    final type = _s(data['type']).isEmpty ? 'other' : _s(data['type']);
    final rating = _toInt(data['rating']);
    final title = _s(data['title']).isEmpty ? '（無標題）' : _s(data['title']);
    final message = _s(data['message']).isEmpty ? '（無內容）' : _s(data['message']);
    final reply = _s(data['reply']);
    final userName = _s(data['userName']);
    final userEmail = _s(data['userEmail']);
    final productName = _s(data['productName']);
    final orderId = _s(data['orderId']);

    final createdAt = toDate(data['createdAt']);
    final replyAt = toDate(data['replyAt']);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(label: status, color: _statusColor(context, status)),
              _MiniTag(label: type),
              if (rating != null) _MiniTag(label: '★$rating'),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'feedbackId',
            value: id,
            onCopy: () => onCopy(id, done: '已複製 feedbackId'),
          ),
          const SizedBox(height: 6),
          _InfoRow(
            label: 'user',
            value: userName.isNotEmpty
                ? userName
                : (userEmail.isNotEmpty ? userEmail : '（匿名）'),
          ),
          const SizedBox(height: 6),
          _InfoRow(label: 'product', value: productName),
          const SizedBox(height: 6),
          _InfoRow(label: 'orderId', value: orderId),
          const SizedBox(height: 6),
          _InfoRow(label: 'createdAt', value: fmt(createdAt)),
          const SizedBox(height: 6),
          _InfoRow(label: 'replyAt', value: fmt(replyAt)),
          const Divider(height: 24),
          Text(
            '內容',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          _box(context, message),
          const SizedBox(height: 12),
          Text(
            '回覆',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          _box(context, reply.isEmpty ? '（尚未回覆）' : reply),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply_outlined),
                  label: const Text('回覆/處理'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      onSetStatus(status == 'closed' ? 'open' : 'closed'),
                  icon: Icon(
                    status == 'closed'
                        ? Icons.lock_open_outlined
                        : Icons.lock_outline,
                  ),
                  label: Text(status == 'closed' ? '重新開啟' : '關閉'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => onCopy(jsonEncode(data), done: '已複製 JSON'),
                icon: const Icon(Icons.code),
                label: const Text('複製 JSON'),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('刪除'),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '提示：回覆後建議將 status 設為 replied 或 closed，以利追蹤。',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _box(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
      ),
      child: Text(text),
    );
  }
}

class _DetailDialog extends StatelessWidget {
  const _DetailDialog({
    required this.id,
    required this.data,
    required this.fmt,
    required this.toDate,
    required this.onCopy,
    required this.onReply,
    required this.onSetStatus,
    required this.onDelete,
  });

  final String id;
  final Map<String, dynamic> data;

  final String Function(DateTime?) fmt;
  final DateTime? Function(dynamic) toDate;

  final Future<void> Function(String text, {String done}) onCopy;

  final VoidCallback onReply;
  final Future<void> Function(String status) onSetStatus;
  final VoidCallback onDelete;

  String _s(dynamic v) => (v ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final title = _s(data['title']).isEmpty ? '（無標題）' : _s(data['title']);
    final status = _s(data['status']).isEmpty ? 'open' : _s(data['status']);

    return Dialog(
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
                  _Pill(label: status, color: _statusColor(context, status)),
                  IconButton(
                    tooltip: '複製 feedbackId',
                    onPressed: () => onCopy(id, done: '已複製 feedbackId'),
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _s(data['message']).isEmpty ? '（無內容）' : _s(data['message']),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onReply();
                    },
                    icon: const Icon(Icons.reply_outlined),
                    label: const Text('回覆/處理'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onSetStatus(status == 'closed' ? 'open' : 'closed');
                    },
                    icon: Icon(
                      status == 'closed'
                          ? Icons.lock_open_outlined
                          : Icons.lock_outline,
                    ),
                    label: Text(status == 'closed' ? '重新開啟' : '關閉'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onDelete();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('刪除'),
                  ),
                ],
              ),
            ],
          ),
        ),
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

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.onCopy});
  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
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
        if (onCopy != null)
          IconButton(
            tooltip: '複製',
            onPressed: onCopy,
            icon: const Icon(Icons.copy, size: 18),
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

// ------------------------------------------------------------
// Helpers
// ------------------------------------------------------------
Widget _kv(BuildContext context, String k, String v, {VoidCallback? copy}) {
  final cs = Theme.of(context).colorScheme;
  return Row(
    children: [
      SizedBox(
        width: 90,
        child: Text(
          k,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
      ),
      Expanded(
        child: Text(
          v.isEmpty ? '-' : v,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      if (copy != null)
        IconButton(
          tooltip: '複製',
          onPressed: copy,
          icon: const Icon(Icons.copy, size: 18),
        ),
    ],
  );
}

Color _statusColor(BuildContext context, String status) {
  final s = status.trim().toLowerCase();
  final cs = Theme.of(context).colorScheme;
  switch (s) {
    case 'open':
      return cs.primary;
    case 'replied':
      return cs.tertiary;
    case 'closed':
      return cs.error;
    default:
      return cs.primary;
  }
}

IconData _statusIcon(String status) {
  final s = status.trim().toLowerCase();
  switch (s) {
    case 'open':
      return Icons.mark_email_unread_outlined;
    case 'replied':
      return Icons.mark_email_read_outlined;
    case 'closed':
      return Icons.check_circle_outline;
    default:
      return Icons.feedback_outlined;
  }
}
