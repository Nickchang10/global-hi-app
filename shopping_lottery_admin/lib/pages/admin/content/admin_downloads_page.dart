// lib/pages/admin/content/admin_downloads_page.dart
//
// ✅ AdminDownloadsPage（檔案 / 下載管理｜A. 基礎專業版｜單檔完整版｜可編譯）
// ------------------------------------------------------------
// - Firestore：downloads 集合（不強制 orderBy，避免欄位不存在導致查詢失敗）
// - 功能：
//   1) 列表：搜尋 / 分類篩選 / 上下架篩選
//   2) 新增 / 編輯：標題、分類、描述、類型（URL / StoragePath）、上架狀態
//   3) Firebase Storage：輸入 storagePath 一鍵解析 downloadURL（不依賴 file_picker）
//   4) 拖曳排序：ReorderableListView（✅ 只允許在「無篩選」狀態排序，避免排序邏輯混亂）
//   5) 多選批次：上架 / 下架 / 刪除
//   6) 安全容錯：Map 轉型、Timestamp 轉 DateTime、欄位缺失不崩潰
//
// 建議資料結構：downloads/{id}
// {
//   title: "說明書 PDF",
//   category: "manual" | "firmware" | "policy" | "other",
//   description: "...",
//   type: "url" | "storage",
//   url: "https://....",               // type=url 或 storage 解析後
//   storagePath: "downloads/xxx.pdf",  // type=storage
//   enabled: true,
//   sortOrder: 0,
//   createdAt: Timestamp,
//   updatedAt: Timestamp,
//   updatedBy: "admin"
// }
//
// 依賴：cloud_firestore, firebase_storage, intl
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminDownloadsPage extends StatefulWidget {
  const AdminDownloadsPage({super.key});

  @override
  State<AdminDownloadsPage> createState() => _AdminDownloadsPageState();
}

class _AdminDownloadsPageState extends State<AdminDownloadsPage> {
  final _db = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _col = _db.collection('downloads');

  final _search = TextEditingController();

  bool _selectionMode = false;
  final Set<String> _selected = {};

  static const String _catAll = 'all';
  String _category = _catAll;

  static const String _statusAll = 'all';
  static const String _statusEnabled = 'enabled';
  static const String _statusDisabled = 'disabled';
  String _status = _statusAll;

  final _dtFmt = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    // ✅ 不做 orderBy：避免 createdAt/updatedAt/sortOrder 欄位不存在時直接噴錯
    return _col.limit(500).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('檔案 / 下載管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: '批次下架',
              icon: const Icon(Icons.visibility_off),
              onPressed: _selected.isEmpty ? null : () => _batchSetEnabled(false),
            ),
            IconButton(
              tooltip: '批次上架',
              icon: const Icon(Icons.visibility),
              onPressed: _selected.isEmpty ? null : () => _batchSetEnabled(true),
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
            tooltip: '新增',
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
                    onRetry: () => setState(() {}),
                    hint: '請確認 Firestore rules：downloads 允許 admin 讀寫。',
                  );
                }

                final docs = (snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .map((d) => _DownloadDoc.fromDoc(d))
                    .toList();

                // ✅ 先以 sortOrder（缺省很大）排序，再用 updatedAt 做 tie-break
                docs.sort((a, b) {
                  final so = a.sortOrder.compareTo(b.sortOrder);
                  if (so != 0) return so;
                  final ad = a.updatedAt ?? a.createdAt;
                  final bd = b.updatedAt ?? b.createdAt;
                  final at = ad?.millisecondsSinceEpoch ?? 0;
                  final bt = bd?.millisecondsSinceEpoch ?? 0;
                  return bt.compareTo(at);
                });

                final filtered = _applyFilters(docs);

                // 動態分類 options（包含 all）
                final cats = <String>{_catAll};
                for (final d in docs) {
                  if (d.category.trim().isNotEmpty) cats.add(d.category.trim());
                }
                final catKeys = cats.toList()
                  ..sort((a, b) {
                    if (a == _catAll) return -1;
                    if (b == _catAll) return 1;
                    return a.compareTo(b);
                  });

                // 若目前 category 不在 keys（避免 dropdown assertion）
                if (!catKeys.contains(_category)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() => _category = _catAll);
                  });
                }

                return Column(
                  children: [
                    _summaryRow(count: filtered.length, cs: cs),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('沒有符合條件的下載項'))
                          : _buildReorderableList(filtered, allowReorder: _canReorderNow()),
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
          final narrow = c.maxWidth < 880;

          final searchField = TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜尋（標題 / 分類 / 描述 / id）',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          final statusDD = DropdownButtonFormField<String>(
            isExpanded: true,
            value: _status,
            decoration: InputDecoration(
              isDense: true,
              labelText: '狀態',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: const [
              DropdownMenuItem(value: _statusAll, child: Text('全部')),
              DropdownMenuItem(value: _statusEnabled, child: Text('上架')),
              DropdownMenuItem(value: _statusDisabled, child: Text('下架')),
            ],
            onChanged: (v) => setState(() => _status = v ?? _statusAll),
          );

          final catDD = DropdownButtonFormField<String>(
            isExpanded: true,
            value: _category,
            decoration: InputDecoration(
              isDense: true,
              labelText: '分類',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: [
              const DropdownMenuItem(value: _catAll, child: Text('全部')),
              if (_category != _catAll) DropdownMenuItem(value: _category, child: Text(_category)),
            ],
            onChanged: (v) => setState(() => _category = v ?? _catAll),
          );

          final reorderHint = Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _canReorderNow()
                        ? '提示：可拖曳排序（將寫回 sortOrder）'
                        : '提示：需清除搜尋/篩選後才可排序（避免排序在子集合視圖中失真）',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _search.clear();
                      _category = _catAll;
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
                    Expanded(child: statusDD),
                    const SizedBox(width: 10),
                    Expanded(child: catDD),
                  ],
                ),
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
            style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
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
    return q.isEmpty && _category == _catAll && _status == _statusAll && !_selectionMode;
  }

  List<_DownloadDoc> _applyFilters(List<_DownloadDoc> input) {
    final q = _search.text.trim().toLowerCase();

    return input.where((d) {
      final matchQ = q.isEmpty ||
          d.id.toLowerCase().contains(q) ||
          d.title.toLowerCase().contains(q) ||
          d.category.toLowerCase().contains(q) ||
          d.description.toLowerCase().contains(q);

      final matchCat = _category == _catAll ? true : d.category == _category;

      final matchStatus = switch (_status) {
        _statusAll => true,
        _statusEnabled => d.enabled,
        _statusDisabled => !d.enabled,
        _ => true,
      };

      return matchQ && matchCat && matchStatus;
    }).toList();
  }

  Widget _buildReorderableList(List<_DownloadDoc> items, {required bool allowReorder}) {
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
        return _buildTile(d, index: i, key: ValueKey(d.id), allowReorder: allowReorder);
      },
    );
  }

  Widget _buildTile(_DownloadDoc d, {required int index, required Key key, required bool allowReorder}) {
    final cs = Theme.of(context).colorScheme;
    final selected = _selected.contains(d.id);

    final updatedText = d.updatedAt == null ? '' : _dtFmt.format(d.updatedAt!);
    final typeLabel = d.type == _DownloadType.storage ? 'Storage' : 'URL';

    return Card(
      key: key,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: d.enabled ? cs.primaryContainer : Colors.grey.shade200,
          child: Icon(
            d.type == _DownloadType.storage ? Icons.cloud_outlined : Icons.link_outlined,
            color: d.enabled ? cs.onPrimaryContainer : Colors.grey.shade600,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                d.title.isEmpty ? '(未命名)' : d.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            _pill(typeLabel),
            const SizedBox(width: 6),
            _pill(d.enabled ? '上架' : '下架', enabled: d.enabled),
          ],
        ),
        subtitle: Text(
          [
            if (d.category.isNotEmpty) '分類：${d.category}',
            if (updatedText.isNotEmpty) '更新：$updatedText',
            if (d.description.isNotEmpty) d.description,
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
                width: 160,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: '複製連結',
                      icon: const Icon(Icons.copy),
                      onPressed: () => _copyText(d.url),
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
                      Icon(Icons.drag_handle, color: cs.onSurfaceVariant.withOpacity(0.35)),
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
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg)),
    );
  }

  Future<void> _onReorder(List<_DownloadDoc> items, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;

    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    final batch = _db.batch();
    for (int i = 0; i < items.length; i++) {
      batch.set(_col.doc(items[i].id), {
        'sortOrder': i,
        'updatedAt': FieldValue.serverTimestamp(),
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
      builder: (_) => _DownloadsEditorDialog(
        title: '新增下載項',
        initial: const {},
        onSave: (payload) async {
          // ✅ 建立時給 sortOrder：用目前最大 sortOrder + 1（讀取一次）
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
      builder: (_) => _DownloadsEditorDialog(
        title: '編輯下載項',
        initial: d.raw,
        docId: d.id,
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
    // 讀取少量即可（避免 500 筆）
    // 若資料量大，建議用 aggregate；此處以簡單可用為主
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

  Future<void> _batchSetEnabled(bool enabled) async {
    final ok = await _confirm(
      title: enabled ? '批次上架' : '批次下架',
      message: '共選取 ${_selected.length} 筆，確定要${enabled ? '上架' : '下架'}？',
      confirmText: '確認',
    );
    if (ok != true) return;

    final batch = _db.batch();
    for (final id in _selected) {
      batch.set(_col.doc(id), {
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'admin',
      }, SetOptions(merge: true));
    }
    await batch.commit();

    if (!mounted) return;
    setState(() => _selected.clear());
    _toast('已${enabled ? '上架' : '下架'}選取項目');
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
    _toast('已刪除選取項目');
  }

  Future<void> _confirmDeleteOne(String id) async {
    final ok = await _confirm(
      title: '刪除下載項',
      message: '確定要刪除這筆資料嗎？\nID: $id',
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
    _toast('已複製連結');
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

class _DownloadsEditorDialog extends StatefulWidget {
  final String title;
  final String? docId;
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, dynamic> payload) onSave;
  final VoidCallback? onDelete;

  const _DownloadsEditorDialog({
    required this.title,
    required this.initial,
    required this.onSave,
    this.docId,
    this.onDelete,
  });

  @override
  State<_DownloadsEditorDialog> createState() => _DownloadsEditorDialogState();
}

class _DownloadsEditorDialogState extends State<_DownloadsEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _category = TextEditingController();
  final _description = TextEditingController();
  final _url = TextEditingController();
  final _storagePath = TextEditingController();

  bool _enabled = true;
  _DownloadType _type = _DownloadType.url;

  bool _saving = false;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _title.text = (d['title'] ?? '').toString();
    _category.text = (d['category'] ?? '').toString();
    _description.text = (d['description'] ?? '').toString();
    _url.text = (d['url'] ?? '').toString();
    _storagePath.text = (d['storagePath'] ?? '').toString();
    _enabled = d['enabled'] == null ? true : (d['enabled'] == true);

    final t = (d['type'] ?? 'url').toString().toLowerCase();
    _type = (t == 'storage') ? _DownloadType.storage : _DownloadType.url;
  }

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _description.dispose();
    _url.dispose();
    _storagePath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 840,
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
                      hintText: 'manual / firmware / policy / other...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '描述（可空）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _row2(
                  left: DropdownButtonFormField<_DownloadType>(
                    value: _type,
                    decoration: const InputDecoration(
                      labelText: '類型',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: _DownloadType.url, child: Text('URL 連結')),
                      DropdownMenuItem(value: _DownloadType.storage, child: Text('Firebase Storage 路徑')),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) {
                            setState(() => _type = v ?? _DownloadType.url);
                          },
                  ),
                  right: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('上架', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(_enabled ? '目前：上架' : '目前：下架',
                        style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                    value: _enabled,
                    onChanged: _saving ? null : (v) => setState(() => _enabled = v),
                  ),
                ),
                const SizedBox(height: 10),

                if (_type == _DownloadType.url) ...[
                  TextFormField(
                    controller: _url,
                    decoration: const InputDecoration(
                      labelText: 'URL（必填）',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return '請輸入 URL';
                      if (!s.startsWith('http://') && !s.startsWith('https://')) return 'URL 必須以 http(s) 開頭';
                      return null;
                    },
                  ),
                ] else ...[
                  TextFormField(
                    controller: _storagePath,
                    decoration: const InputDecoration(
                      labelText: 'Storage Path（必填）',
                      hintText: 'downloads/xxx.pdf',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? '請輸入 Storage Path' : null,
                  ),
                  const SizedBox(height: 10),
                  _row2(
                    left: TextFormField(
                      controller: _url,
                      decoration: const InputDecoration(
                        labelText: '解析後的 Download URL（可由下方按鈕生成）',
                        hintText: 'https://firebasestorage.googleapis.com/...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    right: FilledButton.tonalIcon(
                      onPressed: _saving || _resolving ? null : _resolveDownloadUrl,
                      icon: _resolving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                            )
                          : const Icon(Icons.link),
                      label: Text(_resolving ? '解析中...' : '一鍵解析 URL'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '提示：此功能不需要上傳檔案，只要輸入 storagePath，就能取得可下載的 URL。',
                      style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],

                const SizedBox(height: 10),
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
        final narrow = c.maxWidth < 760;
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

  Future<void> _resolveDownloadUrl() async {
    final path = _storagePath.text.trim();
    if (path.isEmpty) {
      _toast('請先輸入 Storage Path');
      return;
    }

    setState(() => _resolving = true);
    try {
      final url = await FirebaseStorage.instance.ref(path).getDownloadURL();
      _url.text = url;
      _toast('已解析 URL');
    } catch (e) {
      _toast('解析失敗：$e');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _title.text.trim();
    final category = _category.text.trim();
    final description = _description.text.trim();
    final url = _url.text.trim();
    final storagePath = _storagePath.text.trim();

    // 額外防呆
    if (_type == _DownloadType.storage && url.isEmpty) {
      // 允許沒解析 URL 也先存，但專業版建議提示
      final ok = await _confirm(
        title: '尚未解析 URL',
        message: '你選擇了 Storage Path 類型，但 URL 目前為空。\n仍要儲存嗎？（之後可再解析）',
        confirmText: '仍要儲存',
      );
      if (ok != true) return;
    }

    final payload = <String, dynamic>{
      'title': title,
      'category': category,
      'description': description,
      'type': _type == _DownloadType.storage ? 'storage' : 'url',
      'enabled': _enabled,
      'url': url,
      'storagePath': _type == _DownloadType.storage ? storagePath : '',
    };

    setState(() => _saving = true);
    try {
      await widget.onSave(payload);
      if (!mounted) return;
      Navigator.pop(context);
      _toast('已儲存');
    } catch (e) {
      _toast('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmText)),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ============================================================
// Model + Utils
// ============================================================

enum _DownloadType { url, storage }

class _DownloadDoc {
  final String id;
  final Map<String, dynamic> raw;

  final String title;
  final String category;
  final String description;

  final _DownloadType type;
  final String url;
  final String storagePath;

  final bool enabled;

  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  _DownloadDoc({
    required this.id,
    required this.raw,
    required this.title,
    required this.category,
    required this.description,
    required this.type,
    required this.url,
    required this.storagePath,
    required this.enabled,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _DownloadDoc.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();

    final t = (d['type'] ?? 'url').toString().toLowerCase();
    final type = (t == 'storage') ? _DownloadType.storage : _DownloadType.url;

    return _DownloadDoc(
      id: doc.id,
      raw: d,
      title: (d['title'] ?? '').toString(),
      category: (d['category'] ?? '').toString(),
      description: (d['description'] ?? '').toString(),
      type: type,
      url: (d['url'] ?? '').toString(),
      storagePath: (d['storagePath'] ?? '').toString(),
      enabled: d['enabled'] == null ? true : (d['enabled'] == true),
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
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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
