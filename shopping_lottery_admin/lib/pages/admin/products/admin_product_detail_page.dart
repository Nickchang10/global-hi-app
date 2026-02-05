// lib/pages/admin/products/admin_product_detail_page.dart
//
// ✅ AdminProductDetailPage（完整版）
// ------------------------------------------------------------
// - 商品基本資訊（名稱、價格、分類、狀態）
// - 多圖上傳 / 預覽 / 刪除
// - 商品亮點（可新增 / 編輯 / 移除）
// - 商品說明（多行文字）
// - 售後服務（icon + 文字列表）
// - 即時儲存到 Firestore
// ------------------------------------------------------------

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AdminProductDetailPage extends StatefulWidget {
  final String productId;
  const AdminProductDetailPage({super.key, required this.productId});

  @override
  State<AdminProductDetailPage> createState() => _AdminProductDetailPageState();
}

class _AdminProductDetailPageState extends State<AdminProductDetailPage> {
  final _db = FirebaseFirestore.instance;
  final _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  Object? _error;
  Map<String, dynamic>? _data;

  // 控制器
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _desc = TextEditingController();

  List<String> _images = [];
  List<String> _highlights = [];
  List<Map<String, String>> _afterService = [];
  String _category = '未分類';
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doc = await _db.collection('products').doc(widget.productId).get();
      if (!doc.exists) throw Exception('商品不存在');
      final d = doc.data()!;
      setState(() {
        _data = d;
        _name.text = d['name'] ?? '';
        _price.text = (d['price'] ?? '').toString();
        _desc.text = d['description'] ?? '';
        _images = (d['images'] as List?)?.cast<String>() ?? [];
        _highlights = (d['highlight'] as List?)?.cast<String>() ?? [];
        _afterService = (d['afterService'] as List?)
                ?.map((e) => Map<String, String>.from(e))
                .toList() ??
            [];
        _category = d['category'] ?? '未分類';
        _status = d['status'] ?? 'active';
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _db.collection('products').doc(widget.productId).update({
        'name': _name.text.trim(),
        'price': double.tryParse(_price.text) ?? 0,
        'description': _desc.text.trim(),
        'category': _category,
        'status': _status,
        'images': _images,
        'highlight': _highlights,
        'afterService': _afterService,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已儲存商品資料')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗：$e')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  // ==========================================================
  // 主要畫面
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('商品詳情')),
        body: Center(child: Text('載入失敗：$_error')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('商品詳情管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '儲存商品',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBasicInfo(),
                  const SizedBox(height: 16),
                  _buildImageSection(),
                  const SizedBox(height: 16),
                  _buildHighlightSection(),
                  const SizedBox(height: 16),
                  _buildDescriptionSection(),
                  const SizedBox(height: 16),
                  _buildAfterServiceSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // ==========================================================
  // 商品基本資訊
  // ==========================================================
  Widget _buildBasicInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('基本資訊',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '商品名稱'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _price,
              decoration: const InputDecoration(labelText: '商品價格 (NT\$)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _category,
              items: const [
                DropdownMenuItem(value: '未分類', child: Text('未分類')),
                DropdownMenuItem(value: '手錶', child: Text('手錶')),
                DropdownMenuItem(value: '配件', child: Text('配件')),
                DropdownMenuItem(value: '服務', child: Text('服務')),
                DropdownMenuItem(value: '優惠', child: Text('優惠')),
              ],
              onChanged: (v) => setState(() => _category = v ?? '未分類'),
              decoration: const InputDecoration(labelText: '商品分類'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _status,
              items: const [
                DropdownMenuItem(value: 'active', child: Text('上架中')),
                DropdownMenuItem(value: 'inactive', child: Text('下架')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'active'),
              decoration: const InputDecoration(labelText: '狀態'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // 圖片區
  // ==========================================================
  Widget _buildImageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              const Expanded(
                child: Text('商品圖片',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.add_a_photo),
                tooltip: '新增圖片',
                onPressed: _addImage,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final url in _images)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(url,
                          width: 120, height: 120, fit: BoxFit.cover),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () =>
                          setState(() => _images.remove(url)),
                    ),
                  ],
                ),
            ],
          ),
        ]),
      ),
    );
  }

  Future<void> _addImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final file = File(picked.path);
    final name = picked.name;
    final ref = FirebaseStorage.instance.ref('products/${widget.productId}/$name');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    setState(() => _images.add(url));
  }

  // ==========================================================
  // 商品亮點
  // ==========================================================
  Widget _buildHighlightSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              const Expanded(
                child: Text('商品亮點',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _addHighlight,
              ),
            ],
          ),
          for (int i = 0; i < _highlights.length; i++)
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.teal),
              title: TextField(
                controller: TextEditingController(text: _highlights[i]),
                onChanged: (v) => _highlights[i] = v,
                decoration: const InputDecoration(
                    border: InputBorder.none, hintText: '亮點內容'),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => _highlights.removeAt(i)),
              ),
            ),
        ]),
      ),
    );
  }

  void _addHighlight() {
    setState(() => _highlights.add(''));
  }

  // ==========================================================
  // 商品說明
  // ==========================================================
  Widget _buildDescriptionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('商品說明',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _desc,
            maxLines: 6,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '輸入商品詳細說明...',
            ),
          ),
        ]),
      ),
    );
  }

  // ==========================================================
  // 售後服務
  // ==========================================================
  Widget _buildAfterServiceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              const Expanded(
                child: Text('售後服務',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _addService,
              ),
            ],
          ),
          for (int i = 0; i < _afterService.length; i++)
            ListTile(
              leading: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => _afterService.removeAt(i)),
              ),
              title: TextField(
                controller:
                    TextEditingController(text: _afterService[i]['text'] ?? ''),
                onChanged: (v) => _afterService[i]['text'] = v,
                decoration: const InputDecoration(
                    border: InputBorder.none, hintText: '服務內容'),
              ),
              subtitle: TextField(
                controller:
                    TextEditingController(text: _afterService[i]['icon'] ?? ''),
                onChanged: (v) => _afterService[i]['icon'] = v,
                decoration: const InputDecoration(
                    border: InputBorder.none, hintText: 'Icon 名稱（如 local_shipping）'),
              ),
            ),
        ]),
      ),
    );
  }

  void _addService() {
    setState(() => _afterService.add({'icon': '', 'text': ''}));
  }
}
