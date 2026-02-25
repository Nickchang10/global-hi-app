// lib/pages/admin/products/admin_product_edit_page.dart
//
// ✅ AdminProductEditPage（商品編輯｜完整版｜可編譯）
// ------------------------------------------------------------
// - 支援：新增 / 編輯 products/{id}
// - 內容：名稱、價格、庫存、分類、上架狀態、圖片、描述、tags
// - ✅ 修正 DropdownButtonFormField deprecated: value → initialValue
// - ✅ Dropdown 防呆：initialValue 必須存在於 items
// - 相容 Web/桌面/手機
//
// 路由建議：
// '/admin_product_edit': (_) => const AdminProductEditPage(),
// Navigator.pushNamed(context, '/admin_product_edit', arguments: {'productId': id});
// 若不傳 productId → 走新增模式

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminProductEditPage extends StatefulWidget {
  const AdminProductEditPage({super.key});

  @override
  State<AdminProductEditPage> createState() => _AdminProductEditPageState();
}

class _AdminProductEditPageState extends State<AdminProductEditPage> {
  final _db = FirebaseFirestore.instance;

  String? _productId;
  String? _argError;

  bool get _isCreate => _productId == null;

  // controllers
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  final _stockCtrl = TextEditingController(text: '0');
  final _coverCtrl = TextEditingController(); // 主要圖片 url
  final _imagesCtrl = TextEditingController(); // 其他圖片（用換行或逗號）
  final _descCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController(); // 逗號分隔

  // form selections
  bool _published = false;
  String _categoryId = 'uncategorized';

  // options (可替換成你的分類集合)
  // 若你有 categories collection，你可以改成動態載入
  static const List<String> _categoryOptions = <String>[
    'uncategorized',
    'watch',
    'accessory',
    'service',
    'other',
  ];

  final _money = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

  bool _loading = false;
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    String? pid;

    if (args is String) {
      pid = args.trim();
    } else if (args is Map) {
      final v = args['productId'] ?? args['id'];
      if (v != null) pid = v.toString().trim();
    }

    if (pid != null && pid.isNotEmpty) {
      _productId = pid;
      _loadProduct();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _coverCtrl.dispose();
    _imagesCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('products').doc(_productId);

  // ===========================================================
  // Helpers
  // ===========================================================
  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  num _asNum(String s) => num.tryParse(s.trim()) ?? 0;
  int _asInt(String s) => int.tryParse(s.trim()) ?? 0;

  List<String> _parseImages(String s) {
    final raw = s
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return raw;
  }

  List<String> _parseTags(String s) {
    final raw = s
        .split(RegExp(r'[,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    // 去重（忽略大小寫）
    final seen = <String>{};
    final out = <String>[];
    for (final t in raw) {
      final k = t.toLowerCase();
      if (seen.contains(k)) continue;
      seen.add(k);
      out.add(t);
    }
    return out;
  }

  /// ✅ Dropdown 防呆：initialValue 必須存在於 items（否則給 fallback）
  T _safeInitial<T>(T value, List<T> items, {required T fallback}) {
    if (items.contains(value)) return value;
    return fallback;
  }

  // ===========================================================
  // Load
  // ===========================================================
  Future<void> _loadProduct() async {
    if (_productId == null) return;

    setState(() => _loading = true);
    try {
      final snap = await _ref.get();
      if (!snap.exists) {
        setState(() {
          _argError = '找不到商品：products/$_productId';
        });
        return;
      }

      final d = snap.data() ?? <String, dynamic>{};

      _nameCtrl.text = (d['name'] ?? d['title'] ?? '').toString();
      _priceCtrl.text = (d['price'] ?? d['salePrice'] ?? 0).toString();
      _stockCtrl.text = (d['stock'] ?? d['stockQty'] ?? d['inventory'] ?? 0)
          .toString();

      _published = d['published'] == true || d['isPublished'] == true;

      _categoryId = (d['categoryId'] ?? d['category'] ?? 'uncategorized')
          .toString()
          .trim();
      if (_categoryId.isEmpty) _categoryId = 'uncategorized';

      _descCtrl.text = (d['description'] ?? '').toString();

      // images
      final cover = (d['imageUrl'] ?? '').toString().trim();
      _coverCtrl.text = cover;

      final imgs = (d['images'] is List)
          ? (d['images'] as List).map((e) => e.toString()).toList()
          : <String>[];
      _imagesCtrl.text = imgs.join('\n');

      final tags = (d['tags'] is List)
          ? (d['tags'] as List).map((e) => e.toString()).toList()
          : <String>[];
      _tagsCtrl.text = tags.join(', ');
    } catch (e) {
      _snack('載入失敗：$e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ===========================================================
  // Save
  // ===========================================================
  Future<void> _save() async {
    if (_loading) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('請輸入商品名稱');
      return;
    }

    final price = _asNum(_priceCtrl.text);
    final stock = _asInt(_stockCtrl.text);
    final cover = _coverCtrl.text.trim();
    final images = _parseImages(_imagesCtrl.text);
    final tags = _parseTags(_tagsCtrl.text);
    final desc = _descCtrl.text.trim();

    setState(() => _loading = true);

    try {
      final data = <String, dynamic>{
        'name': name,
        'price': price,
        'stock': stock,
        'published': _published,
        'categoryId': _categoryId,
        'description': desc,
        'imageUrl': cover,
        'images': images,
        'tags': tags,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isCreate) {
        final doc = _db.collection('products').doc();
        await doc.set({...data, 'createdAt': FieldValue.serverTimestamp()});
        if (!mounted) return;
        _snack('已新增商品');
        Navigator.pop(context, {'productId': doc.id});
      } else {
        await _ref.update(data);
        if (!mounted) return;
        _snack('已儲存變更');
        Navigator.pop(context, {'productId': _productId});
      }
    } catch (e) {
      if (!mounted) return;
      _snack('儲存失敗：$e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ===========================================================
  // UI
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_argError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('商品編輯')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: cs.error, size: 44),
                    const SizedBox(height: 10),
                    Text(
                      '開啟失敗',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: cs.error,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _argError!,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('返回'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreate ? '新增商品' : '編輯商品：$_productId'),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('儲存'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _sectionCard(
                  title: '基本資料',
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: '商品名稱',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, c) {
                          final isNarrow = c.maxWidth < 560;
                          final priceField = TextField(
                            controller: _priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: '價格',
                              helperText: _money.format(
                                _asNum(_priceCtrl.text),
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          );
                          final stockField = TextField(
                            controller: _stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '庫存',
                              border: OutlineInputBorder(),
                            ),
                          );

                          if (isNarrow) {
                            return Column(
                              children: [
                                priceField,
                                const SizedBox(height: 10),
                                stockField,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: priceField),
                              const SizedBox(width: 10),
                              Expanded(child: stockField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      // ✅ DropdownButtonFormField：value → initialValue
                      // key 用當前狀態/值，讓 setState 更新後能重建吃到 initialValue
                      DropdownButtonFormField<String>(
                        key: ValueKey('category_$_categoryId'),
                        initialValue: _safeInitial<String>(
                          _categoryId,
                          _categoryOptions,
                          fallback: 'uncategorized',
                        ),
                        items: _categoryOptions
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _categoryId = v);
                        },
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '分類（categoryId）',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 10),

                      SwitchListTile.adaptive(
                        value: _published,
                        onChanged: (v) => setState(() => _published = v),
                        title: const Text('上架（published）'),
                        subtitle: Text(_published ? '上架中' : '未上架'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),

                _sectionCard(
                  title: '圖片',
                  child: Column(
                    children: [
                      TextField(
                        controller: _coverCtrl,
                        decoration: const InputDecoration(
                          labelText: '封面圖片 URL（imageUrl）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _imagesCtrl,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: '其他圖片（images）— 每行一張 或 用逗號分隔',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ImagesPreview(
                        coverUrl: _coverCtrl.text.trim(),
                        images: _parseImages(_imagesCtrl.text),
                      ),
                    ],
                  ),
                ),

                _sectionCard(
                  title: '描述 / Tags',
                  child: Column(
                    children: [
                      TextField(
                        controller: _descCtrl,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: '描述（description）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _tagsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tags（逗號分隔）',
                          helperText: '例如：熱賣, 新品, 限量',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _loading ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('儲存'),
                ),
              ],
            ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Images preview
// ============================================================================
class _ImagesPreview extends StatelessWidget {
  final String coverUrl;
  final List<String> images;

  const _ImagesPreview({required this.coverUrl, required this.images});

  @override
  Widget build(BuildContext context) {
    final urls = <String>[
      if (coverUrl.isNotEmpty) coverUrl,
      ...images.where((e) => e.isNotEmpty),
    ];

    if (urls.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('（尚無圖片）', style: TextStyle(color: Colors.black54)),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final u in urls.take(8))
          SizedBox(
            width: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.network(
                  u,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Text('載入失敗')),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
