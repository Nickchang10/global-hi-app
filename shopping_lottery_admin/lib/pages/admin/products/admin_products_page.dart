// lib/pages/admin/products/admin_products_page.dart
//
// ✅ AdminProductsPage（專業修復後完整版｜可編譯）
// ------------------------------------------------------------
// - Firestore 即時同步商品清單（products）
// - 搜尋（名稱/分類）、狀態篩選（上架/下架）、分類篩選
// - ReorderableListView 拖曳排序（寫回 sortOrder）
//   ✅ 為避免「篩選後重排造成全域 sortOrder 混亂」：
//      只有在「未搜尋、狀態=全部、分類=全部」時才允許拖曳排序
// - 多選批次刪除、批次上下架
// - 點擊進入編輯頁（新增/編輯共用 AdminProductEditPage）
// - ✅ 不依賴 reorderables 套件
//
// ------------------------------------------------------------
// 你需要確保存在：
// - lib/pages/admin/products/admin_product_edit_page.dart
//   class AdminProductEditPage extends StatelessWidget { ... }
//   - 建議 Navigator.pop(context, true) 表示成功儲存
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_product_edit_page.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  final _db = FirebaseFirestore.instance;
  final TextEditingController _search = TextEditingController();

  bool _selectionMode = false;
  final Set<String> _selected = {};

  // --- Status filter keys (fixed to avoid dropdown assertion) ---
  static const String _statusAll = 'all';
  static const String _statusActive = 'active';
  static const String _statusInactive = 'inactive';
  String _statusFilterKey = _statusAll;

  // --- Category filter keys ---
  static const String _catAll = 'all';
  String _categoryFilterKey = _catAll;

  // Categories options derived from products snapshot
  List<String> _categoryKeys = const [_catAll];

  final _moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // Query: order by sortOrder for drag sorting
  // ------------------------------------------------------------
  Query<Map<String, dynamic>> _baseQuery() {
    return _db.collection('products').orderBy('sortOrder', descending: false);
  }

  // ------------------------------------------------------------
  // Field compat / safe getters
  // ------------------------------------------------------------
  bool _isActive(Map<String, dynamic> d) {
    // compatible: available(bool) OR status('active'/'inactive')
    final available = d['available'];
    if (available is bool) return available;

    final status = (d['status'] ?? '').toString().toLowerCase();
    if (status == _statusInactive) return false;
    if (status == _statusActive) return true;

    return true; // default active
  }

  String _categoryOf(Map<String, dynamic> d) {
    final c = d['category'];
    return c == null ? '' : c.toString().trim();
  }

  String? _imageOf(Map<String, dynamic> d) {
    final imageUrl = d['imageUrl'];
    if (imageUrl is String && imageUrl.trim().isNotEmpty) return imageUrl.trim();

    final images = d['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is String && first.trim().isNotEmpty) return first.trim();
    }
    return null;
  }

  num _priceOf(Map<String, dynamic> d) {
    final p = d['price'];
    if (p is num) return p;
    return num.tryParse((p ?? '0').toString()) ?? 0;
  }

  int _stockOf(Map<String, dynamic> d) {
    final s = d['stock'];
    if (s is int) return s;
    return int.tryParse((s ?? '0').toString()) ?? 0;
  }

  // ------------------------------------------------------------
  // Dropdown value coercion (avoid assertion)
  // ------------------------------------------------------------
  String _coerceValue(String value, List<String> allowed, String fallback) {
    return allowed.contains(value) ? value : fallback;
  }

  bool get _isFiltering {
    final s = _search.text.trim();
    return s.isNotEmpty || _statusFilterKey != _statusAll || _categoryFilterKey != _catAll;
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final query = _baseQuery();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('商品管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: '批次下架',
              icon: const Icon(Icons.visibility_off),
              onPressed: _selected.isEmpty ? null : () => _batchSetActive(false),
            ),
            IconButton(
              tooltip: '批次上架',
              icon: const Icon(Icons.visibility),
              onPressed: _selected.isEmpty ? null : () => _batchSetActive(true),
            ),
            IconButton(
              tooltip: '刪除選取商品',
              icon: const Icon(Icons.delete),
              onPressed: _selected.isEmpty ? null : _confirmBatchDelete,
            ),
          ],
          IconButton(
            tooltip: _selectionMode ? '取消多選' : '多選模式',
            icon: Icon(_selectionMode ? Icons.close : Icons.checklist),
            onPressed: () {
              setState(() {
                _selectionMode = !_selectionMode;
                if (!_selectionMode) _selected.clear();
              });
            },
          ),
          IconButton(
            tooltip: '新增商品',
            icon: const Icon(Icons.add),
            onPressed: _openCreate,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('新增商品'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              title: '載入失敗',
              message: snap.error.toString(),
              hint:
                  '請確認 Firestore rules/權限、products 集合是否存在、以及 sortOrder 欄位是否可排序。',
              onRetry: () => setState(() {}),
            );
          }

          final data = snap.data;
          if (data == null || data.docs.isEmpty) {
            return _emptyState(
              context,
              title: '目前沒有商品',
              subtitle: '點右下角「新增商品」開始建立商品資料。',
            );
          }

          // Build category options from snapshot
          final categorySet = <String>{_catAll};
          for (final doc in data.docs) {
            final c = _categoryOf(doc.data());
            if (c.isNotEmpty) categorySet.add(c);
          }
          final nextCategoryKeys = categorySet.toList()
            ..sort((a, b) {
              if (a == _catAll) return -1;
              if (b == _catAll) return 1;
              return a.compareTo(b);
            });

          // Update state categories if changed + coerce selected category
          if (_categoryKeys.join('|') != nextCategoryKeys.join('|')) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _categoryKeys = nextCategoryKeys;
                _categoryFilterKey = _coerceValue(_categoryFilterKey, _categoryKeys, _catAll);
              });
            });
          } else {
            // still coerce to avoid dropdown mismatch when data changed
            final coerced = _coerceValue(_categoryFilterKey, _categoryKeys, _catAll);
            if (coerced != _categoryFilterKey) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _categoryFilterKey = coerced);
              });
            }
          }

          // Coerce status filter
          _statusFilterKey = _coerceValue(
            _statusFilterKey,
            const [_statusAll, _statusActive, _statusInactive],
            _statusAll,
          );

          // Apply filters
          final s = _search.text.trim().toLowerCase();
          final filtered = data.docs.where((doc) {
            final d = doc.data();
            final name = (d['name'] ?? '').toString().toLowerCase();
            final cat = _categoryOf(d).toLowerCase();
            final active = _isActive(d);

            final matchSearch = s.isEmpty || name.contains(s) || cat.contains(s);

            final matchStatus = switch (_statusFilterKey) {
              _statusAll => true,
              _statusActive => active,
              _statusInactive => !active,
              _ => true,
            };

            final matchCategory =
                _categoryFilterKey == _catAll ? true : _categoryOf(d) == _categoryFilterKey;

            return matchSearch && matchStatus && matchCategory;
          }).toList();

          return Column(
            children: [
              _filterBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    Text(
                      '共 ${filtered.length} 筆',
                      style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 10),
                    if (_isFiltering)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '篩選中：排序拖曳已停用',
                          style: TextStyle(
                            color: cs.onSecondaryContainer,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: (_search.text.trim().isEmpty &&
                              _statusFilterKey == _statusAll &&
                              _categoryFilterKey == _catAll)
                          ? null
                          : () {
                              setState(() {
                                _search.clear();
                                _statusFilterKey = _statusAll;
                                _categoryFilterKey = _catAll;
                              });
                            },
                      icon: const Icon(Icons.filter_alt_off),
                      label: const Text('清除篩選'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? _emptyState(
                        context,
                        title: '沒有符合條件的商品',
                        subtitle: '請調整搜尋/篩選條件後再試一次。',
                      )
                    : (!_isFiltering
                        ? _buildReorderableList(filtered)
                        : _buildNormalList(filtered)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // Filter bar (responsive to prevent overflow)
  // ============================================================
  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 720;

          final searchField = TextField(
            controller: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜尋（名稱/分類）',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => setState(() {}),
          );

          final statusDropdown = DropdownButtonFormField<String>(
            isExpanded: true,
            value: _statusFilterKey,
            decoration: InputDecoration(
              isDense: true,
              labelText: '狀態',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: const [
              DropdownMenuItem(value: _statusAll, child: Text('全部')),
              DropdownMenuItem(value: _statusActive, child: Text('上架中')),
              DropdownMenuItem(value: _statusInactive, child: Text('下架')),
            ],
            onChanged: (v) => setState(() => _statusFilterKey = v ?? _statusAll),
          );

          final categoryDropdown = DropdownButtonFormField<String>(
            isExpanded: true,
            value: _categoryFilterKey,
            decoration: InputDecoration(
              isDense: true,
              labelText: '分類',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: _categoryKeys.map((k) {
              if (k == _catAll) {
                return const DropdownMenuItem(value: _catAll, child: Text('全部'));
              }
              return DropdownMenuItem(value: k, child: Text(k, overflow: TextOverflow.ellipsis));
            }).toList(),
            onChanged: (v) => setState(() => _categoryFilterKey = v ?? _catAll),
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
                    Expanded(child: categoryDropdown),
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
              Expanded(flex: 2, child: categoryDropdown),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // Lists
  // ============================================================
  Widget _buildReorderableList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      buildDefaultDragHandles: false,
      itemCount: docs.length,
      onReorder: (oldIndex, newIndex) => _onReorder(docs, oldIndex, newIndex),
      itemBuilder: (context, i) {
        final doc = docs[i];
        return _buildProductTile(
          doc,
          index: i,
          key: ValueKey(doc.id),
          allowReorder: !_selectionMode,
        );
      },
    );
  }

  Widget _buildNormalList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final doc = docs[i];
        return _buildProductTile(
          doc,
          index: i,
          key: ValueKey(doc.id),
          allowReorder: false,
        );
      },
    );
  }

  // ============================================================
  // Product tile
  // ============================================================
  Widget _buildProductTile(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required int index,
    required Key key,
    required bool allowReorder,
  }) {
    final d = doc.data() ?? {};
    final name = (d['name'] ?? '').toString().trim();
    final price = _priceOf(d);
    final stock = _stockOf(d);
    final cat = _categoryOf(d);
    final img = _imageOf(d);
    final active = _isActive(d);
    final selected = _selected.contains(doc.id);

    return ListTile(
      key: key,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      tileColor: selected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35) : null,
      leading: _thumb(img),
      title: Text(
        name.isEmpty ? '(未命名商品)' : name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${cat.isEmpty ? '未分類' : cat} ｜ 庫存：$stock ｜ ${_moneyFmt.format(price)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _selectionMode
          ? Checkbox(
              value: selected,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selected.add(doc.id);
                  } else {
                    _selected.remove(doc.id);
                  }
                });
              },
            )
          : SizedBox(
              width: 148,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _statusChip(active),
                  const SizedBox(width: 8),
                  if (allowReorder)
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    )
                  else
                    const Icon(Icons.drag_handle, color: Colors.black26),
                ],
              ),
            ),
      onLongPress: () {
        setState(() {
          _selectionMode = true;
          _selected.add(doc.id);
        });
      },
      onTap: () {
        if (_selectionMode) {
          setState(() {
            if (selected) {
              _selected.remove(doc.id);
            } else {
              _selected.add(doc.id);
            }
          });
          return;
        }
        _openEdit(doc);
      },
    );
  }

  Widget _thumb(String? img) {
    if (img == null || img.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image_not_supported),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        img,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 48,
          height: 48,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image),
        ),
      ),
    );
  }

  Widget _statusChip(bool active) {
    return Chip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Text(active ? '上架' : '下架', overflow: TextOverflow.ellipsis),
      backgroundColor: active ? Colors.green.shade100 : Colors.grey.shade200,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      padding: EdgeInsets.zero,
    );
  }

  // ============================================================
  // Reorder: write sortOrder back (only when not filtering)
  // ============================================================
  Future<void> _onReorder(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int oldIndex,
    int newIndex,
  ) async {
    if (_isFiltering) {
      // safety guard
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('篩選中不允許排序，請先清除篩選後再拖曳。')),
      );
      return;
    }

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
    await batch.commit();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('排序已更新')),
    );
  }

  // ============================================================
  // Navigation: create/edit
  // ============================================================
  Future<void> _openCreate() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdminProductEditPage()),
    );
    if (!mounted) return;
    if (ok == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('商品已新增')));
    }
  }

  Future<void> _openEdit(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data() ?? {};
    final payload = <String, dynamic>{...d, 'id': doc.id};

    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminProductEditPage(product: payload)),
    );
    if (!mounted) return;
    if (ok == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('商品已更新')));
    }
  }

  // ============================================================
  // Batch delete
  // ============================================================
  Future<void> _confirmBatchDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認刪除選取商品？', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('共選取 ${_selected.length} 筆，刪除後無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final batch = _db.batch();
    for (final id in _selected) {
      batch.delete(_db.collection('products').doc(id));
    }
    await batch.commit();

    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除選取商品')));
  }

  // ============================================================
  // Batch active/inactive (compatible with available/status)
  // ============================================================
  Future<void> _batchSetActive(bool active) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(active ? '批次上架' : '批次下架', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text('共選取 ${_selected.length} 筆，確定要${active ? '上架' : '下架'}？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('確認')),
        ],
      ),
    );
    if (ok != true) return;

    final batch = _db.batch();
    for (final id in _selected) {
      batch.update(_db.collection('products').doc(id), {
        'available': active,
        'status': active ? _statusActive : _statusInactive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已${active ? '上架' : '下架'}選取商品')));
  }

  // ============================================================
  // Empty state
  // ============================================================
  Widget _emptyState(BuildContext context, {required String title, required String subtitle}) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 44, color: cs.primary),
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Error view
// ------------------------------------------------------------
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
        constraints: const BoxConstraints(maxWidth: 640),
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
