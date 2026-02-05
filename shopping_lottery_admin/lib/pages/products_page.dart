// lib/pages/products_page.dart
//
// ✅ ProductsPage（Dashboard 風格商品管理｜完整版｜可編譯｜避免 Firestore 複合索引錯誤）
//
// 特點：
// - Admin：看全部 / Vendor：只看 vendorId == 自己
// - 搜尋（client-side）、狀態篩選、分類篩選
// - 匯出 CSV
// - 商品上架/下架切換（isActive）
// - 寬螢幕右側詳情面板；窄螢幕用 Dialog
// - 新增/編輯商品 Dialog
// - ✅ 避免 [cloud_firestore/failed-precondition] The query requires an index：
//    - 只要 query 有 where(...) 就不加 orderBy(...)，改用 client-side sort
//
// Firestore 建議：products/{productId}
//   - name: String
//   - price: num
//   - stock: int
//   - vendorId: String
//   - categoryId: String? (可選)
//   - isActive: bool
//   - createdAt: Timestamp (serverTimestamp)
//   - updatedAt: Timestamp (serverTimestamp)
//
// categories/{categoryId}（可選，若你有分類功能）
//   - name: String
//   - sort: num (越小越前)
//   - isActive: bool
//
// 依賴：
// - cloud_firestore
// - firebase_auth
// - flutter/material
// - services/admin_gate.dart
// - utils/csv_download.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_gate.dart';
import '../utils/csv_download.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _db = FirebaseFirestore.instance;

  Future<RoleInfo>? _roleFuture;
  String? _lastUid;

  // filters
  String _q = '';
  bool? _isActive; // null=全部 true=上架 false=下架
  String? _categoryId; // null=全部
  String? _selectedId;

  // ---------- utils ----------
  String _s(dynamic v) => (v ?? '').toString().trim();
  bool _b(dynamic v) => v == true;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  num _num(dynamic v, {num fallback = 0}) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  int _int(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  int _sortTime(Map<String, dynamic> p) {
    final u = _toDate(p['updatedAt']);
    final c = _toDate(p['createdAt']);
    final d = u ?? c;
    return d?.millisecondsSinceEpoch ?? 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && (_roleFuture == null || _lastUid != user.uid)) {
      _lastUid = user.uid;
      _roleFuture = AdminGate().ensureAndGetRole(user, forceRefresh: false);
    }
  }

  // ---------- categories (optional) ----------
  // ✅ 避免複合索引：只 orderBy(sort)，isActive 在前端篩
  Stream<QuerySnapshot<Map<String, dynamic>>> _categoriesStream() {
    return _db.collection('categories').orderBy('sort').limit(500).snapshots();
  }

  // ---------- products query ----------
  // ✅ 避免複合索引策略：
  // - 若有 where(...) -> 不 orderBy；改 client-side sort
  // - 若沒有 where(...) -> 可 orderBy(updatedAt)（單欄位排序不需複合索引）
  Stream<QuerySnapshot<Map<String, dynamic>>> _productsStream({
    required bool isAdmin,
    required String vendorId,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('products');

    bool hasWhere = false;

    if (!isAdmin && vendorId.trim().isNotEmpty) {
      q = q.where('vendorId', isEqualTo: vendorId.trim());
      hasWhere = true;
    }
    if (_isActive != null) {
      q = q.where('isActive', isEqualTo: _isActive);
      hasWhere = true;
    }
    if (_categoryId != null && _categoryId!.trim().isNotEmpty) {
      q = q.where('categoryId', isEqualTo: _categoryId!.trim());
      hasWhere = true;
    }

    // 只在沒有 where 時做 server-side orderBy（避免複合索引）
    if (!hasWhere) {
      q = q.orderBy('updatedAt', descending: true);
    }

    return q.limit(1000).snapshots();
  }

  bool _matchProduct(Map<String, dynamic> p) {
    final t = _q.trim().toLowerCase();
    if (t.isEmpty) return true;

    final name = _s(p['name']).toLowerCase();
    final id = _s(p['id']).toLowerCase();
    final vendorId = _s(p['vendorId']).toLowerCase();
    final categoryId = _s(p['categoryId']).toLowerCase();

    return name.contains(t) || id.contains(t) || vendorId.contains(t) || categoryId.contains(t);
  }

  Future<void> _toggleActive(String id, bool v) async {
    final pid = id.trim();
    if (pid.isEmpty) return;

    try {
      await _db.collection('products').doc(pid).set(
        <String, dynamic>{
          'isActive': v,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _snack('商品 $pid 已${v ? '上架' : '下架'}');
    } catch (e) {
      _snack('操作失敗：$e');
    }
  }

  Future<void> _deleteProduct(String id) async {
    final pid = id.trim();
    if (pid.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除商品'),
        content: Text('確定要刪除 $pid 嗎？（不可復原）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _db.collection('products').doc(pid).delete();
      if (_selectedId == pid) setState(() => _selectedId = null);
      _snack('已刪除商品：$pid');
    } catch (e) {
      _snack('刪除失敗：$e');
    }
  }

  Future<void> _exportCsv(List<Map<String, dynamic>> products) async {
    if (products.isEmpty) return;

    final headers = [
      'productId',
      'name',
      'price',
      'stock',
      'vendorId',
      'categoryId',
      'isActive',
      'createdAt',
      'updatedAt',
    ];

    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));

    for (final p in products) {
      final createdAt = _toDate(p['createdAt'])?.toIso8601String() ?? '';
      final updatedAt = _toDate(p['updatedAt'])?.toIso8601String() ?? '';

      final row = [
        p['id'] ?? '',
        p['name'] ?? '',
        p['price'] ?? '',
        p['stock'] ?? '',
        p['vendorId'] ?? '',
        p['categoryId'] ?? '',
        p['isActive'] ?? '',
        createdAt,
        updatedAt,
      ].map((e) => e.toString().replaceAll(',', '，')).join(',');

      buffer.writeln(row);
    }

    await downloadCsv('products_export.csv', buffer.toString());
    _snack('已匯出 products_export.csv');
  }

  Future<void> _openEditDialog({
    Map<String, dynamic>? data,
    required RoleInfo? role,
  }) async {
    final isCreate = (data == null);

    final nameCtrl = TextEditingController(text: _s(data?['name']));
    final priceCtrl = TextEditingController(text: isCreate ? '' : '${data?['price'] ?? ''}');
    final stockCtrl = TextEditingController(text: isCreate ? '' : '${data?['stock'] ?? ''}');
    final categoryCtrl = TextEditingController(text: _s(data?['categoryId']));
    bool isActive = isCreate ? true : _b(data?['isActive']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isCreate ? '新增商品' : '編輯商品'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '名稱',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(
                    labelText: '價格',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: stockCtrl,
                  decoration: const InputDecoration(
                    labelText: '庫存',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'categoryId（可選）',
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: '例如: kids / watch / accessories',
                  ),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  title: const Text('上架中'),
                  value: isActive,
                  onChanged: (v) => isActive = v,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('儲存')),
        ],
      ),
    );

    if (ok != true) {
      nameCtrl.dispose();
      priceCtrl.dispose();
      stockCtrl.dispose();
      categoryCtrl.dispose();
      return;
    }

    final name = nameCtrl.text.trim();
    final price = _num(priceCtrl.text.trim(), fallback: 0);
    final stock = _int(stockCtrl.text.trim(), fallback: 0);
    final categoryId = categoryCtrl.text.trim();

    if (name.isEmpty) {
      _snack('名稱不可為空');
      nameCtrl.dispose();
      priceCtrl.dispose();
      stockCtrl.dispose();
      categoryCtrl.dispose();
      return;
    }

    try {
      if (isCreate) {
        // vendorId：Admin 可留空或由你決定；Vendor 一律寫入自己 vendorId
        final vendorId = (role?.isAdmin ?? false) ? _s(role?.vendorId) : _s(role?.vendorId);
        await _db.collection('products').add(<String, dynamic>{
          'name': name,
          'price': price,
          'stock': stock,
          'categoryId': categoryId.isEmpty ? null : categoryId,
          'isActive': isActive,
          'vendorId': vendorId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        _snack('已新增商品');
      } else {
        final pid = _s(data['id']);
        await _db.collection('products').doc(pid).set(<String, dynamic>{
          'name': name,
          'price': price,
          'stock': stock,
          'categoryId': categoryId.isEmpty ? FieldValue.delete() : categoryId,
          'isActive': isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        _snack('已更新商品：$pid');
      }
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      nameCtrl.dispose();
      priceCtrl.dispose();
      stockCtrl.dispose();
      categoryCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('尚未登入')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('商品管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '新增商品',
            onPressed: () async {
              final role = await _roleFuture;
              if (!context.mounted) return;
              await _openEditDialog(role: role);
            },
            icon: const Icon(Icons.add_box_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<RoleInfo>(
        future: _roleFuture,
        builder: (context, roleSnap) {
          if (roleSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (roleSnap.hasError) {
            return Center(child: Text('讀取角色失敗：${roleSnap.error}'));
          }

          final role = roleSnap.data;
          final isAdmin = role?.isAdmin ?? false;
          final vendorId = _s(role?.vendorId);

          final cs = Theme.of(context).colorScheme;

          return Column(
            children: [
              // Filters + Categories
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 320,
                          child: TextField(
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                              hintText: '搜尋：商品名稱 / ID / vendorId / categoryId',
                            ),
                            onChanged: (v) => setState(() => _q = v),
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<bool?>(
                            value: _isActive,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              labelText: '狀態',
                            ),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('全部')),
                              DropdownMenuItem(value: true, child: Text('上架中')),
                              DropdownMenuItem(value: false, child: Text('已下架')),
                            ],
                            onChanged: (v) => setState(() => _isActive = v),
                          ),
                        ),

                        // category filter (optional)
                        SizedBox(
                          width: 260,
                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _categoriesStream(),
                            builder: (context, snap) {
                              // categories 讀取失敗也不要卡住產品頁
                              final docs = snap.data?.docs ?? const [];
                              final activeCategories = docs
                                  .map((d) => {'id': d.id, ...d.data()})
                                  .where((c) => c['isActive'] == null || c['isActive'] == true) // client-side
                                  .toList();

                              return DropdownButtonFormField<String?>(
                                value: _categoryId,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  labelText: '分類（可選）',
                                ),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('全部分類')),
                                  ...activeCategories.map((c) {
                                    final id = _s(c['id']);
                                    final name = _s(c['name']).isEmpty ? id : _s(c['name']);
                                    return DropdownMenuItem(
                                      value: id,
                                      child: Text(name, overflow: TextOverflow.ellipsis),
                                    );
                                  }),
                                ],
                                onChanged: (v) => setState(() => _categoryId = v),
                              );
                            },
                          ),
                        ),

                        if (!isAdmin && vendorId.isNotEmpty)
                          Text('Vendor：$vendorId', style: TextStyle(color: cs.onSurfaceVariant)),

                        OutlinedButton.icon(
                          onPressed: () => setState(() {
                            _q = '';
                            _isActive = null;
                            _categoryId = null;
                            _selectedId = null;
                          }),
                          icon: const Icon(Icons.refresh),
                          label: const Text('重設'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Products list
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _productsStream(isAdmin: isAdmin, vendorId: vendorId),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('讀取失敗：${snap.error}'),
                        ),
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snap.data!.docs;
                    final products = docs
                        .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
                        .where(_matchProduct)
                        .toList();

                    // ✅ client-side sort：updatedAt/createdAt 新到舊
                    products.sort((a, b) => _sortTime(b).compareTo(_sortTime(a)));

                    return LayoutBuilder(
                      builder: (context, c) {
                        final isWide = c.maxWidth > 980;

                        Widget listView() {
                          if (products.isEmpty) {
                            return Center(
                              child: Text('沒有資料', style: TextStyle(color: cs.onSurfaceVariant)),
                            );
                          }

                          return ListView.separated(
                            itemCount: products.length + 1,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              // header row actions
                              if (i == 0) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                  child: Row(
                                    children: [
                                      Text('共 ${products.length} 項', style: TextStyle(color: cs.onSurfaceVariant)),
                                      const Spacer(),
                                      OutlinedButton.icon(
                                        onPressed: products.isEmpty ? null : () => _exportCsv(products),
                                        icon: const Icon(Icons.download_outlined),
                                        label: const Text('匯出 CSV'),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final p = products[i - 1];
                              final id = _s(p['id']);
                              final name = _s(p['name']).isEmpty ? '（未命名）' : _s(p['name']);
                              final price = _num(p['price']);
                              final stock = _int(p['stock']);
                              final active = _b(p['isActive']);

                              return ListTile(
                                selected: id == _selectedId,
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                                subtitle: Text('NT\$ $price  ・ 庫存 $stock'),
                                leading: Icon(active ? Icons.inventory_2_outlined : Icons.inventory_2, color: active ? cs.primary : cs.error),
                                trailing: Wrap(
                                  spacing: 6,
                                  children: [
                                    Switch(
                                      value: active,
                                      onChanged: (v) => _toggleActive(id, v),
                                    ),
                                    PopupMenuButton<String>(
                                      tooltip: '更多',
                                      onSelected: (v) async {
                                        if (v == 'edit') {
                                          await _openEditDialog(data: p, role: role);
                                        } else if (v == 'delete') {
                                          await _deleteProduct(id);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(value: 'edit', child: Text('編輯')),
                                        PopupMenuDivider(),
                                        PopupMenuItem(value: 'delete', child: Text('刪除')),
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  setState(() => _selectedId = id);
                                  if (!isWide) {
                                    showDialog(
                                      context: context,
                                      builder: (_) => _ProductDetailDialog(
                                        data: p,
                                        onEdit: () async {
                                          Navigator.pop(context);
                                          await _openEditDialog(data: p, role: role);
                                        },
                                        onDelete: () async {
                                          Navigator.pop(context);
                                          await _deleteProduct(id);
                                        },
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          );
                        }

                        Widget detailPanel() {
                          if (_selectedId == null) {
                            return Center(
                              child: Text('請選擇商品', style: TextStyle(color: cs.onSurfaceVariant)),
                            );
                          }
                          final data = products.firstWhere(
                            (e) => _s(e['id']) == _selectedId,
                            orElse: () => <String, dynamic>{},
                          );
                          if (data.isEmpty) {
                            return Center(
                              child: Text('找不到商品', style: TextStyle(color: cs.onSurfaceVariant)),
                            );
                          }
                          return _ProductDetailPanel(
                            data: data,
                            onEdit: () => _openEditDialog(data: data, role: role),
                            onDelete: () => _deleteProduct(_s(data['id'])),
                          );
                        }

                        return Row(
                          children: [
                            Expanded(flex: 3, child: listView()),
                            if (isWide) const VerticalDivider(width: 1),
                            if (isWide) Expanded(flex: 2, child: detailPanel()),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// Detail UI
// ------------------------------------------------------------
class _ProductDetailPanel extends StatelessWidget {
  const _ProductDetailPanel({
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _s(dynamic v) => (v ?? '').toString().trim();
  bool _b(dynamic v) => v == true;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('無資料'));
    final cs = Theme.of(context).colorScheme;

    final id = _s(data['id']);
    final name = _s(data['name']).isEmpty ? '（未命名）' : _s(data['name']);
    final vendorId = _s(data['vendorId']);
    final categoryId = _s(data['categoryId']);
    final price = data['price'] ?? 0;
    final stock = data['stock'] ?? 0;
    final active = _b(data['isActive']);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 10),
          Text('ID：$id', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text('價格：NT\$ $price'),
          Text('庫存：$stock'),
          const SizedBox(height: 6),
          Text('Vendor：${vendorId.isEmpty ? '-' : vendorId}', style: TextStyle(color: cs.onSurfaceVariant)),
          Text('分類：${categoryId.isEmpty ? '-' : categoryId}', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text('狀態：${active ? '上架中' : '已下架'}', style: TextStyle(color: active ? cs.primary : cs.error)),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('刪除'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('編輯'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductDetailDialog extends StatelessWidget {
  const _ProductDetailDialog({
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: SizedBox(
        width: 520,
        height: 520,
        child: _ProductDetailPanel(
          data: data,
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ),
    );
  }
}
