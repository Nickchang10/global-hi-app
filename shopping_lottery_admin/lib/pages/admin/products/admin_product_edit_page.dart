// lib/pages/admin/products/admin_product_edit_page.dart
// =====================================================
// ✅ AdminProductEditPage（修正 Dropdown + 向下相容 product: payload）完整版
// - 支援 AdminProductEditPage(product: payload) 舊呼叫方式 ✅
// - 也支援 AdminProductEditPage(productId: 'xxx') 新方式 ✅
// - Dropdown items 去重（避免同 value 出現 2 次）
// - Dropdown value 安全化（不在 items 內就設 ''）避免 1795 assertion
// - 類別/商家一律用 doc.id 當 value（避免資料欄位重複）
// =====================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminProductEditPage extends StatefulWidget {
  /// ✅ 新增：向下相容 AdminProductsPage 傳進來的 payload
  /// payload 常見格式：
  /// - {'id': 'xxx', ...fields}
  /// - {'productId': 'xxx', ...fields}
  /// - {'ref': DocumentReference, ...fields}
  final Map<String, dynamic>? product;

  /// ✅ 仍保留：可直接傳 productId
  final String? productId;

  const AdminProductEditPage({
    super.key,
    this.productId,
    this.product,
  });

  @override
  State<AdminProductEditPage> createState() => _AdminProductEditPageState();
}

class _AdminProductEditPageState extends State<AdminProductEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

  // controllers
  final _nameCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _compareAtCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _imageUrlsCtrl = TextEditingController(); // 用換行/逗號分隔
  final _tagsCtrl = TextEditingController(); // 用逗號分隔

  bool _enabled = true;
  bool _saving = false;

  /// ✅ 僅初始化一次（避免 Stream rebuild 覆蓋你正在輸入）
  bool _didInit = false;

  String? _categoryId; // categories/{id}
  String? _vendorId; // vendors/{id}

  // -------------------------
  // lifecycle
  // -------------------------
  @override
  void dispose() {
    _nameCtrl.dispose();
    _subtitleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _compareAtCtrl.dispose();
    _stockCtrl.dispose();
    _skuCtrl.dispose();
    _imageUrlsCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // productId 解析（支援 payload）
  // -------------------------
  String? _resolveProductIdFromPayload(Map<String, dynamic>? p) {
    if (p == null) return null;

    final v1 = p['id'];
    if (v1 is String && v1.trim().isNotEmpty) return v1.trim();

    final v2 = p['productId'];
    if (v2 is String && v2.trim().isNotEmpty) return v2.trim();

    final v3 = p['ref'];
    if (v3 is DocumentReference) return v3.id;

    final v4 = p['docRef'];
    if (v4 is DocumentReference) return v4.id;

    return null;
  }

  String? get _effectiveProductId =>
      widget.productId ?? _resolveProductIdFromPayload(widget.product);

  bool get _isEdit => _effectiveProductId != null;

  // -------------------------
  // Helpers: Dropdown 防呆
  // -------------------------
  String? _safeValue(String? value, Set<String> values) {
    if (value == null) return null;
    return values.contains(value) ? value : null;
  }

  /// ✅ items 去重：同 id 只留一個
  List<DropdownMenuItem<String>> _uniqueItemsFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required String Function(QueryDocumentSnapshot<Map<String, dynamic>> d)
        labelOf,
    String? leadingValue,
    String? leadingLabel,
  }) {
    final map = <String, String>{};

    if (leadingValue != null && leadingLabel != null) {
      map[leadingValue] = leadingLabel;
    }

    for (final d in docs) {
      map[d.id] = labelOf(d);
    }

    return map.entries
        .map((e) => DropdownMenuItem<String>(
              value: e.key,
              child: Text(
                e.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ))
        .toList(growable: false);
  }

  num _toNum(TextEditingController c) => num.tryParse(c.text.trim()) ?? 0;
  int _toInt(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  List<String> _parseUrls(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return [];
    final parts = s
        .replaceAll('\n', ',')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final set = <String>{};
    final out = <String>[];
    for (final p in parts) {
      if (set.add(p)) out.add(p);
    }
    return out;
  }

  List<String> _parseTags(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return [];
    final parts = s
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final set = <String>{};
    final out = <String>[];
    for (final p in parts) {
      if (set.add(p)) out.add(p);
    }
    return out;
  }

  String? _pickCategoryId(Map<String, dynamic> data) {
    final v1 = data['categoryId'];
    if (v1 is String && v1.trim().isNotEmpty) return v1.trim();

    final v2 = data['category'];
    if (v2 is String && v2.trim().isNotEmpty) return v2.trim();

    final v3 = data['categoryRef'];
    if (v3 is DocumentReference) return v3.id;

    return null;
  }

  String? _pickVendorId(Map<String, dynamic> data) {
    final v1 = data['vendorId'];
    if (v1 is String && v1.trim().isNotEmpty) return v1.trim();

    final v2 = data['vendor'];
    if (v2 is String && v2.trim().isNotEmpty) return v2.trim();

    final v3 = data['vendorRef'];
    if (v3 is DocumentReference) return v3.id;

    return null;
  }

  void _initFromMapOnce(Map<String, dynamic> p) {
    if (_didInit) return;
    _didInit = true;

    _nameCtrl.text = (p['name'] ?? '').toString();
    _subtitleCtrl.text = (p['subtitle'] ?? '').toString();
    _descCtrl.text = (p['description'] ?? p['desc'] ?? '').toString();

    final price = p['price'];
    _priceCtrl.text =
        (price is num) ? price.toString() : (price?.toString() ?? '');

    final compareAt = p['compareAtPrice'] ?? p['compareAt'];
    _compareAtCtrl.text = (compareAt is num)
        ? compareAt.toString()
        : (compareAt?.toString() ?? '');

    final stock = p['stock'];
    _stockCtrl.text =
        (stock is num) ? stock.toInt().toString() : (stock?.toString() ?? '');

    _skuCtrl.text = (p['sku'] ?? '').toString();

    final enabled = p['enabled'];
    _enabled = (enabled is bool) ? enabled : true;

    _categoryId = _pickCategoryId(p);
    _vendorId = _pickVendorId(p);

    final urls = p['imageUrls'] ?? p['images'];
    if (urls is List) {
      _imageUrlsCtrl.text = urls.map((e) => e.toString()).join('\n');
    } else {
      _imageUrlsCtrl.text = (p['imageUrl'] ?? '').toString();
    }

    final tags = p['tags'];
    if (tags is List) {
      _tagsCtrl.text = tags.map((e) => e.toString()).join(',');
    } else {
      _tagsCtrl.text = (p['tag'] ?? '').toString();
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'subtitle': _subtitleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'price': _toNum(_priceCtrl),
      'compareAtPrice': _toNum(_compareAtCtrl),
      'stock': _toInt(_stockCtrl),
      'sku': _skuCtrl.text.trim(),
      'enabled': _enabled,
      'categoryId': _categoryId,
      'vendorId': _vendorId,
      'imageUrls': _parseUrls(_imageUrlsCtrl.text),
      'tags': _parseTags(_tagsCtrl.text),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    data.removeWhere((k, v) => v == null);

    try {
      final col = FirebaseFirestore.instance.collection('products');

      if (_effectiveProductId == null) {
        await col.add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await col.doc(_effectiveProductId).update(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已儲存')),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_effectiveProductId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除商品'),
        content: const Text('確定要刪除這個商品？此動作無法復原。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(_effectiveProductId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已刪除')),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刪除失敗：$e')),
      );
    }
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    // ✅ 若外部有傳 payload（product），可先用它預填一次（即使是 edit 也 OK）
    if (!_didInit && widget.product != null) {
      _initFromMapOnce(widget.product!);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '編輯商品' : '新增商品'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: '刪除',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isEdit ? _buildEditBody() : _buildCreateBody(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? '儲存中…' : '儲存'),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateBody() {
    return _buildForm();
  }

  Widget _buildEditBody() {
    final id = _effectiveProductId!;
    final docRef = FirebaseFirestore.instance.collection('products').doc(id);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('讀取失敗：${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snap.data!.data();
        if (data == null) {
          return const Center(child: Text('商品不存在或已刪除'));
        }

        // ✅ 用雲端資料初始化一次（如果你已用 payload 初始化過，也不會覆蓋）
        _initFromMapOnce(data);

        return _buildForm();
      },
    );
  }

  Widget _buildForm() {
    final urls = _parseUrls(_imageUrlsCtrl.text);
    final previewUrl = urls.isNotEmpty ? urls.first : '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        if (previewUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                previewUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        if (previewUrl.isNotEmpty) const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                    title: const Text('上架狀態'),
                    subtitle: Text(_enabled ? 'enabled=true（前台可見）' : 'enabled=false（前台不可見）'),
                  ),
                  const Divider(),

                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '商品名稱',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '請輸入商品名稱' : null,
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _subtitleCtrl,
                    decoration: const InputDecoration(
                      labelText: '副標題（可空）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '商品描述',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _CategoryDropdown(
                    selectedId: _categoryId,
                    onChanged: (v) => setState(() => _categoryId = v),
                    uniqueItemsFromDocs: _uniqueItemsFromDocs,
                    safeValue: _safeValue,
                  ),
                  const SizedBox(height: 12),

                  _VendorDropdown(
                    selectedId: _vendorId,
                    onChanged: (v) => setState(() => _vendorId = v),
                    uniqueItemsFromDocs: _uniqueItemsFromDocs,
                    safeValue: _safeValue,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '售價',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final n = num.tryParse((v ?? '').trim());
                            if (n == null || n < 0) return '售價格式不正確';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _compareAtCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '原價（可空）',
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
                          controller: _stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '庫存',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _skuCtrl,
                          decoration: const InputDecoration(
                            labelText: 'SKU（可空）',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _imageUrlsCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '圖片 URLs（可多筆，換行或逗號分隔）',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _tagsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'tags（逗號分隔，可空）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_priceCtrl.text.trim().isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '前台顯示參考：${_moneyFmt.format(_toNum(_priceCtrl))}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================
// Category Dropdown
// =====================================================
class _CategoryDropdown extends StatelessWidget {
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  final List<DropdownMenuItem<String>> Function(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required String Function(QueryDocumentSnapshot<Map<String, dynamic>> d)
        labelOf,
    String? leadingValue,
    String? leadingLabel,
  }) uniqueItemsFromDocs;

  final String? Function(String? value, Set<String> values) safeValue;

  const _CategoryDropdown({
    required this.selectedId,
    required this.onChanged,
    required this.uniqueItemsFromDocs,
    required this.safeValue,
  });

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('categories')
        .orderBy(FieldPath.documentId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final items = uniqueItemsFromDocs(
          docs,
          leadingValue: '',
          leadingLabel: '（未選擇分類）',
          labelOf: (d) {
            final m = d.data();
            final name = (m['name'] ?? m['title'] ?? d.id).toString().trim();
            return name.isEmpty ? d.id : name;
          },
        );

        final values = items.map((e) => e.value ?? '').toSet();
        final fixed = safeValue((selectedId ?? ''), values) ?? '';

        return DropdownButtonFormField<String>(
          value: fixed,
          items: items,
          isExpanded: true,
          onChanged: (v) => onChanged((v == null || v.isEmpty) ? null : v),
          decoration: const InputDecoration(
            labelText: '分類',
            border: OutlineInputBorder(),
          ),
        );
      },
    );
  }
}

// =====================================================
// Vendor Dropdown
// =====================================================
class _VendorDropdown extends StatelessWidget {
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  final List<DropdownMenuItem<String>> Function(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required String Function(QueryDocumentSnapshot<Map<String, dynamic>> d)
        labelOf,
    String? leadingValue,
    String? leadingLabel,
  }) uniqueItemsFromDocs;

  final String? Function(String? value, Set<String> values) safeValue;

  const _VendorDropdown({
    required this.selectedId,
    required this.onChanged,
    required this.uniqueItemsFromDocs,
    required this.safeValue,
  });

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('vendors')
        .orderBy(FieldPath.documentId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final items = uniqueItemsFromDocs(
          docs,
          leadingValue: '',
          leadingLabel: '（未指定商家）',
          labelOf: (d) {
            final m = d.data();
            final name = (m['name'] ?? m['title'] ?? d.id).toString().trim();
            return name.isEmpty ? d.id : name;
          },
        );

        final values = items.map((e) => e.value ?? '').toSet();
        final fixed = safeValue((selectedId ?? ''), values) ?? '';

        return DropdownButtonFormField<String>(
          value: fixed,
          items: items,
          isExpanded: true,
          onChanged: (v) => onChanged((v == null || v.isEmpty) ? null : v),
          decoration: const InputDecoration(
            labelText: '商家（vendor）',
            border: OutlineInputBorder(),
          ),
        );
      },
    );
  }
}
