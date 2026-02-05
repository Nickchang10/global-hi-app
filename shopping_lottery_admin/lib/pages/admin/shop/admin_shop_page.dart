// lib/pages/admin/shop/admin_shop_page.dart
//
// ✅ AdminShopPage（完整版）
// ------------------------------------------------------------
// - 商品列表（即時 Firestore 同步）
// - 搜尋 / 篩選 / 標籤 / 上架下架切換
// - 支援熱門排序 / 價格排序
// - 點擊進入商品詳情編輯頁（admin_product_detail_page）
// ------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminShopPage extends StatefulWidget {
  const AdminShopPage({super.key});

  @override
  State<AdminShopPage> createState() => _AdminShopPageState();
}

class _AdminShopPageState extends State<AdminShopPage> {
  final _db = FirebaseFirestore.instance;
  final TextEditingController _search = TextEditingController();

  String _categoryFilter = '全部';
  String _sortMode = '最新';
  bool _showOnlyActive = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('商城管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '新增商品',
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.pushNamed(context, '/admin_products/edit'),
          ),
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildProductList()),
        ],
      ),
    );
  }

  // ======================================================
  // 篩選列
  // ======================================================
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade100,
      child: Column(
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜尋商品（名稱 / 描述）',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _categoryFilter,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: '全部', child: Text('全部分類')),
                    DropdownMenuItem(value: '手錶', child: Text('手錶')),
                    DropdownMenuItem(value: '配件', child: Text('配件')),
                    DropdownMenuItem(value: '服務', child: Text('服務')),
                    DropdownMenuItem(value: '優惠', child: Text('優惠')),
                  ],
                  onChanged: (v) => setState(() => _categoryFilter = v ?? '全部'),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _sortMode,
                items: const [
                  DropdownMenuItem(value: '最新', child: Text('最新上架')),
                  DropdownMenuItem(value: '熱門', child: Text('熱門排序')),
                  DropdownMenuItem(value: '價格高到低', child: Text('價格高到低')),
                  DropdownMenuItem(value: '價格低到高', child: Text('價格低到高')),
                ],
                onChanged: (v) => setState(() => _sortMode = v ?? '最新'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('僅顯示上架中'),
                selected: _showOnlyActive,
                onSelected: (v) => setState(() => _showOnlyActive = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ======================================================
  // 商品清單（即時監聽）
  // ======================================================
  Widget _buildProductList() {
    Query<Map<String, dynamic>> q = _db.collection('products');

    // 狀態篩選
    if (_showOnlyActive) q = q.where('status', isEqualTo: 'active');

    // 類別篩選
    if (_categoryFilter != '全部') q = q.where('category', isEqualTo: _categoryFilter);

    // 排序
    if (_sortMode == '最新') {
      q = q.orderBy('createdAt', descending: true);
    } else if (_sortMode == '熱門') {
      q = q.orderBy('popularity', descending: true);
    } else if (_sortMode == '價格高到低') {
      q = q.orderBy('price', descending: true);
    } else if (_sortMode == '價格低到高') {
      q = q.orderBy('price', descending: false);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text('目前無商品'));
        }

        final docs = snap.data!.docs.where((d) {
          final name = (d['name'] ?? '').toString();
          final desc = (d['description'] ?? '').toString();
          final searchText = _search.text.trim();
          return searchText.isEmpty ||
              name.contains(searchText) ||
              desc.contains(searchText);
        }).toList();

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: docs.length,
          itemBuilder: (_, i) => _buildProductTile(docs[i]),
        );
      },
    );
  }

  // ======================================================
  // 商品卡片
  // ======================================================
  Widget _buildProductTile(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final img = (d['images'] is List && d['images'].isNotEmpty) ? d['images'][0] : null;
    final name = d['name'] ?? '';
    final price = d['price'] ?? 0;
    final category = d['category'] ?? '未分類';
    final status = d['status'] ?? 'inactive';
    final isActive = status == 'active';
    final tags = (d['tags'] as List?)?.cast<String>() ?? [];

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(
          context,
          '/admin_product_detail',
          arguments: {'id': doc.id},
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: img != null
                    ? Image.network(img, width: 80, height: 80, fit: BoxFit.cover)
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('NT\$${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: -6,
                      children: [
                        Chip(
                          label: Text(category),
                          backgroundColor: Colors.blue.shade50,
                          visualDensity: VisualDensity.compact,
                        ),
                        ...tags
                            .map((t) => Chip(
                                  label: Text(t),
                                  backgroundColor: Colors.teal.shade50,
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                onChanged: (v) async {
                  await doc.reference.update({'status': v ? 'active' : 'inactive'});
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.red.shade300,
                onPressed: () => _confirmDelete(doc),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ======================================================
  // 刪除確認
  // ======================================================
  Future<void> _confirmDelete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認刪除？'),
        content: Text('確定要刪除商品「${doc['name']}」嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('刪除')),
        ],
      ),
    );

    if (ok == true) {
      await doc.reference.delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('商品已刪除')),
        );
      }
    }
  }
}
