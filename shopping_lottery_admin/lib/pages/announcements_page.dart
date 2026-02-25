// lib/pages/announcements_page.dart
//
// ✅ AnnouncementsPage（正式版｜完整版｜可直接編譯｜已修正 lint）
//
// Firestore：announcements/{id}
// 建議欄位：
// - title: String
// - body: String
// - level: String              // info / warning / urgent
// - status: String             // draft / published / archived
// - audience: String           // all_users / members / vendors / admins
// - pinned: bool
// - enabled: bool
// - startAt: Timestamp?        // 公告開始顯示（可空）
// - endAt: Timestamp?          // 公告結束顯示（可空）
// - createdAt, updatedAt: Timestamp
//
// ✅ 修正點：
// 1) extends_non_class：確保 AnnouncementsPage class 先宣告，再讓別名頁 extends 它
// 2) use_build_context_synchronously：
//    - State.context 的 async gap 後，用 `if (!mounted) return;`（不要用 context.mounted 來 guard State.context）
//    - Dialog / BottomSheet 內的 Navigator.pop 使用 dialogCtx/sheetCtx，避免用外層 context

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

/// ✅ 兼容你原本 AdminShellPage 可能用的名稱
class AdminInternalAnnouncementsPage extends AnnouncementsPage {
  const AdminInternalAnnouncementsPage({super.key});
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final _searchCtrl = TextEditingController();
  bool _busy = false;

  String _status = 'all';
  String _level = 'all';
  String _audience = 'all';
  bool _pinnedOnly = false;

  CollectionReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('announcements');

  static const _statusAllowed = {'all', 'draft', 'published', 'archived'};
  static const _levelAllowed = {'all', 'info', 'warning', 'urgent'};
  static const _audAllowed = {
    'all',
    'all_users',
    'members',
    'vendors',
    'admins',
  };

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

  Query<Map<String, dynamic>> _query() {
    return _ref
        .orderBy('pinned', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(600);
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

  String _fmtDateTime(dynamic v) {
    final dt = _toDate(v);
    if (dt == null) return '-';
    final l = dt.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-'
        '${l.month.toString().padLeft(2, '0')}-'
        '${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  bool _matchKeyword(String keyword, String id, Map<String, dynamic> m) {
    if (keyword.isEmpty) return true;
    final k = keyword.toLowerCase();
    String s(String key) => (m[key] ?? '').toString().toLowerCase();
    return id.toLowerCase().contains(k) ||
        s('title').contains(k) ||
        s('body').contains(k) ||
        s('level').contains(k) ||
        s('status').contains(k) ||
        s('audience').contains(k);
  }

  bool _matchFilters(Map<String, dynamic> m) {
    final status = (m['status'] ?? 'draft').toString();
    final level = (m['level'] ?? 'info').toString();
    final aud = (m['audience'] ?? 'all_users').toString();
    final pinned = m['pinned'] == true;

    if (_status != 'all' && status != _status) return false;
    if (_level != 'all' && level != _level) return false;
    if (_audience != 'all' && aud != _audience) return false;
    if (_pinnedOnly && !pinned) return false;

    return true;
  }

  Color _levelColor(String lv) {
    switch (lv) {
      case 'urgent':
        return Colors.red;
      case 'warning':
        return Colors.deepOrange;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _levelIcon(String lv) {
    switch (lv) {
      case 'urgent':
        return Icons.report;
      case 'warning':
        return Icons.warning_amber;
      default:
        return Icons.info_outline;
    }
  }

  Future<void> _openEditor({String? id, Map<String, dynamic>? initial}) async {
    final res = await showModalBottomSheet<_AnnouncementEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => _AnnouncementEditorSheet(id: id, initial: initial),
    );
    if (res == null) return;

    // ✅ State.context 的 async gap 後，用 mounted
    if (!mounted) return;
    setState(() => _busy = true);

    try {
      final payload = <String, dynamic>{
        ...res.payload,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (id == null) {
        await _ref.add({...payload, 'createdAt': FieldValue.serverTimestamp()});
        _snack('已新增公告');
      } else {
        await _ref.doc(id).set(payload, SetOptions(merge: true));
        _snack('已更新公告');
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
      builder: (dialogCtx) => AlertDialog(
        title: const Text('刪除公告'),
        content: Text('確定要刪除公告 id=$id 嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    if (!mounted) return;
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

  Future<void> _toggle(String id, String key, bool v) async {
    try {
      await _ref.doc(id).set({
        key: v,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _snack('更新失敗：$e', error: true);
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

  @override
  Widget build(BuildContext context) {
    final keyword = _searchCtrl.text.trim();

    final safeStatus = _statusAllowed.contains(_status) ? _status : 'all';
    final safeLevel = _levelAllowed.contains(_level) ? _level : 'all';
    final safeAudience = _audAllowed.contains(_audience) ? _audience : 'all';

    return Scaffold(
      appBar: AppBar(
        title: const Text('公告管理'),
        actions: [
          IconButton(
            tooltip: '新增公告',
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
                        '搜尋：title / body / status / level / audience / id',
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
                        initialValue: safeStatus,
                        decoration: InputDecoration(
                          labelText: '狀態',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('全部')),
                          DropdownMenuItem(
                            value: 'draft',
                            child: Text('draft'),
                          ),
                          DropdownMenuItem(
                            value: 'published',
                            child: Text('published'),
                          ),
                          DropdownMenuItem(
                            value: 'archived',
                            child: Text('archived'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _status = v ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: safeLevel,
                        decoration: InputDecoration(
                          labelText: '等級',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('全部')),
                          DropdownMenuItem(value: 'info', child: Text('info')),
                          DropdownMenuItem(
                            value: 'warning',
                            child: Text('warning'),
                          ),
                          DropdownMenuItem(
                            value: 'urgent',
                            child: Text('urgent'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _level = v ?? 'all'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: safeAudience,
                        decoration: InputDecoration(
                          labelText: '受眾',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('全部')),
                          DropdownMenuItem(
                            value: 'all_users',
                            child: Text('all_users'),
                          ),
                          DropdownMenuItem(
                            value: 'members',
                            child: Text('members'),
                          ),
                          DropdownMenuItem(
                            value: 'vendors',
                            child: Text('vendors'),
                          ),
                          DropdownMenuItem(
                            value: 'admins',
                            child: Text('admins'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _audience = v ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('只看置頂'),
                        value: _pinnedOnly,
                        onChanged: (v) => setState(() => _pinnedOnly = v),
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
                      return _matchFilters(m) &&
                          _matchKeyword(keyword, d.id, m);
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

                    final title = (m['title'] ?? '').toString().trim();
                    final body = (m['body'] ?? '').toString().trim();
                    final level = (m['level'] ?? 'info').toString();
                    final status = (m['status'] ?? 'draft').toString();
                    final audience = (m['audience'] ?? 'all_users').toString();
                    final pinned = m['pinned'] == true;
                    final enabled = m['enabled'] != false;

                    final startAt = m['startAt'];
                    final endAt = m['endAt'];
                    final createdAt = m['createdAt'];
                    final updatedAt = m['updatedAt'];

                    final now = DateTime.now();
                    final sdt = _toDate(startAt);
                    final edt = _toDate(endAt);
                    final inWindow =
                        (sdt == null || !now.isBefore(sdt)) &&
                        (edt == null || now.isBefore(edt));

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
                            _levelIcon(level),
                            color: _levelColor(level),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title.isEmpty ? '(未命名公告)' : title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (pinned)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.push_pin, size: 18),
                              ),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(status),
                            ),
                            const SizedBox(width: 6),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(level),
                              labelStyle: TextStyle(color: _levelColor(level)),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              body.isEmpty ? '(內容空白)' : body,
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
                                  avatar: const Icon(Icons.people, size: 16),
                                  label: Text('aud: $audience'),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.play_circle_outline,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'start: ${_fmtDateTime(startAt)}',
                                  ),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.stop_circle_outlined,
                                    size: 16,
                                  ),
                                  label: Text('end: ${_fmtDateTime(endAt)}'),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.add_circle_outline,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'created: ${_fmtDateTime(createdAt)}',
                                  ),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.update, size: 16),
                                  label: Text(
                                    'updated: ${_fmtDateTime(updatedAt)}',
                                  ),
                                ),
                                if (!inWindow)
                                  const Chip(
                                    visualDensity: VisualDensity.compact,
                                    avatar: Icon(Icons.timer_off, size: 16),
                                    label: Text('不在有效期間'),
                                  ),
                                if (!enabled)
                                  const Chip(
                                    visualDensity: VisualDensity.compact,
                                    avatar: Icon(Icons.block, size: 16),
                                    label: Text('停用'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        trailing: SizedBox(
                          width: 170,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Text(
                                    '啟用',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Switch(
                                    value: enabled,
                                    onChanged: _busy
                                        ? null
                                        : (v) => _toggle(d.id, 'enabled', v),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Wrap(
                                spacing: 4,
                                children: [
                                  PopupMenuButton<String>(
                                    tooltip: '快速改狀態',
                                    onSelected: (v) => _quickSetStatus(d.id, v),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'draft',
                                        child: Text('draft'),
                                      ),
                                      PopupMenuItem(
                                        value: 'published',
                                        child: Text('published'),
                                      ),
                                      PopupMenuItem(
                                        value: 'archived',
                                        child: Text('archived'),
                                      ),
                                    ],
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 6,
                                        horizontal: 6,
                                      ),
                                      child: Icon(Icons.more_vert),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: pinned ? '取消置頂' : '置頂',
                                    onPressed: _busy
                                        ? null
                                        : () =>
                                              _toggle(d.id, 'pinned', !pinned),
                                    icon: Icon(
                                      pinned
                                          ? Icons.push_pin
                                          : Icons.push_pin_outlined,
                                    ),
                                  ),
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

class _AnnouncementEditResult {
  const _AnnouncementEditResult(this.payload);
  final Map<String, dynamic> payload;
}

class _AnnouncementEditorSheet extends StatefulWidget {
  const _AnnouncementEditorSheet({required this.id, required this.initial});

  final String? id;
  final Map<String, dynamic>? initial;

  @override
  State<_AnnouncementEditorSheet> createState() =>
      _AnnouncementEditorSheetState();
}

class _AnnouncementEditorSheetState extends State<_AnnouncementEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _body;

  String _level = 'info';
  String _status = 'draft';
  String _audience = 'all_users';
  bool _pinned = false;
  bool _enabled = true;

  DateTime? _startAt;
  DateTime? _endAt;

  static const _levelAllowed = {'info', 'warning', 'urgent'};
  static const _statusAllowed = {'draft', 'published', 'archived'};
  static const _audAllowed = {'all_users', 'members', 'vendors', 'admins'};

  @override
  void initState() {
    super.initState();
    final m = widget.initial ?? <String, dynamic>{};

    _title = TextEditingController(text: (m['title'] ?? '').toString());
    _body = TextEditingController(text: (m['body'] ?? '').toString());

    _level = (m['level'] ?? 'info').toString();
    _status = (m['status'] ?? 'draft').toString();
    _audience = (m['audience'] ?? 'all_users').toString();
    _pinned = m['pinned'] == true;
    _enabled = m['enabled'] != false;

    final s = m['startAt'];
    final e = m['endAt'];
    if (s is Timestamp) _startAt = s.toDate();
    if (s is DateTime) _startAt = s;
    if (e is Timestamp) _endAt = e.toDate();
    if (e is DateTime) _endAt = e;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '-';
    final l = dt.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-'
        '${l.month.toString().padLeft(2, '0')}-'
        '${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  Future<DateTime?> _pickDateTime(DateTime? current) async {
    final now = DateTime.now();
    final base = current ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null) return null;

    // ✅ State.context 的 async gap 後：用 mounted（不要用 context.mounted 來 guard State.context）
    if (!mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return null;

    if (!mounted) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final payload = <String, dynamic>{
      'title': _title.text.trim(),
      'body': _body.text,
      'level': _level,
      'status': _status,
      'audience': _audience,
      'pinned': _pinned,
      'enabled': _enabled,
      'startAt': _startAt == null ? null : Timestamp.fromDate(_startAt!),
      'endAt': _endAt == null ? null : Timestamp.fromDate(_endAt!),
    };

    // 這裡是同步操作，不存在 async gap
    Navigator.pop(context, _AnnouncementEditResult(payload));
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.id == null;
    final pad = MediaQuery.of(context).viewInsets;

    final safeLevel = _levelAllowed.contains(_level) ? _level : 'info';
    final safeStatus = _statusAllowed.contains(_status) ? _status : 'draft';
    final safeAudience = _audAllowed.contains(_audience)
        ? _audience
        : 'all_users';

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
                  isCreate ? '新增公告' : '編輯公告',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!isCreate) ...[
                  const SizedBox(height: 6),
                  Text(
                    'ID: ${widget.id}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
                const SizedBox(height: 14),

                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: '標題（必填）',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? '必填' : null,
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _body,
                  minLines: 6,
                  maxLines: 18,
                  decoration: const InputDecoration(
                    labelText: '內容 body',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: safeLevel,
                        decoration: const InputDecoration(
                          labelText: 'level',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'info', child: Text('info')),
                          DropdownMenuItem(
                            value: 'warning',
                            child: Text('warning'),
                          ),
                          DropdownMenuItem(
                            value: 'urgent',
                            child: Text('urgent'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _level = v ?? 'info'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: safeStatus,
                        decoration: const InputDecoration(
                          labelText: 'status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'draft',
                            child: Text('draft'),
                          ),
                          DropdownMenuItem(
                            value: 'published',
                            child: Text('published'),
                          ),
                          DropdownMenuItem(
                            value: 'archived',
                            child: Text('archived'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _status = v ?? 'draft'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  initialValue: safeAudience,
                  decoration: const InputDecoration(
                    labelText: 'audience',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'all_users',
                      child: Text('all_users'),
                    ),
                    DropdownMenuItem(value: 'members', child: Text('members')),
                    DropdownMenuItem(value: 'vendors', child: Text('vendors')),
                    DropdownMenuItem(value: 'admins', child: Text('admins')),
                  ],
                  onChanged: (v) =>
                      setState(() => _audience = v ?? 'all_users'),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('pinned（置頂）'),
                        value: _pinned,
                        onChanged: (v) => setState(() => _pinned = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('enabled（啟用）'),
                        value: _enabled,
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Card(
                  elevation: 0.4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.play_circle_outline),
                            const SizedBox(width: 10),
                            Expanded(child: Text('startAt: ${_fmt(_startAt)}')),
                            TextButton.icon(
                              onPressed: () async {
                                final dt = await _pickDateTime(_startAt);
                                if (dt == null) return;
                                if (!mounted) return;
                                setState(() => _startAt = dt);
                              },
                              icon: const Icon(Icons.edit_calendar),
                              label: const Text('選擇'),
                            ),
                            const SizedBox(width: 6),
                            TextButton(
                              onPressed: () => setState(() => _startAt = null),
                              child: const Text('清除'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.stop_circle_outlined),
                            const SizedBox(width: 10),
                            Expanded(child: Text('endAt: ${_fmt(_endAt)}')),
                            TextButton.icon(
                              onPressed: () async {
                                final dt = await _pickDateTime(_endAt);
                                if (dt == null) return;
                                if (!mounted) return;
                                setState(() => _endAt = dt);
                              },
                              icon: const Icon(Icons.edit_calendar),
                              label: const Text('選擇'),
                            ),
                            const SizedBox(width: 6),
                            TextButton(
                              onPressed: () => setState(() => _endAt = null),
                              child: const Text('清除'),
                            ),
                          ],
                        ),
                        if (_startAt != null &&
                            _endAt != null &&
                            _endAt!.isBefore(_startAt!)) ...[
                          const SizedBox(height: 10),
                          const Text(
                            '⚠ endAt 不能早於 startAt',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ],
                    ),
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
