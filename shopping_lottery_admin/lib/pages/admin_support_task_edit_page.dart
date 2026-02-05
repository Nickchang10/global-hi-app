// lib/pages/admin_support_task_edit_page.dart
//
// ✅ AdminSupportTaskEditPage（最終完整版｜新增/編輯客服任務｜指派+到期+通知）
// ------------------------------------------------------------
// - Admin 可選 vendorId、可指派任務給 users
// - Vendor 只能寫自己的 vendorId（用 AdminGate vendorId 限制）
// - 儲存後若有 assigneeUid → 發送通知到該使用者
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';
import '../services/notification_service.dart';

class AdminSupportTaskEditPage extends StatefulWidget {
  final String? taskId;
  const AdminSupportTaskEditPage({super.key, this.taskId});

  @override
  State<AdminSupportTaskEditPage> createState() => _AdminSupportTaskEditPageState();
}

class _AdminSupportTaskEditPageState extends State<AdminSupportTaskEditPage> {
  final _db = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _vendorCtrl = TextEditingController(); // fallback when no vendors dropdown
  final _assigneeEmailCtrl = TextEditingController(); // bind by email
  final _tagsCtrl = TextEditingController();

  String _status = 'new';
  String _priority = 'normal';
  bool _isActive = true;

  DateTime? _dueAt;

  bool _loading = false;
  bool _saving = false;

  // role
  Future<RoleInfo>? _roleFuture;
  String? _lastUid;
  String _role = '';
  String? _vendorId;

  // assignee
  String? _assigneeUid;
  String? _assigneeName;
  String? _assigneeEmail;

  bool get _isEdit => widget.taskId != null;

  @override
  void initState() {
    super.initState();
    _primeRole();
  }

  void _primeRole() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final gate = context.read<AdminGate>();
    if (_roleFuture == null || _lastUid != user.uid) {
      _lastUid = user.uid;
      _roleFuture = gate.ensureAndGetRole(user, forceRefresh: false);
      if (_isEdit) _load();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _vendorCtrl.dispose();
    _assigneeEmailCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _s(dynamic v) => (v ?? '').toString().trim();
  DateTime? _toDate(dynamic v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  Future<void> _load() async {
    if (!_isEdit) return;
    setState(() => _loading = true);
    try {
      final doc = await _db.collection('supportTasks').doc(widget.taskId).get();
      if (!doc.exists) return;
      final d = doc.data() ?? {};

      setState(() {
        _titleCtrl.text = _s(d['title']);
        _descCtrl.text = _s(d['description']);
        _status = _s(d['status']).isEmpty ? 'new' : _s(d['status']);
        _priority = _s(d['priority']).isEmpty ? 'normal' : _s(d['priority']);
        _isActive = d['isActive'] == true;

        final vendorId = _s(d['vendorId']);
        _vendorCtrl.text = vendorId;

        _assigneeUid = _s(d['assigneeUid']).isEmpty ? null : _s(d['assigneeUid']);
        _assigneeName = _s(d['assigneeName']).isEmpty ? null : _s(d['assigneeName']);
        _assigneeEmail = _s(d['assigneeEmail']).isEmpty ? null : _s(d['assigneeEmail']);
        _assigneeEmailCtrl.text = _assigneeEmail ?? '';

        _dueAt = _toDate(d['dueAt']);

        final tags = (d['tags'] is List) ? List<String>.from(d['tags'] as List) : <String>[];
        _tagsCtrl.text = tags.join(', ');
      });
    } catch (e) {
      _snack('載入失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final base = _dueAt ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;

    setState(() {
      _dueAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _clearDueDate() async {
    setState(() => _dueAt = null);
  }

  // -------------------------
  // Bind assignee by users.email
  // -------------------------
  Future<void> _bindAssigneeByEmail() async {
    final email = _assigneeEmailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      _snack('請輸入指派 Email（users.email）');
      return;
    }

    try {
      final snap = await _db.collection('users').where('email', isEqualTo: email).limit(20).get();
      if (snap.docs.isEmpty) {
        _snack('找不到 users.email = $email（請確認 users 文件有寫入 email 欄位）');
        return;
      }

      DocumentSnapshot<Map<String, dynamic>> picked = snap.docs.first;

      if (snap.docs.length > 1) {
        final uid = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('選擇要指派的使用者'),
            content: SizedBox(
              width: 420,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final d in snap.docs)
                    ListTile(
                      title: Text(_s(d.data()['displayName']).isEmpty ? d.id : _s(d.data()['displayName'])),
                      subtitle: Text('uid: ${d.id}'),
                      onTap: () => Navigator.pop(context, d.id),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            ],
          ),
        );
        if (uid == null) return;
        picked = snap.docs.firstWhere((e) => e.id == uid);
      }

      final data = picked.data() ?? {};
      setState(() {
        _assigneeUid = picked.id;
        _assigneeName = _s(data['displayName']).isEmpty ? null : _s(data['displayName']);
        _assigneeEmail = _s(data['email']).isEmpty ? email : _s(data['email']);
      });

      _snack('已綁定指派人：${_assigneeEmail ?? picked.id}');
    } catch (e) {
      _snack('綁定指派人失敗：$e');
    }
  }

  Future<void> _clearAssignee() async {
    setState(() {
      _assigneeUid = null;
      _assigneeName = null;
      _assigneeEmail = null;
      _assigneeEmailCtrl.clear();
    });
  }

  List<String> _parseTags(String raw) {
    final parts = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    // unique preserve order
    final seen = <String>{};
    final out = <String>[];
    for (final t in parts) {
      final k = t.toLowerCase();
      if (seen.add(k)) out.add(t);
    }
    return out;
  }

  Future<void> _save(RoleInfo info) async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final role = (info.role).toLowerCase().trim();
    final isAdmin = role == 'admin';
    final isVendor = role == 'vendor';

    // vendor must have vendorId
    final vendorIdFinal = isVendor ? (info.vendorId ?? '').trim() : _vendorCtrl.text.trim();
    if (isVendor && vendorIdFinal.isEmpty) {
      _snack('Vendor 帳號缺少 vendorId，無法建立任務');
      return;
    }

    final payload = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'status': _status,
      'priority': _priority,
      'vendorId': vendorIdFinal.isEmpty ? null : vendorIdFinal,
      'assigneeUid': _assigneeUid,
      'assigneeName': _assigneeName,
      'assigneeEmail': _assigneeEmail,
      'dueAt': _dueAt == null ? null : Timestamp.fromDate(_dueAt!),
      'tags': _parseTags(_tagsCtrl.text),
      'isActive': _isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // avoid writing nulls as fields if you prefer:
    payload.removeWhere((k, v) => v == null);

    setState(() => _saving = true);
    try {
      final ref = _isEdit
          ? _db.collection('supportTasks').doc(widget.taskId)
          : _db.collection('supportTasks').doc();

      if (_isEdit) {
        await ref.set(payload, SetOptions(merge: true));
      } else {
        await ref.set({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // send notification to assignee (best effort)
      if ((_assigneeUid ?? '').trim().isNotEmpty) {
        try {
          final notif = context.read<NotificationService>();
          await notif.sendToUser(
            uid: _assigneeUid!.trim(),
            title: '你有新的客服任務',
            body: '任務：${_titleCtrl.text.trim()}（狀態：${_statusLabel(_status)}）',
            type: 'support_task',
            route: '/admin_support_tasks',
            extra: <String, dynamic>{
              'taskId': ref.id,
              if (vendorIdFinal.isNotEmpty) 'vendorId': vendorIdFinal,
              'status': _status,
              'priority': _priority,
            },
          );
        } catch (_) {
          // ignore notification failure
        }
      }

      if (!mounted) return;
      _snack('已儲存');
      Navigator.pop(context, true);
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _primeRole();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('請登入')));

    return FutureBuilder<RoleInfo>(
      future: _roleFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting || _loading) {
          return Scaffold(
            appBar: AppBar(title: Text(_isEdit ? '編輯客服任務' : '新增客服任務')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final info = snap.data;
        if (info == null || info.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('客服任務')),
            body: Center(child: Text(info?.error ?? '讀取角色失敗')),
          );
        }

        final role = info.role.toLowerCase().trim();
        final isAdmin = role == 'admin';
        final isVendor = role == 'vendor';

        if (_role != role) _role = role;
        if (_vendorId != info.vendorId) _vendorId = info.vendorId;

        if (isVendor && (_vendorId ?? '').trim().isEmpty) {
          return const Scaffold(
            body: Center(child: Text('Vendor 帳號缺少 vendorId，請在 users/{uid} 補上 vendorId')),
          );
        }

        final title = _isEdit ? '編輯客服任務' : '新增客服任務';

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              IconButton(
                tooltip: '儲存',
                onPressed: _saving ? null : () => _save(info),
                icon: const Icon(Icons.save_outlined),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: Stack(
            children: [
              Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: '任務標題',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty ? '請輸入任務標題' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _descCtrl,
                      minLines: 3,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: '任務描述',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _status,
                            decoration: const InputDecoration(
                              labelText: '狀態',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'new', child: Text('未處理')),
                              DropdownMenuItem(value: 'in_progress', child: Text('處理中')),
                              DropdownMenuItem(value: 'waiting', child: Text('等待回覆')),
                              DropdownMenuItem(value: 'resolved', child: Text('已解決')),
                              DropdownMenuItem(value: 'closed', child: Text('已關閉')),
                            ],
                            onChanged: _saving ? null : (v) => setState(() => _status = v ?? 'new'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _priority,
                            decoration: const InputDecoration(
                              labelText: '優先級',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'low', child: Text('低')),
                              DropdownMenuItem(value: 'normal', child: Text('一般')),
                              DropdownMenuItem(value: 'high', child: Text('高')),
                              DropdownMenuItem(value: 'urgent', child: Text('緊急')),
                            ],
                            onChanged: _saving ? null : (v) => setState(() => _priority = v ?? 'normal'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (isAdmin)
                      TextFormField(
                        controller: _vendorCtrl,
                        decoration: const InputDecoration(
                          labelText: 'vendorId（管理員可選填）',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Text(
                          'vendorId：${(_vendorId ?? '').isEmpty ? '(未設定)' : _vendorId}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // assignee
                    const Text('指派客服（選填）', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _assigneeEmailCtrl,
                            decoration: const InputDecoration(
                              hintText: '輸入 users.email 綁定指派人',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: _saving ? null : _bindAssigneeByEmail,
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('綁定'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if ((_assigneeUid ?? '').trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '已指派：${_assigneeName ?? ''} ${_assigneeEmail ?? ''}\nuid: ${_assigneeUid!}',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            TextButton(onPressed: _saving ? null : _clearAssignee, child: const Text('清除')),
                          ],
                        ),
                      ),

                    const Divider(height: 26),

                    // due date
                    const Text('到期時間（選填）', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).dividerColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _dueAt == null ? '未設定' : _fmtDateTime(_dueAt!),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _pickDueDate,
                          icon: const Icon(Icons.event),
                          label: const Text('設定'),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: (_saving || _dueAt == null) ? null : _clearDueDate,
                          child: const Text('清除'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: _tagsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tags（逗號分隔）',
                        hintText: '例如：退款, 出貨, 保固',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),

                    const SizedBox(height: 8),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('啟用狀態', style: TextStyle(fontWeight: FontWeight.w800)),
                      value: _isActive,
                      onChanged: _saving ? null : (v) => setState(() => _isActive = v),
                    ),

                    const SizedBox(height: 18),

                    FilledButton.icon(
                      onPressed: _saving ? null : () => _save(info),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('儲存'),
                    ),
                  ],
                ),
              ),

              if (_saving)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Material(
                    elevation: 10,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: const [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 10),
                          Expanded(child: Text('儲存中...', style: TextStyle(fontWeight: FontWeight.w800))),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'new':
        return '未處理';
      case 'in_progress':
        return '處理中';
      case 'waiting':
        return '等待回覆';
      case 'resolved':
        return '已解決';
      case 'closed':
        return '已關閉';
      default:
        return s;
    }
  }

  static String _fmtDateTime(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y/$m/$day $hh:$mm';
  }
}
