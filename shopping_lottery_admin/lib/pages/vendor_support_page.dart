// lib/pages/vendor_support_page.dart
//
// ✅ VendorSupportPage（最終穩定完整版｜可編譯｜Vendor Only｜工單/客服｜即時監聽｜新增工單｜對話回覆｜Web+App）
//
// Firestore 建議：support_tickets/{ticketId}
//   - vendorId: String
//   - subject: String
//   - category: String        // e.g. "訂單", "商品", "付款", "其他"
//   - priority: String        // "low" | "normal" | "high"
//   - status: String          // "open" | "pending" | "closed"
//   - lastMessage: String
//   - lastMessageAt: Timestamp
//   - createdAt: Timestamp
//   - updatedAt: Timestamp
//
// 子集合：support_tickets/{ticketId}/messages/{messageId}
//   - senderRole: String      // "vendor" | "admin"
//   - senderId: String
//   - text: String
//   - createdAt: Timestamp
//
// 依賴：cloud_firestore, firebase_auth, flutter/material, flutter/services

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VendorSupportPage extends StatefulWidget {
  const VendorSupportPage({
    super.key,
    this.vendorId,
    this.collection = 'support_tickets',
  });

  final String? vendorId;
  final String collection;

  static const routeName = '/vendor/support';

  @override
  State<VendorSupportPage> createState() => _VendorSupportPageState();
}

class _VendorSupportPageState extends State<VendorSupportPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _searchCtrl = TextEditingController();
  String _q = '';

  String _status = 'open'; // open/pending/closed/all
  bool _busy = false;
  String _busyLabel = '';

  String get _vid => (widget.vendorId ?? _auth.currentUser?.uid ?? '').trim();
  CollectionReference<Map<String, dynamic>> get _tcol =>
      _db.collection(widget.collection);

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (!mounted) {
        return;
      }
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

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) {
      return v.toDate();
    }
    if (v is DateTime) {
      return v;
    }
    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) {
      return '-';
    }
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  void _snack(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _setBusy(bool v, {String label = ''}) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = v;
      _busyLabel = label;
    });
  }

  Future<void> _copy(String text, {String done = '已複製'}) async {
    final t = text.trim();
    if (t.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: t));
    _snack(done);
  }

  // -------------------------
  // Query/Stream
  // -------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _streamTickets() {
    Query<Map<String, dynamic>> q = _tcol.where('vendorId', isEqualTo: _vid);

    if (_status != 'all') {
      q = q.where('status', isEqualTo: _status);
    }

    q = q.orderBy('lastMessageAt', descending: true).limit(400);
    return q.snapshots();
  }

  bool _matchLocal(String id, Map<String, dynamic> d) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) {
      return true;
    }

    final subject = _s(d['subject']).toLowerCase();
    final category = _s(d['category']).toLowerCase();
    final priority = _s(d['priority']).toLowerCase();
    final status = _s(d['status']).toLowerCase();
    final last = _s(d['lastMessage']).toLowerCase();

    return id.toLowerCase().contains(q) ||
        subject.contains(q) ||
        category.contains(q) ||
        priority.contains(q) ||
        status.contains(q) ||
        last.contains(q);
  }

  // -------------------------
  // Actions
  // -------------------------
  Future<void> _openCreateTicket() async {
    final result = await showDialog<_NewTicketResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _NewTicketDialog(),
    );

    if (!mounted) {
      return;
    }
    if (result == null) {
      return;
    }

    await _setBusy(true, label: '建立工單...');
    try {
      final now = FieldValue.serverTimestamp();
      final doc = _tcol.doc();

      final ticketPayload = <String, dynamic>{
        'vendorId': _vid,
        'subject': result.subject.trim(),
        'category': result.category,
        'priority': result.priority,
        'status': 'open',
        'lastMessage': result.message.trim(),
        'lastMessageAt': now,
        'createdAt': now,
        'updatedAt': now,
      };

      final msgRef = doc.collection('messages').doc();
      final msgPayload = <String, dynamic>{
        'senderRole': 'vendor',
        'senderId': _vid,
        'text': result.message.trim(),
        'createdAt': now,
      };

      final batch = _db.batch();
      batch.set(doc, ticketPayload);
      batch.set(msgRef, msgPayload);
      await batch.commit();

      _snack('已建立工單');
    } catch (e) {
      _snack('建立失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _openTicketDetail(
    String ticketId,
    Map<String, dynamic> ticket,
  ) async {
    await showDialog(
      context: context,
      builder: (_) => _TicketDetailDialog(
        vendorId: _vid,
        ticketRef: _tcol.doc(ticketId),
        initialTicket: ticket,
      ),
    );
  }

  Future<void> _setStatus(
    DocumentReference<Map<String, dynamic>> ref,
    String status,
  ) async {
    await _setBusy(true, label: '更新狀態...');
    try {
      await ref.set(<String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack('已更新狀態');
    } catch (e) {
      _snack('更新失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_vid.isEmpty) {
      return const Scaffold(body: Center(child: Text('請先登入 Vendor 帳號')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('客服工單'),
        actions: [
          IconButton(
            tooltip: '新增工單',
            onPressed: _busy ? null : _openCreateTicket,
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _SupportFilters(
                searchCtrl: _searchCtrl,
                status: _status,
                onQueryChanged: (v) {
                  setState(() => _q = v);
                },
                onClearQuery: () {
                  _searchCtrl.clear();
                  setState(() => _q = '');
                },
                onStatusChanged: (v) {
                  setState(() => _status = v);
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _streamTickets(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(child: Text('讀取失敗：${snap.error}'));
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final rows = snap.data!.docs
                        .map((d) => _TicketRow(id: d.id, data: d.data()))
                        .where((r) => _matchLocal(r.id, r.data))
                        .toList();

                    if (rows.isEmpty) {
                      return Center(
                        child: Text(
                          '沒有工單',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        final d = r.data;

                        final subject = _s(d['subject']).isEmpty
                            ? '（無主旨）'
                            : _s(d['subject']);
                        final category = _s(d['category']);
                        final priority = _s(d['priority']);
                        final status = _s(d['status']);
                        final last = _s(d['lastMessage']);
                        final lastAt = _toDate(d['lastMessageAt']);

                        final statusColor = switch (status) {
                          'closed' => cs.outline,
                          'pending' => cs.tertiary,
                          _ => cs.primary,
                        };

                        return ListTile(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  subject,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _Pill(
                                label: status.isEmpty ? 'open' : status,
                                color: statusColor,
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (last.isNotEmpty) ...[
                                  Text(
                                    last,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 4,
                                  children: [
                                    if (category.isNotEmpty)
                                      Text(
                                        '分類：$category',
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    if (priority.isNotEmpty)
                                      Text(
                                        '優先級：$priority',
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    Text(
                                      '更新：${_fmt(lastAt)}',
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
                                    if (v == 'copy_id') {
                                      await _copy(r.id, done: '已複製 ticketId');
                                    } else if (v == 'open') {
                                      await _setStatus(_tcol.doc(r.id), 'open');
                                    } else if (v == 'pending') {
                                      await _setStatus(
                                        _tcol.doc(r.id),
                                        'pending',
                                      );
                                    } else if (v == 'closed') {
                                      await _setStatus(
                                        _tcol.doc(r.id),
                                        'closed',
                                      );
                                    }
                                  },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'copy_id',
                                child: Text('複製 ticketId'),
                              ),
                              PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'open',
                                child: Text('狀態：open'),
                              ),
                              PopupMenuItem(
                                value: 'pending',
                                child: Text('狀態：pending'),
                              ),
                              PopupMenuItem(
                                value: 'closed',
                                child: Text('狀態：closed'),
                              ),
                            ],
                          ),
                          onTap: () => _openTicketDetail(r.id, d),
                        );
                      },
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
class _TicketRow {
  final String id;
  final Map<String, dynamic> data;
  _TicketRow({required this.id, required this.data});
}

// ------------------------------------------------------------
// Filters (✅ DropdownButtonFormField 用 initialValue)
// ------------------------------------------------------------
class _SupportFilters extends StatelessWidget {
  const _SupportFilters({
    required this.searchCtrl,
    required this.status,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onStatusChanged,
  });

  final TextEditingController searchCtrl;
  final String status;

  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      controller: searchCtrl,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        hintText: '搜尋：subject / 分類 / 狀態 / ticketId / 最後訊息',
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

    final dd = DropdownButtonFormField<String>(
      initialValue: status,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        labelText: '狀態',
      ),
      items: const [
        DropdownMenuItem(value: 'open', child: Text('open（處理中）')),
        DropdownMenuItem(value: 'pending', child: Text('pending（等待回覆）')),
        DropdownMenuItem(value: 'closed', child: Text('closed（已結案）')),
        DropdownMenuItem(value: 'all', child: Text('all（全部）')),
      ],
      onChanged: (v) {
        onStatusChanged(v ?? 'open');
      },
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
              SizedBox(width: 280, child: dd),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// Create Ticket Dialog
// ------------------------------------------------------------
class _NewTicketDialog extends StatefulWidget {
  const _NewTicketDialog();

  @override
  State<_NewTicketDialog> createState() => _NewTicketDialogState();
}

class _NewTicketDialogState extends State<_NewTicketDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  String _category = '其他';
  String _priority = 'normal';

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: SizedBox(
        width: 680,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '新增工單',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '關閉',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _subjectCtrl,
                  decoration: const InputDecoration(
                    labelText: '主旨（subject）*',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) {
                      return '主旨不可為空';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _category,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '分類（category）',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: '訂單', child: Text('訂單')),
                          DropdownMenuItem(value: '商品', child: Text('商品')),
                          DropdownMenuItem(value: '付款', child: Text('付款')),
                          DropdownMenuItem(value: '帳號', child: Text('帳號')),
                          DropdownMenuItem(value: '其他', child: Text('其他')),
                        ],
                        onChanged: (v) {
                          setState(() => _category = v ?? '其他');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _priority,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '優先級（priority）',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('low')),
                          DropdownMenuItem(
                            value: 'normal',
                            child: Text('normal'),
                          ),
                          DropdownMenuItem(value: 'high', child: Text('high')),
                        ],
                        onChanged: (v) {
                          setState(() => _priority = v ?? 'normal');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _messageCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: '內容（message）*',
                    border: OutlineInputBorder(),
                    isDense: true,
                    alignLabelWithHint: true,
                  ),
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) {
                      return '內容不可為空';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          if (!(_formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          Navigator.pop(
                            context,
                            _NewTicketResult(
                              subject: _subjectCtrl.text,
                              category: _category,
                              priority: _priority,
                              message: _messageCtrl.text,
                            ),
                          );
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('送出'),
                      ),
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
}

class _NewTicketResult {
  final String subject;
  final String category;
  final String priority;
  final String message;

  _NewTicketResult({
    required this.subject,
    required this.category,
    required this.priority,
    required this.message,
  });
}

// ------------------------------------------------------------
// Ticket Detail Dialog (messages stream + reply)
// ------------------------------------------------------------
class _TicketDetailDialog extends StatefulWidget {
  const _TicketDetailDialog({
    required this.vendorId,
    required this.ticketRef,
    required this.initialTicket,
  });

  final String vendorId;
  final DocumentReference<Map<String, dynamic>> ticketRef;
  final Map<String, dynamic> initialTicket;

  @override
  State<_TicketDetailDialog> createState() => _TicketDetailDialogState();
}

class _TicketDetailDialogState extends State<_TicketDetailDialog> {
  final _replyCtrl = TextEditingController();
  bool _sending = false;

  CollectionReference<Map<String, dynamic>> get _msgCol =>
      widget.ticketRef.collection('messages');

  String _s(dynamic v) => (v ?? '').toString().trim();

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() => _sending = true);
    try {
      final now = FieldValue.serverTimestamp();
      await _msgCol.add(<String, dynamic>{
        'senderRole': 'vendor',
        'senderId': widget.vendorId,
        'text': text,
        'createdAt': now,
      });

      await widget.ticketRef.set(<String, dynamic>{
        'lastMessage': text,
        'lastMessageAt': now,
        'updatedAt': now,
        'status': 'pending',
      }, SetOptions(merge: true));

      _replyCtrl.clear();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('送出失敗：$e')));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subject = _s(widget.initialTicket['subject']).isEmpty
        ? '（無主旨）'
        : _s(widget.initialTicket['subject']);

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: SizedBox(
        width: 820,
        height: 640,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subject,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '複製 ticketId',
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: widget.ticketRef.id),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已複製 ticketId')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                  ),
                  IconButton(
                    tooltip: '關閉',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _msgCol
                      .orderBy('createdAt', descending: false)
                      .limit(500)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(child: Text('讀取失敗：${snap.error}'));
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          '尚無訊息',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final d = docs[i].data();
                        final role = _s(d['senderRole']);
                        final text = _s(d['text']);
                        final at = (d['createdAt'] is Timestamp)
                            ? (d['createdAt'] as Timestamp).toDate()
                            : null;

                        final isMe = role == 'vendor';
                        final bubbleColor = isMe
                            ? cs.primary.withValues(alpha: 0.10)
                            : cs.surfaceContainerHighest.withValues(
                                alpha: 0.55,
                              );

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 620),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: cs.outline.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isMe ? '你（Vendor）' : '客服（Admin）',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: cs.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(text.isEmpty ? '（空）' : text),
                                const SizedBox(height: 6),
                                Text(
                                  at == null
                                      ? '-'
                                      : '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')} '
                                            '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
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
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyCtrl,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: '輸入回覆內容...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _sending ? null : _sendReply,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: const Text('送出'),
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
