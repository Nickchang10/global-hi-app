// lib/pages/products_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/firestore_mock_service.dart';
import '../services/cart_service.dart';
import 'product_detail_page.dart';

/// ProductsPage - 商品中心（搜尋、分類、精選、熱門）
/// 改版重點：
/// - 橘色作為「交易/轉換」主色（加入購物車/結帳）
/// - 加強加入購物車可點性（從 icon 改為明顯按鈕）
/// - 分類改成 ChoiceChip（更像篩選）
/// - 增加 AppBar 購物車入口（含 badge）
class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  String _query = '';
  String _activeCat = '全部';

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _featured = [];
  bool _loading = true;

  // 分類（示範）
  final List<Map<String, dynamic>> _cats = const [
    {'icon': Icons.apps_rounded, 'label': '全部'},
    {'icon': Icons.watch, 'label': '手錶'},
    {'icon': Icons.bolt, 'label': '配件'},
    {'icon': Icons.fitness_center, 'label': '運動'},
    {'icon': Icons.headset, 'label': '3C'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final fs = Provider.of<FirestoreMockService>(context, listen: false);
      try {
        final res = await fs.fetchProducts(page: 1, limit: 24);
        if (res is List && res.isNotEmpty) {
          final list = List<Map<String, dynamic>>.from(res.map((e) {
            if (e is Map<String, dynamic>) return e;
            if (e is Map) return Map<String, dynamic>.from(e);
            return <String, dynamic>{};
          }));
          _products = list;
          _featured = list.length >= 4 ? list.sublist(0, 4) : list.take(4).toList();
        } else {
          _products = _sampleProducts();
          _featured = _products.take(4).toList();
        }
      } catch (_) {
        _products = _sampleProducts();
        _featured = _products.take(4).toList();
      }
    } catch (_) {
      _products = _sampleProducts();
      _featured = _products.take(4).toList();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _sampleProducts() {
    return [
      {'id': 'p1', 'name': 'Osmile S5 健康錶', 'price': 3990, 'image': 'https://picsum.photos/seed/1/600/400'},
      {'id': 'p2', 'name': 'Osmile 充電座', 'price': 490, 'image': 'https://picsum.photos/seed/2/600/400'},
      {'id': 'p3', 'name': '運動繃帶', 'price': 199, 'image': 'https://picsum.photos/seed/3/600/400'},
      {'id': 'p4', 'name': '藍牙耳機', 'price': 1750, 'image': 'https://picsum.photos/seed/4/600/400'},
      {'id': 'p5', 'name': '行動電源', 'price': 899, 'image': 'https://picsum.photos/seed/5/600/400'},
      {'id': 'p6', 'name': '健身鞋', 'price': 2590, 'image': 'https://picsum.photos/seed/6/600/400'},
      {'id': 'p7', 'name': '運動手環', 'price': 1290, 'image': 'https://picsum.photos/seed/7/600/400'},
      {'id': 'p8', 'name': '車載支架', 'price': 299, 'image': 'https://picsum.photos/seed/8/600/400'},
    ];
  }

  String _formatPrice(dynamic v) {
    if (v is num) return 'NT\$${v.toStringAsFixed(0)}';
    return 'NT\$${v ?? ''}';
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _query = v);
    });
  }

  Future<void> _addToCart(Map<String, dynamic> p) async {
    final cart = Provider.of<CartService>(context, listen: false);
    await cart.addItem(
      productId: p['id']?.toString() ?? p['name'],
      name: p['name'] ?? '商品',
      price: (p['price'] is num)
          ? (p['price'] as num).toDouble()
          : double.tryParse('${p['price']}') ?? 0.0,
      qty: 1,
      image: p['image'],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${p['name']} 已加入購物車'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _products;
    return _products.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      // 示範：分類=直接用關鍵字搜尋（你之後可改成真正的 category 欄位）
      return name.contains(q);
    }).toList();
  }

  // ---------------- UI 元件 ----------------
  Widget _sectionHeader(String title, {VoidCallback? onMore}) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6, bottom: 6, top: 4),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          if (onMore != null)
            TextButton(
              onPressed: onMore,
              child: const Text('查看更多', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: '搜尋商品名稱、分類…',
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        suffixIcon: (_searchCtrl.text.isEmpty)
            ? null
            : IconButton(
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {
                    _query = '';
                    _activeCat = '全部';
                  });
                },
                icon: const Icon(Icons.close),
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Image.network(
            'https://picsum.photos/seed/products_banner/1100/420',
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Container(
            height: 140,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black45, Colors.transparent],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('本週熱銷',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      SizedBox(height: 2),
                      Text('健康錶與配件限時優惠',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: () {
                    // 保持在本頁，清空搜尋即可視為「看全部」
                    setState(() {
                      _activeCat = '全部';
                      _query = '';
                      _searchCtrl.clear();
                    });
                  },
                  child: const Text('看全部', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: _cats.length,
        itemBuilder: (_, i) {
          final c = _cats[i];
          final label = c['label'] as String;
          final selected = _activeCat == label;

          return ChoiceChip(
            selected: selected,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  c['icon'] as IconData,
                  size: 16,
                  color: selected ? Colors.white : Colors.blueGrey,
                ),
                const SizedBox(width: 6),
                Text(label),
              ],
            ),
            selectedColor: Colors.blueAccent,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              fontSize: 12,
              color: selected ? Colors.white : Colors.black87,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            onSelected: (_) {
              setState(() {
                _activeCat = label;
                if (label == '全部') {
                  _query = '';
                  _searchCtrl.clear();
                } else {
                  _query = label;
                  _searchCtrl.text = label;
                  _searchCtrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: _searchCtrl.text.length),
                  );
                }
              });
            },
          );
        },
      ),
    );
  }

  Widget _productCardGridItem(Map<String, dynamic> p) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProductDetailPage(product: p)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.network(
                p['image'],
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['name'] ?? '商品',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _formatPrice(p['price']),
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: () => _addToCart(p),
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: const Text('加入', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedGrid() {
    if (_featured.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _featured.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 230,
      ),
      itemBuilder: (_, i) => _productCardGridItem(_featured[i]),
    );
  }

  Widget _buildAllGrid() {
    final list = _filtered;
    if (list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text('沒有符合的商品'),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 230,
      ),
      itemBuilder: (_, idx) => _productCardGridItem(list[idx]),
    );
  }

  Widget _buildCartAction(int cartCount) {
    return IconButton(
      onPressed: () => Navigator.pushNamed(context, '/checkout'),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.shopping_cart_outlined),
          if (cartCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$cartCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      tooltip: '購物車',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartService>().count;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('商城', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        actions: [
          _buildCartAction(cartCount),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: RefreshIndicator(
            onRefresh: _loadProducts,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  _buildBanner(),
                  const SizedBox(height: 10),
                  _buildCategories(),
                  const SizedBox(height: 12),

                  _sectionHeader('精選商品'),
                  _loading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _buildFeaturedGrid(),

                  const SizedBox(height: 14),
                  _sectionHeader('熱門商品'),
                  _loading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _buildAllGrid(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
