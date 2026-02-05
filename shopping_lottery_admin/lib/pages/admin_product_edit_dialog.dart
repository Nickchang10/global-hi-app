// lib/pages/admin_product_edit_page.dart
//
// ✅ AdminProductEditPage（最終完整版｜可新增 / 編輯 / 上傳圖片 / 分類 / 即時預覽）
// ------------------------------------------------------------
// 功能：
// - 新增或編輯商品（根據 productId 判斷）
// - 圖片上傳（支援 Web + App）
// - Firestore 寫入 / 更新（含 imageUrl）
// - 分類下拉（從 Firestore 載入）
// - 即時預覽（商品圖、名稱、價格）
// - 自動刷新預覽（Controller listener）
// ------------------------------------------------------------

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart'; // ✅ 自動推測 contentType

class AdminProductEditPage extends StatefulWidget {
  final String? productId; // null → 新增模式

  const AdminProductEditPage({super.key, this.productId});

  @override
  State<AdminProductEditPage> createState() => _AdminProductEditPageState();
}

class _AdminProductEditPageState extends State<AdminProductEditPage> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String _category = '全部';
  bool _isActive = true;
  String? _imageUrl;
  bool _saving = false;

  List<String> _categories = ['全部'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _titleCtrl.addListener(() => setState(() {}));
    _priceCtrl.addListener(() => setState(() {}));
    if (widget.productId != null) {
      _loadProduct(widget.productId!);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  // ----------------------------
  // Firestore：分類與商品載入
  // ----------------------------
  Future<void> _loadCategories() async {
    try {
      final snap = await _db.collection('categories').orderBy('sort').get();
      final names = snap.docs.map((e) => (e.data()['name'] ?? '').toString()).toSet();
      setState(() {
        _categories = ['全部', ...names];
      });
    } catch (e) {
      debugPrint('分類載入失敗：$e');
    }
  }

  Future<void> _loadProduct(String id) async {
    try {
      final doc = await _db.collection('products').doc(id).get();
      if (!doc.exists) return;
      final data = doc.data()!;
      setState(() {
        _titleCtrl.text = data['title'] ?? '';
        _priceCtrl.text = (data['price'] ?? '').toString();
        _category = data['categoryId'] ?? '全部';
        _isActive = data['isActive'] ?? true;
        _imageUrl = data['imageUrl'];
      });
    } catch (e) {
      debugPrint('載入商品失敗：$e');
    }
  }

  // ----------------------------
  // 圖片上傳
  // ----------------------------
  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      final mimeType = lookupMimeType(file.name) ?? 'image/jpeg';
      final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = _storage.ref('products/$fileName');

      await ref.putData(
        bytes,
        SettableMetadata(contentType: mimeType),
      );

      final url = await ref.getDownloadURL();
      setState(() => _imageUrl = url);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('圖片已上傳成功')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('圖片上傳失敗：$e')),
      );
    }
  }

  // ----------------------------
  // Firestore 儲存商品
  // ----------------------------
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final data = {
        'title': _titleCtrl.text.trim(),
        'price': num.tryParse(_priceCtrl.text.trim()) ?? 0,
        'categoryId': _category,
        'isActive': _isActive,
        'imageUrl': _imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.productId == null) {
        await _db.collection('products').add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _db.collection('products').doc(widget.productId).update(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('商品已儲存成功')));
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  // ----------------------------
  // UI
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.productId != null;
    final title = isEdit ? '編輯商品' : '新增商品';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (!_saving)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: '儲存',
              onPressed: _save,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 預覽圖片
            if (_imageUrl != null)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _imageUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.image_outlined),
              label: const Text('選擇圖片'),
              onPressed: _saving ? null : _pickImage,
            ),
            const SizedBox(height: 20),

            // 商品名稱
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: '商品名稱',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.trim().isEmpty ? '請輸入商品名稱' : null,
            ),
            const SizedBox(height: 16),

            // 價格
            TextFormField(
              controller: _priceCtrl,
              decoration: const InputDecoration(
                labelText: '價格 (NT\$)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = num.tryParse(v ?? '');
                if (n == null || n < 0) return '請輸入有效價格';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 分類
            DropdownButtonFormField<String>(
              value: _categories.contains(_category) ? _category : '全部',
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? '全部'),
              decoration: const InputDecoration(
                labelText: '分類',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // 狀態切換
            SwitchListTile(
              title: const Text('上架狀態'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              activeColor: Colors.green,
            ),
            const Divider(height: 32),

            // 即時預覽
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('即時預覽'),
              subtitle: Text(
                '${_titleCtrl.text.isEmpty ? '(未命名)' : _titleCtrl.text} - '
                'NT\$${_priceCtrl.text.isEmpty ? 0 : _priceCtrl.text}',
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
