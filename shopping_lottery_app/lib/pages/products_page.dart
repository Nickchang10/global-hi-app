// lib/pages/product_detail_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProductDetailPage extends StatelessWidget {
  final Map<String, dynamic>? product;
  final String? productId;

  const ProductDetailPage({super.key, this.product, this.productId})
    : assert(
        product != null || productId != null,
        'product 或 productId 至少要有一個',
      );

  String _s(dynamic v, [String fb = '']) => (v ?? fb).toString();
  num _num(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    if (product != null) {
      return _buildContent(context, product!);
    }

    final ref = FirebaseFirestore.instance
        .collection('products')
        .doc(productId);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('商品詳情')),
            body: Center(child: Text('讀取失敗：${snap.error}')),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snap.data!.data();
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('商品詳情')),
            body: const Center(child: Text('商品不存在或已刪除')),
          );
        }
        final p = <String, dynamic>{'id': snap.data!.id, ...data};
        return _buildContent(context, p);
      },
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> p) {
    final name = _s(p['name'], '未命名商品');
    final price = _num(p['price']).toInt();
    final seller = _s(p['seller']);
    final image = _s(p['image']);

    return Scaffold(
      appBar: AppBar(title: const Text('商品詳情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 220,
              color: Colors.grey.shade200,
              child: image.startsWith('http')
                  ? Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image_not_supported),
                    )
                  : Image.asset(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image_not_supported),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'NT\$$price',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          if (seller.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('商家：$seller', style: const TextStyle(color: Colors.black54)),
          ],
          const SizedBox(height: 10),
          Text(
            'ID：${_s(p['id'])}',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
