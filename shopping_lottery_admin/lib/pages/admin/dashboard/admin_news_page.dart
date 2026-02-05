// lib/pages/admin/content/admin_news_page.dart
//
// ✅ AdminNewsPage（內容管理｜最新消息｜專業單檔完整版｜可編譯）
// ------------------------------------------------------------
// 功能：
// - Firestore 即時列表：news
// - 搜尋：標題/副標/內容/slug
// - 篩選：狀態（draft/published/archived）、公開（isPublic）
// - 拖曳排序：ReorderableListView（寫回 sortOrder）
// - 多選批次：上架/下架/封存/刪除
// - 新增/編輯：同檔 Dialog（title/subtitle/content/coverImageUrl/slug/publishAt/pinned/status/isPublic）
// - 欄位容錯：避免 Object?/null 造成崩潰
//
// 建議 Firestore 結構：news/{id}
// {
//   title: "xxx",
//   subtitle: "xxx",
//   content: "長文...",
//   coverImageUrl: "https://...",
//   slug: "xxx-yyy",
//   status: "draft" | "published" | "archived",
//   isPublic: true/false,
//   pinned: true/false,
//   publishAt: Timestamp?,
//   sortOrder: 0,
//   createdAt: Timestamp,
//   updatedAt: Timestamp
// }
//
// ✅ Query index 建議：
// - orderBy(sortOrder) + orderBy(updatedAt) 會需要複合索引（Firestore 會提示建立）
//
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminNewsPage extends StatefulWidget {
  const AdminNewsPage({super.key});

  @override
  State<AdminNewsPage> createState() => _AdminNewsPageState();
}

class _AdminNewsPageState extends State<AdminNewsPage> {
  final _db = FirebaseFirestore.instance;

  final _search = TextEditingController();
  bool _selectionMode = false;
  final Set<String> _selected = {};

  static const _statusAll = 'all';
  static const _statusDraft = 'draft';
  static const _statusPublished = 'published';
  static const _statusArchived = 'archived';

  static const _publicAll = 'all';
  static const _publicOnly = 'public';
  static const _privateOnly = 'private';

  String _statusFilter = _statusAll;
  String _publicFilter = _publicAll;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('news');

  Query<Map<String, dynamic>> _baseQuery() {
    // ✅ 以 sortOrder 為主排序；若你沒有 sortOrder，也可改成 createdAt
    return _col.orderBy('sortOrder', descending: false).orderBy('updatedAt', descending: true);
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('最新消息管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: '批次上架',
              icon: const Icon(Icons.visibility),
              onPressed: _selected.isEmpty ? null : () => _batchPublish(true),
            ),
            IconButton(
              tooltip: '批次下架',
              icon: const Icon(Icons.visibility_off),
              onPressed: _selected.isEmpty ? null : () => _batchPublish(false),
            ),
            IconButton(
              tooltip: '批次封存',
              icon: const Icon(Icons.inventory_2_outlined),
              onPressed: _selected.isEmpty ? null : _batchArchive,
            ),
            IconButton(
              tooltip: '批次刪除',
              icon: const Icon(Icons.delete_outline),
              onPressed: _selected.isEmpty ? null : _batchDelete,
            ),
          ],
          IconButton(
            tooltip: _selectionMode ? '退出多選' : '多選模式',
            icon: Icon(_selectionMode ? Icons.close : Icons.checklist),
            onPressed: () {
              setState(() {
                _selectionMode = !_selectionMode;
                if (!_selectionMode) _selected.clear();
              });
            },
          ),
          IconButton(
            tooltip: '新增消息',
            icon: const Icon(Icons.add),
            onPressed: _openCreate,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('新增消息'),
      ),
      body: Column(
        children: [
          _filterBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _baseQuery().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('載入失敗：${snap.error}'));
                }

                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) return const Center(child: Text('目前沒有最新消息'));

                final filtered = _applyFilters(docs);

                if (filtered.isEmpty) {
                  return const Center(child: Text('沒有符合條件的內容'));
                }

                return ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  buildDefaultDragHandles: false,
                  itemCount: filtered.length,
                  onReorder: (oldIndex, newIndex) => _onReorder(filtered, oldIndex, newIndex),
                  itemBuilder: (context, i) {
                    final doc = filtered[i];
                    return _newsTile(
                      doc,
                      index: i,
                      key: ValueKey(doc.id),
                      cs: cs,
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

  // ============================================================
  // Filter Bar
  // ============================================================

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 760;

          final searchField = TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜尋（標題/副標/內容/slug）',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          final statusDropdown = DropdownButtonFormField<String>(
            isExpanded: true,
            value: _statusFilter,
            decoration: InputDecoration(
              isDense: true,
              labelText: '狀態',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: const [
              DropdownMenuItem(value: _statusAll, child: Text('全部')),
              DropdownMenuItem(value: _statusDraft, child: Text('草稿')),
              DropdownMenuItem(value: _statusPublished, child: Text('已上架')),
              DropdownMenuItem(value: _statusArchived, child: Text('封存')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v ?? _statusAll),
          );

          final publicDropdown = DropdownButtonFormField<String>(
            isExpanded: true,
            value: _publicFilter,
            decoration: InputDecoration(
              isDense: true,
              labelText: '公開',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: const [
              DropdownMenuItem(value: _publicAll, child: Text('全部')),
              DropdownMenuItem(value: _publicOnly, child: Text('僅公開')),
              DropdownMenuItem(value: _privateOnly, child: Text('僅不公開')),
            ],
            onChanged: (v) => setState(() => _publicFilter = v ?? _publicAll),
          );

          if (isNarrow) {
            return Column(
              children: [
                searchField,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: statusDropdown),
                    const SizedBox(width: 10),
                    Expanded(child: publicDropdown),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: searchField),
              const SizedBox(width: 12),
              Expanded(flex: 1, child: statusDropdown),
              const SizedBox(width: 12),
              Expanded(flex: 1, child: publicDropdown),
            ],
          );
        },
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final q = _search.text.trim().toLowerCase();

    return docs.where((doc) {
      final d = doc.data();
      final title = (d['title'] ?? '').toString().toLowerCase();
      final subtitle = (d['subtitle'] ?? '').toString().toLowerCase();
      final content = (d['content'] ?? '').toString().toLowerCase();
      final slug = (d['slug'] ?? '').toString().toLowerCase();

      final matchSearch = q.isEmpty ||
          title.contains(q) ||
          subtitle.contains(q) ||
          content.contains(q) ||
          slug.contains(q) ||
          doc.id.toLowerCase().contains(q);

      final status = _normalizeStatus(d);
      final isPublic = _asBool(d['isPublic']) || status == _statusPublished;

      final matchStatus = _statusFilter == _statusAll ? true : status == _statusFilter;

      final matchPublic = switch (_publicFilter) {
        _publicAll => true,
        _publicOnly => isPublic,
        _privateOnly => !isPublic,
        _ => true,
      };

      return matchSearch && matchStatus && matchPublic;
    }).toList();
  }

  // ============================================================
  // Tile
  // ============================================================

  Widget _newsTile(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required int index,
    required Key key,
    required ColorScheme cs,
  }) {
    final d = doc.data();

    final title = (d['title'] ?? '').toString().trim();
    final subtitle = (d['subtitle'] ?? '').toString().trim();
    final status = _normalizeStatus(d);
    final pinned = _asBool(d['pinned']);
    final isPublic = _asBool(d['isPublic']) || status == _statusPublished;

    final publishAt = _toDateTime(d['publishAt']);
    final publishText = publishAt == null ? '' : DateFormat('yyyy/MM/dd HH:mm').format(publishAt);

    final cover = (d['coverImageUrl'] ?? '').toString().trim();
    final selected = _selected.contains(doc.id);

    return ListTile(
      key: key,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: _thumb(cover),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title.isEmpty ? '(未命名消息)' : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          if (pinned) const SizedBox(width: 6),
          if (pinned) const Icon(Icons.push_pin, size: 18),
        ],
      ),
      subtitle: Text(
        [
          if (subtitle.isNotEmpty) subtitle,
          if (publishText.isNotEmpty) '上架時間：$publishText',
          'ID: ${doc.id}',
        ].join('\n'),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _selectionMode
          ? Checkbox(
              value: selected,
              onChanged: (v) => _toggleSelect(doc.id, v == true),
            )
          : SizedBox(
              width: 160,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _statusChip(status),
                  const SizedBox(width: 8),
                  Icon(isPublic ? Icons.public : Icons.lock_outline,
                      size: 18, color: isPublic ? Colors.green.shade700 : cs.onSurfaceVariant),
                  const SizedBox(width: 10),
                  ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                ],
              ),
            ),
      onTap: () {
        if (_selectionMode) {
          _toggleSelect(doc.id, !selected);
          return;
        }
        _openEdit(doc);
      },
      onLongPress: () {
        setState(() {
          _selectionMode = true;
          _selected.add(doc.id);
        });
      },
    );
  }

  Widget _thumb(String url) {
    if (url.isEmpty) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.image_not_supported),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 52,
          height: 52,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    String text = status;
    Color bg = Colors.grey.shade200;
    Color fg = Colors.black87;

    switch (status) {
      case _statusDraft:
        text = '草稿';
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
        break;
      case _statusPublished:
        text = '上架';
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
      case _statusArchived:
        text = '封存';
        bg = Colors.blueGrey.shade100;
        fg = Colors.blueGrey.shade900;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg)),
    );
  }

  void _toggleSelect(String id, bool add) {
    setState(() {
      if (add) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  // ============================================================
  // Reorder
  // ============================================================

  Future<void> _onReorder(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex--;
    final moved = docs.removeAt(oldIndex);
    docs.insert(newIndex, moved);

    final batch = _db.batch();
    for (int i = 0; i < docs.length; i++) {
      batch.update(docs[i].reference, {
        'sortOrder': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('排序已更新')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('排序更新失敗：$e')));
    }
  }

  // ============================================================
  // CRUD
  // ============================================================

  Future<void> _openCreate() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _NewsEditDialog(
        titleText: '新增最新消息',
        initial: const {},
        onSave: (payload) => _create(payload),
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已新增消息')));
    }
  }

  Future<void> _openEdit(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _NewsEditDialog(
        titleText: '編輯最新消息',
        initial: {...doc.data(), 'id': doc.id},
        onSave: (payload) => _update(doc.id, payload),
        onDelete: () => _deleteOne(doc.id),
      ),
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已更新消息')));
    }
  }

  Future<void> _create(Map<String, dynamic> payload) async {
    final nextSortOrder = await _nextSortOrder();
    final nowPatch = <String, dynamic>{
      ...payload,
      'sortOrder': payload['sortOrder'] ?? nextSortOrder,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _col.add(nowPatch);
  }

  Future<void> _update(String id, Map<String, dynamic> payload) async {
    await _col.doc(id).set({
      ...payload,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteOne(String id) async {
    final ok = await _confirm(
      title: '刪除消息',
      message: '確定要刪除此消息？刪除後無法復原。\nID: $id',
      confirmText: '刪除',
      danger: true,
    );
    if (ok != true) return;

    await _col.doc(id).delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除消息')));
    }
  }

  Future<int> _nextSortOrder() async {
    try {
      final snap = await _col.orderBy('sortOrder', descending: true).limit(1).get();
      if (snap.docs.isEmpty) return 0;
      final d = snap.docs.first.data();
      final v = d['sortOrder'];
      if (v is int) return v + 1;
      if (v is num) return v.toInt() + 1;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  // ============================================================
  // Batch
  // ============================================================

  Future<void> _batchPublish(bool publish) async {
    final ok = await _confirm(
      title: publish ? '批次上架' : '批次下架',
      message: '共選取 ${_selected.length} 筆，確定要${publish ? '上架' : '下架'}？',
      confirmText: '確認',
    );
    if (ok != true) return;

    final batch = _db.batch();
    for (final id in _selected) {
      batch.update(_col.doc(id), {
        'status': publish ? _statusPublished : _statusDraft,
        'isPublic': publish,
        if (publish) 'publishAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
      if (!mounted) return;
      setState(() {
        _selectionMode = false;
        _selected.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已${publish ? '上架' : '下架'}選取內容')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('批次操作失敗：$e')));
    }
  }

  Future<void> _batchArchive() async {
    final ok = await _confirm(
      title: '批次封存',
      message: '共選取 ${_selected.length} 筆，確定要封存？',
      confirmText: '封存',
    );
    if (ok != true) return;

    final batch = _db.batch();
    for (final id in _selected) {
      batch.update(_col.doc(id), {
        'status': _statusArchived,
        'isPublic': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
      if (!mounted) return;
      setState(() {
        _selectionMode = false;
        _selected.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已封存選取內容')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('批次封存失敗：$e')));
    }
  }

  Future<void> _batchDelete() async {
    final ok = await _confirm(
      title: '批次刪除',
      message: '共選取 ${_selected.length} 筆，刪除後無法復原。是否繼續？',
      confirmText: '刪除',
      danger: true,
    );
    if (ok != true) return;

    final batch = _db.batch();
    for (final id in _selected) {
      batch.delete(_col.doc(id));
    }

    try {
      await batch.commit();
      if (!mounted) return;
      setState(() {
        _selectionMode = false;
        _selected.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除選取內容')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('批次刪除失敗：$e')));
    }
  }

  // ============================================================
  // Helpers
  // ============================================================

  String _normalizeStatus(Map<String, dynamic> d) {
    final s = (d['status'] ?? '').toString().trim().toLowerCase();
    if (s == _statusDraft || s == _statusPublished || s == _statusArchived) return s;

    // 兼容舊資料：若沒有 status 但 isPublic==true → 視為 published
    if (_asBool(d['isPublic'])) return _statusPublished;
    return _statusDraft;
  }

  static bool _asBool(dynamic v) => v == true;

  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool danger = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: danger ? cs.error : null,
              foregroundColor: danger ? cs.onError : null,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Edit Dialog (single-file, no extra routes)
// ============================================================

class _NewsEditDialog extends StatefulWidget {
  final String titleText;
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, dynamic> payload) onSave;
  final Future<void> Function()? onDelete;

  const _NewsEditDialog({
    required this.titleText,
    required this.initial,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_NewsEditDialog> createState() => _NewsEditDialogState();
}

class _NewsEditDialogState extends State<_NewsEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _content;
  late final TextEditingController _cover;
  late final TextEditingController _slug;

  static const _statusDraft = 'draft';
  static const _statusPublished = 'published';
  static const _statusArchived = 'archived';

  late String _status;
  late bool _isPublic;
  late bool _pinned;
  DateTime? _publishAt;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;

    _title = TextEditingController(text: (d['title'] ?? '').toString());
    _subtitle = TextEditingController(text: (d['subtitle'] ?? '').toString());
    _content = TextEditingController(text: (d['content'] ?? '').toString());
    _cover = TextEditingController(text: (d['coverImageUrl'] ?? '').toString());
    _slug = TextEditingController(text: (d['slug'] ?? '').toString());

    final statusRaw = (d['status'] ?? '').toString().trim().toLowerCase();
    _status = (statusRaw == _statusDraft || statusRaw == _statusPublished || statusRaw == _statusArchived)
        ? statusRaw
        : ((_asBool(d['isPublic'])) ? _statusPublished : _statusDraft);

    _isPublic = _asBool(d['isPublic']) || _status == _statusPublished;
    _pinned = _asBool(d['pinned']);
    _publishAt = _toDateTime(d['publishAt']);
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _content.dispose();
    _cover.dispose();
    _slug.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasDelete = widget.onDelete != null && (widget.initial['id'] ?? '').toString().isNotEmpty;

    return AlertDialog(
      title: Text(widget.titleText, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _textField(
                  controller: _title,
                  label: '標題',
                  hint: '例：新品上市 / 活動公告 / 系統更新',
                  validator: (v) => (v == null || v.trim().isEmpty) ? '請輸入標題' : null,
                  onChanged: (v) {
                    // ✅ 若 slug 空白，跟著 title 自動生成（不覆蓋手動輸入）
                    if (_slug.text.trim().isEmpty) {
                      _slug.text = _slugify(v);
                    }
                    setState(() {});
                  },
                ),
                const SizedBox(height: 10),
                _textField(
                  controller: _subtitle,
                  label: '副標（可選）',
                  hint: '用一句話描述重點',
                ),
                const SizedBox(height: 10),

                _textField(
                  controller: _slug,
                  label: 'Slug（可選）',
                  hint: '例：2026-new-launch（用於網址或查找）',
                ),
                const SizedBox(height: 10),

                _textField(
                  controller: _cover,
                  label: '封面圖片 URL（可選）',
                  hint: '貼上 https://... 圖片網址',
                  onChanged: (_) => setState(() {}),
                ),
                if (_cover.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _cover.text.trim(),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 160,
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Text('封面預覽失敗（URL 可能無效）'),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                _textField(
                  controller: _content,
                  label: '內容（可選）',
                  hint: '支援長文（可先用純文字，後續再升級成 Markdown/HTML 編輯器）',
                  maxLines: 8,
                ),

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _status,
                        isExpanded: true,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: '狀態',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: const [
                          DropdownMenuItem(value: _statusDraft, child: Text('草稿')),
                          DropdownMenuItem(value: _statusPublished, child: Text('已上架')),
                          DropdownMenuItem(value: _statusArchived, child: Text('封存')),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _status = v ?? _statusDraft;
                            // ✅ 狀態與公開同步
                            if (_status == _statusPublished) _isPublic = true;
                            if (_status == _statusArchived) _isPublic = false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dateTimePicker(cs),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('公開（isPublic）', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    _isPublic ? '前台可見' : '前台不可見',
                    style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                  ),
                  value: _isPublic,
                  onChanged: (v) {
                    setState(() {
                      _isPublic = v;
                      if (_isPublic && _status == _statusDraft) _status = _statusPublished;
                      if (!_isPublic && _status == _statusPublished) _status = _statusDraft;
                    });
                  },
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('置頂（pinned）', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    _pinned ? '此內容將優先顯示' : '不置頂',
                    style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                  ),
                  value: _pinned,
                  onChanged: (v) => setState(() => _pinned = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (hasDelete)
          TextButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    final ok = await _confirm(
                      context,
                      title: '刪除',
                      message: '確定要刪除此消息？刪除後無法復原。',
                      confirmText: '刪除',
                      danger: true,
                    );
                    if (ok != true) return;
                    await widget.onDelete!.call();
                    if (context.mounted) Navigator.pop(context, true);
                  },
            icon: const Icon(Icons.delete_outline),
            label: const Text('刪除'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? '儲存中...' : '儲存'),
        ),
      ],
    );
  }

  Widget _dateTimePicker(ColorScheme cs) {
    final txt = _publishAt == null ? '未設定' : DateFormat('yyyy/MM/dd HH:mm').format(_publishAt!);
    return OutlinedButton.icon(
      onPressed: _saving
          ? null
          : () async {
              final picked = await _pickDateTime(context, initial: _publishAt);
              if (!mounted) return;
              if (picked == null) return;
              setState(() => _publishAt = picked);
            },
      icon: const Icon(Icons.schedule),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '上架時間：$txt',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: cs.onSurface),
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'title': _title.text.trim(),
        'subtitle': _subtitle.text.trim(),
        'content': _content.text.trim(),
        'coverImageUrl': _cover.text.trim(),
        'slug': _slug.text.trim(),
        'status': _status,
        'isPublic': _isPublic,
        'pinned': _pinned,
        'publishAt': _publishAt == null ? null : Timestamp.fromDate(_publishAt!),
      };

      // 清理 null（避免覆蓋）
      payload.removeWhere((k, v) => v == null);

      await widget.onSave(payload);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static bool _asBool(dynamic v) => v == true;

  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  static String _slugify(String input) {
    final s = input.trim().toLowerCase();
    final cleaned = s
        .replaceAll(RegExp(r'[\s]+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9\-]+'), '')
        .replaceAll(RegExp(r'\-+'), '-')
        .replaceAll(RegExp(r'^\-|\-$'), '');
    return cleaned;
  }

  static Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    bool danger = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: danger ? cs.error : null,
              foregroundColor: danger ? cs.onError : null,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DateTime picker helper
// ============================================================

Future<DateTime?> _pickDateTime(BuildContext context, {DateTime? initial}) async {
  final now = DateTime.now();
  final init = initial ?? now;

  final d = await showDatePicker(
    context: context,
    initialDate: init,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
  if (d == null) return null;

  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(init),
  );
  if (t == null) return DateTime(d.year, d.month, d.day);

  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}
