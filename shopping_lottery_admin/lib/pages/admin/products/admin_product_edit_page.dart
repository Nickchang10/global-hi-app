// lib/pages/admin/products/admin_product_edit_page.dart
//
// ✅ AdminProductEditPage（商品編輯｜最終完整版｜含上傳圖到 Firebase Storage｜可編譯）
// ------------------------------------------------------------
// - 新增 / 編輯 products/{id}
// - 欄位：名稱、價格、庫存、分類、上架狀態、封面圖、其他圖片、描述、tags
// - ✅ 圖片：ImagePicker 選圖 → Firebase Storage putData → 取得 URL → 寫回表單
// - ✅ Web/桌面/手機相容：不用 dart:io（避免 web 編譯炸）
// - ✅ Dropdown 防呆：value 必須存在 items
//
// 路由建議：
// '/admin_product_edit': (_) => const AdminProductEditPage(),
// Navigator.pushNamed(context, '/admin_product_edit', arguments: {'productId': id});
// 不傳 productId → 新增模式

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AdminProductEditPage extends StatefulWidget {
  const AdminProductEditPage({super.key});

  @override
  State<AdminProductEditPage> createState() => _AdminProductEditPageState();
}

class _AdminProductEditPageState extends State<AdminProductEditPage> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  String? _productId; // edit mode
  String? _draftId; // create mode: 用來上傳圖前先生成 id
  String? _argError;

  bool get _isCreate => _productId == null;

  // controllers
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  final _stockCtrl = TextEditingController(text: '0');
  final _coverCtrl = TextEditingController(); // 封面 imageUrl
  final _imagesCtrl = TextEditingController(); // images (urls，用換行/逗號)
  final _descCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  // form selections
  bool _published = false;
  String _categoryId = 'uncategorized';

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

  // upload state
  bool _uploading = false;
  String _uploadLabel = '';
  double _uploadProgress = 0;

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

  // ===========================================================
  // Helpers
  // ===========================================================
  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  num _asNum(String s) => num.tryParse(s.trim()) ?? 0;
  int _asInt(String s) => int.tryParse(s.trim()) ?? 0;

  List<String> _parseImages(String s) {
    return s
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> _parseTags(String s) {
    final raw = s
        .split(RegExp(r'[,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

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

  T _safeValue<T>(T value, List<T> items, {required T fallback}) {
    if (items.contains(value)) return value;
    return fallback;
  }

  String _ensureDocId() {
    // 編輯：直接用 productId
    if (_productId != null && _productId!.isNotEmpty) return _productId!;

    // 新增：若已生成 draftId 就用；否則生成一個
    _draftId ??= _db.collection('products').doc().id;
    return _draftId!;
  }

  String _guessContentType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<String> _uploadXFileToStorage({
    required XFile file,
    required String folder,
    required String filenamePrefix,
  }) async {
    final docId = _ensureDocId();
    final bytes = await file.readAsBytes();
    final ext = (file.name.contains('.'))
        ? file.name.substring(file.name.lastIndexOf('.'))
        : '.jpg';

    final safeExt = (ext.length <= 10) ? ext : '.jpg';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '$folder/$docId/${filenamePrefix}_$ts$safeExt';

    final ref = _storage.ref().child(path);
    final meta = SettableMetadata(contentType: _guessContentType(file.name));

    setState(() {
      _uploading = true;
      _uploadLabel = '上傳中：$filenamePrefix';
      _uploadProgress = 0;
    });

    final task = ref.putData(bytes, meta);

    // 進度（Web / Mobile 都可用）
    task.snapshotEvents.listen((s) {
      final total = s.totalBytes;
      if (total > 0) {
        final p = s.bytesTransferred / total;
        if (mounted) {
          setState(() => _uploadProgress = p.clamp(0, 1));
        }
      }
    });

    await task;
    final url = await ref.getDownloadURL();

    if (mounted) {
      setState(() {
        _uploading = false;
        _uploadLabel = '';
        _uploadProgress = 0;
      });
    }

    return url;
  }

  void _appendImageUrl(String url) {
    final current = _parseImages(_imagesCtrl.text);
    if (current.contains(url)) return;
    current.add(url);
    _imagesCtrl.text = current.join('\n');
    setState(() {}); // refresh preview
  }

  void _removeImageUrl(String url) {
    final current = _parseImages(_imagesCtrl.text);
    current.removeWhere((e) => e == url);
    _imagesCtrl.text = current.join('\n');
    setState(() {});
  }

  // ===========================================================
  // Load
  // ===========================================================
  Future<void> _loadProduct() async {
    if (_productId == null) return;

    setState(() => _loading = true);
    try {
      final snap = await _db.collection('products').doc(_productId).get();
      if (!snap.exists) {
        setState(() => _argError = '找不到商品：products/$_productId');
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
      if (!_categoryOptions.contains(_categoryId)) {
        _categoryId = 'uncategorized';
      }

      _descCtrl.text = (d['description'] ?? '').toString();

      // cover
      _coverCtrl.text = (d['imageUrl'] ?? '').toString().trim();

      // images list
      final imgs = (d['images'] is List)
          ? (d['images'] as List).map((e) => e.toString()).toList()
          : <String>[];
      _imagesCtrl.text = imgs.join('\n');

      // tags list
      final tags = (d['tags'] is List)
          ? (d['tags'] as List).map((e) => e.toString()).toList()
          : <String>[];
      _tagsCtrl.text = tags.join(', ');
    } catch (e) {
      _snack('載入失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===========================================================
  // Pick & Upload images
  // ===========================================================
  Future<void> _pickAndUploadCover() async {
    if (_uploading) return;
    try {
      final x = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (x == null) return;

      final url = await _uploadXFileToStorage(
        file: x,
        folder: 'products',
        filenamePrefix: 'cover',
      );

      _coverCtrl.text = url;
      if (mounted) setState(() {});
      _snack('封面已上傳');
    } catch (e) {
      if (!mounted) return;
      _snack('封面上傳失敗：$e');
    }
  }

  Future<void> _pickAndUploadMoreImages() async {
    if (_uploading) return;

    try {
      List<XFile> files = <XFile>[];

      // web / mobile 都嘗試 multi pick；失敗再 fallback single
      try {
        final picked = await _picker.pickMultiImage(imageQuality: 92);
        if (picked.isNotEmpty) files = picked;
      } catch (_) {}

      if (files.isEmpty) {
        final one = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 92,
        );
        if (one != null) files = [one];
      }

      if (files.isEmpty) return;

      for (int i = 0; i < files.length; i++) {
        final f = files[i];
        final url = await _uploadXFileToStorage(
          file: f,
          folder: 'products',
          filenamePrefix: 'img_${i + 1}',
        );
        _appendImageUrl(url);
      }

      if (!mounted) return;
      _snack('圖片已上傳');
    } catch (e) {
      if (!mounted) return;
      _snack('圖片上傳失敗：$e');
    }
  }

  // ===========================================================
  // Save
  // ===========================================================
  Future<void> _save() async {
    if (_loading || _uploading) return;

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
        final id = _ensureDocId();
        final doc = _db.collection('products').doc(id);
        await doc.set({...data, 'createdAt': FieldValue.serverTimestamp()});

        if (!mounted) return;
        _snack('已新增商品');
        Navigator.pop(context, {'productId': id});
      } else {
        await _db.collection('products').doc(_productId).update(data);

        if (!mounted) return;
        _snack('已儲存變更');
        Navigator.pop(context, {'productId': _productId});
      }
    } catch (e) {
      if (!mounted) return;
      _snack('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
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

    final images = _parseImages(_imagesCtrl.text);
    final coverUrl = _coverCtrl.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreate ? '新增商品' : '編輯商品：$_productId'),
        actions: [
          TextButton.icon(
            onPressed: (_loading || _uploading) ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('儲存'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (_uploading) _uploadBanner(),

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

                          DropdownButtonFormField<String>(
                            key: ValueKey('category_$_categoryId'),
                            value: _safeValue<String>(
                              _categoryId,
                              _categoryOptions,
                              fallback: 'uncategorized',
                            ),
                            items: _categoryOptions
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
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
                      title: '圖片（上傳到 Firebase Storage）',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 封面
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _coverCtrl,
                                  decoration: const InputDecoration(
                                    labelText: '封面圖片 URL（imageUrl）',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed: (_uploading)
                                    ? null
                                    : _pickAndUploadCover,
                                icon: const Icon(Icons.upload_file),
                                label: const Text('選圖上傳'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // 其他圖
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _imagesCtrl,
                                  maxLines: 5,
                                  decoration: const InputDecoration(
                                    labelText: '其他圖片（images）— URL 每行一個（可手動貼）',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.tonalIcon(
                                onPressed: (_uploading)
                                    ? null
                                    : _pickAndUploadMoreImages,
                                icon: const Icon(Icons.collections_outlined),
                                label: Text(kIsWeb ? '多選上傳' : '選多張'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),
                          _ImagesPreview(
                            coverUrl: coverUrl,
                            images: images,
                            onRemoveCover: coverUrl.isEmpty
                                ? null
                                : () {
                                    _coverCtrl.text = '';
                                    setState(() {});
                                  },
                            onRemoveImage: (u) => _removeImageUrl(u),
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
                      onPressed: (_loading || _uploading) ? null : _save,
                      icon: const Icon(Icons.save),
                      label: Text(_uploading ? '上傳中…' : '儲存'),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _uploadBanner() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _uploadLabel.isEmpty ? '上傳中…' : _uploadLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: 140,
              child: LinearProgressIndicator(value: _uploadProgress),
            ),
          ],
        ),
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
// Images preview (可刪除)
// ============================================================================
class _ImagesPreview extends StatelessWidget {
  final String coverUrl;
  final List<String> images;
  final VoidCallback? onRemoveCover;
  final void Function(String url)? onRemoveImage;

  const _ImagesPreview({
    required this.coverUrl,
    required this.images,
    this.onRemoveCover,
    this.onRemoveImage,
  });

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
        for (final u in urls.take(12))
          SizedBox(
            width: 160,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.network(
                      u,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.black.withValues(alpha: 0.06),
                        child: const Center(child: Text('載入失敗')),
                      ),
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: InkWell(
                    onTap: () {
                      if (u == coverUrl) {
                        onRemoveCover?.call();
                      } else {
                        onRemoveImage?.call(u);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
