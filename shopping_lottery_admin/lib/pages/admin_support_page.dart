// lib/pages/admin_support_page.dart
//
// ✅ AdminSupportPage（單檔完整版｜可編譯可用｜修正 deprecated withOpacity -> withValues(alpha:)）
// ------------------------------------------------------------
// Firestore:
// support_tickets/{ticketId}
//  - uid: String
//  - userEmail: String
//  - title: String
//  - content: String
//  - status: "open" | "pending" | "closed"
//  - assignee: String (可空)
//  - tags: List<String> (可空)
//  - createdAt: Timestamp
//  - updatedAt: Timestamp
//  - closedAt: Timestamp? (可空)
//
// support_tickets/{ticketId}/messages/{messageId}
//  - sender: "admin" | "user"
//  - text: String
//  - createdAt: Timestamp
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminSupportPage extends StatefulWidget {
  const AdminSupportPage({super.key});

  @override
  State<AdminSupportPage> createState() => _AdminSupportPageState();
}

class _AdminSupportPageState extends State<AdminSupportPage> {
  // ✅ 修正：_db 真的用在 query / 更新 / 回覆
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _col = _db.collection(
    'support_tickets',
  );

  final _searchCtrl = TextEditingController();
  SupportFilter _filter = SupportFilter.open;
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  DateTime? _toDt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  String _fmtDt(DateTime? d) {
    if (d == null) return '—';
    return DateFormat('yyyy/MM/dd HH:mm').format(d);
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  bool _match(Map<String, dynamic> m) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;

    final text = <String>[
      _s(m['uid']),
      _s(m['userEmail']),
      _s(m['title']),
      _s(m['content']),
      _s(m['status']),
      _s(m['assignee']),
      if (m['tags'] is List) (m['tags'] as List).join(' '),
    ].join(' ').toLowerCase();

    return text.contains(q);
  }

  Query<Map<String, dynamic>> _baseQuery() {
    // 為避免資料缺欄位直接炸，先用 docId 排序；顯示再以 updatedAt/createdAt 客端排序
    return _col.orderBy(FieldPath.documentId).limit(500);
  }

  List<SupportTicket> _apply(List<SupportTicket> list) {
    Iterable<SupportTicket> out = list;

    switch (_filter) {
      case SupportFilter.open:
        out = out.where((t) => t.status == 'open');
        break;
      case SupportFilter.pending:
        out = out.where((t) => t.status == 'pending');
        break;
      case SupportFilter.closed:
        out = out.where((t) => t.status == 'closed');
        break;
      case SupportFilter.all:
        break;
    }

    if (_q.trim().isNotEmpty) {
      out = out.where((t) => _match(t.raw));
    }

    final sorted = out.toList()
      ..sort((a, b) {
        final atA =
            a.updatedAt ??
            a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final atB =
            b.updatedAt ??
            b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return atB.compareTo(atA);
      });

    return sorted;
  }

  Future<void> _openDetail(String ticketId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminSupportTicketDetailPage(ticketId: ticketId),
      ),
    );
  }

  Future<void> _updateStatus(String ticketId, String next) async {
    try {
      final patch = <String, dynamic>{
        'status': next,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (next == 'closed') {
        patch['closedAt'] = FieldValue.serverTimestamp();
      }
      await _col.doc(ticketId).set(patch, SetOptions(merge: true));
      _snack('已更新狀態：$next');
    } catch (e) {
      _snack('更新失敗：$e');
    }
  }

  Future<void> _setAssignee(String ticketId, String assignee) async {
    try {
      await _col.doc(ticketId).set({
        'assignee': assignee.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack('已更新指派');
    } catch (e) {
      _snack('更新失敗：$e');
    }
  }

  Future<void> _deleteTicket(String ticketId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除工單'),
        content: const Text('確定刪除此工單？此操作不可復原。'),
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
    if (ok != true) return;

    try {
      await _col.doc(ticketId).delete();
      _snack('已刪除工單');
    } catch (e) {
      _snack('刪除失敗：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '客服工單',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          const SizedBox(width: 6),
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
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '搜尋 uid / email / 標題 / 內容 / 指派 / 標籤',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _q = v),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<SupportFilter>(
                  value: _filter,
                  onChanged: (v) =>
                      setState(() => _filter = v ?? SupportFilter.open),
                  items: const [
                    DropdownMenuItem(
                      value: SupportFilter.open,
                      child: Text('未處理'),
                    ),
                    DropdownMenuItem(
                      value: SupportFilter.pending,
                      child: Text('處理中'),
                    ),
                    DropdownMenuItem(
                      value: SupportFilter.closed,
                      child: Text('已結案'),
                    ),
                    DropdownMenuItem(
                      value: SupportFilter.all,
                      child: Text('全部'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _baseQuery().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorView(
                    title: '載入失敗',
                    message: snap.error.toString(),
                    onRetry: () => setState(() {}),
                  );
                }

                final docs = snap.data?.docs ?? const [];
                final tickets = docs
                    .map((d) => SupportTicket.fromDoc(d, toDt: _toDt))
                    .toList();

                final filtered = _apply(tickets);

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      '沒有符合條件的工單',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = filtered[i];
                    final statusText = _statusLabel(t.status);
                    final statusColor = _statusColor(context, t.status);

                    final subtitle = <String>[
                      if (t.uid.isNotEmpty) 'uid:${t.uid}',
                      if (t.userEmail.isNotEmpty) 'email:${t.userEmail}',
                      if (t.assignee.isNotEmpty) '指派:${t.assignee}',
                      '更新:${_fmtDt(t.updatedAt ?? t.createdAt)}',
                      if (t.tags.isNotEmpty) 'tags:${t.tags.join(",")}',
                    ].join('｜');

                    return ListTile(
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.title.isEmpty ? '(未命名工單)' : t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              // ✅ FIX: withOpacity -> withValues(alpha:)
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'open') await _openDetail(t.id);
                          if (v == 'to_open') await _updateStatus(t.id, 'open');
                          if (v == 'to_pending') {
                            await _updateStatus(t.id, 'pending');
                          }
                          if (v == 'to_closed') {
                            await _updateStatus(t.id, 'closed');
                          }
                          if (v == 'assignee') {
                            final a = await _promptText(
                              title: '指派人（assignee）',
                              hint: '可填 admin email / uid / 名稱',
                              initial: t.assignee,
                            );
                            if (a != null) await _setAssignee(t.id, a);
                          }
                          if (v == 'delete') await _deleteTicket(t.id);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'open',
                            child: Text('查看/回覆'),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'to_open',
                            child: Text('標記：未處理'),
                          ),
                          const PopupMenuItem(
                            value: 'to_pending',
                            child: Text('標記：處理中'),
                          ),
                          const PopupMenuItem(
                            value: 'to_closed',
                            child: Text('標記：已結案'),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'assignee',
                            child: Text('設定指派'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              '刪除',
                              style: TextStyle(
                                color: cs.error,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _openDetail(t.id),
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

  String _statusLabel(String s) {
    switch (s) {
      case 'open':
        return '未處理';
      case 'pending':
        return '處理中';
      case 'closed':
        return '已結案';
      default:
        return s.isEmpty ? '未處理' : s;
    }
  }

  Color _statusColor(BuildContext context, String s) {
    final cs = Theme.of(context).colorScheme;
    switch (s) {
      case 'open':
        return cs.primary;
      case 'pending':
        return Colors.orange.shade800;
      case 'closed':
        return Colors.green.shade800;
      default:
        return cs.onSurfaceVariant;
    }
  }

  Future<String?> _promptText({
    required String title,
    required String hint,
    String initial = '',
  }) async {
    final ctrl = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
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
    );
    final v = ctrl.text.trim();
    ctrl.dispose();
    if (ok == true) return v;
    return null;
  }
}

// ============================== Detail Page ==============================

class AdminSupportTicketDetailPage extends StatefulWidget {
  final String ticketId;
  const AdminSupportTicketDetailPage({super.key, required this.ticketId});

  @override
  State<AdminSupportTicketDetailPage> createState() =>
      _AdminSupportTicketDetailPageState();
}

class _AdminSupportTicketDetailPageState
    extends State<AdminSupportTicketDetailPage> {
  final _db = FirebaseFirestore.instance;
  late final DocumentReference<Map<String, dynamic>> _doc = _db
      .collection('support_tickets')
      .doc(widget.ticketId);

  final _replyCtrl = TextEditingController();
  bool _sending = false;

  DateTime? _toDt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  String _fmtDt(DateTime? d) {
    if (d == null) return '—';
    return DateFormat('yyyy/MM/dd HH:mm').format(d);
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReply(String ticketId) async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) {
      _snack('回覆不可為空');
      return;
    }
    if (_sending) return;

    setState(() => _sending = true);
    try {
      final now = FieldValue.serverTimestamp();

      // messages 子集合
      await _doc.collection('messages').add({
        'sender': 'admin',
        'text': text,
        'createdAt': now,
      });

      // 更新工單 updatedAt / status
      await _doc.set({
        'updatedAt': now,
        'status': 'pending',
      }, SetOptions(merge: true));

      _replyCtrl.clear();
      _snack('已送出回覆');
    } catch (e) {
      _snack('送出失敗：$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _setStatus(String status) async {
    try {
      final patch = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (status == 'closed') patch['closedAt'] = FieldValue.serverTimestamp();
      await _doc.set(patch, SetOptions(merge: true));
      _snack('已更新狀態：$status');
    } catch (e) {
      _snack('更新失敗：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '工單：${widget.ticketId}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'open') await _setStatus('open');
              if (v == 'pending') await _setStatus('pending');
              if (v == 'closed') await _setStatus('closed');
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'open', child: Text('標記：未處理')),
              PopupMenuItem(value: 'pending', child: Text('標記：處理中')),
              PopupMenuItem(value: 'closed', child: Text('標記：已結案')),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _doc.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              title: '載入失敗',
              message: snap.error.toString(),
              onRetry: () => setState(() {}),
            );
          }
          final data = snap.data?.data();
          if (data == null) {
            return const Center(child: Text('工單不存在或已刪除'));
          }

          final title = _s(data['title']);
          final content = _s(data['content']);
          final status = _s(data['status']).isEmpty
              ? 'open'
              : _s(data['status']);
          final uid = _s(data['uid']);
          final email = _s(data['userEmail']);
          final assignee = _s(data['assignee']);
          final tags = (data['tags'] is List)
              ? (data['tags'] as List).map((e) => e.toString()).toList()
              : <String>[];
          final createdAt = _toDt(data['createdAt']);
          final updatedAt = _toDt(data['updatedAt']);
          final closedAt = _toDt(data['closedAt']);

          return Column(
            children: [
              Card(
                elevation: 0,
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? '(未命名工單)' : title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(content.isEmpty ? '(無內容)' : content),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _pill(cs, '狀態：$status'),
                          if (uid.isNotEmpty) _pill(cs, 'uid：$uid'),
                          if (email.isNotEmpty) _pill(cs, 'email：$email'),
                          if (assignee.isNotEmpty) _pill(cs, '指派：$assignee'),
                          _pill(cs, '建立：${_fmtDt(createdAt)}'),
                          _pill(cs, '更新：${_fmtDt(updatedAt)}'),
                          if (closedAt != null)
                            _pill(cs, '結案：${_fmtDt(closedAt)}'),
                          if (tags.isNotEmpty)
                            _pill(cs, 'tags：${tags.join(",")}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _doc
                      .collection('messages')
                      .orderBy('createdAt', descending: false)
                      .limit(500)
                      .snapshots(),
                  builder: (context, msnap) {
                    if (msnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final msgs = msnap.data?.docs ?? const [];
                    if (msgs.isEmpty) {
                      return Center(
                        child: Text(
                          '尚無對話紀錄',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[i].data();
                        final sender = _s(m['sender']);
                        final text = _s(m['text']);
                        final at = _toDt(m['createdAt']);
                        final isAdmin = sender == 'admin';

                        return Align(
                          alignment: isAdmin
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Card(
                              elevation: 0,
                              color: isAdmin
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHighest,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: isAdmin
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      text,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: isAdmin
                                            ? cs.onPrimaryContainer
                                            : cs.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _fmtDt(at),
                                      style: TextStyle(
                                        fontSize: 12,
                                        // ✅ FIX: withOpacity -> withValues(alpha:)
                                        color: isAdmin
                                            ? cs.onPrimaryContainer.withValues(
                                                alpha: 0.8,
                                              )
                                            : cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // reply box
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyCtrl,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: '輸入回覆（送出後會自動標記為 pending）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _sending
                            ? null
                            : () => _sendReply(widget.ticketId),
                        icon: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(_sending ? '送出中...' : '送出'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pill(ColorScheme cs, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ============================== Models ==============================

class SupportTicket {
  final String id;
  final Map<String, dynamic> raw;

  final String uid;
  final String userEmail;
  final String title;
  final String content;
  final String status; // open/pending/closed
  final String assignee;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SupportTicket({
    required this.id,
    required this.raw,
    required this.uid,
    required this.userEmail,
    required this.title,
    required this.content,
    required this.status,
    required this.assignee,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportTicket.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required DateTime? Function(dynamic) toDt,
  }) {
    final m = doc.data() ?? <String, dynamic>{};

    final tags = <String>[];
    if (m['tags'] is List) {
      for (final e in (m['tags'] as List)) {
        final s = (e ?? '').toString().trim();
        if (s.isNotEmpty) tags.add(s);
      }
    }

    final status = (m['status'] ?? 'open').toString().trim();
    return SupportTicket(
      id: doc.id,
      raw: m,
      uid: (m['uid'] ?? '').toString(),
      userEmail: (m['userEmail'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      content: (m['content'] ?? '').toString(),
      status: status.isEmpty ? 'open' : status,
      assignee: (m['assignee'] ?? '').toString(),
      tags: tags,
      createdAt: toDt(m['createdAt']),
      updatedAt: toDt(m['updatedAt']),
    );
  }
}

// ============================== UI Helpers ==============================

enum SupportFilter { open, pending, closed, all }

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
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
