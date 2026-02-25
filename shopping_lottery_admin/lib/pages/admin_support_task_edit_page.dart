// lib/pages/admin_support_task_edit_page.dart
//
// ✅ AdminSupportTaskEditPage（最終完整版｜可編譯｜修正 use_build_context_synchronously + Dropdown value deprecated）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSupportTaskEditPage extends StatefulWidget {
  const AdminSupportTaskEditPage({
    super.key,
    this.taskId, // null => 新增
    this.collection = 'support_tasks',
  });

  final String? taskId;
  final String collection;

  @override
  State<AdminSupportTaskEditPage> createState() =>
      _AdminSupportTaskEditPageState();
}

class _AdminSupportTaskEditPageState extends State<AdminSupportTaskEditPage> {
  final _db = FirebaseFirestore.instance;

  late final DocumentReference<Map<String, dynamic>> _ref = _db
      .collection(widget.collection)
      .doc(widget.taskId ?? _db.collection(widget.collection).doc().id);

  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _assigneeCtrl = TextEditingController();
  final _vendorIdCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  String _status = 'open';
  String _priority = 'normal';
  DateTime? _dueAt;

  bool _loading = true;
  bool _saving = false;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _loadOnce();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _assigneeCtrl.dispose();
    _vendorIdCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();
  DateTime? _toDate(dynamic v) =>
      v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y/$m/$day';
  }

  List<String> _parseTags(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return <String>[];
    return s
        .split(RegExp(r'[,，\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _loadOnce() async {
    setState(() => _loading = true);
    try {
      final snap = await _ref.get();
      if (!mounted) return;

      if (snap.exists) {
        final d = snap.data() ?? <String, dynamic>{};
        _hydrateFrom(d);
      } else {
        _hydrated = true;
      }
    } catch (e) {
      if (!mounted) return;
      _snack('讀取失敗：$e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _hydrateFrom(Map<String, dynamic> d) {
    if (_hydrated) return;

    _titleCtrl.text = _s(d['title']);
    _descCtrl.text = _s(d['description']);
    _assigneeCtrl.text = _s(d['assigneeUid']);
    _vendorIdCtrl.text = _s(d['vendorId']);

    final tags = (d['tags'] is List)
        ? List<String>.from(d['tags'])
        : <String>[];
    _tagsCtrl.text = tags.join(', ');

    _status = _s(d['status']).isEmpty ? 'open' : _s(d['status']);
    _priority = _s(d['priority']).isEmpty ? 'normal' : _s(d['priority']);
    _dueAt = _toDate(d['dueAt']);

    _hydrated = true;
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initial = _dueAt ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(
      () =>
          _dueAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final messenger = mounted ? ScaffoldMessenger.of(context) : null;
    final nav = mounted ? Navigator.of(context) : null;

    try {
      final now = FieldValue.serverTimestamp();

      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'status': _status,
        'priority': _priority,
        'assigneeUid': _assigneeCtrl.text.trim(),
        'vendorId': _vendorIdCtrl.text.trim(),
        'tags': _parseTags(_tagsCtrl.text),
        'updatedAt': now,
        'createdAt': now,
        if (_dueAt != null) 'dueAt': Timestamp.fromDate(_dueAt!),
        if (_dueAt == null) 'dueAt': FieldValue.delete(),
      };

      await _ref.set(payload, SetOptions(merge: true));

      if (!mounted) return;
      messenger?.showSnackBar(const SnackBar(content: Text('已儲存')));
      nav?.pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.taskId == null) {
      _snack('新增模式無法刪除');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除任務'),
        content: const Text('確定要刪除？此動作無法復原。'),
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

    setState(() => _saving = true);

    final messenger = mounted ? ScaffoldMessenger.of(context) : null;
    final nav = mounted ? Navigator.of(context) : null;

    try {
      await _ref.delete();
      if (!mounted) return;
      messenger?.showSnackBar(const SnackBar(content: Text('已刪除')));
      nav?.pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.taskId == null;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? '新增客服任務' : '編輯客服任務'),
        actions: [
          if (!isNew)
            IconButton(
              tooltip: '刪除',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          IconButton(
            tooltip: '儲存',
            onPressed: (_loading || _saving) ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    elevation: 0.6,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '基本資訊',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(
                              labelText: '標題（必填）',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v ?? '').trim().isEmpty ? '必填' : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _descCtrl,
                            minLines: 5,
                            maxLines: 12,
                            decoration: const InputDecoration(
                              labelText: '描述/內容',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Card(
                    elevation: 0.6,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '狀態與指派',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  // ✅ 修正：value deprecated -> initialValue
                                  // ✅ 加 key 確保 initialValue 會跟著 state 更新
                                  key: ValueKey('status_$_status'),
                                  initialValue: _status,
                                  decoration: const InputDecoration(
                                    labelText: '狀態',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'open',
                                      child: Text('open'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'in_progress',
                                      child: Text('in_progress'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'done',
                                      child: Text('done'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'canceled',
                                      child: Text('canceled'),
                                    ),
                                  ],
                                  onChanged: _saving
                                      ? null
                                      : (v) => setState(
                                          () => _status = (v ?? 'open'),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('priority_$_priority'),
                                  initialValue: _priority,
                                  decoration: const InputDecoration(
                                    labelText: '優先度',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'low',
                                      child: Text('low'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'normal',
                                      child: Text('normal'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'high',
                                      child: Text('high'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'urgent',
                                      child: Text('urgent'),
                                    ),
                                  ],
                                  onChanged: _saving
                                      ? null
                                      : (v) => setState(
                                          () => _priority = (v ?? 'normal'),
                                        ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _assigneeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'assigneeUid（可空）',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _vendorIdCtrl,
                            decoration: const InputDecoration(
                              labelText: 'vendorId（可空）',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Card(
                    elevation: 0.6,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '到期日與標籤',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _saving ? null : _pickDueDate,
                                  icon: const Icon(Icons.event_outlined),
                                  label: Text(
                                    _dueAt == null
                                        ? '設定到期日'
                                        : '到期：${_fmtDate(_dueAt)}',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              TextButton(
                                onPressed: (_saving || _dueAt == null)
                                    ? null
                                    : () => setState(() => _dueAt = null),
                                child: Text(
                                  '清除',
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _tagsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'tags（用逗號或空白分隔）',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  FilledButton.icon(
                    onPressed: (_saving || _loading) ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? '儲存中...' : '儲存'),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
