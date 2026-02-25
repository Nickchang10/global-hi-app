// lib/pages/admin/internal/admin_approvals_page.dart
//
// ✅ AdminApprovalsPage（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// Firestore collection: approvals
//
// 功能：
// ✅ 列表（依 createdAt desc）
// ✅ 搜尋（前端 filter：title/summary/type/status/requester）
// ✅ 狀態操作：approve / reject / close / reopen（寫回 status + resolver + timestamps）
// ✅ 快速篩選：All / Pending / Approved / Rejected / Closed
//
// 欄位建議：
// title        String
// summary      String
// type         String (e.g. vendor_join / refund / content / other)
// status       String (pending|approved|rejected|closed)
// requesterUid String (optional)
// requesterName String (optional)
// payload      Map (optional)
// createdAt    Timestamp
// updatedAt    Timestamp
// resolvedAt   Timestamp (optional)
// resolverUid  String (optional)
// resolverName String (optional)
// note         String (optional)   // 審核備註
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminApprovalsPage extends StatefulWidget {
  const AdminApprovalsPage({super.key});

  @override
  State<AdminApprovalsPage> createState() => _AdminApprovalsPageState();
}

class _AdminApprovalsPageState extends State<AdminApprovalsPage> {
  static const _colName = 'approvals';

  final _searchCtrl = TextEditingController();
  String _keyword = '';

  String _filter = 'all'; // all/pending/approved/rejected/closed

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(_colName);

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final v = _searchCtrl.text.trim();
      if (v == _keyword) return;
      setState(() => _keyword = v);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _query() {
    // ✅ 避免複合索引：只 orderBy createdAt，status 篩選走前端
    return _col.orderBy('createdAt', descending: true).limit(400);
  }

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  String _fmtTs(dynamic ts) {
    try {
      DateTime? dt;
      if (ts is Timestamp) dt = ts.toDate();
      if (ts is DateTime) dt = ts;
      if (dt == null) return '';
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$y-$m-$d $hh:$mm';
    } catch (_) {
      return '';
    }
  }

  bool _match(Map<String, dynamic> data) {
    // 狀態 filter
    final status = _s(data['status'], 'pending').trim().toLowerCase();
    if (_filter != 'all' && status != _filter) return false;

    // keyword filter
    final k = _keyword.trim().toLowerCase();
    if (k.isEmpty) return true;

    final title = _s(data['title']).toLowerCase();
    final summary = _s(data['summary']).toLowerCase();
    final type = _s(data['type']).toLowerCase();
    final requester = _s(data['requesterName']).toLowerCase();
    final requesterUid = _s(data['requesterUid']).toLowerCase();

    return title.contains(k) ||
        summary.contains(k) ||
        type.contains(k) ||
        requester.contains(k) ||
        requesterUid.contains(k) ||
        status.contains(k);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'closed':
        return Colors.blueGrey;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return '已通過';
      case 'rejected':
        return '已拒絕';
      case 'closed':
        return '已結案';
      default:
        return '待審核';
    }
  }

  Future<void> _updateStatus(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String nextStatus,
    String? note,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    try {
      await doc.reference.update({
        'status': nextStatus,
        'note': note,
        'updatedAt': FieldValue.serverTimestamp(),
        'resolvedAt': (nextStatus == 'pending')
            ? null
            : FieldValue.serverTimestamp(),
        'resolverUid': user?.uid,
        'resolverName': user?.displayName ?? user?.email,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已更新狀態：${_statusLabel(nextStatus)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  Future<String?> _askNote({required String title}) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '可填寫審核備註（選填）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定'),
          ),
        ],
      ),
    );

    if (ok != true) return null;
    return ctrl.text.trim();
  }

  void _openDetail(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};

    final title = _s(d['title'], '(未命名)');
    final summary = _s(d['summary'], '');
    final type = _s(d['type'], '');
    final status = _s(d['status'], 'pending').toLowerCase();

    final requesterName = _s(d['requesterName'], '');
    final requesterUid = _s(d['requesterUid'], '');
    final createdAt = _fmtTs(d['createdAt']);
    final updatedAt = _fmtTs(d['updatedAt']);
    final resolvedAt = _fmtTs(d['resolvedAt']);
    final resolverName = _s(d['resolverName'], '');
    final note = _s(d['note'], '');

    showModalBottomSheet(
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
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
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
                const SizedBox(height: 10),
                _kv('ID', doc.id),
                if (type.isNotEmpty) _kv('Type', type),
                _kv('狀態', _statusLabel(status)),
                if (summary.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '摘要',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(summary),
                ],
                const SizedBox(height: 10),
                _kv(
                  'Requester',
                  [
                    if (requesterName.isNotEmpty) requesterName,
                    if (requesterUid.isNotEmpty) requesterUid,
                  ].join(' / '),
                ),
                if (createdAt.isNotEmpty) _kv('建立', createdAt),
                if (updatedAt.isNotEmpty) _kv('更新', updatedAt),
                if (resolvedAt.isNotEmpty) _kv('處理時間', resolvedAt),
                if (resolverName.isNotEmpty) _kv('處理人', resolverName),
                if (note.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '備註',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(note),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (status == 'pending') ...[
                      FilledButton.icon(
                        onPressed: () async {
                          final n = await _askNote(title: '通過（可填備註）');
                          if (n == null && !mounted) return;
                          Navigator.pop(context);
                          await _updateStatus(
                            doc,
                            nextStatus: 'approved',
                            note: n,
                          );
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('通過'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final n = await _askNote(title: '拒絕（可填備註）');
                          if (n == null && !mounted) return;
                          Navigator.pop(context);
                          await _updateStatus(
                            doc,
                            nextStatus: 'rejected',
                            note: n,
                          );
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('拒絕'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final n = await _askNote(title: '結案（可填備註）');
                          if (n == null && !mounted) return;
                          Navigator.pop(context);
                          await _updateStatus(
                            doc,
                            nextStatus: 'closed',
                            note: n,
                          );
                        },
                        icon: const Icon(Icons.archive_outlined),
                        label: const Text('結案'),
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _updateStatus(
                            doc,
                            nextStatus: 'pending',
                            note: note,
                          );
                        },
                        icon: const Icon(Icons.undo),
                        label: const Text('重新開啟'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final n = await _askNote(title: '更新備註');
                          if (n == null && !mounted) return;
                          Navigator.pop(context);
                          await _updateStatus(doc, nextStatus: status, note: n);
                        },
                        icon: const Icon(Icons.edit_note_outlined),
                        label: const Text('更新備註'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    if (v.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(k, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('審核 / 工單'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: '搜尋 title / summary / type / status / requester',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _keyword.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除',
                            onPressed: () => _searchCtrl.clear(),
                            icon: const Icon(Icons.clear),
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _filterChip('all', '全部'),
                      _filterChip('pending', '待審核'),
                      _filterChip('approved', '已通過'),
                      _filterChip('rejected', '已拒絕'),
                      _filterChip('closed', '已結案'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _query().snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('讀取失敗：${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs.where((d) => _match(d.data())).toList();

          if (docs.isEmpty) {
            return const Center(child: Text('沒有符合條件的資料'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();

              final title = _s(d['title'], '(未命名)');
              final summary = _s(d['summary'], '');
              final type = _s(d['type'], '');
              final status = _s(d['status'], 'pending').toLowerCase();

              final createdAt = _fmtTs(d['createdAt']);
              final color = _statusColor(status);

              return Card(
                elevation: 0.8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openDetail(doc),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _Tag(text: _statusLabel(status), color: color),
                          ],
                        ),
                        if (summary.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.black87,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          [
                            if (type.isNotEmpty) 'type: $type',
                            if (createdAt.isNotEmpty) '建立: $createdAt',
                            'id: ${doc.id}',
                          ].join('   •   '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (status == 'pending') ...[
                              FilledButton.icon(
                                onPressed: () async {
                                  final n = await _askNote(title: '通過（可填備註）');
                                  await _updateStatus(
                                    doc,
                                    nextStatus: 'approved',
                                    note: n,
                                  );
                                },
                                icon: const Icon(Icons.check),
                                label: const Text('通過'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () async {
                                  final n = await _askNote(title: '拒絕（可填備註）');
                                  await _updateStatus(
                                    doc,
                                    nextStatus: 'rejected',
                                    note: n,
                                  );
                                },
                                icon: const Icon(Icons.close),
                                label: const Text('拒絕'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final n = await _askNote(title: '結案（可填備註）');
                                  await _updateStatus(
                                    doc,
                                    nextStatus: 'closed',
                                    note: n,
                                  );
                                },
                                icon: const Icon(Icons.archive_outlined),
                                label: const Text('結案'),
                              ),
                            ] else ...[
                              OutlinedButton.icon(
                                onPressed: () => _openDetail(doc),
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('查看'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await _updateStatus(
                                    doc,
                                    nextStatus: 'pending',
                                  );
                                },
                                icon: const Icon(Icons.undo),
                                label: const Text('重新開啟'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _filterChip(String v, String label) {
    final selected = _filter == v;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = v),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // ✅ 修正 deprecated: withOpacity -> withValues(alpha: )
    // 0.12 * 255 ≈ 31；0.35 * 255 ≈ 89
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 31),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 89)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
