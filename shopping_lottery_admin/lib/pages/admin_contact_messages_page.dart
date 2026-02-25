// lib/pages/admin_contact_messages_page.dart
//
// ✅ AdminContactMessagesPage（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// - 修正：deprecated_member_use（DropdownButtonFormField 的 value -> initialValue）
// - 修正：deprecated_member_use（Color.withOpacity -> withValues(alpha: ...)）
// - 修正：use_build_context_synchronously（async gap 後用 context -> 改用 context.mounted guard）
// - Firestore：contact_messages（可自行改 collection 名稱）
//   欄位建議：
//   - name, email, phone, subject, message
//   - createdAt: Timestamp
//   - status: 'open' | 'closed'
//   - read: bool
//   - adminNote: String
//   - updatedAt: Timestamp
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminContactMessagesPage extends StatefulWidget {
  const AdminContactMessagesPage({super.key});

  @override
  State<AdminContactMessagesPage> createState() =>
      _AdminContactMessagesPageState();
}

class _AdminContactMessagesPageState extends State<AdminContactMessagesPage> {
  CollectionReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('contact_messages');

  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all'; // all/open/closed
  bool _busy = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  bool _match(String q, String id, Map<String, dynamic> m) {
    if (q.isEmpty) return true;
    final s = q.toLowerCase();

    String getStr(String key) => (m[key] ?? '').toString().toLowerCase();

    final name = getStr('name');
    final email = getStr('email');
    final phone = getStr('phone');
    final subject = getStr('subject');
    final message = getStr('message');
    final status = getStr('status');

    return id.toLowerCase().contains(s) ||
        name.contains(s) ||
        email.contains(s) ||
        phone.contains(s) ||
        subject.contains(s) ||
        message.contains(s) ||
        status.contains(s);
  }

  String _fmtTs(dynamic v) {
    DateTime? dt;
    if (v is Timestamp) dt = v.toDate();
    if (v is DateTime) dt = v;
    if (dt == null) return '-';
    final l = dt.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-'
        '${l.month.toString().padLeft(2, '0')}-'
        '${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _setRead(String id, bool read) async {
    try {
      await _ref.doc(id).set({
        'read': read,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack(read ? '已標記為已讀' : '已標記為未讀');
    } catch (e) {
      _snack('更新已讀狀態失敗：$e', error: true);
    }
  }

  Future<void> _setStatus(String id, String status) async {
    try {
      await _ref.doc(id).set({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack('已更新狀態：$status');
    } catch (e) {
      _snack('更新狀態失敗：$e', error: true);
    }
  }

  Future<void> _saveNote(String id, String note) async {
    try {
      await _ref.doc(id).set({
        'adminNote': note.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack('已保存內部備註');
    } catch (e) {
      _snack('保存備註失敗：$e', error: true);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除訊息'),
        content: Text('確定要刪除訊息 id=$id 嗎？'),
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

    setState(() => _busy = true);
    try {
      await _ref.doc(id).delete();
      _snack('已刪除訊息');
    } catch (e) {
      _snack('刪除失敗：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDetail(String id, Map<String, dynamic> data) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ContactMessageDetailSheet(
        id: id,
        data: data,
        fmtTs: _fmtTs,
        onSetRead: (read) => _setRead(id, read),
        onSetStatus: (status) => _setStatus(id, status),
        onSaveNote: (note) => _saveNote(id, note),
        onDelete: () => _delete(id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Query<Map<String, dynamic>> q = _ref
        .orderBy('createdAt', descending: true)
        .limit(500);

    return Scaffold(
      appBar: AppBar(
        title: const Text('聯絡我們訊息'),
        actions: [
          IconButton(
            tooltip: '重新整理（重建畫面）',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '搜尋：姓名/Email/電話/主旨/內容/id',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        tooltip: '清除',
                        onPressed: () {
                          _searchCtrl.clear();
                          FocusScope.of(context).unfocus();
                          (context as Element).markNeedsBuild();
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    ),
                    onChanged: (_) => (context as Element).markNeedsBuild(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    decoration: InputDecoration(
                      labelText: '狀態',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('全部')),
                      DropdownMenuItem(value: 'open', child: Text('未結案')),
                      DropdownMenuItem(value: 'closed', child: Text('已結案')),
                    ],
                    onChanged: (v) =>
                        setState(() => _statusFilter = v ?? 'all'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      '讀取失敗：${snap.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;
                final keyword = _searchCtrl.text.trim();

                final rows = <({String id, Map<String, dynamic> data})>[];
                for (final d in docs) {
                  final id = d.id;
                  final data = d.data();

                  final status = (data['status'] ?? 'open').toString().trim();
                  if (_statusFilter != 'all' && status != _statusFilter) {
                    continue;
                  }

                  if (_match(keyword, id, data)) rows.add((id: id, data: data));
                }

                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      '沒有訊息',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final id = rows[i].id;
                    final m = rows[i].data;

                    final name = (m['name'] ?? '').toString().trim();
                    final email = (m['email'] ?? '').toString().trim();
                    final subject = (m['subject'] ?? '').toString().trim();
                    final message = (m['message'] ?? '').toString().trim();

                    final read = m['read'] == true;
                    final status = (m['status'] ?? 'open').toString().trim();
                    final createdAt = _fmtTs(m['createdAt']);

                    Color badgeColor;
                    if (status == 'closed') {
                      badgeColor = Colors.green;
                    } else {
                      badgeColor = read ? cs.outline : Colors.orange;
                    }

                    final title = subject.isEmpty ? '(無主旨)' : subject;
                    final subtitle = [
                      if (name.isNotEmpty) name,
                      if (email.isNotEmpty) email,
                      createdAt,
                    ].join(' · ');

                    return Card(
                      elevation: 0.6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: badgeColor.withValues(alpha: 0.12),
                          child: Icon(
                            status == 'closed'
                                ? Icons.check_circle
                                : (read
                                      ? Icons.mark_email_read
                                      : Icons.mark_email_unread),
                            color: badgeColor,
                          ),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(subtitle),
                            const SizedBox(height: 6),
                            Text(
                              message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: Icon(
                                    Icons.flag,
                                    size: 16,
                                    color: badgeColor,
                                  ),
                                  label: Text(status),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: Icon(
                                    read ? Icons.done : Icons.fiber_new,
                                    size: 16,
                                  ),
                                  label: Text(read ? '已讀' : '未讀'),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.key, size: 16),
                                  label: Text(id),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: SizedBox(
                          width: 140,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Switch(
                                value: status == 'closed',
                                onChanged: _busy
                                    ? null
                                    : (v) =>
                                          _setStatus(id, v ? 'closed' : 'open'),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                children: [
                                  IconButton(
                                    tooltip: read ? '標記未讀' : '標記已讀',
                                    onPressed: _busy
                                        ? null
                                        : () => _setRead(id, !read),
                                    icon: Icon(
                                      read
                                          ? Icons.mark_email_unread
                                          : Icons.mark_email_read,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '刪除',
                                    onPressed: _busy ? null : () => _delete(id),
                                    icon: Icon(Icons.delete, color: cs.error),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        onTap: () => _openDetail(id, m),
                      ),
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
}

// ===========================
// Detail Sheet
// ===========================

class _ContactMessageDetailSheet extends StatefulWidget {
  const _ContactMessageDetailSheet({
    required this.id,
    required this.data,
    required this.fmtTs,
    required this.onSetRead,
    required this.onSetStatus,
    required this.onSaveNote,
    required this.onDelete,
  });

  final String id;
  final Map<String, dynamic> data;

  final String Function(dynamic) fmtTs;
  final Future<void> Function(bool read) onSetRead;
  final Future<void> Function(String status) onSetStatus;
  final Future<void> Function(String note) onSaveNote;
  final Future<void> Function() onDelete;

  @override
  State<_ContactMessageDetailSheet> createState() =>
      _ContactMessageDetailSheetState();
}

class _ContactMessageDetailSheetState
    extends State<_ContactMessageDetailSheet> {
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(
      text: (widget.data['adminNote'] ?? '').toString(),
    );
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.data;

    final name = (m['name'] ?? '').toString().trim();
    final email = (m['email'] ?? '').toString().trim();
    final phone = (m['phone'] ?? '').toString().trim();
    final subject = (m['subject'] ?? '').toString().trim();
    final message = (m['message'] ?? '').toString().trim();

    final status = (m['status'] ?? 'open').toString().trim();
    final read = m['read'] == true;

    final createdAt = widget.fmtTs(m['createdAt']);
    final updatedAt = widget.fmtTs(m['updatedAt']);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '訊息詳情',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(
                    avatar: const Icon(Icons.key, size: 16),
                    label: Text(widget.id),
                  ),
                  Chip(
                    avatar: const Icon(Icons.flag, size: 16),
                    label: Text(status),
                  ),
                  Chip(
                    avatar: Icon(read ? Icons.done : Icons.fiber_new, size: 16),
                    label: Text(read ? '已讀' : '未讀'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _kv('姓名', name.isEmpty ? '-' : name),
              _kv('Email', email.isEmpty ? '-' : email),
              _kv('電話', phone.isEmpty ? '-' : phone),
              _kv('建立時間', createdAt),
              _kv('更新時間', updatedAt),
              const SizedBox(height: 12),
              _sectionTitle('主旨'),
              Text(subject.isEmpty ? '(無主旨)' : subject),
              const SizedBox(height: 12),
              _sectionTitle('內容'),
              Text(message.isEmpty ? '(無內容)' : message),
              const SizedBox(height: 16),
              _sectionTitle('內部備註'),
              TextField(
                controller: _noteCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '僅管理端可見（adminNote）',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await widget.onSaveNote(_noteCtrl.text);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('保存備註'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await widget.onSetRead(!read);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      icon: Icon(
                        read ? Icons.mark_email_unread : Icons.mark_email_read,
                      ),
                      label: Text(read ? '標記未讀' : '標記已讀'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await widget.onSetStatus(
                          status == 'closed' ? 'open' : 'closed',
                        );
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      icon: Icon(
                        status == 'closed' ? Icons.undo : Icons.check_circle,
                      ),
                      label: Text(status == 'closed' ? '恢復未結案' : '結案'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () async {
                        await widget.onDelete();
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('刪除'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(k, style: TextStyle(color: Colors.grey[700])),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
