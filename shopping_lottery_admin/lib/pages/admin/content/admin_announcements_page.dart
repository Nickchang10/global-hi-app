// lib/pages/admin/content/admin_announcements_page.dart
//
// ✅ AdminAnnouncementsPage（公告管理｜A. 基礎專業版｜單檔完整版｜可編譯）
// ------------------------------------------------------------
// - Firestore：announcements 集合
// - 功能：
//   1) 列表：搜尋 / 分類篩選 / 上下架（isPublic）/ 置頂（isPinned）篩選
//   2) 新增 / 編輯：標題、內容、分類、上架、置頂、封面圖、外連
//   3) 排程：startAt / endAt（可選）
//   4) 拖曳排序：ReorderableListView（✅ 只允許在「無篩選」狀態排序）
//   5) 多選批次：上架 / 下架 / 刪除
//   6) 欄位容錯：Map 轉型、Timestamp 轉 DateTime、欄位缺失不崩潰
//
// 建議資料結構：announcements/{id}
// {
//   title: "春節出貨公告",
//   content: "....",
//   category: "system" | "promo" | "shipping" | "other",
//   isPublic: true,
//   isPinned: false,
//   imageUrl: "https://... (可選)",
//   linkText: "查看詳情",
//   linkUrl: "https://... (可選)",
//   startAt: Timestamp (可選，排程上架開始),
//   endAt: Timestamp (可選，排程下架時間),
//   sortOrder: 0,
//   createdAt: Timestamp,
//   updatedAt: Timestamp,
//   updatedBy: "admin"
// }
//
// 依賴：cloud_firestore, intl
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});

  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  final _db = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _col =
      _db.collection('announcements');

  final _search = TextEditingController();

  bool _selectionMode = false;
  final Set<String> _selected = {};

  static const String _catAll = 'all';
  String _category = _catAll;

  static const String _statusAll = 'all';
  static const String _statusPublic = 'public';
  static const String _statusHidden = 'hidden';
  String _status = _statusAll;

  static const String _pinAll = 'all';
  static const String _pinPinned = 'pinned';
  static const String _pinNormal = 'normal';
  String _pin = _pinAll;

  final _dtFmt = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    // ✅ 不做 orderBy：避免欄位不存在時查詢失敗
    return _col.limit(500).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('公告管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: '批次下架',
              icon: const Icon(Icons.visibility_off),
              onPressed: _selected.isEmpty ? null : () => _batchSetPublic(false),
            ),
            IconButton(
              tooltip: '批次上架',
              icon: const Icon(Icons.visibility),
              onPressed: _selected.isEmpty ? null : () => _batchSetPublic(true),
            ),
            IconButton(
              tooltip: '批次刪除',
              icon: const Icon(Icons.delete_outline),
              onPressed: _selected.isEmpty ? null : _confirmBatchDelete,
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
            tooltip: '新增公告',
            icon: const Icon(Icons.add),
            onPressed: _openCreate,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('新增公告'),
      ),
      body: Column(
        children: [
          _filterBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorView(
                    title: '載入失敗',
                    message: snap.error.toString(),
                    onRetry: () => setState(() {}),
                    hint: '請確認 Firestore rules：announcements 允許 admin 讀寫。',
                  );
                }

                final docs = (snap.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .map((d) => _AnnouncementDoc.fromDoc(d))
                    .toList();

                // ✅ 排序：置頂優先 -> sortOrder -> updatedAt/createdAt
                docs.sort((a, b) {
                  if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
                  final so = a.sortOrder.compareTo(b.sortOrder);
                  if (so != 0) return so;
                  final ad = a.updatedAt ?? a.createdAt;
                  final bd = b.updatedAt ?? b.createdAt;
                  final at = ad?.millisecondsSinceEpoch ?? 0;
                  final bt = bd?.millisecondsSinceEpoch ?? 0;
                  return bt.compareTo(at);
                });

                // 動態分類 options
                final cats = <String>{_catAll};
                for (final d in docs) {
                  final c = d.category.trim();
                  if (c.isNotEmpty) cats.add(c);
                }
                final catKeys = cats.toList()
                  ..sort((a, b) {
                    if (a == _catAll) return -1;
                    if (b == _catAll) return 1;
                    return a.compareTo(b);
                  });

                if (!catKeys.contains(_category)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() => _category = _catAll);
                  });
                }

                final filtered = _applyFilters(docs);

                return Column(
                  children: [
                    _summaryRow(count: filtered.length, cs: cs),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('沒有符合條件的公告'))
                          : _buildReorderableList(
                              filtered,
                              allowReorder: _canReorderNow(),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Filter UI
  // ============================================================

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 980;

          final searchField = TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜尋（標題 / 內容 / 分類 / id）',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          final statusDD = DropdownButtonFormField<String>(
            isExpanded: true,
            value: _status,
            decoration: InputDecoration(
              isDense: true,
              labelText: '上架狀態',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: const [
              DropdownMenuItem(value: _statusAll, child: Text('全部')),
              DropdownMenuItem(value: _statusPublic, child: Text('上架')),
              DropdownMenuItem(value: _statusHidden, child: Text('下架')),
            ],
            onChanged: (v) => setState(() => _status = v ?? _statusAll),
          );

          final pinDD = DropdownButtonFormField<String>(
            isExpanded: true,
            value: _pin,
            decoration: InputDecoration(
              isDense: true,
              labelText: '置頂',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: const [
              DropdownMenuItem(value: _pinAll, child: Text('全部')),
              DropdownMenuItem(value: _pinPinned, child: Text('置頂')),
              DropdownMenuItem(value: _pinNormal, child: Text('一般')),
            ],
            onChanged: (v) => setState(() => _pin = v ?? _pinAll),
          );

          final catDD = DropdownButtonFormField<String>(
            isExpanded: true,
            value: _category,
            decoration: InputDecoration(
              isDense: true,
              labelText: '分類',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: [
              const DropdownMenuItem(value: _catAll, child: Text('全部')),
              if (_category != _catAll)
                DropdownMenuItem(value: _category, child: Text(_category)),
            ],
            onChanged: (v) => setState(() => _category = v ?? _catAll),
          );

          final reorderHint = Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _canReorderNow()
                        ? '提示：可拖曳排序（將寫回 sortOrder）'
                        : '提示：需清除搜尋/篩選後才可排序（避免排序在子集合視圖中失真）',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _search.clear();
                      _category = _catAll;
                      _status = _statusAll;
                      _pin = _pinAll;
                    });
                  },
                  child: const Text('清除篩選'),
                ),
              ],
            ),
          );

          if (narrow) {
            return Column(
              children: [
                searchField,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: statusDD),
                    const SizedBox(width: 10),
                    Expanded(child: pinDD),
                  ],
                ),
                const SizedBox(height: 10),
                catDD,
                reorderHint,
              ],
            );
          }

          return Column(
            children: [
              Row(
                children: [
                  Expanded(flex: 4, child: searchField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: statusDD),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: pinDD),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: catDD),
                ],
              ),
              reorderHint,
            ],
          );
        },
      ),
    );
  }

  Widget _summaryRow({required int count, required ColorScheme cs}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Text(
            '共 $count 筆',
            style:
                TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('重新整理'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // List + Reorder
  // ============================================================

  bool _canReorderNow() {
    final q = _search.text.trim();
    return q.isEmpty &&
        _category == _catAll &&
        _status == _statusAll &&
        _pin == _pinAll &&
        !_selectionMode;
  }

  List<_AnnouncementDoc> _applyFilters(List<_AnnouncementDoc> input) {
    final q = _search.text.trim().toLowerCase();

    return input.where((d) {
      final matchQ = q.isEmpty ||
          d.id.toLowerCase().contains(q) ||
          d.title.toLowerCase().contains(q) ||
          d.content.toLowerCase().contains(q) ||
          d.category.toLowerCase().contains(q);

      final matchCat = _category == _catAll ? true : d.category == _category;

      final matchStatus = switch (_status) {
        _statusAll => true,
        _statusPublic => d.isPublicNow,
        _statusHidden => !d.isPublicNow,
        _ => true,
      };

      final matchPin = switch (_pin) {
        _pinAll => true,
        _pinPinned => d.isPinned,
        _pinNormal => !d.isPinned,
        _ => true,
      };

      return matchQ && matchCat && matchStatus && matchPin;
    }).toList();
  }

  Widget _buildReorderableList(List<_AnnouncementDoc> items,
      {required bool allowReorder}) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) async {
        if (!allowReorder) {
          _toast('請清除篩選後再排序');
          return;
        }
        await _onReorder(items, oldIndex, newIndex);
      },
      itemBuilder: (context, i) {
        final d = items[i];
        return _buildTile(
          d,
          index: i,
          key: ValueKey(d.id),
          allowReorder: allowReorder,
        );
      },
    );
  }

  Widget _buildTile(_AnnouncementDoc d,
      {required int index, required Key key, required bool allowReorder}) {
    final cs = Theme.of(context).colorScheme;
    final selected = _selected.contains(d.id);

    final updatedText = d.updatedAt == null ? '' : _dtFmt.format(d.updatedAt!);
    final scheduleText = d.scheduleLabel(_dtFmt);

    return Card(
      key: key,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: d.isPublicNow ? cs.primaryContainer : Colors.grey.shade200,
          child: Icon(
            d.isPinned ? Icons.push_pin_outlined : Icons.campaign_outlined,
            color: d.isPublicNow ? cs.onPrimaryContainer : Colors.grey.shade600,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                d.title.isEmpty ? '(未命名公告)' : d.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            if (d.isPinned) _pill('置頂', enabled: true),
            const SizedBox(width: 6),
            _pill(d.isPublicNow ? '上架' : '下架', enabled: d.isPublicNow),
          ],
        ),
        subtitle: Text(
          [
            if (d.category.isNotEmpty) '分類：${d.category}',
            if (updatedText.isNotEmpty) '更新：$updatedText',
            if (scheduleText.isNotEmpty) scheduleText,
            if (d.content.isNotEmpty) d.content,
          ].join('  •  '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _selectionMode
            ? Checkbox(
                value: selected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selected.add(d.id);
                    } else {
                      _selected.remove(d.id);
                    }
                  });
                },
              )
            : SizedBox(
                width: 170,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: '複製外連',
                      icon: const Icon(Icons.copy),
                      onPressed: () => _copyText(d.linkUrl),
                    ),
                    IconButton(
                      tooltip: '編輯',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openEdit(d),
                    ),
                    if (allowReorder)
                      ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      )
                    else
                      Icon(Icons.drag_handle,
                          color: cs.onSurfaceVariant.withOpacity(0.35)),
                  ],
                ),
              ),
        onTap: () {
          if (_selectionMode) {
            setState(() {
              if (selected) {
                _selected.remove(d.id);
              } else {
                _selected.add(d.id);
              }
            });
            return;
          }
          _openEdit(d);
        },
        onLongPress: () {
          setState(() {
            _selectionMode = true;
            _selected.add(d.id);
          });
        },
      ),
    );
  }

  Widget _pill(String text, {bool enabled = true}) {
    final cs = Theme.of(context).colorScheme;
    final bg = enabled ? Colors.green.shade100 : Colors.grey.shade200;
    final fg = enabled ? Colors.green.shade900 : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg)),
    );
  }

  Future<void> _onReorder(List<_AnnouncementDoc> items, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;

    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    final batch = _db.batch();
    for (int i = 0; i < items.length; i++) {
      batch.set(_col.doc(items[i].id), {
        'sortOrder': i,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'admin',
      }, SetOptions(merge: true));
    }
    await batch.commit();

    _toast('排序已更新');
  }

  // ============================================================
  // CRUD
  // ============================================================

  Future<void> _openCreate() async {
    await showDialog(
      context: context,
      builder: (_) => _AnnouncementEditorDialog(
        title: '新增公告',
        initial: const {},
        onSave: (payload) async {
          final nextOrder = await _nextSortOrder();
          final ref = _col.doc();
          await ref.set({
            ...payload,
            'sortOrder': nextOrder,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': 'admin',
          }, SetOptions(merge: true));
        },
      ),
    );
  }

  Future<void> _openEdit(_AnnouncementDoc d) async {
    await showDialog(
      context: context,
      builder: (_) => _AnnouncementEditorDialog(
        title: '編輯公告',
        docId: d.id,
        initial: d.raw,
        onSave: (payload) async {
          await _col.doc(d.id).set({
            ...payload,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': 'admin',
          }, SetOptions(merge: true));
        },
        onDelete: () => _confirmDeleteOne(d.id),
      ),
    );
  }

  Future<int> _nextSortOrder() async {
    final snap = await _col.limit(300).get();
    int maxOrder = -1;
    for (final doc in snap.docs) {
      final d = doc.data();
      final so = _asInt(d['sortOrder'], fallback: 999999);
      if (so != 999999 && so > maxOrder) maxOrder = so;
    }
    return maxOrder + 1;
  }

  // ============================================================
  // Batch operations
  // ============================================================

  Future<void> _batchSetPublic(bool isPublic) async {
    final ok = await _confirm(
      title: isPublic ? '批次上架' : '批次下架',
      message: '共選取 ${_selected.length} 筆，確定要${isPublic ? '上架' : '下架'}？',
      confirmText: '確認',
    );
    if (ok != true) return;

    final batch = _db.batch();
    for (final id in _selected) {
      batch.set(_col.doc(id), {
        'isPublic': isPublic,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'admin',
      }, SetOptions(merge: true));
    }
    await batch.commit();

    if (!mounted) return;
    setState(() => _selected.clear());
    _toast('已${isPublic ? '上架' : '下架'}選取公告');
  }

  Future<void> _confirmBatchDelete() async {
    final ok = await _confirm(
      title: '批次刪除',
      message: '共選取 ${_selected.length} 筆，刪除後無法復原。',
      confirmText: '刪除',
      isDanger: true,
    );
    if (ok != true) return;

    final batch = _db.batch();
    for (final id in _selected) {
      batch.delete(_col.doc(id));
    }
    await batch.commit();

    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
    _toast('已刪除選取公告');
  }

  Future<void> _confirmDeleteOne(String id) async {
    final ok = await _confirm(
      title: '刪除公告',
      message: '確定要刪除這筆公告嗎？\nID: $id',
      confirmText: '刪除',
      isDanger: true,
    );
    if (ok != true) return;

    await _col.doc(id).delete();
    if (!mounted) return;
    _toast('已刪除');
  }

  // ============================================================
  // Helpers
  // ============================================================

  Future<void> _copyText(String? text) async {
    final v = (text ?? '').trim();
    if (v.isEmpty) {
      _toast('沒有可複製的連結');
      return;
    }
    await Clipboard.setData(ClipboardData(text: v));
    _toast('已複製');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool isDanger = false,
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
              backgroundColor: isDanger ? cs.error : null,
              foregroundColor: isDanger ? cs.onError : null,
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
// Editor Dialog
// ============================================================

class _AnnouncementEditorDialog extends StatefulWidget {
  final String title;
  final String? docId;
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, dynamic> payload) onSave;
  final VoidCallback? onDelete;

  const _AnnouncementEditorDialog({
    required this.title,
    required this.initial,
    required this.onSave,
    this.docId,
    this.onDelete,
  });

  @override
  State<_AnnouncementEditorDialog> createState() => _AnnouncementEditorDialogState();
}

class _AnnouncementEditorDialogState extends State<_AnnouncementEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _category = TextEditingController();
  final _content = TextEditingController();
  final _imageUrl = TextEditingController();
  final _linkText = TextEditingController();
  final _linkUrl = TextEditingController();

  bool _isPublic = true;
  bool _isPinned = false;

  DateTime? _startAt;
  DateTime? _endAt;

  bool _saving = false;

  final _dtFmt = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void initState() {
    super.initState();
    final d = widget.initial;

    _title.text = (d['title'] ?? '').toString();
    _category.text = (d['category'] ?? '').toString();
    _content.text = (d['content'] ?? '').toString();
    _imageUrl.text = (d['imageUrl'] ?? '').toString();
    _linkText.text = (d['linkText'] ?? '').toString();
    _linkUrl.text = (d['linkUrl'] ?? '').toString();

    _isPublic = d['isPublic'] == null ? true : (d['isPublic'] == true);
    _isPinned = d['isPinned'] == true;

    _startAt = _toDateTime(d['startAt']);
    _endAt = _toDateTime(d['endAt']);
  }

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _content.dispose();
    _imageUrl.dispose();
    _linkText.dispose();
    _linkUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 920,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _row2(
                  left: TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: '標題',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? '請輸入標題' : null,
                  ),
                  right: TextFormField(
                    controller: _category,
                    decoration: const InputDecoration(
                      labelText: '分類（可空）',
                      hintText: 'system / promo / shipping / other...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _content,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: '內容',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '請輸入內容' : null,
                ),
                const SizedBox(height: 10),
                _row2(
                  left: TextFormField(
                    controller: _imageUrl,
                    decoration: const InputDecoration(
                      labelText: '封面圖 URL（可空）',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  right: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('上架', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(_isPublic ? '目前：上架' : '目前：下架',
                        style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                    value: _isPublic,
                    onChanged: _saving ? null : (v) => setState(() => _isPublic = v),
                  ),
                ),
                const SizedBox(height: 10),
                _row2(
                  left: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('置頂', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(_isPinned ? '目前：置頂' : '目前：一般',
                        style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                    value: _isPinned,
                    onChanged: _saving ? null : (v) => setState(() => _isPinned = v),
                  ),
                  right: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _dateRow(
                        label: '排程開始',
                        value: _startAt,
                        onPick: () => _pickDateTime(setter: (dt) => setState(() => _startAt = dt)),
                        onClear: () => setState(() => _startAt = null),
                      ),
                      const SizedBox(height: 8),
                      _dateRow(
                        label: '排程結束',
                        value: _endAt,
                        onPick: () => _pickDateTime(setter: (dt) => setState(() => _endAt = dt)),
                        onClear: () => setState(() => _endAt = null),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _row2(
                  left: TextFormField(
                    controller: _linkText,
                    decoration: const InputDecoration(
                      labelText: '外連文字（可空）',
                      hintText: '查看詳情',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  right: TextFormField(
                    controller: _linkUrl,
                    decoration: const InputDecoration(
                      labelText: '外連 URL（可空）',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.docId == null ? '' : 'ID：${widget.docId}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (widget.onDelete != null)
          TextButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    Navigator.pop(context);
                    widget.onDelete?.call();
                  },
            icon: const Icon(Icons.delete_outline),
            label: const Text('刪除'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
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

  Widget _row2({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 820;
        if (narrow) {
          return Column(
            children: [
              left,
              const SizedBox(height: 10),
              right,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _dateRow({
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final text = value == null ? '—' : _dtFmt.format(value);
    return Row(
      children: [
        Expanded(
          child: Text('$label：$text', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        TextButton(onPressed: onPick, child: const Text('選擇')),
        TextButton(onPressed: onClear, child: const Text('清除')),
      ],
    );
  }

  Future<void> _pickDateTime({required void Function(DateTime dt) setter}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
    if (time == null) return;

    setter(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // 依排程判斷：此處不強制關聯 isPublic，
    // 後端顯示邏輯可用「isPublic && schedule within range」做真正上架。
    final payload = <String, dynamic>{
      'title': _title.text.trim(),
      'category': _category.text.trim(),
      'content': _content.text.trim(),
      'imageUrl': _imageUrl.text.trim(),
      'linkText': _linkText.text.trim(),
      'linkUrl': _linkUrl.text.trim(),
      'isPublic': _isPublic,
      'isPinned': _isPinned,
      'startAt': _startAt == null ? null : Timestamp.fromDate(_startAt!),
      'endAt': _endAt == null ? null : Timestamp.fromDate(_endAt!),
    };

    // 清掉 null（避免 Firestore 寫入 null 覆蓋造成混亂）
    payload.removeWhere((k, v) => v == null);

    setState(() => _saving = true);
    try {
      await widget.onSave(payload);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已儲存')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ============================================================
// Model + Utils
// ============================================================

class _AnnouncementDoc {
  final String id;
  final Map<String, dynamic> raw;

  final String title;
  final String category;
  final String content;

  final bool isPublic; // 原始 isPublic
  final bool isPinned;

  final String imageUrl;
  final String linkText;
  final String linkUrl;

  final DateTime? startAt;
  final DateTime? endAt;

  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  _AnnouncementDoc({
    required this.id,
    required this.raw,
    required this.title,
    required this.category,
    required this.content,
    required this.isPublic,
    required this.isPinned,
    required this.imageUrl,
    required this.linkText,
    required this.linkUrl,
    required this.startAt,
    required this.endAt,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _AnnouncementDoc.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return _AnnouncementDoc(
      id: doc.id,
      raw: d,
      title: (d['title'] ?? '').toString(),
      category: (d['category'] ?? '').toString(),
      content: (d['content'] ?? '').toString(),
      isPublic: d['isPublic'] == null ? true : (d['isPublic'] == true),
      isPinned: d['isPinned'] == true,
      imageUrl: (d['imageUrl'] ?? '').toString(),
      linkText: (d['linkText'] ?? '').toString(),
      linkUrl: (d['linkUrl'] ?? '').toString(),
      startAt: _toDateTime(d['startAt']),
      endAt: _toDateTime(d['endAt']),
      sortOrder: _asInt(d['sortOrder'], fallback: 999999),
      createdAt: _toDateTime(d['createdAt']),
      updatedAt: _toDateTime(d['updatedAt']),
    );
  }

  // ✅ 前台真正顯示可用：isPublic && within schedule
  bool get isPublicNow {
    if (!isPublic) return false;
    final now = DateTime.now();
    if (startAt != null && now.isBefore(startAt!)) return false;
    if (endAt != null && now.isAfter(endAt!)) return false;
    return true;
  }

  String scheduleLabel(DateFormat fmt) {
    if (startAt == null && endAt == null) return '';
    final s = startAt == null ? '—' : fmt.format(startAt!);
    final e = endAt == null ? '—' : fmt.format(endAt!);
    return '排程：$s ~ $e';
  }
}

int _asInt(dynamic v, {required int fallback}) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  final p = int.tryParse(v?.toString() ?? '');
  return p ?? fallback;
}

DateTime? _toDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

// ============================================================
// Error View
// ============================================================

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String? hint;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    this.hint,
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
                  Text(title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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
