// lib/pages/favorites_page.dart
// =======================================================
// ✅ FavoritesPage - 我的收藏（Wishlist）完整版（最終優化版）
// =======================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/cart_service.dart';
import '../services/firestore_mock_service.dart';
import '../services/wishlist_service.dart';
import 'product_detail_page.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistService>();
    final cart = context.watch<CartService>();

    final items = wishlist.toProductList(); // ✅ 使用標準化輸出
    final cartCount = _cartCount(cart);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text(
          '我的收藏',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.8,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              tooltip: '清空收藏',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('清空收藏', style: TextStyle(fontWeight: FontWeight.bold)),
                    content: const Text('確定要移除全部收藏商品嗎？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        child: const Text('清空'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await wishlist.clearAll();
                  _toast(context, '已清空收藏');
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: items.isEmpty
            ? _buildEmptyView(context)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final p = items[i];
                  final id = (p['id'] ?? '').toString();
                  final name = (p['name'] ?? '商品').toString();
                  final price = (p['price'] is num)
                      ? (p['price'] as num).toDouble()
                      : double.tryParse('${p['price']}') ?? 0.0;
                  final image = (p['image'] ?? '').toString();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  color: Colors.grey.shade100,
                                  child: image.isEmpty
                                      ? const Icon(Icons.image_outlined, color: Colors.grey)
                                      : Image.network(
                                          image,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.grey,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'NT\$${price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Colors.orangeAccent,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: '移除收藏',
                                onPressed: () async {
                                  await wishlist.removeFromWishlist(id);
                                  _toast(context, '已移除收藏');
                                },
                                icon: const Icon(Icons.favorite, color: Colors.redAccent),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final detail = FirestoreMockService.instance
                                            .fetchProductById(id) ??
                                        p;
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ProductDetailPage(product: detail),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.blueGrey,
                                    side: BorderSide(color: Colors.grey.shade300),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    '查看',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _addToCart(context, p),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    '加入購物車',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      bottomNavigationBar: cartCount <= 0
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '購物車：$cartCount 件',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/cart'),
                      icon: const Icon(Icons.shopping_cart_checkout),
                      label: const Text('查看購物車'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // =======================================================
  // ✅ 空收藏畫面
  // =======================================================
  Widget _buildEmptyView(BuildContext context) {
    return Center(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.favorite_border, size: 100, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              '尚未收藏任何商品',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '在商品頁面點擊「愛心」即可加入收藏。',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          const SizedBox(height: 26),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/shop'),
              icon: const Icon(Icons.storefront),
              label: const Text('去逛逛'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =======================================================
  // ✅ 加入購物車
  // =======================================================
  void _addToCart(BuildContext context, Map<String, dynamic> p) async {
    final dynamic cart = context.read<CartService>();
    final id = (p['id'] ?? '').toString();
    final name = (p['name'] ?? '商品').toString();
    final price = double.tryParse('${p['price']}') ?? 0.0;
    final image = (p['image'] ?? '').toString();

    try {
      await cart.addItem({
        'id': id,
        'productId': id,
        'name': name,
        'price': price,
        'qty': 1,
        'image': image,
      });
      _toast(context, '已加入購物車：$name');
    } catch (_) {
      _toast(context, '加入購物車失敗');
    }
  }

  // =======================================================
  // ✅ SnackBar 通知
  // =======================================================
  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1300),
      ),
    );
  }

  // =======================================================
  // ✅ 計算購物車數量
  // =======================================================
  int _cartCount(dynamic cart) {
    try {
      final v = cart.totalCount;
      if (v is int) return v;
    } catch (_) {}
    try {
      final items = cart.items;
      if (items is List) {
        int sum = 0;
        for (final it in items) {
          if (it == null) continue;
          final dynamic any = it;
          try {
            final q = any.qty;
            if (q is int) sum += q;
            else sum += 1;
          } catch (_) {
            sum += 1;
          }
        }
        return sum;
      }
    } catch (_) {}
    return 0;
  }
}
