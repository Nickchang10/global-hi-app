import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ AdminAnnouncementsPage（公告管理｜可直接放進 AdminShell.child｜可編譯）
/// -----------------------------------------------------------------------------
/// Firestore collection: announcements
/// 建議欄位：
/// - title: String
/// - body: String
/// - published: bool
/// - pinned: bool
/// - startAt: Timestamp?（可選，上架時間）
/// - endAt: Timestamp?（可選，下架時間）
/// - createdAt: Timestamp
/// - updatedAt: Timestamp
/// - authorUid: String
/// - authorEmail: String?
///
/// ✅ 特性：
/// - 搜尋（標題/內容/docId）
/// - 篩選（全部/已發布/草稿、只看置頂）
/// - 分頁載入（Load more）
/// - 建立/編輯（BottomSheet）
/// - 發布/取消發布、置頂/取消置頂、刪除
///
/// ✅ 修正：
/// - use_build_context_synchronously：避免把 context 相關物件（ScaffoldMessenger/Navigator）
///   在 await 前取出並跨 async gap 使用；await 後先檢查 mounted 再用 context。
///
/// ⚠️ 此頁不包 Scaffold（避免 AdminShell 內巢狀 Scaffold）
/// 若你要 standalone 使用，可用 AdminAnnouncementsPage(standalone: true)
class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key, this.standalone = false});

  final bool standalone;

  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  final _fs = FirebaseFirestore.instance;

  // pagination
  static const int _pageSize = 30;
  final List<_AnnRow> _rows = <_AnnRow>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  // filters
  final _searchCtrl = TextEditingController();
  String _status = 'all'; // all / published / draft
  bool _onlyPinned = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _baseQuery() {
    // ✅ 只 orderBy createdAt，避免索引爆炸；其他用本地過濾
    return _fs
        .collection('announcements')
        .orderBy('createdAt', descending: true);
  }

  Future<void> _load({required bool reset}) async {
    if (!mounted) return;

    setState(() {
      _error = null;
      if (reset) {
        _loading = true;
        _rows.clear();
        _lastDoc = null;
        _hasMore = true;
      }
    });

    try {
      Query<Map<String, dynamic>> q = _baseQuery();
      if (!reset && _lastDoc != null) {
        q = q.startAfterDocument(_lastDoc!);
      }

      final snap = await q.limit(_pageSize).get();
      final docs = snap.docs;

      final page = docs.map((d) => _AnnRow(id: d.id, data: d.data())).toList();
      final last = docs.isEmpty ? _lastDoc : docs.last;

      if (!mounted) return;
      setState(() {
        _rows.addAll(page);
        _lastDoc = last;
        _hasMore = docs.length == _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted && reset) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      await _load(reset: false);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ===========================
  // Local filtering
  // ===========================
  List<_AnnRow> get _visibleRows {
    final q = _searchCtrl.text.trim().toLowerCase();
    final s = _status;
    final pinnedOnly = _onlyPinned;

    bool hit(_AnnRow r) {
      final d = r.data;

      final published = (d['published'] == true);
      final pinned = (d['pinned'] == true);

      if (pinnedOnly && !pinned) return false;
      if (s == 'published' && !published) return false;
      if (s == 'draft' && published) return false;

      if (q.isEmpty) return true;

      final id = r.id.toLowerCase();
      final title = (d['title'] ?? '').toString().toLowerCase();
      final body = (d['body'] ?? '').toString().toLowerCase();

      return id.contains(q) || title.contains(q) || body.contains(q);
    }

    return _rows.where(hit).toList();
  }

  // ===========================
  // CRUD
  // ===========================
  Future<void> _openEditor({required _AnnRow? editing}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _AnnouncementEditorSheet(row: editing),
    );

    if (!mounted) return;

    if (ok == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ 已儲存公告')));
      await _load(reset: true);
    }
  }

  Future<void> _togglePublished(_AnnRow row) async {
    try {
      final now = FieldValue.serverTimestamp();
      final published = (row.data['published'] == true);
      await _fs.collection('announcements').doc(row.id).set(<String, dynamic>{
        'published': !published,
        'updatedAt': now,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(published ? '已改為草稿' : '已發布')));
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失敗：$e')));
    }
  }

  Future<void> _togglePinned(_AnnRow row) async {
    try {
      final now = FieldValue.serverTimestamp();
      final pinned = (row.data['pinned'] == true);
      await _fs.collection('announcements').doc(row.id).set(<String, dynamic>{
        'pinned': !pinned,
        'updatedAt': now,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(pinned ? '已取消置頂' : '已置頂')));
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失敗：$e')));
    }
  }

  Future<void> _delete(_AnnRow row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除公告'),
        content: Text(
          '確定要刪除「${(row.data['title'] ?? '').toString()}」？\n此動作無法復原。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm != true) return;

    try {
      await _fs.collection('announcements').doc(row.id).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ 已刪除')));
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  // ===========================
  // UI
  // ===========================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final content = _buildContent(cs);
    if (widget.standalone) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            '公告管理',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              tooltip: '新增公告',
              onPressed: () => _openEditor(editing: null),
              icon: const Icon(Icons.add),
            ),
            IconButton(
              tooltip: '重新整理',
              onPressed: () => _load(reset: true),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: content,
      );
    }

    // ✅ 嵌入 AdminShell：不包 Scaffold，只回傳內容
    return content;
  }

  Widget _buildContent(ColorScheme cs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorBox(
        title: '載入公告失敗',
        message: _error!,
        hint: '常見原因：announcements 缺少 createdAt、或 Firestore 規則阻擋。',
        onRetry: () => _load(reset: true),
      );
    }

    final visible = _visibleRows;

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _topActionsBar(),
          const SizedBox(height: 12),

          _filtersCard(cs),
          const SizedBox(height: 12),

          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _miniStat('已載入', _rows.length.toString()),
                  _miniStat('可見', visible.length.toString()),
                  _miniStat('篩選', _status),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (visible.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '目前沒有符合條件的公告。\n\n'
                  '提示：搜尋/篩選為本地過濾（避免複合索引）；要看更舊資料請按「載入更多」。',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            ...visible.map(_tile),

          const SizedBox(height: 12),

          if (_hasMore)
            Center(
              child: FilledButton.tonalIcon(
                onPressed: _loadingMore ? null : _loadMore,
                icon: _loadingMore
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(_loadingMore ? '載入中...' : '載入更多'),
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _topActionsBar() {
    return Row(
      children: [
        FilledButton.icon(
          onPressed: () => _openEditor(editing: null),
          icon: const Icon(Icons.add),
          label: const Text('新增公告'),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () => _load(reset: true),
          icon: const Icon(Icons.refresh),
          label: const Text('重新整理'),
        ),
      ],
    );
  }

  Widget _filtersCard(ColorScheme cs) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '搜尋與篩選',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '狀態：',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _status,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('全部')),
                        DropdownMenuItem(
                          value: 'published',
                          child: Text('已發布'),
                        ),
                        DropdownMenuItem(value: 'draft', child: Text('草稿')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _status = v);
                      },
                    ),
                  ],
                ),
                FilterChip(
                  label: const Text('只看置頂'),
                  selected: _onlyPinned,
                  onSelected: (v) => setState(() => _onlyPinned = v),
                ),
              ],
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋 docId / 標題 / 內容（本頁已載入資料）',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchCtrl.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除',
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),

            const SizedBox(height: 8),
            Text(
              '提示：此頁用本地過濾避免 Firestore 複合索引；需要更舊資料請「載入更多」。',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
      ],
    );
  }

  Widget _tile(_AnnRow row) {
    final d = row.data;
    final cs = Theme.of(context).colorScheme;

    final title = (d['title'] ?? row.id).toString();
    final body = (d['body'] ?? '').toString();
    final published = (d['published'] == true);
    final pinned = (d['pinned'] == true);

    final startAt = _toDateTime(d['startAt']);
    final endAt = _toDateTime(d['endAt']);
    final active = _isActive(
      published: published,
      startAt: startAt,
      endAt: endAt,
    );

    final statusText = published ? (active ? '已發布（生效）' : '已發布（未生效/已過期）') : '草稿';
    final statusColor = published
        ? cs.primaryContainer
        : cs.surfaceContainerHighest;
    final statusOn = published ? cs.onPrimaryContainer : cs.onSurface;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (pinned)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.push_pin, size: 18),
                  ),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: statusColor,
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusOn,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body.isEmpty ? '(無內容)' : body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _openEditor(editing: row),
                  icon: const Icon(Icons.edit),
                  label: const Text('編輯'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _togglePublished(row),
                  icon: Icon(
                    published ? Icons.visibility_off : Icons.visibility,
                  ),
                  label: Text(published ? '改草稿' : '發布'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _togglePinned(row),
                  icon: Icon(pinned ? Icons.push_pin_outlined : Icons.push_pin),
                  label: Text(pinned ? '取消置頂' : '置頂'),
                ),
                TextButton.icon(
                  onPressed: () => _delete(row),
                  icon: Icon(
                    Icons.delete,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  label: Text(
                    '刪除',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isActive({
    required bool published,
    required DateTime? startAt,
    required DateTime? endAt,
  }) {
    if (!published) return false;
    final now = DateTime.now();
    if (startAt != null && now.isBefore(startAt)) return false;
    if (endAt != null && now.isAfter(endAt)) return false;
    return true;
  }

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    try {
      final dynamic d = v;
      final dt = d.toDate();
      if (dt is DateTime) return dt;
    } catch (_) {}
    return null;
  }
}

class _AnnRow {
  final String id;
  final Map<String, dynamic> data;
  _AnnRow({required this.id, required this.data});
}

/// ===========================
/// Editor Sheet
/// ===========================
class _AnnouncementEditorSheet extends StatefulWidget {
  const _AnnouncementEditorSheet({required this.row});

  final _AnnRow? row;

  @override
  State<_AnnouncementEditorSheet> createState() =>
      _AnnouncementEditorSheetState();
}

class _AnnouncementEditorSheetState extends State<_AnnouncementEditorSheet> {
  final _fs = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;

  bool _published = false;
  bool _pinned = false;

  DateTime? _startAt;
  DateTime? _endAt;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final d = widget.row?.data ?? <String, dynamic>{};

    _titleCtrl = TextEditingController(text: (d['title'] ?? '').toString());
    _bodyCtrl = TextEditingController(text: (d['body'] ?? '').toString());

    _published = (d['published'] == true);
    _pinned = (d['pinned'] == true);

    _startAt = _toDateTime(d['startAt']);
    _endAt = _toDateTime(d['endAt']);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  String? _required(String? v) {
    if (v == null || v.trim().isEmpty) return '此欄位必填';
    return null;
  }

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    return null;
  }

  Future<DateTime?> _pickDateTime({
    required DateTime? initial,
    required String title,
  }) async {
    final now = DateTime.now();
    final init = initial ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year + 3, 12, 31),
      helpText: title,
      confirmText: '下一步',
      cancelText: '取消',
    );
    if (pickedDate == null) return null;

    // ✅ await 後再用 context 前先檢查 mounted
    if (!mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(init),
      helpText: '選擇時間',
      confirmText: '確定',
      cancelText: '取消',
    );
    if (pickedTime == null) {
      return DateTime(pickedDate.year, pickedDate.month, pickedDate.day, 0, 0);
    }

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final now = FieldValue.serverTimestamp();

      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'published': _published,
        'pinned': _pinned,
        'updatedAt': now,
        if (_startAt != null) 'startAt': Timestamp.fromDate(_startAt!),
        if (_endAt != null) 'endAt': Timestamp.fromDate(_endAt!),
        if (_startAt == null) 'startAt': FieldValue.delete(),
        if (_endAt == null) 'endAt': FieldValue.delete(),
        'authorUid': user?.uid ?? '',
        'authorEmail': user?.email,
      };

      if (widget.row == null) {
        await _fs.collection('announcements').add(<String, dynamic>{
          ...payload,
          'createdAt': now,
        });
      } else {
        await _fs
            .collection('announcements')
            .doc(widget.row!.id)
            .set(payload, SetOptions(merge: true));
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEdit = widget.row != null;

    final sheet = DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.98,
      expand: false,
      builder: (context, scrollCtrl) {
        return Material(
          color: cs.surface,
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? '編輯公告' : '新增公告',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '關閉',
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      validator: _required,
                      decoration: const InputDecoration(
                        labelText: '標題',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _bodyCtrl,
                      validator: _required,
                      minLines: 4,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        labelText: '內容',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('發布'),
                            subtitle: Text(
                              _published ? '前台可見（若有時間限制需同時生效）' : '草稿（前台不可見）',
                            ),
                            value: _published,
                            onChanged: _saving
                                ? null
                                : (v) => setState(() => _published = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('置頂'),
                            subtitle: const Text('前台列表可用 pinned 做排序'),
                            value: _pinned,
                            onChanged: _saving
                                ? null
                                : (v) => setState(() => _pinned = v),
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '時間限制（可空）',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () async {
                                    final dt = await _pickDateTime(
                                      initial: _startAt,
                                      title: '選擇上架時間（startAt）',
                                    );
                                    if (!mounted) return;
                                    if (dt == null) return;
                                    setState(() => _startAt = dt);
                                  },
                            icon: const Icon(Icons.schedule),
                            label: Text(
                              _startAt == null
                                  ? '設定 startAt'
                                  : _startAt!.toString(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (_startAt != null)
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _startAt = null),
                            child: const Text('清除'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () async {
                                    final dt = await _pickDateTime(
                                      initial: _endAt,
                                      title: '選擇下架時間（endAt）',
                                    );
                                    if (!mounted) return;
                                    if (dt == null) return;
                                    setState(() => _endAt = dt);
                                  },
                            icon: const Icon(Icons.schedule_outlined),
                            label: Text(
                              _endAt == null ? '設定 endAt' : _endAt!.toString(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (_endAt != null)
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _endAt = null),
                            child: const Text('清除'),
                          ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_saving ? '儲存中…' : '儲存'),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    return SafeArea(child: sheet);
  }
}

/// ===========================
/// Error box
/// ===========================
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({
    required this.title,
    required this.message,
    required this.onRetry,
    this.hint,
  });

  final String title;
  final String message;
  final String? hint;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
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
