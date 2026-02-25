// lib/pages/admin_support_tasks_page.dart
//
// ✅ AdminSupportTasksPage（正式版｜完整版｜可直接編譯｜已修正常見 lint）
// ------------------------------------------------------------
// Firestore collection：support_tasks
// 建議欄位：
// - subject: String
// - description: String
// - status: String            // open / in_progress / resolved / closed
// - priority: String          // low / normal / high / urgent
// - channel: String           // app / line / fb / phone / email / other
// - userId: String
// - orderId: String
// - assignedTo: String        // admin uid/email/name
// - tags: List<String>
// - lastReplyAt: Timestamp?
// - createdAt, updatedAt: Timestamp
//
// 修正點：
// - DropdownButtonFormField: value -> initialValue + ValueKey 強制重建（避免 deprecated lint + UI 不同步）
// - 避免 async gap 後直接用 context（加 mounted guard）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSupportTasksPage extends StatefulWidget {
  const AdminSupportTasksPage({super.key});

  @override
  State<AdminSupportTasksPage> createState() => _AdminSupportTasksPageState();
}

class _AdminSupportTasksPageState extends State<AdminSupportTasksPage> {
  final _searchCtrl = TextEditingController();
  bool _busy = false;

  String _status = 'all';
  String _priority = 'all';

  CollectionReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('support_tasks');

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

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) return DateTime.tryParse(v.trim());
    return null;
  }

  String _fmt(dynamic v) {
    final dt = _toDate(v);
    if (dt == null) return '-';
    final l = dt.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-'
        '${l.month.toString().padLeft(2, '0')}-'
        '${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  Query<Map<String, dynamic>> _query() {
    // 用 createdAt 排序最安全（避免某些舊資料沒有 updatedAt 導致排序錯）
    return _ref.orderBy('createdAt', descending: true).limit(500);
  }

  bool _matchKeyword(String keyword, String id, Map<String, dynamic> m) {
    if (keyword.isEmpty) return true;
    final k = keyword.toLowerCase();

    String s(String key) => (m[key] ?? '').toString().toLowerCase();
    final tags = (m['tags'] is List)
        ? (m['tags'] as List).map((e) => e.toString()).join(',').toLowerCase()
        : '';

    return id.toLowerCase().contains(k) ||
        s('subject').contains(k) ||
        s('description').contains(k) ||
        s('userId').contains(k) ||
        s('orderId').contains(k) ||
        s('assignedTo').contains(k) ||
        s('channel').contains(k) ||
        s('status').contains(k) ||
        s('priority').contains(k) ||
        tags.contains(k);
  }

  bool _matchFilter(Map<String, dynamic> m) {
    final status = (m['status'] ?? 'open').toString();
    final priority = (m['priority'] ?? 'normal').toString();

    if (_status != 'all' && status != _status) return false;
    if (_priority != 'all' && priority != _priority) return false;
    return true;
  }

  Future<void> _openEditor({String? id, Map<String, dynamic>? initial}) async {
    final res = await showModalBottomSheet<_TaskEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SupportTaskEditorSheet(taskId: id, initial: initial),
    );

    if (!mounted) return;
    if (res == null) return;

    setState(() => _busy = true);
    try {
      final payload = <String, dynamic>{
        ...res.payload,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (id == null) {
        await _ref.add({...payload, 'createdAt': FieldValue.serverTimestamp()});
        _snack('已新增工單');
      } else {
        await _ref.doc(id).set(payload, SetOptions(merge: true));
        _snack('已更新工單');
      }
    } catch (e) {
      _snack('保存失敗：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除工單'),
        content: Text('確定要刪除工單 id=$id 嗎？'),
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

    setState(() => _busy = true);
    try {
      await _ref.doc(id).delete();
      _snack('已刪除');
    } catch (e) {
      _snack('刪除失敗：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _quickSetStatus(String id, String status) async {
    try {
      await _ref.doc(id).set({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _snack('更新狀態失敗：$e', error: true);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'open':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'low':
        return Colors.grey;
      case 'normal':
        return Colors.blueGrey;
      case 'high':
        return Colors.deepOrange;
      case 'urgent':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _searchCtrl.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('客服工單管理'),
        actions: [
          IconButton(
            tooltip: '新增工單',
            onPressed: _busy ? null : () => _openEditor(),
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText:
                        '搜尋：subject / userId / orderId / assignedTo / tags ...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      tooltip: '清除',
                      onPressed: () {
                        _searchCtrl.clear();
                        FocusScope.of(context).unfocus();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        // ✅ 避免新版 value lint：改 initialValue
                        key: ValueKey('status_$_status'),
                        initialValue: _status,
                        decoration: InputDecoration(
                          labelText: '狀態',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('全部')),
                          DropdownMenuItem(value: 'open', child: Text('open')),
                          DropdownMenuItem(
                            value: 'in_progress',
                            child: Text('in_progress'),
                          ),
                          DropdownMenuItem(
                            value: 'resolved',
                            child: Text('resolved'),
                          ),
                          DropdownMenuItem(
                            value: 'closed',
                            child: Text('closed'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _status = v ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('priority_$_priority'),
                        initialValue: _priority,
                        decoration: InputDecoration(
                          labelText: '優先度',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('全部')),
                          DropdownMenuItem(value: 'low', child: Text('low')),
                          DropdownMenuItem(
                            value: 'normal',
                            child: Text('normal'),
                          ),
                          DropdownMenuItem(value: 'high', child: Text('high')),
                          DropdownMenuItem(
                            value: 'urgent',
                            child: Text('urgent'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _priority = v ?? 'all'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
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
                final rows = docs
                    .where((d) {
                      final m = d.data();
                      return _matchFilter(m) && _matchKeyword(keyword, d.id, m);
                    })
                    .toList(growable: false);

                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      '沒有資料',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final d = rows[i];
                    final m = d.data();

                    final subject = (m['subject'] ?? '').toString().trim();
                    final desc = (m['description'] ?? '').toString().trim();
                    final status = (m['status'] ?? 'open').toString();
                    final priority = (m['priority'] ?? 'normal').toString();
                    final channel = (m['channel'] ?? 'app').toString();
                    final userId = (m['userId'] ?? '').toString().trim();
                    final orderId = (m['orderId'] ?? '').toString().trim();
                    final assignedTo = (m['assignedTo'] ?? '')
                        .toString()
                        .trim();

                    final tags = (m['tags'] is List)
                        ? (m['tags'] as List)
                              .map((e) => e.toString())
                              .where((e) => e.trim().isNotEmpty)
                              .toList()
                        : <String>[];

                    final createdAt = _fmt(m['createdAt']);
                    final updatedAt = _fmt(m['updatedAt']);

                    return Card(
                      elevation: 0.7,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          child: Icon(
                            Icons.support_agent,
                            color: _statusColor(status),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                subject.isEmpty ? '(未命名工單)' : subject,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(status),
                              labelStyle: TextStyle(
                                color: _statusColor(status),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(priority),
                              labelStyle: TextStyle(
                                color: _priorityColor(priority),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              desc.isEmpty ? '(內容空白)' : desc,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.chat, size: 16),
                                  label: Text('channel: $channel'),
                                ),
                                if (userId.isNotEmpty)
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    avatar: const Icon(Icons.person, size: 16),
                                    label: Text('user: $userId'),
                                  ),
                                if (orderId.isNotEmpty)
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    avatar: const Icon(
                                      Icons.receipt_long,
                                      size: 16,
                                    ),
                                    label: Text('order: $orderId'),
                                  ),
                                if (assignedTo.isNotEmpty)
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    avatar: const Icon(
                                      Icons.assignment_ind,
                                      size: 16,
                                    ),
                                    label: Text('to: $assignedTo'),
                                  ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.add_circle_outline,
                                    size: 16,
                                  ),
                                  label: Text('created: $createdAt'),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.update, size: 16),
                                  label: Text('updated: $updatedAt'),
                                ),
                                if (tags.isNotEmpty)
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    avatar: const Icon(Icons.tag, size: 16),
                                    label: Text(tags.join(',')),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        trailing: SizedBox(
                          width: 160,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              PopupMenuButton<String>(
                                tooltip: '快速改狀態',
                                onSelected: (v) => _quickSetStatus(d.id, v),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'open',
                                    child: Text('open'),
                                  ),
                                  PopupMenuItem(
                                    value: 'in_progress',
                                    child: Text('in_progress'),
                                  ),
                                  PopupMenuItem(
                                    value: 'resolved',
                                    child: Text('resolved'),
                                  ),
                                  PopupMenuItem(
                                    value: 'closed',
                                    child: Text('closed'),
                                  ),
                                ],
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: Icon(Icons.more_vert),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                children: [
                                  IconButton(
                                    tooltip: '編輯',
                                    onPressed: _busy
                                        ? null
                                        : () =>
                                              _openEditor(id: d.id, initial: m),
                                    icon: const Icon(Icons.edit),
                                  ),
                                  IconButton(
                                    tooltip: '刪除',
                                    onPressed: _busy
                                        ? null
                                        : () => _delete(d.id),
                                    icon: const Icon(Icons.delete),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        onTap: _busy
                            ? null
                            : () => _openEditor(id: d.id, initial: m),
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

// =====================
// Editor Sheet
// =====================

class _TaskEditResult {
  const _TaskEditResult(this.payload);
  final Map<String, dynamic> payload;
}

class _SupportTaskEditorSheet extends StatefulWidget {
  const _SupportTaskEditorSheet({required this.taskId, required this.initial});

  final String? taskId;
  final Map<String, dynamic>? initial;

  @override
  State<_SupportTaskEditorSheet> createState() =>
      _SupportTaskEditorSheetState();
}

class _SupportTaskEditorSheetState extends State<_SupportTaskEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _subject;
  late final TextEditingController _description;
  late final TextEditingController _userId;
  late final TextEditingController _orderId;
  late final TextEditingController _assignedTo;
  late final TextEditingController _tags; // comma

  String _status = 'open';
  String _priority = 'normal';
  String _channel = 'app';

  @override
  void initState() {
    super.initState();
    final m = widget.initial ?? <String, dynamic>{};

    _subject = TextEditingController(text: (m['subject'] ?? '').toString());
    _description = TextEditingController(
      text: (m['description'] ?? '').toString(),
    );
    _userId = TextEditingController(text: (m['userId'] ?? '').toString());
    _orderId = TextEditingController(text: (m['orderId'] ?? '').toString());
    _assignedTo = TextEditingController(
      text: (m['assignedTo'] ?? '').toString(),
    );

    final tags = (m['tags'] is List)
        ? (m['tags'] as List)
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList()
        : <String>[];
    _tags = TextEditingController(text: tags.join(','));

    _status = (m['status'] ?? 'open').toString();
    _priority = (m['priority'] ?? 'normal').toString();
    _channel = (m['channel'] ?? 'app').toString();
  }

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    _userId.dispose();
    _orderId.dispose();
    _assignedTo.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final tags = _tags.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final payload = <String, dynamic>{
      'subject': _subject.text.trim(),
      'description': _description.text,
      'status': _status,
      'priority': _priority,
      'channel': _channel,
      'userId': _userId.text.trim(),
      'orderId': _orderId.text.trim(),
      'assignedTo': _assignedTo.text.trim(),
      'tags': tags,
    };

    Navigator.pop(context, _TaskEditResult(payload));
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.taskId == null;
    final pad = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: pad.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCreate ? '新增工單' : '編輯工單',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!isCreate) ...[
                  const SizedBox(height: 6),
                  Text(
                    'ID: ${widget.taskId}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _subject,
                  decoration: const InputDecoration(
                    labelText: '主旨 subject（必填）',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? '必填' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _description,
                  minLines: 6,
                  maxLines: 16,
                  decoration: const InputDecoration(
                    labelText: '描述 description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('sheet_status_$_status'),
                        initialValue: _status,
                        decoration: const InputDecoration(
                          labelText: '狀態 status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'open', child: Text('open')),
                          DropdownMenuItem(
                            value: 'in_progress',
                            child: Text('in_progress'),
                          ),
                          DropdownMenuItem(
                            value: 'resolved',
                            child: Text('resolved'),
                          ),
                          DropdownMenuItem(
                            value: 'closed',
                            child: Text('closed'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _status = v ?? 'open'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('sheet_priority_$_priority'),
                        initialValue: _priority,
                        decoration: const InputDecoration(
                          labelText: '優先度 priority',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('low')),
                          DropdownMenuItem(
                            value: 'normal',
                            child: Text('normal'),
                          ),
                          DropdownMenuItem(value: 'high', child: Text('high')),
                          DropdownMenuItem(
                            value: 'urgent',
                            child: Text('urgent'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _priority = v ?? 'normal'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey('sheet_channel_$_channel'),
                  initialValue: _channel,
                  decoration: const InputDecoration(
                    labelText: '來源 channel',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'app', child: Text('app')),
                    DropdownMenuItem(value: 'line', child: Text('line')),
                    DropdownMenuItem(value: 'fb', child: Text('fb')),
                    DropdownMenuItem(value: 'phone', child: Text('phone')),
                    DropdownMenuItem(value: 'email', child: Text('email')),
                    DropdownMenuItem(value: 'other', child: Text('other')),
                  ],
                  onChanged: (v) => setState(() => _channel = v ?? 'app'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _userId,
                        decoration: const InputDecoration(
                          labelText: 'userId',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _orderId,
                        decoration: const InputDecoration(
                          labelText: 'orderId',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _assignedTo,
                  decoration: const InputDecoration(
                    labelText: '指派給 assignedTo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _tags,
                  decoration: const InputDecoration(
                    labelText: 'tags（逗號分隔）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save),
                    label: const Text('保存'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
