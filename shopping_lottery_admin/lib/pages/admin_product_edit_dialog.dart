// lib/pages/admin_product_edit_dialog.dart
//
// ✅ AdminProductEditDialog（單檔完整版｜可編譯可用｜修正 unused_local_variable: data）
// ------------------------------------------------------------
// - Firestore: products/{productId}
// - 支援：新增/編輯商品、上傳圖片（Storage）、刪除圖片、狀態/庫存/價格等常用欄位
//
// 依賴：cloud_firestore, firebase_storage, file_picker
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class AdminProductEditDialog extends StatefulWidget {
  final String? productId; // null => create
  final Map<String, dynamic>? initialData;

  const AdminProductEditDialog({super.key, this.productId, this.initialData});

  static Future<bool?> open(
    BuildContext context, {
    String? productId,
    Map<String, dynamic>? initialData,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminProductEditDialog(
        productId: productId,
        initialData: initialData,
      ),
    );
  }

  @override
  State<AdminProductEditDialog> createState() => _AdminProductEditDialogState();
}

class _AdminProductEditDialogState extends State<AdminProductEditDialog> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final _idCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _vendorIdCtrl = TextEditingController();
  final _categoryIdCtrl = TextEditingController();

  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _active = true;
  bool _saving = false;
  bool _loading = true;

  // 圖片：url list
  final List<String> _images = [];

  bool get _isCreate =>
      (widget.productId == null || widget.productId!.trim().isEmpty);

  DocumentReference<Map<String, dynamic>> _doc(String id) =>
      _db.collection('products').doc(id);

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  int _toInt(dynamic v, {int def = 0}) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? def;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _skuCtrl.dispose();
    _vendorIdCtrl.dispose();
    _categoryIdCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      if (_isCreate) {
        final m = widget.initialData ?? <String, dynamic>{};
        _idCtrl.text = _s(m['id']);
        _titleCtrl.text = _s(m['title']);
        _subtitleCtrl.text = _s(m['subtitle']);
        _skuCtrl.text = _s(m['sku']);
        _vendorIdCtrl.text = _s(m['vendorId']);
        _categoryIdCtrl.text = _s(m['categoryId']);
        _priceCtrl.text = _toInt(m['price']).toString();
        _stockCtrl.text = _toInt(m['stock']).toString();
        _descCtrl.text = _s(m['description']);
        _active = (m['isActive'] ?? true) == true;

        final imgs = m['images'];
        if (imgs is List) {
          _images
            ..clear()
            ..addAll(imgs.map((e) => _s(e)).where((e) => e.isNotEmpty));
        }
      } else {
        final id = widget.productId!.trim();
        final snap = await _doc(id).get();
        final m = snap.data() ?? widget.initialData ?? <String, dynamic>{};

        _idCtrl.text = id;
        _titleCtrl.text = _s(m['title']);
        _subtitleCtrl.text = _s(m['subtitle']);
        _skuCtrl.text = _s(m['sku']);
        _vendorIdCtrl.text = _s(m['vendorId']);
        _categoryIdCtrl.text = _s(m['categoryId']);
        _priceCtrl.text = _toInt(m['price']).toString();
        _stockCtrl.text = _toInt(m['stock']).toString();
        _descCtrl.text = _s(m['description']);
        _active = (m['isActive'] ?? true) == true;

        final imgs = m['images'];
        if (imgs is List) {
          _images
            ..clear()
            ..addAll(imgs.map((e) => _s(e)).where((e) => e.isNotEmpty));
        } else {
          _images.clear();
        }
      }
    } catch (e) {
      _snack('載入失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _snack('圖片讀取失敗：bytes 為空');
      return;
    }

    final productId = _idCtrl.text.trim().isNotEmpty
        ? _idCtrl.text.trim()
        : (widget.productId ?? '').trim();

    if (productId.isEmpty) {
      _snack('請先填 productId（或先儲存建立商品）再上傳圖片');
      return;
    }

    setState(() => _saving = true);
    try {
      final safeName = file.name.replaceAll(RegExp(r'[^\w\.\-]+'), '_');
      final path =
          'products/$productId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final ref = _storage.ref().child(path);

      // ✅ 修正：移除未使用的 data 變數，直接使用 bytes 上傳
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/${(file.extension ?? 'png').toLowerCase()}',
        ),
      );

      final url = await ref.getDownloadURL();
      _images.add(url);

      await _doc(productId).set({
        'images': _images,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _snack('圖片已上傳');
      if (mounted) setState(() {});
    } catch (e) {
      _snack('上傳失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeImage(String url) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('移除圖片'),
        content: const Text('確定移除這張圖片？\n（會嘗試刪除 Storage 檔案）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final productId = _idCtrl.text.trim().isNotEmpty
        ? _idCtrl.text.trim()
        : (widget.productId ?? '').trim();

    setState(() => _saving = true);
    try {
      try {
        await _storage.refFromURL(url).delete();
      } catch (_) {}

      _images.remove(url);

      if (productId.isNotEmpty) {
        await _doc(productId).set({
          'images': _images,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      _snack('已移除圖片');
      if (mounted) setState(() {});
    } catch (e) {
      _snack('移除失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final id = _idCtrl.text.trim();
    if (id.isEmpty) {
      _snack('productId 不可為空');
      return;
    }

    final price = int.tryParse(_priceCtrl.text.trim()) ?? 0;
    final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;

    setState(() => _saving = true);
    try {
      final now = FieldValue.serverTimestamp();
      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'subtitle': _subtitleCtrl.text.trim(),
        'sku': _skuCtrl.text.trim(),
        'vendorId': _vendorIdCtrl.text.trim(),
        'categoryId': _categoryIdCtrl.text.trim(),
        'price': price,
        'stock': stock,
        'description': _descCtrl.text.trim(),
        'isActive': _active,
        'images': _images,
        'updatedAt': now,
        if (_isCreate) 'createdAt': now,
      };

      await _doc(id).set(payload, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AlertDialog(
        title: Text('商品編輯'),
        content: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      title: Text(_isCreate ? '新增商品' : '編輯商品：${widget.productId}'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _idCtrl,
                enabled: _isCreate,
                decoration: const InputDecoration(
                  labelText: 'productId（docId）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: '標題',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _subtitleCtrl,
                      decoration: const InputDecoration(
                        labelText: '副標題（可空）',
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
                    child: TextField(
                      controller: _skuCtrl,
                      decoration: const InputDecoration(
                        labelText: 'SKU（可空）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _vendorIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'vendorId（可空）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _categoryIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'categoryId（可空）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '價格（int）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '庫存（int）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '描述（可空）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('上架（isActive）'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),

              const Divider(height: 22),

              Row(
                children: [
                  const Text(
                    '圖片',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _saving ? null : _pickAndUploadImage,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_outlined),
                    label: Text(_saving ? '處理中...' : '上傳圖片'),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_images.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('尚無圖片'),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _images.map((url) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 120,
                              height: 120,
                              alignment: Alignment.center,
                              color: Colors.black12,
                              child: const Text('載入失敗'),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: InkWell(
                            onTap: _saving ? null : () => _removeImage(url),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
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
    );
  }
}
