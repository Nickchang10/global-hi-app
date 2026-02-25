// lib/pages/categories_page.dart
//
// ✅ CategoriesPage（單檔完整版｜可編譯可用｜已避免 unnecessary !）
// ------------------------------------------------------------
// Firestore: categories/{id}
// fields:
// - name: String
// - slug: String
// - description: String
// - imageUrl: String
// - parentId: String (可空)
// - isActive: bool
// - order: int
// - createdAt: Timestamp
// - updatedAt: Timestamp
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _col = _db.collection(
    'categories',
  );

  final _searchCtrl = TextEditingController();
  String _q = '';
  CatFilter _filter = CatFilter.all;

  bool _busyReorder = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  DateTime? _toDt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  String _fmtDt(DateTime? d) {
    if (d == null) return '—';
    return DateFormat('yyyy/MM/dd HH:mm').format(d);
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  Query<Map<String, dynamic>> _baseQuery() {
    // ✅ 不依賴 order 欄位，避免舊資料沒補 order 時 query 直接炸
    return _col.orderBy(FieldPath.documentId).limit(500);
  }

  bool _match(CategoryItem c) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;
    final text = <String>[
      c.id,
      c.name,
      c.slug,
      c.description,
      c.parentId,
      c.imageUrl,
    ].join(' ').toLowerCase();
    return text.contains(q);
  }

  List<CategoryItem> _apply(List<CategoryItem> list) {
    Iterable<CategoryItem> out = list;

    switch (_filter) {
      case CatFilter.active:
        out = out.where((c) => c.isActive);
        break;
      case CatFilter.inactive:
        out = out.where((c) => !c.isActive);
        break;
      case CatFilter.all:
        break;
    }

    out = out.where(_match);

    final sorted = out.toList()
      ..sort((a, b) {
        // ✅ order 優先，其次 updatedAt
        final byOrder = a.order.compareTo(b.order);
        if (byOrder != 0) return byOrder;

        final atA =
            a.updatedAt ??
            a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final atB =
            b.updatedAt ??
            b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return atB.compareTo(atA);
      });

    return sorted;
  }

  Future<void> _create() async {
    try {
      final now = FieldValue.serverTimestamp();
      final ref = _col.doc();

      await ref.set({
        'name': '新分類',
        'slug': '',
        'description': '',
        'imageUrl': '',
        'parentId': '',
        'isActive': true,
        'order': DateTime.now().millisecondsSinceEpoch,
        'createdAt': now,
        'updatedAt': now,
      });

      _snack('已新增分類');
      if (!mounted) return;
      await _openEdit(ref.id);
    } catch (e) {
      _snack('新增失敗：$e');
    }
  }

  Future<void> _openEdit(String id) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategoryEditSheet(id: id),
    );
  }

  Future<void> _toggleActive(CategoryItem c) async {
    try {
      await _col.doc(c.id).set({
        'isActive': !c.isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack(!c.isActive ? '已上架' : '已下架');
    } catch (e) {
      _snack('更新失敗：$e');
    }
  }

  Future<void> _delete(CategoryItem c) async {
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除分類'),
        content: Text('確定刪除「${c.name.isEmpty ? c.id : c.name}」？\n此操作不可復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _col.doc(c.id).delete();
      _snack('已刪除');
    } catch (e) {
      _snack('刪除失敗：$e');
    }
  }

  Future<void> _applyReorder(List<CategoryItem> ordered) async {
    if (_busyReorder) return;
    setState(() => _busyReorder = true);
    try {
      final batch = _db.batch();
      for (int i = 0; i < ordered.length; i++) {
        batch.set(_col.doc(ordered[i].id), {
          'order': i + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
      _snack('排序已更新');
    } catch (e) {
      _snack('排序更新失敗：$e');
    } finally {
      if (mounted) setState(() => _busyReorder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '分類管理',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '新增分類',
            icon: const Icon(Icons.add),
            onPressed: _create,
          ),
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
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
                      hintText: '搜尋 name / slug / parentId / 描述',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<CatFilter>(
                  value: _filter,
                  onChanged: (v) =>
                      setState(() => _filter = v ?? CatFilter.all),
                  items: const [
                    DropdownMenuItem(value: CatFilter.all, child: Text('全部')),
                    DropdownMenuItem(
                      value: CatFilter.active,
                      child: Text('上架'),
                    ),
                    DropdownMenuItem(
                      value: CatFilter.inactive,
                      child: Text('下架'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _baseQuery().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorView(
                    title: '載入失敗',
                    message: snap.error.toString(),
                    onRetry: () => setState(() {}),
                  );
                }

                final docs = snap.data?.docs ?? const [];
                final all = docs.map((d) {
                  final m = d.data();
                  return CategoryItem(
                    id: d.id,
                    name: _s(m['name']),
                    slug: _s(m['slug']),
                    description: _s(m['description']),
                    imageUrl: _s(m['imageUrl']),
                    parentId: _s(m['parentId']),
                    isActive: m['isActive'] == true,
                    order: _toInt(m['order']),
                    createdAt: _toDt(m['createdAt']),
                    updatedAt: _toDt(m['updatedAt']),
                  );
                }).toList();

                final filtered = _apply(all);

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      '沒有符合條件的分類',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  );
                }

                // ✅ ReorderableListView 需要可變 list
                final mutable = List<CategoryItem>.from(filtered);

                return Stack(
                  children: [
                    ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                      itemCount: mutable.length,
                      onReorder: (oldIndex, newIndex) async {
                        if (_busyReorder) return;
                        if (newIndex > oldIndex) newIndex--;
                        final moved = mutable.removeAt(oldIndex);
                        mutable.insert(newIndex, moved);
                        await _applyReorder(mutable);
                      },
                      itemBuilder: (context, i) {
                        final c = mutable[i];
                        final statusColor = c.isActive
                            ? Colors.green.shade800
                            : cs.onSurfaceVariant;

                        return Card(
                          key: ValueKey(c.id),
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: c.imageUrl.isEmpty
                                ? CircleAvatar(
                                    backgroundColor: cs.primaryContainer,
                                    child: Icon(
                                      Icons.category_outlined,
                                      color: cs.onPrimaryContainer,
                                    ),
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      c.imageUrl,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          CircleAvatar(
                                            backgroundColor:
                                                cs.primaryContainer,
                                            child: Icon(
                                              Icons
                                                  .image_not_supported_outlined,
                                              color: cs.onPrimaryContainer,
                                            ),
                                          ),
                                    ),
                                  ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.name.isEmpty ? '(未命名分類)' : c.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    // ✅ 修正：withOpacity deprecated → withValues(alpha: ...)
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    c.isActive ? '上架' : '下架',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              [
                                if (c.slug.isNotEmpty) 'slug:${c.slug}',
                                if (c.parentId.isNotEmpty)
                                  'parent:${c.parentId}',
                                'order:${c.order}',
                                '更新:${_fmtDt(c.updatedAt ?? c.createdAt)}',
                              ].join('｜'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'edit') await _openEdit(c.id);
                                if (v == 'toggle') await _toggleActive(c);
                                if (v == 'delete') await _delete(c);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('編輯'),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(c.isActive ? '下架' : '上架'),
                                ),
                                const PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    '刪除',
                                    style: TextStyle(
                                      color: cs.error,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _openEdit(c.id),
                          ),
                        );
                      },
                    ),
                    if (_busyReorder)
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Material(
                          elevation: 10,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '更新排序中...',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
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
}

// ============================== Edit Sheet ==============================

class _CategoryEditSheet extends StatefulWidget {
  final String id;
  const _CategoryEditSheet({required this.id});

  @override
  State<_CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends State<_CategoryEditSheet> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _parentCtrl = TextEditingController();

  bool _active = true;
  bool _loading = true;
  bool _saving = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _descCtrl.dispose();
    _imageCtrl.dispose();
    _parentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final doc = await _db.collection('categories').doc(widget.id).get();
      final d = doc.data() ?? <String, dynamic>{};

      _nameCtrl.text = (d['name'] ?? '').toString();
      _slugCtrl.text = (d['slug'] ?? '').toString();
      _descCtrl.text = (d['description'] ?? '').toString();
      _imageCtrl.text = (d['imageUrl'] ?? '').toString();
      _parentCtrl.text = (d['parentId'] ?? '').toString();
      _active = d['isActive'] == true;
    } catch (e) {
      _snack('載入失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      await _db.collection('categories').doc(widget.id).set({
        'name': _nameCtrl.text.trim(),
        'slug': _slugCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'imageUrl': _imageCtrl.text.trim(),
        'parentId': _parentCtrl.text.trim(),
        'isActive': _active,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.pop(context);
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
          height: 280,
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
            children: [
              const Text(
                '編輯分類',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '名稱 name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _slugCtrl,
                decoration: const InputDecoration(
                  labelText: '代稱 slug（可空）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _parentCtrl,
                decoration: const InputDecoration(
                  labelText: '父分類 parentId（可空）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _imageCtrl,
                decoration: const InputDecoration(
                  labelText: '圖片 imageUrl（可空）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '描述 description（可空）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('前台顯示（上架）'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? '儲存中...' : '儲存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================== Model ==============================

class CategoryItem {
  final String id;
  final String name;
  final String slug;
  final String description;
  final String imageUrl;
  final String parentId;
  final bool isActive;
  final int order;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CategoryItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.imageUrl,
    required this.parentId,
    required this.isActive,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  });
}

enum CatFilter { all, active, inactive }

// ============================== UI ==============================

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
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
