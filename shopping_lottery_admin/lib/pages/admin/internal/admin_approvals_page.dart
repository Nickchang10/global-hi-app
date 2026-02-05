// lib/pages/admin/internal/admin_approvals_page.dart
//
// ✅ AdminApprovalsPage（最終完整版｜多用途審核中心｜可直接使用）
// ------------------------------------------------------------
// Firestore：approvals/{id}
//
// 建議欄位（可彈性存在）：
// {
//   type: "refund" | "support" | "vendor" | "content" | ...
//   title: "退款申請 - 訂單 #A001" (可選)
//   applicantName: "王小明" (可選)
//   userId: "uid" (可選)
//   orderId: "orderId" (可選)
//   status: "pending" | "approved" | "rejected" | "closed"
//   remark: "備註" (可選)
//   createdAt: Timestamp
//   updatedAt: Timestamp
//   reviewedAt: Timestamp (可選)
//   reviewedBy: "admin/uid" (可選)
// }
//
// 功能：
// - 篩選：狀態（all/pending/approved/rejected/closed）
// - 搜尋：申請人 / 類型 / 標題 / ID / 訂單 / 備註
// - 操作：通過 / 退回 / 結案（可填備註）
// - 詳情：一鍵查看整份 doc 欄位
//
// ⚠️ 注意：為避免 where+orderBy 造成索引/權限問題，本頁採用：
//   - 先 orderBy(createdAt desc).limit(1000) 取回
//   - 再在前端做狀態/搜尋篩選
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminApprovalsPage extends StatefulWidget {
  const AdminApprovalsPage({super.key});

  @override
  State<AdminApprovalsPage> createState() => _AdminApprovalsPageState();
}

class _AdminApprovalsPageState extends State<AdminApprovalsPage> {
  final _db = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _col =
      _db.collection('approvals');

  static const _statusAll = 'all';
  static const _statusPending = 'pending';
  static const _statusApproved = 'approved';
  static const _statusRejected = 'rejected';
  static const _statusClosed = 'closed';

  String _status = _statusPending;

  String _search = '';
  final _searchCtl = TextEditingController();

  final _fmt = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    // ✅ 先抓回來再前端篩選，避免 index / where+orderBy 陷阱
    return _col.orderBy('createdAt', descending: true).limit(1000).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('審核 / 工單管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          _statusDropdown(),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _searchBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorView(
                    title: '載入失敗',
                    message: snap.error.toString(),
                    hint: '若出現 permission-denied，請確認 rules：/approvals 允許 isAdmin() 讀寫。',
                    onRetry: () => setState(() {}),
                  );
                }

                final docs = (snap.data?.docs ?? const [])
                    .map((d) => _ApprovalDoc.fromDoc(d))
                    .toList();

                final filtered = _applyFilter(docs);

                return Column(
                  children: [
                    _summaryRow(filtered.length, cs),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('目前沒有符合條件的審核項目'))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) => _buildCard(filtered[i], cs),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  Widget _statusDropdown() {
    return DropdownButton<String>(
      value: _status,
      underline: const SizedBox(),
      onChanged: (v) => setState(() => _status = v ?? _statusPending),
      items: const [
        DropdownMenuItem(value: _statusAll, child: Text('全部')),
        DropdownMenuItem(value: _statusPending, child: Text('待審核')),
        DropdownMenuItem(value: _statusApproved, child: Text('已通過')),
        DropdownMenuItem(value: _statusRejected, child: Text('已退回')),
        DropdownMenuItem(value: _statusClosed, child: Text('已結案')),
      ],
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchCtl,
        onChanged: (v) => setState(() => _search = v.trim()),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: '搜尋：申請人 / 類型 / 標題 / ID / 訂單 / 備註',
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: _searchCtl.text.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: '清除',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _searchCtl.clear();
                      _search = '';
                    });
                  },
                ),
        ),
      ),
    );
  }

  Widget _summaryRow(int count, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Text('共 $count 筆', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('重新整理'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Filter
  // ============================================================

  List<_ApprovalDoc> _applyFilter(List<_ApprovalDoc> input) {
    final s = _search.trim().toLowerCase();

    return input.where((d) {
      final matchStatus = (_status == _statusAll) || d.status == _status;

      if (!matchStatus) return false;

      if (s.isEmpty) return true;

      final hay = <String>[
        d.id,
        d.type,
        d.title,
        d.applicantName,
        d.userId,
        d.orderId,
        d.remark,
      ].join(' ').toLowerCase();

      return hay.contains(s);
    }).toList();
  }

  // ============================================================
  // Card
  // ============================================================

  Widget _buildCard(_ApprovalDoc a, ColorScheme cs) {
    final statusText = _statusLabel(a.status);
    final typeText = a.type.isEmpty ? '未指定類型' : a.type;

    final createdText = a.createdAt == null ? '—' : _fmt.format(a.createdAt!);
    final updatedText = a.updatedAt == null ? '—' : _fmt.format(a.updatedAt!);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(a.status, cs),
          child: Icon(_statusIcon(a.status), color: Colors.white),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                a.title.isNotEmpty ? a.title : '$typeText（${a.applicantName.isEmpty ? '未指定申請人' : a.applicantName}）',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            _chip(statusText, bg: _statusColor(a.status, cs).withOpacity(0.12), fg: _statusColor(a.status, cs)),
            const SizedBox(width: 6),
            _chip(typeText, bg: cs.secondaryContainer.withOpacity(0.45), fg: cs.onSecondaryContainer),
          ],
        ),
        subtitle: Text(
          [
            'ID: ${a.id}',
            if (a.orderId.isNotEmpty) '訂單: ${a.orderId}',
            '建立：$createdText',
            '更新：$updatedText',
            if (a.remark.isNotEmpty) '備註：${a.remark}',
          ].join('\n'),
          style: TextStyle(height: 1.3, color: cs.onSurfaceVariant),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => _handleAction(v, a),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'approve', child: Text('通過')),
            const PopupMenuItem(value: 'reject', child: Text('退回')),
            const PopupMenuItem(value: 'close', child: Text('結案')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'view', child: Text('查看詳情')),
          ],
        ),
        onTap: () => _openDetailDialog(a.id, a.raw),
      ),
    );
  }

  Widget _chip(String text, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg)),
    );
  }

  // ============================================================
  // Actions
  // ============================================================

  Future<void> _handleAction(String action, _ApprovalDoc a) async {
    if (action == 'view') {
      _openDetailDialog(a.id, a.raw);
      return;
    }

    final String nextStatus = switch (action) {
      'approve' => _statusApproved,
      'reject' => _statusRejected,
      'close' => _statusClosed,
      _ => a.status,
    };

    final noteCtl = TextEditingController(text: a.remark);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          action == 'approve'
              ? '通過審核'
              : action == 'reject'
                  ? '退回審核'
                  : '結案',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: noteCtl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '備註（選填）',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('確認')),
        ],
      ),
    );

    if (ok != true) {
      noteCtl.dispose();
      return;
    }

    try {
      await _col.doc(a.id).set({
        'status': nextStatus,
        // ✅ 保留 remark（你原本的欄位），同時加上 reviewNote（更語意化）
        'remark': noteCtl.text.trim(),
        'reviewNote': noteCtl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'reviewedAt': FieldValue.serverTimestamp(),
        // 你若之後要填 uid，可改成 request.auth.uid（後端）或從 App 端傳入
        'reviewedBy': 'admin',
      }, SetOptions(merge: true));

      _toast('已更新審核狀態');
    } catch (e) {
      _toast('操作失敗：$e');
    } finally {
      noteCtl.dispose();
    }
  }

  void _openDetailDialog(String id, Map<String, dynamic> d) {
    final cs = Theme.of(context).colorScheme;

    final entries = d.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('審核詳情：$id', style: const TextStyle(fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 160,
                        child: Text('${e.key}:', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      Expanded(
                        child: Text(
                          _prettyValue(e.value),
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
        ],
      ),
    );
  }

  String _prettyValue(dynamic v) {
    if (v == null) return 'null';
    if (v is Timestamp) return _fmt.format(v.toDate());
    if (v is DateTime) return _fmt.format(v);
    return v.toString();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ============================================================
  // Status UI helpers
  // ============================================================

  String _statusLabel(String status) {
    switch (status) {
      case _statusApproved:
        return '已通過';
      case _statusRejected:
        return '已退回';
      case _statusClosed:
        return '已結案';
      case _statusPending:
      default:
        return '待審核';
    }
  }

  Color _statusColor(String status, ColorScheme cs) {
    switch (status) {
      case _statusApproved:
        return Colors.green;
      case _statusRejected:
        return Colors.redAccent;
      case _statusClosed:
        return Colors.grey;
      case _statusPending:
      default:
        return cs.primary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case _statusApproved:
        return Icons.check_circle;
      case _statusRejected:
        return Icons.cancel;
      case _statusClosed:
        return Icons.archive;
      case _statusPending:
      default:
        return Icons.hourglass_top;
    }
  }
}

// ============================================================
// Model
// ============================================================

class _ApprovalDoc {
  final String id;
  final String type;
  final String title;
  final String applicantName;
  final String userId;
  final String orderId;
  final String status;
  final String remark;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> raw;

  const _ApprovalDoc({
    required this.id,
    required this.type,
    required this.title,
    required this.applicantName,
    required this.userId,
    required this.orderId,
    required this.status,
    required this.remark,
    required this.createdAt,
    required this.updatedAt,
    required this.raw,
  });

  factory _ApprovalDoc.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return _ApprovalDoc(
      id: doc.id,
      type: (d['type'] ?? '').toString(),
      title: (d['title'] ?? '').toString(),
      applicantName: (d['applicantName'] ?? '').toString(),
      userId: (d['userId'] ?? '').toString(),
      orderId: (d['orderId'] ?? '').toString(),
      status: (d['status'] ?? 'pending').toString(),
      remark: (d['remark'] ?? d['reviewNote'] ?? '').toString(),
      createdAt: _toDateTime(d['createdAt']),
      updatedAt: _toDateTime(d['updatedAt']),
      raw: d,
    );
  }
}

DateTime? _toDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

// ============================================================
// Error View
// ============================================================

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final String? hint;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 44, color: cs.error),
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                  if (hint != null) ...[
                    const SizedBox(height: 10),
                    Text(hint!, style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重試'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
