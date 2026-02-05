// lib/pages/product_list_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/wishlist_service.dart';
import '../services/firestore_mock_service.dart';
import 'product_detail_page.dart';

// ======================================================
// ✅ ProductListPage（商品清單頁 - 收藏連動版）
// - 使用 WishlistService 控制收藏狀態
// - 與 ShopPage、FavoritesPage 同步資料
// ======================================================
class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _brand = Colors.orangeAccent;
  static const Color _primary = Colors.blueAccent;

  final WishlistService _wishlist = WishlistService.instance;

  bool _loading = true;
  List<Map<String, dynamic>> _products = [];
  Set<String> _favorites = {};
  Timer? _reloadTimer;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await _loadWishlist();
    await _loadProducts();
    setState(() => _loading = false);
  }

  Future<void> _loadWishlist() async {
    final ids = await _wishlist.getWishlistIds();
    if (mounted) setState(() => _favorites = ids.toSet());
  }

  Future<void> _loadProducts() async {
    await Future.delayed(const Duration(milliseconds: 250));
    final svc = FirestoreMockService.instance;
    List<Map<String, dynamic>> list = [];

    try {
      final data = svc.products;
      if (data is List) {
        list = data.map((e) {
          if (e is Map) return Map<String, dynamic>.from(e);
          return <String, dynamic>{};
        }).toList();
      }
    } catch (_) {}

    if (list.isEmpty) {
      list = [
        _demo('Osmile S5 健康錶', 3990,
            'https://images.unsplash.com/photo-1523275335684-37898b6baf30'),
        _demo('Osmile 兒童守護錶', 2990,
            'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f'),
        _demo('Osmile 充電底座', 490,
            'https://images.unsplash.com/photo-1517336714731-489689fd1ca8'),
        _demo('Osmile Sport Plus', 5990,
            'https://images.unsplash.com/photo-1503342217505-b0a15ec3261c'),
      ];
    }

    if (!mounted) return;
    setState(() => _products = list);
  }

  Map<String, dynamic> _demo(String name, int price, String image) {
    return {
      'id': name.hashCode.toString(),
      'name': name,
      'price': price,
      'image': image,
      'rating': 4.6,
      'sold': 80 + Random().nextInt(420),
    };
  }

  Future<void> _toggleFavorite(Map<String, dynamic> p) async {
    final id = p["id"].toString();
    final isFav = _favorites.contains(id);

    if (isFav) {
      await _wishlist.removeFromWishlist(id);
      setState(() => _favorites.remove(id));
      _showSnack('已取消收藏：${p["name"]}');
    } else {
      await _wishlist.addToWishlist(p);
      setState(() => _favorites.add(id));
      _showSnack('已加入收藏：${p["name"]}');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    super.dispose();
  }

  // ======================================================
  // UI 主體
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('商品列表', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0.4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重新整理',
            onPressed: _loadAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _products.isEmpty
                ? _buildEmpty()
                : GridView.builder(
                    padding: const EdgeInsets.all(14),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (_, i) {
                      final p = _products[i];
                      final id = p["id"].toString();
                      final isFav = _favorites.contains(id);
                      return _ProductCard(
                        product: p,
                        isFavorite: isFav,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailPage(product: p),
                            ),
                          );
                          _loadWishlist();
                        },
                        onFavoriteToggle: () => _toggleFavorite(p),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              color: Colors.grey.shade400, size: 64),
          const SizedBox(height: 10),
          const Text('目前沒有商品',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }
}

// ======================================================
// 商品卡片（支援收藏）
// ======================================================
class _ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const _ProductCard({
    required this.product,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.9,
      upperBound: 1.1,
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final name = (p["name"] ?? "商品").toString();
    final price = (p["price"] ?? 0).toString();
    final image = (p["image"] ?? "").toString();
    final rating = (p["rating"] ?? 4.6).toString();

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.2,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.network(
                      image.isEmpty
                          ? "https://picsum.photos/seed/$name/800/800"
                          : image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image_outlined,
                            color: Colors.grey, size: 40),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: ScaleTransition(
                    scale: Tween(begin: 1.0, end: 1.2).animate(_anim),
                    child: IconButton(
                      onPressed: () {
                        _anim.forward(from: 0.9).then((_) => _anim.reverse());
                        widget.onFavoriteToggle();
                      },
                      icon: Icon(
                        widget.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: widget.isFavorite
                            ? Colors.redAccent
                            : Colors.white,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black26,
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                "NT\$$price",
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.orangeAccent,
                    fontSize: 14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: Colors.orangeAccent, size: 14),
                  const SizedBox(width: 3),
                  Text(rating, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
