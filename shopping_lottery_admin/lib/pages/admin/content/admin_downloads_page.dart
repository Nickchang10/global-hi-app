// lib/pages/admin/content/admin_downloads_page.dart
//
// ✅ AdminDownloadsPage（下載專區管理｜單檔完整版｜可編譯）
// ------------------------------------------------------------
// - Firestore：downloads 集合
// - 功能：
//   1) 列表：搜尋 / 平台篩選 / 上下架篩選
//   2) 新增 / 編輯：標題、平台、版本、下載連結、更新說明、上架
//   3) 拖曳排序：ReorderableListView（✅ 只允許在「無篩選」狀態排序）
//   4) 多選批次：上架 / 下架 / 刪除
//   5) 欄位容錯：Timestamp 轉 DateTime、缺欄位不崩潰
//
// 依賴：cloud_firestore, intl
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminDownloadsPage extends StatefulWidget {
  const AdminDownloadsPage({super.key});

  @override
  State<AdminDownloadsPage> createState() => _AdminDownloadsPageState();
}

class _AdminDownloadsPageState extends State<AdminDownloadsPage> {
  final _db = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _col = _db.collection(
    'downloads',
  );

  final _search = TextEditingController();

  bool _selectionMode = false;
  final Set<String> _selected = {};

  static const String _platAll = 'all';
  static const List<String> _platformOptions = <String>[
    _platAll,
    'android',
    'ios',
    'windows',
    'mac',
    'web',
    'other',
  ];
  String _platform = _platAll;

  static const String _statusAll = 'all';
  static const String _statusPublic = 'public';
  static const String _statusHidden = 'hidden';
  String _status = _statusAll;

  final _dtFmt = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _alpha255(double opacity01) => (opacity01 * 255).round().clamp(0, 255);

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    // ✅ 不 orderBy：避免 sortOrder 欄位不存在時 query 直接炸
    return _col.limit(500).snapshots();
  }

  bool _canReorderNow() {
    final q = _search.text.trim();
    return q.isEmpty &&
        _platform == _platAll &&
        _status == _statusAll &&
        !_selectionMode;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '下載專區管理',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: '批次下架',
              icon: const Icon(Icons.visibility_off),
              onPressed: _selected.isEmpty
                  ? null
                  : () => _batchSetPublic(false),
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
            tooltip: '新增下載項',
            icon: const Icon(Icons.add),
            onPressed: _openCreate,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('新增下載項'),
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
                    hint: '請確認 Firestore rules：downloads 允許 admin 讀寫。',
                    onRetry: () => setState(() {}),
                  );
                }

                final docs =
                    (snap.data?.docs ??
                            <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                        .map((d) => _DownloadDoc.fromDoc(d))
                        .toList();

                // ✅ client-side sort：sortOrder -> updatedAt/createdAt -> id
                docs.sort((a, b) {
                  final so = a.sortOrder.compareTo(b.sortOrder);
                  if (so != 0) return so;
                  final at =
                      (a.updatedAt ?? a.createdAt)?.millisecondsSinceEpoch ?? 0;
                  final bt =
                      (b.updatedAt ?? b.createdAt)?.millisecondsSinceEpoch ?? 0;
                  final c = bt.compareTo(at);
                  if (c != 0) return c;
                  return a.id.compareTo(b.id);
                });

                final filtered = _applyFilters(docs);

                return Column(
                  children: [
                    _summaryRow(
                      total: docs.length,
                      showing: filtered.length,
                      cs: cs,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('沒有符合條件的下載項'))
                          : _buildList(
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
          final cs = Theme.of(context).colorScheme;
          final narrow = c.maxWidth < 980;

          final searchField = TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜尋（title / version / platform / id）',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          final platformDD = DropdownButtonFormField<String>(
            key: ValueKey('plat_$_platform'),
            isExpanded: true,
            initialValue: _platform,
            decoration: InputDecoration(
              isDense: true,
              labelText: '平台',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: _platformOptions
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e == _platAll ? '全部' : e),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _platform = v ?? _platAll),
          );

          final statusDD = DropdownButtonFormField<String>(
            key: ValueKey('status_$_status'),
            isExpanded: true,
            initialValue: _status,
            decoration: InputDecoration(
              isDense: true,
              labelText: '上架狀態',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: const [
              DropdownMenuItem(value: _statusAll, child: Text('全部')),
              DropdownMenuItem(value: _statusPublic, child: Text('上架')),
              DropdownMenuItem(value: _statusHidden, child: Text('下架')),
            ],
            onChanged: (v) => setState(() => _status = v ?? _statusAll),
          );

          final hintRow = Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _canReorderNow()
                        ? '提示：可拖曳排序（將寫回 sortOrder）'
                        : '提示：需清除搜尋/篩選後才可排序',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _search.clear();
                      _platform = _platAll;
                      _status = _statusAll;
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
                    Expanded(child: platformDD),
                    const SizedBox(width: 10),
                    Expanded(child: statusDD),
                  ],
                ),
                hintRow,
              ],
            );
          }

          return Column(
            children: [
              Row(
                children: [
                  Expanded(flex: 4, child: searchField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: platformDD),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: statusDD),
                ],
              ),
              hintRow,
            ],
          );
        },
      ),
    );
  }

  Widget _summaryRow({
    required int total,
    required int showing,
    required ColorScheme cs,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Text(
            '共 $total 筆｜目前顯示 $showing 筆',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
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
  // List
  // ============================================================

  List<_DownloadDoc> _applyFilters(List<_DownloadDoc> input) {
    final q = _search.text.trim().toLowerCase();

    return input.where((d) {
      final matchQ =
          q.isEmpty ||
          d.id.toLowerCase().contains(q) ||
          d.title.toLowerCase().contains(q) ||
          d.version.toLowerCase().contains(q) ||
          d.platform.toLowerCase().contains(q);

      final matchPlat = _platform == _platAll ? true : d.platform == _platform;

      final matchStatus = switch (_status) {
        _statusAll => true,
        _statusPublic => d.isPublic,
        _statusHidden => !d.isPublic,
        _ => true,
      };

      return matchQ && matchPlat && matchStatus;
    }).toList();
  }

  Widget _buildList(List<_DownloadDoc> items, {required bool allowReorder}) {
    if (!allowReorder) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 90),
        itemCount: items.length,
        itemBuilder: (context, i) =>
            _tile(items[i], index: i, allowReorder: false),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) async {
        if (!_canReorderNow()) {
          _toast('請清除篩選後再排序');
          return;
        }
        await _onReorder(items, oldIndex, newIndex);
      },
      itemBuilder: (context, i) => _tile(
        items[i],
        index: i,
        allowReorder: true,
        key: ValueKey(items[i].id),
      ),
    );
  }

  Widget _tile(
    _DownloadDoc d, {
    required int index,
    required bool allowReorder,
    Key? key,
  }) {
    final cs = Theme.of(context).colorScheme;
    final selected = _selected.contains(d.id);

    final updatedText = d.updatedAt == null ? '' : _dtFmt.format(d.updatedAt!);

    final badgeBg = d.isPublic
        ? Colors.green.shade100
        : cs.surfaceContainerHighest.withAlpha(_alpha255(0.65));
    final badgeFg = d.isPublic ? Colors.green.shade900 : cs.onSurfaceVariant;

    return Card(
      key: key ?? ValueKey(d.id),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListTile(
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
        tileColor: selected
            ? cs.primaryContainer.withAlpha(_alpha255(0.35))
            : null,
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(Icons.download_outlined, color: cs.onPrimaryContainer),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                d.title.isEmpty ? '(未命名下載項)' : d.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                d.isPublic ? '上架' : '下架',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: badgeFg,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          [
            'platform=${d.platform.isEmpty ? 'other' : d.platform}',
            if (d.version.isNotEmpty) 'version=${d.version}',
            if (updatedText.isNotEmpty) '更新=$updatedText',
            'id=${d.id}',
          ].join('  •  '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
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
                    Switch(
                      value: d.isPublic,
                      onChanged: (v) => _setPublic(d.id, v),
                    ),
                    const SizedBox(width: 6),
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
                      Icon(
                        Icons.drag_handle,
                        color: cs.onSurfaceVariant.withAlpha(_alpha255(0.35)),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  // ============================================================
  // Reorder
  // ============================================================

  Future<void> _onReorder(
    List<_DownloadDoc> items,
    int oldIndex,
    int newIndex,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

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

    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('排序已更新')));
  }

  // ============================================================
  // CRUD
  // ============================================================

  Future<void> _openCreate() async {
    await showDialog(
      context: context,
      builder: (_) => _DownloadEditorDialog(
        title: '新增下載項',
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

  Future<void> _openEdit(_DownloadDoc d) async {
    await showDialog(
      context: context,
      builder: (_) => _DownloadEditorDialog(
        title: '編輯下載項',
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
      final so = _asInt(doc.data()['sortOrder'], fallback: 999999);
      if (so != 999999 && so > maxOrder) maxOrder = so;
    }
    return maxOrder + 1;
  }

  Future<void> _setPublic(String id, bool isPublic) async {
    // ✅ await 前先抓 messenger，避免 async gap 後用 context
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _col.doc(id).set({
        'isPublic': isPublic,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'admin',
      }, SetOptions(merge: true));

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(isPublic ? '已上架' : '已下架')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  // ============================================================
  // Batch  ✅ FIX: remove use_build_context_synchronously
  // ============================================================

  Future<void> _batchSetPublic(bool isPublic) async {
    // ✅ 先抓 messenger（在任何 await 前）
    final messenger = ScaffoldMessenger.of(context);

    final ok = await _confirm(
      title: isPublic ? '批次上架' : '批次下架',
      message: '共選取 ${_selected.length} 筆，確定要${isPublic ? '上架' : '下架'}？',
      confirmText: '確認',
    );

    if (!mounted) return;
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
    messenger.showSnackBar(
      SnackBar(content: Text('已${isPublic ? '上架' : '下架'}選取項目')),
    );
  }

  Future<void> _confirmBatchDelete() async {
    // ✅ 先抓 messenger（在任何 await 前）
    final messenger = ScaffoldMessenger.of(context);

    final ok = await _confirm(
      title: '批次刪除',
      message: '共選取 ${_selected.length} 筆，刪除後無法復原。',
      confirmText: '刪除',
      isDanger: true,
    );

    if (!mounted) return;
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
    messenger.showSnackBar(const SnackBar(content: Text('已刪除選取項目')));
  }

  Future<void> _confirmDeleteOne(String id) async {
    // ✅ 先抓 messenger（在任何 await 前）
    final messenger = ScaffoldMessenger.of(context);

    final ok = await _confirm(
      title: '刪除下載項',
      message: '確定要刪除這筆資料嗎？\nID: $id',
      confirmText: '刪除',
      isDanger: true,
    );

    if (!mounted) return;
    if (ok != true) return;

    await _col.doc(id).delete();

    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('已刪除')));
  }

  // ============================================================
  // Helpers
  // ============================================================

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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
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

class _DownloadEditorDialog extends StatefulWidget {
  final String title;
  final String? docId;
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, dynamic> payload) onSave;
  final VoidCallback? onDelete;

  const _DownloadEditorDialog({
    required this.title,
    required this.initial,
    required this.onSave,
    this.docId,
    this.onDelete,
  });

  @override
  State<_DownloadEditorDialog> createState() => _DownloadEditorDialogState();
}

class _DownloadEditorDialogState extends State<_DownloadEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _version = TextEditingController();
  final _fileUrl = TextEditingController();
  final _notes = TextEditingController();

  static const List<String> _platforms = <String>[
    'android',
    'ios',
    'windows',
    'mac',
    'web',
    'other',
  ];
  String _platform = 'android';

  bool _isPublic = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;

    _title.text = (d['title'] ?? '').toString();
    _version.text = (d['version'] ?? '').toString();
    _fileUrl.text = (d['fileUrl'] ?? d['url'] ?? '').toString();
    _notes.text = (d['notes'] ?? '').toString();

    final plat = (d['platform'] ?? 'android').toString();
    _platform = _platforms.contains(plat) ? plat : 'other';

    _isPublic = d['isPublic'] == null ? true : (d['isPublic'] == true);
  }

  @override
  void dispose() {
    _title.dispose();
    _version.dispose();
    _fileUrl.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
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
                      labelText: '標題 *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '請輸入標題' : null,
                  ),
                  right: TextFormField(
                    controller: _version,
                    decoration: const InputDecoration(
                      labelText: '版本（可空）',
                      hintText: '1.2.3',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  key: ValueKey('platform_$_platform'),
                  isExpanded: true,
                  initialValue: _platform,
                  decoration: const InputDecoration(
                    labelText: '平台（platform）',
                    border: OutlineInputBorder(),
                  ),
                  items: _platforms
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() => _platform = v);
                        },
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _fileUrl,
                  decoration: const InputDecoration(
                    labelText: '下載連結（fileUrl）*',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '請輸入下載連結' : null,
                ),
                const SizedBox(height: 10),

                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: const Text(
                    '上架',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    _isPublic ? '目前：上架' : '目前：下架',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  value: _isPublic,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _isPublic = v),
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _notes,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '更新說明（notes，可空）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.docId == null ? '' : 'ID：${widget.docId}',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
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
                : () {
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimary,
                  ),
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
          return Column(children: [left, const SizedBox(height: 10), right]);
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final payload = <String, dynamic>{
      'title': _title.text.trim(),
      'version': _version.text.trim(),
      'platform': _platform,
      'fileUrl': _fileUrl.text.trim(),
      'notes': _notes.text.trim(),
      'isPublic': _isPublic,
    };

    // ✅ await 前先抓 nav/messenger，await 後不再用 context
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _saving = true);
    try {
      await widget.onSave(payload);

      if (!mounted) return;
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('已儲存')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ============================================================
// Model + Utils
// ============================================================

class _DownloadDoc {
  final String id;
  final Map<String, dynamic> raw;

  final String title;
  final String platform;
  final String version;
  final String fileUrl;
  final String notes;

  final bool isPublic;
  final int sortOrder;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  _DownloadDoc({
    required this.id,
    required this.raw,
    required this.title,
    required this.platform,
    required this.version,
    required this.fileUrl,
    required this.notes,
    required this.isPublic,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _DownloadDoc.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    return _DownloadDoc(
      id: doc.id,
      raw: d,
      title: (d['title'] ?? '').toString(),
      platform: (d['platform'] ?? 'other').toString(),
      version: (d['version'] ?? '').toString(),
      fileUrl: (d['fileUrl'] ?? d['url'] ?? '').toString(),
      notes: (d['notes'] ?? '').toString(),
      isPublic: d['isPublic'] == null ? true : (d['isPublic'] == true),
      sortOrder: _asInt(d['sortOrder'], fallback: 999999),
      createdAt: _toDateTime(d['createdAt']),
      updatedAt: _toDateTime(d['updatedAt']),
    );
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
  final String? hint;
  final VoidCallback onRetry;

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
