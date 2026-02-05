// lib/pages/vendor/vendor_products_page.dart
//
// ✅ VendorProductsPage（完整最終版）
// ------------------------------------------------------------
// - 僅顯示 vendor 自己的商品
// - Firestore 即時串流
// - 搜尋 / 分類 / 排序
// - 支援商品新增 / 編輯 / 刪除
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VendorProductsPage extends StatefulWidget {
  const VendorProductsPage({super.key});

  @override
  State<VendorProductsPage> createState() => _VendorProductsPageState();
}

class _VendorProductsPageState extends State<VendorProductsPage> {
  String _search = '';
  String _sort = 'createdAt_desc';
  String? _vendorId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVendorId();
  }

  Future<void> _loadVendorId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userSnap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    _vendorId = userSnap.data()?['vendorId'];
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_vendorId == null) {
      return const Scaffold(
        body: Center(child: Text('無法取得廠商資訊')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('商品管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新增商品',
            onPressed: _showAddProductDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildSearchBar(),
          ),
        ),
      ),
      body: _buildStreamList(),
    );
  }

  // =====================================================
  // 搜尋列
  // =====================================================

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '搜尋商品名稱...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v.trim()),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort),
          tooltip: '排序方式',
          onSelected: (v) => setState(() => _sort = v),
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'createdAt_desc', child: Text('最新建立')),
            PopupMenuItem(
                value: 'createdAt_asc', child: Text('最舊建立')),
            PopupMenuItem(
                value: 'sold_desc', child: Text('銷售量最多')),
          ],
        ),
      ],
    );
  }

  // =====================================================
  // 商品串流清單
  // =====================================================

  Widget _buildStreamList() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('products')
        .where('vendorId', isEqualTo: _vendorId);

    if (_search.isNotEmpty) {
      query = query
          .where('titleLower', isGreaterThanOrEqualTo: _search.toLowerCase())
          .where('titleLower', isLessThanOrEqualTo: '${_search.toLowerCase()}\uf8ff');
    }

    if (_sort == 'createdAt_desc') {
      query = query.orderBy('createdAt', descending: true);
    } else if (_sort == 'createdAt_asc') {
      query = query.orderBy('createdAt', descending: false);
    } else if (_sort == 'sold_desc') {
      query = query.orderBy('sold', descending: true);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('讀取商品失敗'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('尚無商品'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data();
            return _buildProductCard(d, docs[i].id);
          },
        );
      },
    );
  }

  // =====================================================
  // 商品卡片
  // =====================================================

  Widget _buildProductCard(Map<String, dynamic> d, String id) {
    final moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
    final createdAt = d['createdAt'] is Timestamp
        ? (d['createdAt'] as Timestamp).toDate()
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: d['image'] != null && d['image'] != ''
            ? Image.network(d['image'], width: 60, height: 60, fit: BoxFit.cover)
            : const Icon(Icons.image_not_supported, size: 50),
        title: Text(d['title'] ?? '未命名商品',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('價格：${moneyFmt.format(d['price'] ?? 0)}'),
            Text('庫存：${d['stock'] ?? 0}  |  已售：${d['sold'] ?? 0}'),
            if (createdAt != null)
              Text('建立於：${DateFormat('yyyy/MM/dd').format(createdAt)}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _showEditProductDialog(id, d);
            if (v == 'delete') _deleteProduct(id);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('編輯')),
            PopupMenuItem(value: 'delete', child: Text('刪除')),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // 新增 / 編輯商品 Dialog
  // =====================================================

  void _showAddProductDialog() {
    _showEditProductDialog(null, {});
  }

  void _showEditProductDialog(String? productId, Map<String, dynamic> data) {
    final titleCtrl = TextEditingController(text: data['title'] ?? '');
    final priceCtrl =
        TextEditingController(text: (data['price'] ?? '').toString());
    final stockCtrl =
        TextEditingController(text: (data['stock'] ?? '').toString());
    final imageCtrl = TextEditingController(text: data['image'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(productId == null ? '新增商品' : '編輯商品'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '商品名稱')),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: '價格'), keyboardType: TextInputType.number),
              TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: '庫存'), keyboardType: TextInputType.number),
              TextField(controller: imageCtrl, decoration: const InputDecoration(labelText: '圖片網址')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;
              final price = num.tryParse(priceCtrl.text.trim()) ?? 0;
              final stock = num.tryParse(stockCtrl.text.trim()) ?? 0;

              final payload = {
                'title': title,
                'titleLower': title.toLowerCase(),
                'price': price,
                'stock': stock,
                'image': imageCtrl.text.trim(),
                'vendorId': _vendorId,
                'updatedAt': FieldValue.serverTimestamp(),
              };

              final col = FirebaseFirestore.instance.collection('products');
              if (productId == null) {
                await col.add({
                  ...payload,
                  'sold': 0,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              } else {
                await col.doc(productId).update(payload);
              }

              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // 刪除商品
  // =====================================================

  Future<void> _deleteProduct(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除商品'),
        content: const Text('確定要刪除此商品嗎？此動作無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance.collection('products').doc(id).delete();
  }
}
