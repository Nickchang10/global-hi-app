// lib/pages/admin/products/admin_products_page.dart
// =====================================================
// ✅ AdminProductsPage（修正版完整版｜可編譯）
// - 修正 undefined_named_parameter：移除 product: 參數（改用 arguments 傳 productId）
// - 搜尋 / 篩選（分類、上架狀態）
// - 列表：商品名稱、價格、庫存、分類、上架狀態、更新時間
// - 操作：新增、編輯、切換上架、刪除
// - Web/桌面/手機：LayoutBuilder 避免 Row overflow
// =====================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ✅ FIX: withOpacity deprecated → withValues(alpha: 0~1)
Color _withOpacity(Color c, double opacity01) {
  final o = opacity01.clamp(0.0, 1.0).toDouble();
  return c.withValues(alpha: o);
}

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _keyword = '';

  // filters
  String _statusFilter = 'all'; // all/published/unpublished
  String _categoryFilter = 'all';

  static const _statusOptions = <String>['all', 'published', 'unpublished'];

  // 你若有 categories collection，可改成動態讀取
  static const _categoryOptions = <String>[
    'all',
    'uncategorized',
    'watch',
    'accessory',
    'service',
    'other',
  ];

  final _df = DateFormat('yyyy/MM/dd HH:mm');
  final _money = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }
      setState(() => _keyword = v.trim().toLowerCase());
    });
  }

  T _safeInitial<T>(T value, List<T> items, {required T fallback}) {
    if (items.contains(value)) {
      return value;
    }
    return fallback;
  }

  Query<Map<String, dynamic>> _productsQuery() {
    // 用 __name__ 排序保證存在；避免你某些文件沒有 updatedAt/createdAt 造成 orderBy 報錯
    var q = _db.collection('products').orderBy(FieldPath.documentId);

    // ✅ 上架狀態：published 欄位（若你是 isPublished 請告訴我我會改）
    if (_statusFilter == 'published') {
      q = q.where('published', isEqualTo: true);
    } else if (_statusFilter == 'unpublished') {
      q = q.where('published', isEqualTo: false);
    }

    // ✅ 分類：categoryId 欄位
    if (_categoryFilter != 'all') {
      q = q.where('categoryId', isEqualTo: _categoryFilter);
    }

    return q.limit(500);
  }

  bool _hitKeyword(Map<String, dynamic> m, String docId) {
    if (_keyword.isEmpty) {
      return true;
    }

    final name = (m['name'] ?? m['title'] ?? '').toString().toLowerCase();
    final sku = (m['sku'] ?? '').toString().toLowerCase();
    final categoryId = (m['categoryId'] ?? m['category'] ?? '')
        .toString()
        .toLowerCase();
    final id = docId.toLowerCase();

    return name.contains(_keyword) ||
        sku.contains(_keyword) ||
        categoryId.contains(_keyword) ||
        id.contains(_keyword);
  }

  String _fmtTs(dynamic v) {
    if (v is Timestamp) {
      return _df.format(v.toDate());
    }
    return '-';
  }

  num _asNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse((v ?? '').toString()) ?? 0;
  }

  bool _asBool(dynamic v) => v == true;

  Future<void> _togglePublished({
    required String productId,
    required bool next,
  }) async {
    try {
      await _db.collection('products').doc(productId).update({
        'published': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(next ? '已上架' : '已下架')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  Future<void> _deleteProduct(String productId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          '刪除商品',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text('確定要刪除商品：$productId ？\n此動作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) {
      return;
    }

    try {
      await _db.collection('products').doc(productId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  void _goCreate() {
    // ✅ 不再傳 product:（避免 undefined_named_parameter）
    try {
      Navigator.pushNamed(context, '/admin_product_edit');
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('尚未註冊路由：/admin_product_edit')),
      );
    }
  }

  void _goEdit(String productId) {
    // ✅ 不再傳 product:（避免 undefined_named_parameter）
    try {
      Navigator.pushNamed(
        context,
        '/admin_product_edit',
        arguments: {'productId': productId},
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('尚未註冊路由：/admin_product_edit')),
      );
    }
  }

  void _goDetail(String productId) {
    // ✅ 不再傳 product:（避免 undefined_named_parameter）
    try {
      Navigator.pushNamed(
        context,
        '/admin_product_detail',
        arguments: {'productId': productId},
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('尚未註冊路由：/admin_product_detail')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('商品管理'),
        actions: [
          IconButton(
            tooltip: '新增商品',
            onPressed: _goCreate,
            icon: const Icon(Icons.add_circle_outline),
          ),
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // =========================
          // Filters
          // =========================
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: LayoutBuilder(
              builder: (context, c) {
                final isNarrow = c.maxWidth < 760;

                final search = TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: '搜尋：商品名稱 / sku / categoryId / productId',
                    isDense: true,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                );

                final statusFilter = DropdownButtonFormField<String>(
                  key: ValueKey('status_$_statusFilter'),
                  initialValue: _safeInitial<String>(
                    _statusFilter,
                    _statusOptions,
                    fallback: 'all',
                  ),
                  items: _statusOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _statusFilter = v);
                  },
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: '上架狀態',
                    isDense: true,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                );

                final categoryFilter = DropdownButtonFormField<String>(
                  key: ValueKey('category_$_categoryFilter'),
                  initialValue: _safeInitial<String>(
                    _categoryFilter,
                    _categoryOptions,
                    fallback: 'all',
                  ),
                  items: _categoryOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _categoryFilter = v);
                  },
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: '分類',
                    isDense: true,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      search,
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: statusFilter),
                          const SizedBox(width: 10),
                          Expanded(child: categoryFilter),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 10),
                    SizedBox(width: 220, child: statusFilter),
                    const SizedBox(width: 10),
                    SizedBox(width: 260, child: categoryFilter),
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1),

          // =========================
          // List
          // =========================
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _productsQuery().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('讀取失敗：${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs
                    .where((d) => _hitKeyword(d.data(), d.id))
                    .toList(growable: false);

                if (docs.isEmpty) {
                  return const Center(child: Text('沒有符合條件的商品'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();

                    final id = doc.id;
                    final name = (d['name'] ?? d['title'] ?? '')
                        .toString()
                        .trim();
                    final categoryId =
                        (d['categoryId'] ?? d['category'] ?? 'uncategorized')
                            .toString()
                            .trim();
                    final published = _asBool(
                      d['published'] ?? d['isPublished'],
                    );
                    final price = _asNum(d['price'] ?? d['salePrice'] ?? 0);
                    final stock = _asNum(
                      d['stock'] ?? d['stockQty'] ?? d['inventory'] ?? 0,
                    );
                    final updatedAt = _fmtTs(d['updatedAt']);
                    final createdAt = _fmtTs(d['createdAt']);

                    final statusColor = published ? cs.primary : cs.error;

                    final statusChip = Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _withOpacity(statusColor, 0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _withOpacity(statusColor, 0.25),
                        ),
                      ),
                      child: Text(
                        published ? '上架' : '下架',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    );

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final isNarrow = c.maxWidth < 760;

                            final left = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name.isEmpty ? '(未命名)' : name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    statusChip,
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  [
                                    '價格：${_money.format(price)}',
                                    '庫存：${stock.toInt()}',
                                    '分類：$categoryId',
                                  ].join('  •  '),
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'id: $id\ncreated: $createdAt   updated: $updatedAt',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 12,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            );

                            final actions = Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: () => _goEdit(id),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('編輯'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _goDetail(id),
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('詳情'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _togglePublished(
                                    productId: id,
                                    next: !published,
                                  ),
                                  icon: Icon(
                                    published
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  label: Text(published ? '下架' : '上架'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _deleteProduct(id),
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: cs.error,
                                  ),
                                  label: Text(
                                    '刪除',
                                    style: TextStyle(color: cs.error),
                                  ),
                                ),
                              ],
                            );

                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  left,
                                  const SizedBox(height: 12),
                                  actions,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: left),
                                const SizedBox(width: 12),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child: Align(
                                    alignment: Alignment.topRight,
                                    child: actions,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
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
