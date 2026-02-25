// lib/pages/admin_site_notifications_page.dart
//
// ✅ AdminSiteNotificationsPage（最終完整版｜可編譯｜站內公告/通知管理）
// ------------------------------------------------------------
// Firestore：site_notifications/{id}
// fields (建議):
// - title: String
// - content: String
// - type: String (general/system/promo/order/support...)
// - route: String? (點擊導向)
// - isActive: bool
// - startAt: Timestamp? (選填)
// - endAt: Timestamp? (選填)
// - createdAt, updatedAt: Timestamp
//
// 功能：
// - Admin：新增/編輯/刪除/上下架
// - 搜尋
// - type 篩選
// - 時間區間設定（選填）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSiteNotificationsPage extends StatefulWidget {
  const AdminSiteNotificationsPage({
    super.key,
    this.collection = 'site_notifications',
    this.limit = 500,
  });

  final String collection;
  final int limit;

  @override
  State<AdminSiteNotificationsPage> createState() =>
      _AdminSiteNotificationsPageState();
}

class _AdminSiteNotificationsPageState
    extends State<AdminSiteNotificationsPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _q = '';

  static const _typeAll = 'all';
  String _typeFilter = _typeAll;

  final List<String> _typeOptions = const [
    _typeAll,
    'general',
    'system',
    'promo',
    'order',
    'support',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  DateTime? _toDate(dynamic v) => v is Timestamp ? v.toDate() : null;

  String _fmtTime(DateTime? d) {
    if (d == null) return '-';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y/$m/$day $hh:$mm';
  }

  Query<Map<String, dynamic>> _query() {
    return _db
        .collection(widget.collection)
        .orderBy('createdAt', descending: true)
        .limit(widget.limit);
  }

  bool _matchSearch(Map<String, dynamic> d, String docId, String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return true;

    final hay = [
      docId,
      _s(d['title']),
      _s(d['content']),
      _s(d['type']),
      _s(d['route']),
    ].join(' ').toLowerCase();

    return hay.contains(s);
  }

  bool _matchType(Map<String, dynamic> d) {
    if (_typeFilter == _typeAll) return true;
    return _s(d['type']).toLowerCase() == _typeFilter.toLowerCase();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _create() async {
    try {
      final ref = _db.collection(widget.collection).doc();
      final now = FieldValue.serverTimestamp();
      await ref.set({
        'title': '新公告',
        'content': '',
        'type': 'general',
        'route': '',
        'isActive': true,
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      if (!mounted) return;
      await _openEditSheet(id: ref.id);
    } catch (e) {
      _snack('新增失敗：$e');
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除公告'),
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

    try {
      await _db.collection(widget.collection).doc(id).delete();
      _snack('已刪除');
    } catch (e) {
      _snack('刪除失敗：$e');
    }
  }

  Future<void> _toggleActive(DocumentSnapshot<Map<String, dynamic>> doc) async {
    try {
      final cur = doc.data()?['isActive'] == true;
      await doc.reference.set({
        'isActive': !cur,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _snack('更新失敗：$e');
    }
  }

  Future<void> _openEditSheet({required String id}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditSheet(collection: widget.collection, id: id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('站內公告/通知'),
        actions: [
          IconButton(
            tooltip: '新增',
            onPressed: _create,
            icon: const Icon(Icons.add_outlined),
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
                    onChanged: (v) => setState(() => _q = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '搜尋 title/content/type/route...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    // ✅ 修正：value deprecated -> initialValue
                    // ✅ 加 key 強制重建，避免 initialValue 只吃第一次造成 UI 不同步
                    key: ValueKey(_typeFilter),
                    initialValue: _typeFilter,
                    decoration: const InputDecoration(
                      labelText: 'type 篩選',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _typeOptions
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t == _typeAll ? '全部' : t),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _typeFilter = v ?? _typeAll),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('載入失敗：${snap.error}'));
                }

                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((d) {
                  final data = d.data();
                  return _matchType(data) && _matchSearch(data, d.id, q);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      docs.isEmpty ? '目前沒有資料' : '沒有符合條件的資料',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final doc = filtered[i];
                    final d = doc.data();

                    final title = _s(d['title']);
                    final content = _s(d['content']);
                    final type = _s(d['type']).isEmpty
                        ? 'general'
                        : _s(d['type']);
                    final route = _s(d['route']);
                    final isActive = d['isActive'] == true;

                    final startAt = _toDate(d['startAt']);
                    final endAt = _toDate(d['endAt']);
                    final createdAt = _fmtTime(_toDate(d['createdAt']));

                    final timeLabel = (startAt == null && endAt == null)
                        ? '期間：未限制'
                        : '期間：${_fmtTime(startAt)} ～ ${_fmtTime(endAt)}';

                    return ListTile(
                      title: Text(
                        title.isEmpty ? '(未命名)' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        [
                          'time: $createdAt',
                          'type: $type',
                          'status: ${isActive ? '上架' : '下架'}',
                          if (route.isNotEmpty) 'route: $route',
                          timeLabel,
                          if (content.isNotEmpty)
                            'content: ${content.length > 60 ? '${content.substring(0, 60)}…' : content}',
                        ].join('  •  '),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') {
                            await _openEditSheet(id: doc.id);
                          } else if (v == 'toggle') {
                            await _toggleActive(doc);
                          } else if (v == 'delete') {
                            await _delete(doc.id);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('編輯')),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(isActive ? '下架' : '上架'),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('刪除'),
                          ),
                        ],
                      ),
                      onTap: () => _openEditSheet(id: doc.id),
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

// ------------------------------------------------------------
// BottomSheet：新增/編輯公告
// ------------------------------------------------------------
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.collection, required this.id});

  final String collection;
  final String id;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  final _db = FirebaseFirestore.instance;

  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();

  bool _active = true;
  String _type = 'general';

  DateTime? _startAt;
  DateTime? _endAt;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _routeCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  DateTime? _toDate(dynamic v) => v is Timestamp ? v.toDate() : null;

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y/$m/$day';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final doc = await _db.collection(widget.collection).doc(widget.id).get();
      final d = doc.data() ?? <String, dynamic>{};

      _titleCtrl.text = (d['title'] ?? '').toString();
      _contentCtrl.text = (d['content'] ?? '').toString();
      _routeCtrl.text = (d['route'] ?? '').toString();
      _active = d['isActive'] != false;
      _type = (d['type'] ?? 'general').toString().trim().isEmpty
          ? 'general'
          : (d['type'] ?? 'general').toString();

      _startAt = _toDate(d['startAt']);
      _endAt = _toDate(d['endAt']);
    } catch (e) {
      _snack('讀取失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final initial = _startAt ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(
      () => _startAt = DateTime(picked.year, picked.month, picked.day, 0, 0, 0),
    );
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final initial = _endAt ?? (_startAt ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(
      () =>
          _endAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59),
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _snack('請輸入標題');
      return;
    }

    if (_startAt != null && _endAt != null && _endAt!.isBefore(_startAt!)) {
      _snack('結束日期不能早於開始日期');
      return;
    }

    setState(() => _saving = true);
    try {
      await _db.collection(widget.collection).doc(widget.id).set({
        'title': title,
        'content': _contentCtrl.text,
        'type': _type.trim().isEmpty ? 'general' : _type.trim(),
        'route': _routeCtrl.text.trim(),
        'isActive': _active,
        'updatedAt': FieldValue.serverTimestamp(),
        if (_startAt != null) 'startAt': Timestamp.fromDate(_startAt!),
        if (_startAt == null) 'startAt': FieldValue.delete(),
        if (_endAt != null) 'endAt': Timestamp.fromDate(_endAt!),
        if (_endAt == null) 'endAt': FieldValue.delete(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(
        child: SizedBox(
          height: 260,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '編輯公告',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: '標題（必填）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _contentCtrl,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: '內容',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _routeCtrl,
                decoration: const InputDecoration(
                  labelText: 'route（可空）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                // ✅ 這裡也用 initialValue（避免 value deprecated）
                key: ValueKey(_type),
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'type',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'general', child: Text('general')),
                  DropdownMenuItem(value: 'system', child: Text('system')),
                  DropdownMenuItem(value: 'promo', child: Text('promo')),
                  DropdownMenuItem(value: 'order', child: Text('order')),
                  DropdownMenuItem(value: 'support', child: Text('support')),
                ],
                onChanged: (v) => setState(() => _type = (v ?? 'general')),
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '上架',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                value: _active,
                onChanged: _saving ? null : (v) => setState(() => _active = v),
              ),

              const Divider(height: 22),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '有效期間（選填）',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickStart,
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      _startAt == null ? '設定開始日' : '開始：${_fmt(_startAt)}',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickEnd,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _endAt == null ? '設定結束日' : '結束：${_fmt(_endAt)}',
                    ),
                  ),
                  if (_startAt != null || _endAt != null)
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              _startAt = null;
                              _endAt = null;
                            }),
                      child: const Text('清除日期'),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? '儲存中...' : '儲存'),
              ),

              if (_saving) ...[
                const SizedBox(height: 12),
                Row(
                  children: const [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '處理中...',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
