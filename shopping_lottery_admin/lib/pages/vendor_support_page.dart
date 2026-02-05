// lib/pages/vendor_support_page.dart
//
// ✅ VendorSupportPage（完整版｜可編譯｜Vendor Only｜客服/支援票單｜即時對話(messages 子集合)｜搜尋｜狀態篩選｜建立票單｜回覆｜結案｜匯出CSV(複製)｜Web+App）
//
// 核心原則：
// - 只顯示 vendorId == 自己 vendorId 的票單
// - 票單與對話皆為 Firestore 即時監聽
// - 與主後台（同集合/同 doc）可連動（管理員可在主後台查看/回覆）
//
// Firestore 建議：support_tickets/{ticketId}
//   - vendorId: String
//   - subject: String
//   - description: String
//   - status: String              // open / processing / resolved
//   - priority: String            // low / normal / high (選用)
//   - createdByUid: String (選用)
//   - createdByName: String (選用)
//   - createdByEmail: String (選用)
//   - lastMessage: String (選用)
//   - lastMessageAt: Timestamp (選用)
//   - createdAt: Timestamp
//   - updatedAt: Timestamp
//   - resolvedAt: Timestamp (選用)
//   - attachments: List<String> (選用)   // 圖片/檔案 URL
//
// 子集合：support_tickets/{ticketId}/messages/{messageId}
//   - vendorId: String
//   - senderRole: String          // vendor/admin/system
//   - senderName: String
//   - text: String
//   - createdAt: Timestamp
//
// 依賴：cloud_firestore, flutter/material, flutter/services
//
// 注意：
// - where(vendorId) + where(status) + orderBy(createdAt) 可能需要複合索引。
// - 本頁未強制依賴登入服務；你可在外層傳入 createdByUid/Name/Email（或自行改為從 FirebaseAuth 取）。
// - 匯出CSV採「複製到剪貼簿」避免依賴額外 utils。

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VendorSupportPage extends StatefulWidget {
  const VendorSupportPage({
    super.key,
    required this.vendorId,
    this.collection = 'support_tickets',
    this.createdByUid,
    this.createdByName,
    this.createdByEmail,
  });

  final String vendorId;
  final String collection;

  /// 選用：建立票單/留言時帶入（若你在外層已拿到 FirebaseAuth uid/email）
  final String? createdByUid;
  final String? createdByName;
  final String? createdByEmail;

  @override
  State<VendorSupportPage> createState() => _VendorSupportPageState();
}

class _VendorSupportPageState extends State<VendorSupportPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _q = '';

  String? _status; // null=全部, open/processing/resolved
  String? _selectedTicketId;

  bool _busy = false;
  String _busyLabel = '';

  final Set<String> _selectedIds = <String>{};

  String get _vid => widget.vendorId.trim();
  CollectionReference<Map<String, dynamic>> get _tcol => _db.collection(widget.collection);

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
  // Stream
  // -------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _streamTickets() {
    Query<Map<String, dynamic>> q = _tcol
        .where('vendorId', isEqualTo: _vid)
        .orderBy('createdAt', descending: true)
        .limit(800);

    if (_status != null && _status!.trim().isNotEmpty) {
      q = _tcol
          .where('vendorId', isEqualTo: _vid)
          .where('status', isEqualTo: _status)
          .orderBy('createdAt', descending: true)
          .limit(800);
    }

    return q.snapshots();
  }

  bool _matchLocal(_TicketRow r) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;

    final d = r.data;
    final id = r.id.toLowerCase();
    final subject = _s(d['subject']).toLowerCase();
    final desc = _s(d['description']).toLowerCase();
    final last = _s(d['lastMessage']).toLowerCase();
    final priority = _s(d['priority']).toLowerCase();

    return id.contains(q) || subject.contains(q) || desc.contains(q) || last.contains(q) || priority.contains(q);
  }

  // -------------------------
  // Create / Update Ticket
  // -------------------------
  Future<void> _openCreateTicketDialog() async {
    final subjectCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final attachCtrl = TextEditingController(); // 以逗號分隔URL
    String priority = 'normal';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('新增支援票單'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: subjectCtrl,
                    decoration: const InputDecoration(
                      labelText: '主旨 subject',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '描述 description',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: priority,
                    decoration: const InputDecoration(
                      labelText: '優先度 priority',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('low')),
                      DropdownMenuItem(value: 'normal', child: Text('normal')),
                      DropdownMenuItem(value: 'high', child: Text('high')),
                    ],
                    onChanged: (v) => setSt(() => priority = v ?? 'normal'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: attachCtrl,
                    decoration: const InputDecoration(
                      labelText: '附件URL（選用，逗號分隔）',
                      border: OutlineInputBorder(),
                      isDense: true,
                      hintText: 'https://... , https://...',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '提示：建立後可在票單內留言；主後台也能看到同一張票單並回覆。',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('建立')),
          ],
        ),
      ),
    );

    if (ok == true) {
      final subject = subjectCtrl.text.trim();
      final desc = descCtrl.text.trim();
      if (subject.isEmpty) {
        _snack('主旨不可為空');
        subjectCtrl.dispose();
        descCtrl.dispose();
        attachCtrl.dispose();
        return;
      }

      final attachments = attachCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await _setBusy(true, label: '建立票單中...');
      try {
        final ref = _tcol.doc();
        final now = FieldValue.serverTimestamp();

        await ref.set(<String, dynamic>{
          'vendorId': _vid,
          'subject': subject,
          'description': desc,
          'status': 'open',
          'priority': priority,
          'attachments': attachments,
          'createdByUid': _s(widget.createdByUid),
          'createdByName': _s(widget.createdByName),
          'createdByEmail': _s(widget.createdByEmail),
          'lastMessage': desc.isNotEmpty ? desc : subject,
          'lastMessageAt': now,
          'createdAt': now,
          'updatedAt': now,
        }, SetOptions(merge: true));

        // 建立第一則 system/vendor 訊息（可選，但很有用）
        await ref.collection('messages').add(<String, dynamic>{
          'vendorId': _vid,
          'senderRole': 'vendor',
          'senderName': _s(widget.createdByName).isEmpty ? 'Vendor' : _s(widget.createdByName),
          'text': desc.isNotEmpty ? desc : subject,
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() => _selectedTicketId = ref.id);
        _snack('已建立票單：${ref.id}');
      } catch (e) {
        _snack('建立失敗：$e');
      } finally {
        await _setBusy(false);
      }
    }

    subjectCtrl.dispose();
    descCtrl.dispose();
    attachCtrl.dispose();
  }

  Future<void> _updateTicketStatus(String ticketId, String status) async {
    await _setBusy(true, label: '更新狀態中...');
    try {
      await _tcol.doc(ticketId).set(
        <String, dynamic>{
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
          if (status == 'resolved') 'resolvedAt': FieldValue.serverTimestamp() else 'resolvedAt': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
      _snack('已更新狀態：$status');
    } catch (e) {
      _snack('更新失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _deleteTicket(String ticketId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除票單'),
        content: Text('確定要刪除 ticket：$ticketId 嗎？（不可復原）\n注意：子集合 messages 不會自動刪除，若要完整刪除請用雲端函式或後端批次處理。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok != true) return;

    await _setBusy(true, label: '刪除中...');
    try {
      await _tcol.doc(ticketId).delete();
      if (_selectedTicketId == ticketId) {
        setState(() => _selectedTicketId = null);
      }
      _snack('已刪除：$ticketId');
    } catch (e) {
      _snack('刪除失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  // -------------------------
  // Messages
  // -------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _streamMessages(String ticketId) {
    return _tcol
        .doc(ticketId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(500)
        .snapshots();
  }

  Future<void> _sendMessage({
    required String ticketId,
    required String text,
  }) async {
    final t = text.trim();
    if (t.isEmpty) return;

    await _setBusy(true, label: '送出留言中...');
    try {
      final msg = <String, dynamic>{
        'vendorId': _vid,
        'senderRole': 'vendor',
        'senderName': _s(widget.createdByName).isEmpty ? 'Vendor' : _s(widget.createdByName),
        'text': t,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final ref = _tcol.doc(ticketId);

      await ref.collection('messages').add(msg);

      await ref.set(
        <String, dynamic>{
          'lastMessage': t,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          // 若票單已 resolved，廠商回覆則自動拉回 processing（可依需求調整）
          'status': 'processing',
        },
        SetOptions(merge: true),
      );

      _snack('已送出');
    } catch (e) {
      _snack('送出失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  // -------------------------
  // Batch / Export
  // -------------------------
  Future<void> _batchUpdateStatus(List<_TicketRow> rows, String status) async {
    if (_selectedIds.isEmpty) {
      _snack('請先勾選票單');
      return;
    }
    final targets = rows.where((r) => _selectedIds.contains(r.id)).toList();
    if (targets.isEmpty) {
      _snack('選取清單為空');
      return;
    }

    await _setBusy(true, label: '批次更新中...');
    try {
      final batch = _db.batch();
      for (final r in targets) {
        batch.set(
          _tcol.doc(r.id),
          <String, dynamic>{
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
            if (status == 'resolved') 'resolvedAt': FieldValue.serverTimestamp() else 'resolvedAt': FieldValue.delete(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      _snack('已批次更新：$status（${targets.length}）');
    } catch (e) {
      _snack('批次失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _exportCsv(List<_TicketRow> rows) async {
    if (rows.isEmpty) return;

    final headers = <String>[
      'ticketId',
      'subject',
      'status',
      'priority',
      'createdAt',
      'updatedAt',
      'lastMessageAt',
      'lastMessage',
    ];

    final buffer = StringBuffer()..writeln(headers.join(','));

    for (final r in rows) {
      final d = r.data;
      final line = <String>[
        r.id,
        _s(d['subject']),
        _s(d['status']),
        _s(d['priority']),
        (_toDate(d['createdAt'])?.toIso8601String() ?? ''),
        (_toDate(d['updatedAt'])?.toIso8601String() ?? ''),
        (_toDate(d['lastMessageAt'])?.toIso8601String() ?? ''),
        _s(d['lastMessage']),
      ].map((e) => e.replaceAll(',', '，')).toList();

      buffer.writeln(line.join(','));
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    _snack('已複製 CSV 到剪貼簿（可貼到 Excel）');
  }

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    if (_vid.isEmpty) return const Center(child: Text('vendorId 不可為空'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('廠商支援中心', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '新增票單',
            onPressed: _busy ? null : _openCreateTicketDialog,
            icon: const Icon(Icons.add_box_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _streamTickets(),
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('讀取失敗：${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              final rows = snap.data!.docs
                  .map((d) => _TicketRow(id: d.id, data: d.data()))
                  .where(_matchLocal)
                  .toList();

              // 清除不存在的選取
              final ids = rows.map((e) => e.id).toSet();
              _selectedIds.removeWhere((id) => !ids.contains(id));

              // 若選取票單已被刪除
              if (_selectedTicketId != null && !ids.contains(_selectedTicketId)) {
                _selectedTicketId = null;
              }

              return Column(
                children: [
                  _TicketFilters(
                    searchCtrl: _searchCtrl,
                    status: _status,
                    countLabel: '${rows.length} 筆',
                    onQueryChanged: (v) => setState(() => _q = v),
                    onClearQuery: () {
                      _searchCtrl.clear();
                      setState(() => _q = '');
                    },
                    onStatusChanged: (v) => setState(() => _status = v),
                    onAdd: _openCreateTicketDialog,
                    onExport: rows.isEmpty || _busy ? null : () => _exportCsv(rows),
                  ),
                  const Divider(height: 1),
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
                    onMarkOpen: (_busy || _selectedIds.isEmpty) ? null : () => _batchUpdateStatus(rows, 'open'),
                    onMarkProcessing: (_busy || _selectedIds.isEmpty) ? null : () => _batchUpdateStatus(rows, 'processing'),
                    onMarkResolved: (_busy || _selectedIds.isEmpty) ? null : () => _batchUpdateStatus(rows, 'resolved'),
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

                            final subject = _s(d['subject']).isEmpty ? '（無主旨）' : _s(d['subject']);
                            final status = _s(d['status']).isEmpty ? 'open' : _s(d['status']);
                            final priority = _s(d['priority']);
                            final last = _s(d['lastMessage']);
                            final lastAt = _toDate(d['lastMessageAt'] ?? d['updatedAt'] ?? d['createdAt']);
                            final createdAt = _toDate(d['createdAt']);

                            final selected = _selectedIds.contains(r.id);

                            return ListTile(
                              selected: r.id == _selectedTicketId,
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
                                      subject,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _Pill(label: status, color: _statusColor(context, status)),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (last.isNotEmpty)
                                      Text(
                                        last,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 4,
                                      children: [
                                        Text('ID：${r.id}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                        if (priority.isNotEmpty)
                                          Text('priority：$priority', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                        Text('建立：${_fmt(createdAt)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                        Text('最近：${_fmt(lastAt)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
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
                                        if (v == 'copy') {
                                          await _copy(r.id, done: '已複製 ticketId');
                                        } else if (v == 'json') {
                                          await _copy(jsonEncode(d), done: '已複製 JSON');
                                        } else if (v == 'open') {
                                          await _updateTicketStatus(r.id, 'open');
                                        } else if (v == 'processing') {
                                          await _updateTicketStatus(r.id, 'processing');
                                        } else if (v == 'resolved') {
                                          await _updateTicketStatus(r.id, 'resolved');
                                        } else if (v == 'delete') {
                                          await _deleteTicket(r.id);
                                        }
                                      },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'copy', child: Text('複製 ticketId')),
                                  PopupMenuItem(value: 'json', child: Text('複製 JSON')),
                                  PopupMenuDivider(),
                                  PopupMenuItem(value: 'open', child: Text('設為 open')),
                                  PopupMenuItem(value: 'processing', child: Text('設為 processing')),
                                  PopupMenuItem(value: 'resolved', child: Text('設為 resolved')),
                                  PopupMenuDivider(),
                                  PopupMenuItem(value: 'delete', child: Text('刪除票單')),
                                ],
                              ),
                              onTap: () {
                                setState(() => _selectedTicketId = r.id);
                                if (!wide) {
                                  showDialog(
                                    context: context,
                                    builder: (_) => _TicketDialog(
                                      ticketId: r.id,
                                      ticket: d,
                                      fmt: _fmt,
                                      toDate: _toDate,
                                      onCopy: _copy,
                                      onUpdateStatus: (st) => _updateTicketStatus(r.id, st),
                                      onDelete: () => _deleteTicket(r.id),
                                      streamMessages: _streamMessages,
                                      onSend: (text) => _sendMessage(ticketId: r.id, text: text),
                                      busy: _busy,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        );

                        if (!wide) return list;

                        final selected = _selectedTicketId == null
                            ? null
                            : rows.where((e) => e.id == _selectedTicketId).cast<_TicketRow?>().firstOrNull;

                        return Row(
                          children: [
                            Expanded(flex: 3, child: list),
                            const VerticalDivider(width: 1),
                            Expanded(
                              flex: 4,
                              child: selected == null
                                  ? Center(
                                      child: Text(
                                        '請選擇票單查看對話',
                                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      ),
                                    )
                                  : _TicketDetailPanel(
                                      ticketId: selected.id,
                                      ticket: selected.data,
                                      fmt: _fmt,
                                      toDate: _toDate,
                                      onCopy: _copy,
                                      onUpdateStatus: (st) => _updateTicketStatus(selected.id, st),
                                      onDelete: () => _deleteTicket(selected.id),
                                      streamMessages: _streamMessages,
                                      onSend: (text) => _sendMessage(ticketId: selected.id, text: text),
                                      busy: _busy,
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
              child: _BusyBar(label: _busyLabel.isEmpty ? '處理中...' : _busyLabel),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Models / Extensions
// ------------------------------------------------------------
class _TicketRow {
  final String id;
  final Map<String, dynamic> data;
  _TicketRow({required this.id, required this.data});
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ------------------------------------------------------------
// UI: Filters / Batch
// ------------------------------------------------------------
class _TicketFilters extends StatelessWidget {
  const _TicketFilters({
    required this.searchCtrl,
    required this.status,
    required this.countLabel,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onStatusChanged,
    required this.onAdd,
    required this.onExport,
  });

  final TextEditingController searchCtrl;
  final String? status;
  final String countLabel;

  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<String?> onStatusChanged;

  final VoidCallback onAdd;
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
        hintText: '搜尋：主旨 / 描述 / lastMessage / ticketId / priority',
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

    final dd = DropdownButtonFormField<String?>(
      value: status,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        labelText: '狀態',
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('全部')),
        DropdownMenuItem(value: 'open', child: Text('open')),
        DropdownMenuItem(value: 'processing', child: Text('processing')),
        DropdownMenuItem(value: 'resolved', child: Text('resolved')),
      ],
      onChanged: onStatusChanged,
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
                    Expanded(child: dd),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('新增'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: onExport,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('匯出CSV'),
                    ),
                    const SizedBox(width: 10),
                    Text('共 $countLabel', style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: search),
              const SizedBox(width: 10),
              SizedBox(width: 220, child: dd),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_outlined),
                label: const Text('匯出CSV'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('新增票單'),
              ),
              const SizedBox(width: 10),
              Text('共 $countLabel', style: TextStyle(color: cs.onSurfaceVariant)),
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
    required this.onMarkOpen,
    required this.onMarkProcessing,
    required this.onMarkResolved,
  });

  final int count;
  final int selectedCount;

  final VoidCallback? onSelectAll;
  final VoidCallback? onMarkOpen;
  final VoidCallback? onMarkProcessing;
  final VoidCallback? onMarkResolved;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Text('共 $count 筆', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Text('已選 $selectedCount 筆', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onSelectAll,
            icon: const Icon(Icons.select_all),
            label: const Text('全選/取消'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onMarkOpen,
            icon: const Icon(Icons.inbox_outlined),
            label: const Text('批次 open'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onMarkProcessing,
            icon: const Icon(Icons.cached_outlined),
            label: const Text('批次 processing'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onMarkResolved,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('批次 resolved'),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// UI: Ticket detail (Panel/Dialog) + Messages
// ------------------------------------------------------------
class _TicketDetailPanel extends StatelessWidget {
  const _TicketDetailPanel({
    required this.ticketId,
    required this.ticket,
    required this.fmt,
    required this.toDate,
    required this.onCopy,
    required this.onUpdateStatus,
    required this.onDelete,
    required this.streamMessages,
    required this.onSend,
    required this.busy,
  });

  final String ticketId;
  final Map<String, dynamic> ticket;

  final String Function(DateTime?) fmt;
  final DateTime? Function(dynamic) toDate;

  final Future<void> Function(String text, {String done}) onCopy;

  final Future<void> Function(String status) onUpdateStatus;
  final Future<void> Function() onDelete;

  final Stream<QuerySnapshot<Map<String, dynamic>>> Function(String ticketId) streamMessages;
  final Future<void> Function(String text) onSend;

  final bool busy;

  String _s(dynamic v) => (v ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final subject = _s(ticket['subject']).isEmpty ? '（無主旨）' : _s(ticket['subject']);
    final status = _s(ticket['status']).isEmpty ? 'open' : _s(ticket['status']);
    final priority = _s(ticket['priority']);
    final createdAt = toDate(ticket['createdAt']);
    final updatedAt = toDate(ticket['updatedAt']);
    final lastAt = toDate(ticket['lastMessageAt']);
    final attachments = (ticket['attachments'] is List)
        ? (ticket['attachments'] as List).map((e) => _s(e)).where((e) => e.isNotEmpty).toList()
        : <String>[];

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(subject, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
              _Pill(label: status, color: _statusColor(context, status)),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '複製 ticketId',
                onPressed: () => onCopy(ticketId, done: '已複製 ticketId'),
                icon: const Icon(Icons.copy, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _InfoChip(label: 'priority', value: priority.isEmpty ? 'normal' : priority),
              _InfoChip(label: 'created', value: fmt(createdAt)),
              _InfoChip(label: 'updated', value: fmt(updatedAt)),
              if (lastAt != null) _InfoChip(label: 'last', value: fmt(lastAt)),
            ],
          ),
          const SizedBox(height: 10),
          if (attachments.isNotEmpty) ...[
            Text('附件', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: attachments
                  .map(
                    (u) => OutlinedButton.icon(
                      onPressed: () => onCopy(u, done: '已複製附件URL'),
                      icon: const Icon(Icons.link),
                      label: Text(u, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => onUpdateStatus('open'),
                  icon: const Icon(Icons.inbox_outlined),
                  label: const Text('open'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => onUpdateStatus('processing'),
                  icon: const Icon(Icons.cached_outlined),
                  label: const Text('processing'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : () => onUpdateStatus('resolved'),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('resolved'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => onCopy(jsonEncode(ticket), done: '已複製 ticket JSON'),
                icon: const Icon(Icons.code),
                label: const Text('複製 JSON'),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('刪除票單'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('對話', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Expanded(
            child: Card(
              elevation: 0,
              child: _MessagesView(
                stream: streamMessages(ticketId),
                onSend: onSend,
                busy: busy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketDialog extends StatelessWidget {
  const _TicketDialog({
    required this.ticketId,
    required this.ticket,
    required this.fmt,
    required this.toDate,
    required this.onCopy,
    required this.onUpdateStatus,
    required this.onDelete,
    required this.streamMessages,
    required this.onSend,
    required this.busy,
  });

  final String ticketId;
  final Map<String, dynamic> ticket;

  final String Function(DateTime?) fmt;
  final DateTime? Function(dynamic) toDate;

  final Future<void> Function(String text, {String done}) onCopy;

  final Future<void> Function(String status) onUpdateStatus;
  final Future<void> Function() onDelete;

  final Stream<QuerySnapshot<Map<String, dynamic>>> Function(String ticketId) streamMessages;
  final Future<void> Function(String text) onSend;

  final bool busy;

  String _s(dynamic v) => (v ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final subject = _s(ticket['subject']).isEmpty ? '（無主旨）' : _s(ticket['subject']);
    final status = _s(ticket['status']).isEmpty ? 'open' : _s(ticket['status']);

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: SizedBox(
        width: 720,
        height: 720,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text(subject, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                  _Pill(label: status, color: _statusColor(context, status)),
                  IconButton(
                    tooltip: '複製 ticketId',
                    onPressed: () => onCopy(ticketId, done: '已複製 ticketId'),
                    icon: const Icon(Icons.copy),
                  ),
                  IconButton(
                    tooltip: '關閉',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: _TicketDetailPanel(
                  ticketId: ticketId,
                  ticket: ticket,
                  fmt: fmt,
                  toDate: toDate,
                  onCopy: onCopy,
                  onUpdateStatus: onUpdateStatus,
                  onDelete: () async {
                    Navigator.pop(context);
                    await onDelete();
                  },
                  streamMessages: streamMessages,
                  onSend: onSend,
                  busy: busy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagesView extends StatefulWidget {
  const _MessagesView({
    required this.stream,
    required this.onSend,
    required this.busy,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final Future<void> Function(String text) onSend;
  final bool busy;

  @override
  State<_MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<_MessagesView> {
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.stream,
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('讀取 messages 失敗：${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Center(child: Text('尚無對話', style: TextStyle(color: cs.onSurfaceVariant)));
              }

              _scrollToBottom();

              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(10),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data();
                  final role = (d['senderRole'] ?? 'vendor').toString();
                  final name = (d['senderName'] ?? role).toString();
                  final text = (d['text'] ?? '').toString();
                  final createdAt = d['createdAt'];

                  final isVendor = role == 'vendor';
                  final bubbleColor = isVendor ? cs.primary.withOpacity(0.10) : cs.surfaceContainerHighest.withOpacity(0.35);
                  final border = isVendor ? cs.primary.withOpacity(0.25) : cs.outline.withOpacity(0.18);

                  return Align(
                    alignment: isVendor ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 520),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$name · $role',
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(text),
                          const SizedBox(height: 6),
                          Text(
                            _fmtTime(createdAt),
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  enabled: !widget.busy,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    hintText: '輸入訊息...',
                  ),
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) async {
                    final t = _msgCtrl.text.trim();
                    if (t.isEmpty) return;
                    _msgCtrl.clear();
                    await widget.onSend(t);
                  },
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: widget.busy
                    ? null
                    : () async {
                        final t = _msgCtrl.text.trim();
                        if (t.isEmpty) return;
                        _msgCtrl.clear();
                        await widget.onSend(t);
                      },
                icon: const Icon(Icons.send),
                label: const Text('送出'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtTime(dynamic v) {
    DateTime? d;
    if (v is Timestamp) d = v.toDate();
    if (v is DateTime) d = v;
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline.withOpacity(0.18)),
      ),
      child: Text(
        '$label：${value.isEmpty ? '-' : value}',
        style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800, fontSize: 12),
      ),
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
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(BuildContext context, String status) {
  final s = status.trim().toLowerCase();
  final cs = Theme.of(context).colorScheme;
  switch (s) {
    case 'open':
      return cs.primary;
    case 'processing':
      return cs.tertiary;
    case 'resolved':
      return Colors.green;
    default:
      return cs.primary;
  }
}
