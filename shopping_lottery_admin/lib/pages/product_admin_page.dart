// lib/pages/product_admin_page.dart
//
// ✅ ProductAdminPage（正式版｜完整版｜可直接編譯｜已修正 DropdownButtonFormField.value deprecated -> initialValue）
// ------------------------------------------------------------
// - 使用 ProductService（lib/services/product_service.dart）
// - 功能：列表（stream）、搜尋、vendor/category 篩選、啟用狀態篩選、新增/編輯、切換 isActive、刪除（含刪圖）
//
// 依賴：flutter/material, provider, services/product_service.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/product_service.dart';

class ProductAdminPage extends StatefulWidget {
  const ProductAdminPage({super.key});

  @override
  State<ProductAdminPage> createState() => _ProductAdminPageState();
}

class _ProductAdminPageState extends State<ProductAdminPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _vendorCtrl = TextEditingController();
  final TextEditingController _categoryCtrl = TextEditingController();

  String _activeFilter = 'all'; // all / active / inactive
  bool _busy = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _vendorCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  num _toNum(dynamic v, {num fallback = 0}) {
    if (v is num) return v;
    return num.tryParse('${v ?? ''}') ?? fallback;
  }

  bool _matches(Map<String, dynamic> p) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final vf = _vendorCtrl.text.trim();
    final cf = _categoryCtrl.text.trim();

    final id = _s(p['id']).toLowerCase();
    final title = _s(p['title']).toLowerCase();
    final vendorId = _s(p['vendorId']);
    final categoryId = _s(p['categoryId']);
    final isActive = p['isActive'] != false;

    if (vf.isNotEmpty && vendorId != vf) return false;
    if (cf.isNotEmpty && categoryId != cf) return false;

    if (_activeFilter == 'active' && !isActive) return false;
    if (_activeFilter == 'inactive' && isActive) return false;

    if (q.isEmpty) return true;
    return id.contains(q) ||
        title.contains(q) ||
        vendorId.toLowerCase().contains(q) ||
        categoryId.toLowerCase().contains(q);
  }

  Future<void> _openEditor({
    required ProductService svc,
    Map<String, dynamic>? initial,
  }) async {
    final res = await showDialog<_ProductEditResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProductEditDialog(initial: initial),
    );
    if (res == null) return;

    setState(() => _busy = true);
    try {
      await svc.upsert(id: res.productId, data: res.data);
      _snack(initial == null ? '已新增商品' : '已更新商品');
    } catch (e) {
      _snack('保存失敗：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete({
    required ProductService svc,
    required String productId,
    required String title,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除商品'),
        content: Text('確定要刪除「$title」\nID: $productId\n（會一併刪除 Storage 圖檔）？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await svc.deleteProductWithImages(productId);
      _snack('已刪除商品');
    } catch (e) {
      _snack('刪除失敗：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleActive(
    ProductService svc,
    String productId,
    bool v,
  ) async {
    try {
      await svc.toggleActive(productId, v);
    } catch (e) {
      _snack('更新失敗：$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.read<ProductService>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('商品管理'),
        actions: [
          IconButton(
            tooltip: '新增商品',
            onPressed: _busy ? null : () => _openEditor(svc: svc),
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: _FiltersBar(
              searchCtrl: _searchCtrl,
              vendorCtrl: _vendorCtrl,
              categoryCtrl: _categoryCtrl,
              activeFilter: _activeFilter,
              onActiveFilterChanged: (v) => setState(() => _activeFilter = v),
              onChanged: () => setState(() {}),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: svc.streamProducts(limit: 500),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      '載入失敗：${snap.error}',
                      style: TextStyle(color: cs.error),
                    ),
                  );
                }

                final list = (snap.data ?? <Map<String, dynamic>>[])
                    .where(_matches)
                    .toList(growable: false);

                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      '沒有資料',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = list[i];

                    final id = _s(p['id']);
                    final title = _s(p['title']).isEmpty
                        ? '(未命名商品)'
                        : _s(p['title']);
                    final vendorId = _s(p['vendorId']);
                    final categoryId = _s(p['categoryId']);
                    final price = _toNum(
                      p['price'],
                      fallback: _toNum(p['amount'], fallback: 0),
                    );
                    final isActive = p['isActive'] != false;

                    final imageUrl = _s(p['imageUrl']);

                    return Card(
                      elevation: 0.8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        leading: _Thumb(url: imageUrl),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(isActive ? 'active' : 'inactive'),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'ID: $id'
                            '${vendorId.isNotEmpty ? ' ｜ vendorId: $vendorId' : ''}'
                            '${categoryId.isNotEmpty ? ' ｜ categoryId: $categoryId' : ''}'
                            ' ｜ price: ${price.toStringAsFixed(0)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: SizedBox(
                          width: 178,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Text(
                                    '啟用',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Switch(
                                    value: isActive,
                                    onChanged: _busy
                                        ? null
                                        : (v) => _toggleActive(svc, id, v),
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: '編輯',
                                    onPressed: _busy
                                        ? null
                                        : () =>
                                              _openEditor(svc: svc, initial: p),
                                    icon: const Icon(Icons.edit),
                                  ),
                                  IconButton(
                                    tooltip: '刪除',
                                    onPressed: _busy
                                        ? null
                                        : () => _delete(
                                            svc: svc,
                                            productId: id,
                                            title: title,
                                          ),
                                    icon: const Icon(Icons.delete),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        onTap: _busy
                            ? null
                            : () => _openEditor(svc: svc, initial: p),
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

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.searchCtrl,
    required this.vendorCtrl,
    required this.categoryCtrl,
    required this.activeFilter,
    required this.onActiveFilterChanged,
    required this.onChanged,
  });

  final TextEditingController searchCtrl;
  final TextEditingController vendorCtrl;
  final TextEditingController categoryCtrl;

  final String activeFilter;
  final ValueChanged<String> onActiveFilterChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 820;

    final search = TextField(
      controller: searchCtrl,
      onChanged: (_) => onChanged(),
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: '搜尋：title / id / vendorId / categoryId',
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );

    final vendor = TextField(
      controller: vendorCtrl,
      onChanged: (_) => onChanged(),
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.store_mall_directory_outlined),
        hintText: 'vendorId 篩選（可空）',
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );

    final category = TextField(
      controller: categoryCtrl,
      onChanged: (_) => onChanged(),
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.category_outlined),
        hintText: 'categoryId 篩選（可空）',
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );

    // ✅ FIX：DropdownButtonFormField.value deprecated -> initialValue
    final active = DropdownButtonFormField<String>(
      initialValue: activeFilter,
      decoration: const InputDecoration(
        labelText: '啟用狀態',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('全部')),
        DropdownMenuItem(value: 'active', child: Text('只看 active')),
        DropdownMenuItem(value: 'inactive', child: Text('只看 inactive')),
      ],
      onChanged: (v) => onActiveFilterChanged(v ?? 'all'),
    );

    if (isNarrow) {
      return Column(
        children: [
          search,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: active),
              const SizedBox(width: 10),
              Expanded(child: vendor),
            ],
          ),
          const SizedBox(height: 10),
          category,
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 3, child: search),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: active),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: vendor),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: category),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 56,
        height: 56,
        child: url.trim().isEmpty
            ? Container(
                color: cs.surfaceContainerHighest,
                child: const Icon(Icons.image_not_supported_outlined),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: cs.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
      ),
    );
  }
}

class _ProductEditResult {
  const _ProductEditResult({required this.productId, required this.data});
  final String productId;
  final Map<String, dynamic> data;
}

class _ProductEditDialog extends StatefulWidget {
  const _ProductEditDialog({this.initial});

  final Map<String, dynamic>? initial;

  @override
  State<_ProductEditDialog> createState() => _ProductEditDialogState();
}

class _ProductEditDialogState extends State<_ProductEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _idCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _vendorCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _imageUrlCtrl;

  bool _isActive = true;

  String _s(dynamic v) => (v ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    final m = widget.initial ?? <String, dynamic>{};

    final id = _s(m['id']);
    _idCtrl = TextEditingController(text: id);
    _titleCtrl = TextEditingController(text: _s(m['title']));
    _priceCtrl = TextEditingController(
      text: m['price'] is num ? '${m['price']}' : _s(m['price']),
    );
    _vendorCtrl = TextEditingController(text: _s(m['vendorId']));
    _categoryCtrl = TextEditingController(text: _s(m['categoryId']));
    _imageUrlCtrl = TextEditingController(text: _s(m['imageUrl']));
    _isActive = m['isActive'] != false;

    if (widget.initial == null && _idCtrl.text.trim().isEmpty) {
      _idCtrl.text = _genId();
    }
  }

  String _genId() {
    final r = Random();
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'p$ts${r.nextInt(900) + 100}';
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _vendorCtrl.dispose();
    _categoryCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final pid = _idCtrl.text.trim();
    final price = num.tryParse(_priceCtrl.text.trim()) ?? 0;

    final data = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'price': price,
      'vendorId': _vendorCtrl.text.trim(),
      'categoryId': _categoryCtrl.text.trim(),
      'isActive': _isActive,
      'imageUrl': _imageUrlCtrl.text.trim(),
    };

    Navigator.pop(context, _ProductEditResult(productId: pid, data: data));
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.initial == null;

    return AlertDialog(
      title: Text(isCreate ? '新增商品' : '編輯商品'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _idCtrl,
                  enabled: isCreate,
                  decoration: const InputDecoration(
                    labelText: 'productId（必填）',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? '必填' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'title（必填）',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? '必填' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'price',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _vendorCtrl,
                        decoration: const InputDecoration(
                          labelText: 'vendorId',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _categoryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'categoryId',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _imageUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: '主圖 imageUrl（可空）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('isActive（上架/啟用）'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save),
          label: const Text('保存'),
        ),
      ],
    );
  }
}
