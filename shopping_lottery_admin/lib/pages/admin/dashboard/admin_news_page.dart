// lib/pages/admin/dashboard/admin_news_page.dart
//
// ✅ AdminNewsPage（最新消息管理｜單檔完整版｜可直接使用｜可編譯）
// ------------------------------------------------------------
// Firestore：news 集合
// 功能：
// 1) 列表：搜尋 / 狀態篩選（draft/published）/ 公開篩選
// 2) 新增/編輯：標題、摘要、封面連結、內容、狀態、公開
// 3) 拖曳排序：ReorderableListView（✅ 只允許在「無篩選」狀態排序）
// 4) 多選批次：公開/不公開/刪除
// 5) 欄位容錯：Timestamp → DateTime、缺欄位不崩潰
//
// 依賴：cloud_firestore, intl
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
  late final CollectionReference<Map<String, dynamic>> _col = _db.collection(
    'news',
  );

  final _search = TextEditingController();

  bool _selectionMode = false;
  final Set<String> _selected = {};

  static const String _statusAll = 'all';
  static const String _statusDraft = 'draft';
  static const String _statusPublished = 'published';
  String _status = _statusAll;

  static const String _pubAll = 'all';
  static const String _pubPublic = 'public';
  static const String _pubHidden = 'hidden';
  String _pub = _pubAll;

  final _dtFmt = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _alpha255(double opacity01) => (opacity01 * 255).round().clamp(0, 255);

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    // ✅ 不 orderBy：避免 sortOrder / updatedAt 欄位不存在時 query 直接炸
    return _col.limit(800).snapshots();
  }

  bool _canReorderNow() {
    final q = _search.text.trim();
    return q.isEmpty &&
        _status == _statusAll &&
        _pub == _pubAll &&
        !_selectionMode;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '最新消息管理',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: '批次設為不公開',
              icon: const Icon(Icons.visibility_off),
              onPressed: _selected.isEmpty
                  ? null
                  : () => _batchSetPublic(false),
            ),
            IconButton(
              tooltip: '批次設為公開',
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
              stream: _stream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorView(
                    title: '載入失敗',
                    message: snap.error.toString(),
                    hint: '請確認 Firestore rules：news 允許 admin 讀寫。',
                    onRetry: () => setState(() {}),
                  );
                }

                final items = (snap.data?.docs ?? const [])
                    .map((d) => _NewsDoc.fromDoc(d))
                    .toList();

                // ✅ client-side sort：sortOrder -> updatedAt/createdAt desc -> id
                items.sort((a, b) {
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

                final filtered = _applyFilters(items);

                return Column(
                  children: [
                    _summaryRow(
                      total: items.length,
                      showing: filtered.length,
                      cs: cs,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('沒有符合條件的消息'))
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
              hintText: '搜尋（title / summary / status / id）',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          final statusDD = DropdownButtonFormField<String>(
            key: ValueKey('status_$_status'),
            isExpanded: true,
            initialValue: _status,
            decoration: InputDecoration(
              isDense: true,
              labelText: '狀態',
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
              DropdownMenuItem(value: _statusDraft, child: Text('草稿')),
              DropdownMenuItem(value: _statusPublished, child: Text('已上架')),
            ],
            onChanged: (v) => setState(() => _status = v ?? _statusAll),
          );

          final pubDD = DropdownButtonFormField<String>(
            key: ValueKey('pub_$_pub'),
            isExpanded: true,
            initialValue: _pub,
            decoration: InputDecoration(
              isDense: true,
              labelText: '公開',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: const [
              DropdownMenuItem(value: _pubAll, child: Text('全部')),
              DropdownMenuItem(value: _pubPublic, child: Text('公開')),
              DropdownMenuItem(value: _pubHidden, child: Text('不公開')),
            ],
            onChanged: (v) => setState(() => _pub = v ?? _pubAll),
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
                      _status = _statusAll;
                      _pub = _pubAll;
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
                    Expanded(child: pubDD),
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
                  Expanded(flex: 2, child: statusDD),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: pubDD),
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

  List<_NewsDoc> _applyFilters(List<_NewsDoc> input) {
    final q = _search.text.trim().toLowerCase();

    return input.where((d) {
      final matchQ =
          q.isEmpty ||
          d.id.toLowerCase().contains(q) ||
          d.title.toLowerCase().contains(q) ||
          d.summary.toLowerCase().contains(q) ||
          d.status.toLowerCase().contains(q);

      final matchStatus = switch (_status) {
        _statusAll => true,
        _statusDraft => d.status == _statusDraft,
        _statusPublished => d.status == _statusPublished,
        _ => true,
      };

      final matchPub = switch (_pub) {
        _pubAll => true,
        _pubPublic => d.isPublic == true,
        _pubHidden => d.isPublic != true,
        _ => true,
      };

      return matchQ && matchStatus && matchPub;
    }).toList();
  }

  Widget _buildList(List<_NewsDoc> items, {required bool allowReorder}) {
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
    _NewsDoc d, {
    required int index,
    required bool allowReorder,
    Key? key,
  }) {
    final cs = Theme.of(context).colorScheme;
    final selected = _selected.contains(d.id);

    final time = d.updatedAt ?? d.createdAt;
    final timeText = time == null ? '—' : _dtFmt.format(time);

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
            ? cs.primaryContainer.withAlpha(_alpha255(0.28))
            : null,
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(Icons.article_outlined, color: cs.onPrimaryContainer),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                d.title.isEmpty ? '(未命名消息)' : d.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            _pill(
              d.status == _statusPublished ? '已上架' : '草稿',
              enabled: d.status == _statusPublished,
            ),
            const SizedBox(width: 6),
            _pill(d.isPublic ? '公開' : '不公開', enabled: d.isPublic),
          ],
        ),
        subtitle: Text(
          [
            if (d.summary.isNotEmpty) d.summary,
            '更新：$timeText',
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
                width: 240,
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

  Widget _pill(String text, {bool enabled = true}) {
    final bg = enabled ? Colors.green.shade100 : Colors.grey.shade200;
    final fg = enabled ? Colors.green.shade900 : Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }

  // ============================================================
  // Reorder
  // ============================================================

  Future<void> _onReorder(
    List<_NewsDoc> items,
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
      builder: (_) => _NewsEditorDialog(
        title: '新增消息',
        initial: const {},
        onSave: (payload) async {
          final nextOrder = await _nextSortOrder();
          await _col.add({
            ...payload,
            'sortOrder': nextOrder,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': 'admin',
          });
        },
      ),
    );
  }

  Future<void> _openEdit(_NewsDoc d) async {
    await showDialog(
      context: context,
      builder: (_) => _NewsEditorDialog(
        title: '編輯消息',
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
      final so = _asInt(doc.data()['sortOrder'], fallback: -1);
      if (so > maxOrder) maxOrder = so;
    }
    return maxOrder + 1;
  }

  Future<void> _setPublic(String id, bool isPublic) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _col.doc(id).set({
        'isPublic': isPublic,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'admin',
      }, SetOptions(merge: true));
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(isPublic ? '已設為公開' : '已設為不公開')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  // ============================================================
  // Batch
  // ============================================================

  Future<void> _batchSetPublic(bool isPublic) async {
    final ok = await _confirm(
      title: isPublic ? '批次設為公開' : '批次設為不公開',
      message: '共選取 ${_selected.length} 筆，確定要執行？',
      confirmText: '確認',
    );
    if (ok != true) return;

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

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
    messenger.showSnackBar(const SnackBar(content: Text('已批次更新')));
  }

  Future<void> _confirmBatchDelete() async {
    final ok = await _confirm(
      title: '批次刪除',
      message: '共選取 ${_selected.length} 筆，刪除後無法復原。',
      confirmText: '刪除',
      isDanger: true,
    );
    if (ok != true) return;

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

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
    final ok = await _confirm(
      title: '刪除消息',
      message: '確定要刪除這筆資料嗎？\nID: $id',
      confirmText: '刪除',
      isDanger: true,
    );
    if (ok != true) return;

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

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

class _NewsEditorDialog extends StatefulWidget {
  final String title;
  final String? docId;
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, dynamic> payload) onSave;
  final VoidCallback? onDelete;

  const _NewsEditorDialog({
    required this.title,
    required this.initial,
    required this.onSave,
    this.docId,
    this.onDelete,
  });

  @override
  State<_NewsEditorDialog> createState() => _NewsEditorDialogState();
}

class _NewsEditorDialogState extends State<_NewsEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _coverUrl = TextEditingController();
  final _content = TextEditingController();

  String _status = 'draft';
  bool _isPublic = true;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;

    _title.text = (d['title'] ?? '').toString();
    _summary.text = (d['summary'] ?? '').toString();
    _coverUrl.text = (d['coverUrl'] ?? '').toString();
    _content.text = (d['content'] ?? '').toString();

    final st = (d['status'] ?? 'draft').toString();
    _status = (st == 'published' || st == 'draft') ? st : 'draft';
    _isPublic = d['isPublic'] == null ? true : (d['isPublic'] == true);
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _coverUrl.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      // ✅ FIX: 這行括號已修正（上一版多打一個 ')'）
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
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: '標題 *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '請輸入標題' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _summary,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '摘要（可空）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _coverUrl,
                  decoration: const InputDecoration(
                    labelText: '封面圖片連結 coverUrl（可空）',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  key: ValueKey('status_$_status'),
                  isExpanded: true,
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: '狀態（status）',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('草稿')),
                    DropdownMenuItem(value: 'published', child: Text('已上架')),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _status = v ?? _status),
                ),
                const SizedBox(height: 6),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    '前台公開（isPublic）',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    _isPublic ? '目前：公開' : '目前：不公開',
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
                const SizedBox(height: 6),

                TextFormField(
                  controller: _content,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: '內容 content（可用 Markdown / HTML）',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (widget.docId != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ID：${widget.docId}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final payload = <String, dynamic>{
      'title': _title.text.trim(),
      'summary': _summary.text.trim(),
      'coverUrl': _coverUrl.text.trim(),
      'content': _content.text,
      'status': _status,
      'isPublic': _isPublic,
    };

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

class _NewsDoc {
  final String id;
  final Map<String, dynamic> raw;

  final String title;
  final String summary;
  final String coverUrl;
  final String content;

  final String status; // draft / published
  final bool isPublic;

  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  _NewsDoc({
    required this.id,
    required this.raw,
    required this.title,
    required this.summary,
    required this.coverUrl,
    required this.content,
    required this.status,
    required this.isPublic,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _NewsDoc.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final st = (d['status'] ?? 'draft').toString();
    return _NewsDoc(
      id: doc.id,
      raw: d,
      title: (d['title'] ?? '').toString(),
      summary: (d['summary'] ?? '').toString(),
      coverUrl: (d['coverUrl'] ?? '').toString(),
      content: (d['content'] ?? '').toString(),
      status: (st == 'published' || st == 'draft') ? st : 'draft',
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
