// lib/pages/admin/products/admin_variants_page.dart
//
// ✅ AdminVariantsPage（完整版｜可直接編譯｜不依賴 reorderables）
// ------------------------------------------------------------
// 用途：商品「規格/款式/變體」後台管理（例如：顏色/尺寸/SKU/加價/庫存）
//
// Firestore 建議結構：
// - products/{productId}
// - products/{productId}/variants/{variantId}
//   欄位建議：
//   - name: String
//   - sku: String
//   - attrs: Map<String, dynamic>   // 例如 {color: "黑", size:"L"}
//   - price: num?                  // 可選：覆蓋價格（優先於 priceDelta）
//   - priceDelta: num?             // 可選：相對於商品 basePrice 的加價/減價
//   - stock: int                   // 庫存
//   - isActive: bool               // 是否啟用
//   - sort: int                    // 排序用
//   - createdAt / updatedAt: Timestamp
//
// ------------------------------------------------------------
// ✅ 功能：
// - 產品選擇（若未帶 productId）
// - 規格清單（搜尋 / 顯示停用 / 拖曳排序）
// - 新增 / 編輯 / 刪除
// - 快速啟用/停用（單筆 + 批次）
// - 庫存調整（單筆 + 批次歸零）
// ------------------------------------------------------------
//
// ✅ 本版修正：
// - 修正 lint：avoid_types_as_parameter_names（fold accumulator 改名 total）
// - 修正 lint：unnecessary_string_interpolations（移除多餘插值）
// - 修正 lint：use_build_context_synchronously
//   - showDialog await 後先檢查 mounted
//   - _VariantEditDialog.resultOf() 移除 context 依賴（直接讀 static store）
//

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminVariantsPage extends StatefulWidget {
  /// 你可以：
  /// - 直接傳 productId 進來（建議）
  /// - 或不傳 productId，頁面會先顯示商品清單讓你挑選
  final String? productId;

  const AdminVariantsPage({super.key, this.productId});

  @override
  State<AdminVariantsPage> createState() => _AdminVariantsPageState();
}

class _AdminVariantsPageState extends State<AdminVariantsPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;

  // 若未帶 productId，可先選擇商品
  String? _productId;

  // 商品本體（用來顯示名稱/基礎價格）
  DocumentSnapshot<Map<String, dynamic>>? _productDoc;
  num _basePrice = 0;

  // variants 清單（一次性查詢，由 UI 觸發 refresh）
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _variants = [];

  // UI state
  final TextEditingController _searchCtrl = TextEditingController();
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    _productId = widget.productId?.trim().isEmpty == true
        ? null
        : widget.productId?.trim();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // Load
  // ============================================================
  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_productId == null) {
        // 沒有 productId -> 顯示商品選擇頁（不需要再查 variants）
        setState(() {
          _productDoc = null;
          _variants = [];
          _basePrice = 0;
          _loading = false;
        });
        return;
      }

      // 讀商品
      final p = await _db.collection('products').doc(_productId).get();
      if (!p.exists) {
        throw Exception('找不到商品：$_productId');
      }

      final pdata = p.data() ?? {};
      final base = _readNum(pdata['price'] ?? pdata['basePrice'] ?? 0);

      // 讀 variants（用 sort 排序；沒有 sort 也能讀，但建議都寫入 sort）
      final snap = await _db
          .collection('products')
          .doc(_productId)
          .collection('variants')
          .orderBy('sort')
          .orderBy('createdAt', descending: false)
          .get();

      if (!mounted) return;
      setState(() {
        _productDoc = p;
        _basePrice = base;
        _variants = snap.docs;
        _loading = false;
      });

      // 若發現部分沒有 sort，補齊一次（避免排序混亂）
      await _ensureSortIndexes();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _ensureSortIndexes() async {
    if (_productId == null) return;
    if (_variants.isEmpty) return;

    bool needsFix = false;
    for (int i = 0; i < _variants.length; i++) {
      final d = _variants[i].data();
      final sort = d['sort'];
      if (sort is! int) {
        needsFix = true;
        break;
      }
    }
    if (!needsFix) return;

    final batch = _db.batch();
    for (int i = 0; i < _variants.length; i++) {
      final ref = _variants[i].reference;
      batch.update(ref, {'sort': i, 'updatedAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();

    // 重載一次確保排序一致
    await _reloadVariantsOnly();
  }

  Future<void> _reloadVariantsOnly() async {
    if (_productId == null) return;
    final snap = await _db
        .collection('products')
        .doc(_productId)
        .collection('variants')
        .orderBy('sort')
        .orderBy('createdAt', descending: false)
        .get();
    if (!mounted) return;
    setState(() => _variants = snap.docs);
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            '商品規格管理',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: _ErrorView(
          title: '載入失敗',
          message: _error!,
          onRetry: _load,
          hint:
              '常見原因：Firestore 權限不足、products/variants 欄位結構不同、缺少必要欄位（例如 name/stock）。',
        ),
      );
    }

    // 尚未選商品 -> 顯示商品選擇
    if (_productId == null) {
      return _ProductPicker(
        onPicked: (id) async {
          if (!mounted) return;
          setState(() => _productId = id);
          await _load();
        },
      );
    }

    final pname =
        (_productDoc?.data()?['name'] ?? _productDoc?.data()?['title'] ?? '商品')
            .toString();
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

    final filtered = _filteredVariants();

    final activeCount = _variants
        .where((v) => _readBool(v.data()['isActive'], fallback: true))
        .length;

    // ✅ 修正：避免 lint（avoid_types_as_parameter_names）
    final stockSum = _variants.fold<int>(
      0,
      (total, v) => total + _readInt(v.data()['stock'], 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '商品規格管理｜$pname',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '新增規格',
            onPressed: _openEditDialogCreate,
            icon: const Icon(Icons.add),
          ),
          PopupMenuButton<String>(
            tooltip: '批次操作',
            onSelected: _handleBatchAction,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'enable_all', child: Text('全部啟用')),
              PopupMenuItem(value: 'disable_all', child: Text('全部停用')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'stock_zero', child: Text('全部庫存歸零')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _headerCard(
              productName: pname,
              basePriceText: fmtMoney.format(_basePrice),
              variantCount: _variants.length,
              activeCount: activeCount,
              stockSum: stockSum,
            ),
            const SizedBox(height: 12),
            _toolbar(),
            const SizedBox(height: 12),
            if (_variants.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('尚未建立任何規格。請按右上角「＋」新增。'),
                ),
              )
            else if (filtered.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('查無符合條件的規格（請調整搜尋或顯示停用）。'),
                ),
              )
            else
              _variantsList(filtered, fmtMoney),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _headerCard({
    required String productName,
    required String basePriceText,
    required int variantCount,
    required int activeCount,
    required int stockSum,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              productName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '基礎價格：$basePriceText',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statChip('規格數', variantCount.toString()),
                const SizedBox(width: 8),
                _statChip('啟用中', activeCount.toString()),
                const SizedBox(width: 8),
                _statChip('總庫存', stockSum.toString()),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    if (!mounted) return;
                    setState(() => _productId = null);
                    await _load();
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('切換商品'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        '$title：$value',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _toolbar() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: '搜尋：名稱 / SKU / 屬性（color,size...）',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilterChip(
              label: const Text('顯示停用'),
              selected: _showInactive,
              onSelected: (v) => setState(() => _showInactive = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _variantsList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> list,
    NumberFormat fmtMoney,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          onReorder: (oldIndex, newIndex) =>
              _onReorder(oldIndex, newIndex, list),
          itemBuilder: (context, index) {
            final doc = list[index];
            final data = doc.data();

            final name = (data['name'] ?? '未命名規格').toString();
            final sku = (data['sku'] ?? '').toString();
            final attrs = _readMap(data['attrs']);
            final stock = _readInt(data['stock'], 0);
            final isActive = _readBool(data['isActive'], fallback: true);

            final price = _computeVariantPrice(data);
            final priceText = fmtMoney.format(price);

            return Card(
              key: ValueKey(doc.id),
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              child: ListTile(
                leading: const Icon(Icons.drag_handle),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: isActive ? null : Colors.black45,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      priceText,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sku.isNotEmpty)
                      Text(
                        'SKU：$sku',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        // ✅ 修正：移除不必要的字串插值
                        for (final e in attrs.entries)
                          _attrChip(e.key.toString(), e.value.toString()),
                        _attrChip('stock', stock.toString()),
                      ],
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Switch(
                      value: isActive,
                      onChanged: (v) => _setVariantActive(doc, v),
                    ),
                    PopupMenuButton<String>(
                      tooltip: '更多',
                      onSelected: (v) => _handleRowAction(v, doc),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('編輯')),
                        PopupMenuItem(value: 'stock', child: Text('調整庫存')),
                        PopupMenuDivider(),
                        PopupMenuItem(value: 'delete', child: Text('刪除')),
                      ],
                    ),
                  ],
                ),
                onTap: () => _openEditDialogEdit(doc),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _attrChip(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(
        '$k:$v',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ============================================================
  // Filtering
  // ============================================================
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredVariants() {
    final q = _searchCtrl.text.trim().toLowerCase();

    return _variants.where((doc) {
      final d = doc.data();
      final isActive = _readBool(d['isActive'], fallback: true);
      if (!_showInactive && !isActive) return false;

      if (q.isEmpty) return true;

      final name = (d['name'] ?? '').toString().toLowerCase();
      final sku = (d['sku'] ?? '').toString().toLowerCase();
      final attrs = _readMap(d['attrs']);
      final attrsText = attrs.entries
          .map((e) => '${e.key}:${e.value}')
          .join(' ')
          .toLowerCase();

      return name.contains(q) || sku.contains(q) || attrsText.contains(q);
    }).toList();
  }

  // ============================================================
  // Reorder
  // ============================================================
  Future<void> _onReorder(
    int oldIndex,
    int newIndex,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> visibleList,
  ) async {
    if (_productId == null) return;

    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex < 0 || oldIndex >= visibleList.length) return;
    if (newIndex < 0 || newIndex >= visibleList.length) return;

    final moving = visibleList.removeAt(oldIndex);
    visibleList.insert(newIndex, moving);

    final visibleIds = visibleList.map((e) => e.id).toSet();
    final rest = _variants.where((v) => !visibleIds.contains(v.id)).toList();

    final newAll = <QueryDocumentSnapshot<Map<String, dynamic>>>[
      ...visibleList,
      ...rest,
    ];

    if (!mounted) return;
    setState(() => _variants = newAll);

    await _persistOrder();
  }

  Future<void> _persistOrder() async {
    if (_productId == null) return;
    if (_variants.isEmpty) return;

    try {
      final batch = _db.batch();
      for (int i = 0; i < _variants.length; i++) {
        batch.update(_variants[i].reference, {
          'sort': i,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('排序已更新')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新排序失敗：$e')));
    } finally {
      await _reloadVariantsOnly();
    }
  }

  // ============================================================
  // Row actions
  // ============================================================
  Future<void> _handleRowAction(
    String action,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    switch (action) {
      case 'edit':
        await _openEditDialogEdit(doc);
        return;
      case 'stock':
        await _adjustStock(doc);
        return;
      case 'delete':
        await _deleteVariant(doc);
        return;
    }
  }

  Future<void> _setVariantActive(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool v,
  ) async {
    try {
      await doc.reference.update({
        'isActive': v,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _reloadVariantsOnly();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新啟用狀態失敗：$e')));
    }
  }

  Future<void> _adjustStock(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final name = (data['name'] ?? '規格').toString();
    final current = _readInt(data['stock'], 0);

    final ctrl = TextEditingController(text: current.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('調整庫存：$name'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '庫存數量（整數）'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('更新'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final n = int.tryParse(ctrl.text.trim()) ?? current;
    final newStock = math.max(0, n);

    try {
      await doc.reference.update({
        'stock': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _reloadVariantsOnly();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('庫存已更新：$newStock')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新庫存失敗：$e')));
    }
  }

  Future<void> _deleteVariant(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final name = (doc.data()['name'] ?? '規格').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除規格「$name」？此操作不可復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await doc.reference.delete();
      await _reloadVariantsOnly();
      await _ensureSortIndexes();
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

  // ============================================================
  // Batch actions
  // ============================================================
  Future<void> _handleBatchAction(String action) async {
    if (_productId == null) return;
    if (_variants.isEmpty) return;

    Future<bool> confirm(String title, String msg) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確認'),
            ),
          ],
        ),
      );
      return ok == true;
    }

    try {
      if (action == 'enable_all') {
        final ok = await confirm('全部啟用', '將所有規格設為啟用？');
        if (!ok) return;

        final batch = _db.batch();
        for (final v in _variants) {
          batch.update(v.reference, {
            'isActive': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        await _reloadVariantsOnly();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已全部啟用')));
      }

      if (action == 'disable_all') {
        final ok = await confirm('全部停用', '將所有規格設為停用？');
        if (!ok) return;

        final batch = _db.batch();
        for (final v in _variants) {
          batch.update(v.reference, {
            'isActive': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        await _reloadVariantsOnly();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已全部停用')));
      }

      if (action == 'stock_zero') {
        final ok = await confirm('全部庫存歸零', '將所有規格庫存設為 0？');
        if (!ok) return;

        final batch = _db.batch();
        for (final v in _variants) {
          batch.update(v.reference, {
            'stock': 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        await _reloadVariantsOnly();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已全部庫存歸零')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('批次操作失敗：$e')));
    }
  }

  // ============================================================
  // Create/Edit dialogs
  // ============================================================
  Future<void> _openEditDialogCreate() async {
    if (_productId == null) return;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VariantEditDialog(
        title: '新增規格',
        basePrice: _basePrice,
        initial: const {},
      ),
    );

    // ✅ 修正：跨 async gap 先檢查 mounted，且 resultOf 不用 context
    if (!mounted) return;

    if (created == true) {
      await _createVariantFromDialog(_VariantEditDialog.resultOf());
    }
  }

  Future<void> _openEditDialogEdit(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final initial = doc.data();

    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VariantEditDialog(
        title: '編輯規格',
        basePrice: _basePrice,
        initial: initial,
      ),
    );

    // ✅ 修正：跨 async gap 先檢查 mounted，且 resultOf 不用 context
    if (!mounted) return;

    if (updated == true) {
      await _updateVariantFromDialog(doc, _VariantEditDialog.resultOf());
    }
  }

  Future<void> _createVariantFromDialog(Map<String, dynamic>? payload) async {
    if (_productId == null) return;
    if (payload == null) return;

    try {
      final nextSort = _variants.length;

      await _db
          .collection('products')
          .doc(_productId)
          .collection('variants')
          .add({
            ...payload,
            'sort': nextSort,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      await _reloadVariantsOnly();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已新增規格')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('新增失敗：$e')));
    }
  }

  Future<void> _updateVariantFromDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic>? payload,
  ) async {
    if (payload == null) return;

    try {
      await doc.reference.update({
        ...payload,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _reloadVariantsOnly();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已更新規格')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  // ============================================================
  // Price / parsing helpers
  // ============================================================
  num _computeVariantPrice(Map<String, dynamic> d) {
    final override = d['price'];
    if (override is num) return override;

    final delta = _readNum(d['priceDelta'] ?? 0);
    return _basePrice + delta;
  }

  Map<String, dynamic> _readMap(dynamic v) {
    if (v is Map) {
      return v.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }

  int _readInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  num _readNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  bool _readBool(dynamic v, {required bool fallback}) {
    if (v is bool) return v;
    if (v is String) {
      final t = v.toLowerCase().trim();
      if (t == 'true' || t == '1' || t == 'yes') return true;
      if (t == 'false' || t == '0' || t == 'no') return false;
    }
    if (v is num) return v != 0;
    return fallback;
  }
}

// ============================================================================
// 商品選擇器（當未帶 productId 時）
// ============================================================================
class _ProductPicker extends StatefulWidget {
  final ValueChanged<String> onPicked;
  const _ProductPicker({required this.onPicked});

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _loading = true;
  String? _error;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _products = [];
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snap = await _db.collection('products').orderBy('name').get();
      if (!mounted) return;
      setState(() {
        _products = snap.docs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('選擇商品')),
        body: _ErrorView(
          title: '載入商品失敗',
          message: _error!,
          onRetry: _load,
          hint: '請確認 Firestore products 集合存在且可讀取。',
        ),
      );
    }

    final q = _search.text.trim().toLowerCase();
    final list = _products.where((p) {
      final d = p.data();
      final name = (d['name'] ?? d['title'] ?? '').toString().toLowerCase();
      return q.isEmpty || name.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '選擇商品',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋商品',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('查無商品'),
                ),
              )
            else
              ...list.map((p) {
                final d = p.data();
                final name = (d['name'] ?? d['title'] ?? '商品').toString();
                final price = d['price'] ?? d['basePrice'] ?? 0;

                return Card(
                  child: ListTile(
                    leading: _productImage(d),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('價格：$price'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onPicked(p.id),
                  ),
                );
              }),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _productImage(Map<String, dynamic> d) {
    final images = d['images'];
    if (images is List && images.isNotEmpty) {
      final url = images.first.toString();
      if (url.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(url, width: 46, height: 46, fit: BoxFit.cover),
        );
      }
    }
    return const Icon(Icons.shopping_bag_outlined);
  }
}

// ============================================================================
// 規格編輯 Dialog（回傳 payload Map<String,dynamic>）
// ============================================================================
class _VariantEditDialog extends StatefulWidget {
  final String title;
  final num basePrice;
  final Map<String, dynamic> initial;

  const _VariantEditDialog({
    required this.title,
    required this.basePrice,
    required this.initial,
  });

  /// ✅ 修正：不需要 BuildContext（避免 async gap lint）
  static Map<String, dynamic>? resultOf() =>
      _VariantEditDialogResultStore.value;

  @override
  State<_VariantEditDialog> createState() => _VariantEditDialogState();
}

class _VariantEditDialogState extends State<_VariantEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _color;
  late final TextEditingController _size;
  late final TextEditingController _priceOverride;
  late final TextEditingController _priceDelta;
  late final TextEditingController _stock;
  late final TextEditingController _extraAttrs;

  bool _isActive = true;

  @override
  void initState() {
    super.initState();

    final init = widget.initial;
    final attrs = _readMap(init['attrs']);

    _name = TextEditingController(text: (init['name'] ?? '').toString());
    _sku = TextEditingController(text: (init['sku'] ?? '').toString());

    _color = TextEditingController(text: (attrs['color'] ?? '').toString());
    _size = TextEditingController(text: (attrs['size'] ?? '').toString());

    _priceOverride = TextEditingController(text: _stringOrEmpty(init['price']));
    _priceDelta = TextEditingController(
      text: _stringOrEmpty(init['priceDelta']),
    );
    _stock = TextEditingController(text: (init['stock'] ?? 0).toString());

    _isActive = _readBool(init['isActive'], fallback: true);

    final extras = <String, dynamic>{...attrs};
    extras.remove('color');
    extras.remove('size');
    _extraAttrs = TextEditingController(text: _formatExtraAttrs(extras));
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _color.dispose();
    _size.dispose();
    _priceOverride.dispose();
    _priceDelta.dispose();
    _stock.dispose();
    _extraAttrs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

    final previewText = fmtMoney.format(_previewFinalPrice());

    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _tipCard(cs, '價格規則：price（覆蓋） > basePrice + priceDelta（加價/減價）'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: '規格名稱（必填）',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '請輸入規格名稱' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _sku,
                  decoration: const InputDecoration(
                    labelText: 'SKU（選填）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _color,
                        decoration: const InputDecoration(
                          labelText: '顏色（color）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _size,
                        decoration: const InputDecoration(
                          labelText: '尺寸（size）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceOverride,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'price（覆蓋價，選填）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _priceDelta,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'priceDelta（加價/減價，選填）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _stock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '庫存 stock（必填，整數）',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null) return '請輸入整數';
                    if (n < 0) return '不可小於 0';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text('啟用 isActive'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _extraAttrs,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: '其他屬性 attrs（key=value，每行一組，可選）',
                    hintText: '例如：\nmaterial=矽膠\nedition=2026',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '預估顯示價格：$previewText',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check),
          label: const Text('儲存'),
        ),
      ],
    );
  }

  Widget _tipCard(ColorScheme cs, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final attrs = <String, dynamic>{};

    final c = _color.text.trim();
    final s = _size.text.trim();
    if (c.isNotEmpty) attrs['color'] = c;
    if (s.isNotEmpty) attrs['size'] = s;

    attrs.addAll(_parseExtraAttrs(_extraAttrs.text));

    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'sku': _sku.text.trim(),
      'attrs': attrs,
      'stock': math.max(0, int.tryParse(_stock.text.trim()) ?? 0),
      'isActive': _isActive,
    };

    final p = num.tryParse(_priceOverride.text.trim());
    final d = num.tryParse(_priceDelta.text.trim());
    if (p != null) {
      payload['price'] = p;
    } else {
      payload.remove('price');
    }
    if (d != null) {
      payload['priceDelta'] = d;
    } else {
      payload.remove('priceDelta');
    }

    _VariantEditDialogResultStore.value = payload;
    Navigator.pop(context, true);
  }

  num _previewFinalPrice() {
    final p = num.tryParse(_priceOverride.text.trim());
    if (p != null) return p;

    final d = num.tryParse(_priceDelta.text.trim()) ?? 0;
    return widget.basePrice + d;
  }

  Map<String, dynamic> _parseExtraAttrs(String text) {
    final m = <String, dynamic>{};
    final lines = text.split('\n');
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final idx = line.indexOf('=');
      if (idx <= 0) continue;
      final k = line.substring(0, idx).trim();
      final v = line.substring(idx + 1).trim();
      if (k.isEmpty || v.isEmpty) continue;
      m[k] = v;
    }
    return m;
  }

  String _formatExtraAttrs(Map<String, dynamic> extras) {
    if (extras.isEmpty) return '';
    final keys = extras.keys.toList()..sort();
    return keys.map((k) => '$k=${extras[k]}').join('\n');
  }

  String _stringOrEmpty(dynamic v) => (v == null) ? '' : v.toString();

  Map<String, dynamic> _readMap(dynamic v) {
    if (v is Map) {
      return v.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }

  bool _readBool(dynamic v, {required bool fallback}) {
    if (v is bool) return v;
    if (v is String) {
      final t = v.toLowerCase().trim();
      if (t == 'true' || t == '1' || t == 'yes') return true;
      if (t == 'false' || t == '0' || t == 'no') return false;
    }
    if (v is num) return v != 0;
    return fallback;
  }
}

class _VariantEditDialogResultStore {
  static Map<String, dynamic>? value;
}

// ============================================================================
// Error View（通用）
// ============================================================================
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
