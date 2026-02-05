// lib/pages/shop_page.dart
// ======================================================
// ✅ ShopPage（最終完整版｜支援未登入狀態｜已串接後台 Banner）
// ------------------------------------------------------
// - 未登入：可瀏覽商品 / 查看詳情
// - 需登入：收藏 / 進入收藏頁 / 立即購買（建立訂單->付款頁）
// - 收藏：統一使用 WishlistService（避免 key 不一致）
// - 商品：FirestoreMockService + demo fallback
// - RWD Grid（Web/平板/手機）
//
// ✅ Banner 串接（❗本版不使用 snapshots/watch，避免 Web ca9/b815）：
//    1) app_config/app_center.bannerEnabled (總開關，缺省 true)
//    2) shop_config/banners.items (Banner 列表，缺省空)
//    - 以 get() + Timer 輪詢取代 snapshots()
// ------------------------------------------------------
//
// Firestore 建議結構：
// app_config/app_center { bannerEnabled: true, ... }
// shop_config/banners { enabled:true, items:[...] }
// ======================================================

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/firestore_mock_service.dart';
import '../services/order_service.dart';
import '../services/notification_service.dart';
import '../services/wishlist_service.dart';

import 'favorites_page.dart';
import 'payment_page.dart';
import 'product_detail_page.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

enum _SortType { hot, newest, priceAsc, priceDesc }

class _ShopPageState extends State<ShopPage> {
  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _brand = Colors.orangeAccent;
  static const Color _primary = Colors.blueAccent;

  final TextEditingController _searchCtrl = TextEditingController();
  final List<String> _categories = const ['全部', '手錶', '配件', '服務', '優惠'];

  String _selectedCategory = '全部';
  _SortType _sort = _SortType.hot;

  bool _loading = true;
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _view = [];

  Timer? _searchDebounce;
  String? _buyingProductId;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // ✅ 確保 Wishlist 已載入（Web 熱重載/重整後也能拿到收藏）
    try {
      await context.read<WishlistService>().init();
    } catch (_) {}
    await _loadProducts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ======================================================
  // ✅ 未登入提示 + 導去登入
  // ======================================================
  bool _ensureLogin({String message = '請先登入以使用此功能'}) {
    if (!mounted) return false;

    final auth = context.read<AuthService>();
    if (auth.loggedIn) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      Navigator.pushNamed(context, '/login');
    });

    return false;
  }

  // ======================================================
  // ✅ 收藏（統一使用 WishlistService）— 需登入
  // ======================================================
  Future<void> _toggleFavorite(
    WishlistService ws,
    Map<String, dynamic> product,
  ) async {
    if (!_ensureLogin()) return;

    final p = _normalizeProduct(product);
    final id = p['id'].toString();
    final wasFav = ws.isInWishlist(id);

    await ws.toggleWishlist({
      'id': id,
      'name': p['name'],
      'price': p['price'],
      'image': p['image'],
      'category': p['category'],
    });

    _toast(wasFav ? '已取消收藏：${p['name']}' : '已加入收藏：${p['name']}');
  }

  // ======================================================
  // ✅ 立即購買：建立訂單 -> 付款頁（需登入）
  // ======================================================
  String _extractOrderId(dynamic order) {
    try {
      if (order is String && order.isNotEmpty) return order;
      if (order is Map) {
        final v = order['id'] ?? order['orderId'];
        if (v != null) return v.toString();
      }
      final dynamic any = order;
      try {
        final v = any.id;
        if (v != null) return v.toString();
      } catch (_) {}
      try {
        final v = any.orderId;
        if (v != null) return v.toString();
      } catch (_) {}
    } catch (_) {}
    return 'ord_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _buyNow(Map<String, dynamic> product) async {
    if (!_ensureLogin(message: '登入後才能下單與付款')) return;

    final p = _normalizeProduct(product);
    final pid = p['id'].toString();

    if (!mounted) return;
    if (_buyingProductId == pid) return;

    setState(() => _buyingProductId = pid);

    try {
      final item = <String, dynamic>{
        'productId': pid,
        'name': (p['name'] ?? '商品').toString(),
        'qty': 1,
        'price': _toDouble(p['price']),
        'image': (p['image'] ?? '').toString(),
      };

      final total = _toDouble(p['price']);

      final order = await OrderService.instance.createOrder(
        items: [item],
        total: total,
        shipping: null,
      );

      final orderId = _extractOrderId(order);

      NotificationService.instance.addNotification(
        type: 'shop',
        title: '已建立訂單',
        message: '訂單 $orderId 已建立，請完成付款以便追蹤出貨。',
        icon: Icons.shopping_bag_outlined,
      );

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            orderId: orderId,
            orderSummary: {
              'items': [
                {
                  'name': item['name'],
                  'price': item['price'],
                  'qty': item['qty'],
                  'productId': item['productId'],
                  'image': item['image'],
                }
              ],
              'total': total,
            },
            totalAmount: total,
          ),
        ),
      );
    } catch (e) {
      _toast('下單失敗：$e');
    } finally {
      if (mounted) setState(() => _buyingProductId = null);
    }
  }

  // ======================================================
  // ✅ 商品資料（FirestoreMockService + fallback demo）
  // ======================================================
  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() => _loading = true);

    await Future.delayed(const Duration(milliseconds: 180));

    List<Map<String, dynamic>> result = [];

    try {
      final svc = FirestoreMockService.instance;
      final p = svc.products;
      if (p is List) {
        result = p
            .where((e) => e is Map)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((m) => m.isNotEmpty)
            .toList();
      }
    } catch (_) {}

    if (result.isEmpty) {
      result = [
        _demo(
          'Osmile S5 健康錶',
          3990,
          '手錶',
          'https://images.unsplash.com/photo-1523275335684-37898b6baf30',
        ),
        _demo(
          'Osmile 充電座',
          490,
          '配件',
          'https://images.unsplash.com/photo-1517336714731-489689fd1ca8',
        ),
        _demo(
          '運動藍牙耳機',
          1280,
          '配件',
          'https://images.unsplash.com/photo-1518441311925-10f8f6f2d1b4',
        ),
        _demo(
          '延長保固服務',
          890,
          '服務',
          'https://images.unsplash.com/photo-1556761175-4b46a572b786',
        ),
        _demo(
          '限時優惠券包',
          199,
          '優惠',
          'https://images.unsplash.com/photo-1520975958225-230f5ff9f7d0',
        ),
      ];
    }

    final normalized = result.map(_normalizeProduct).toList();

    if (!mounted) return;
    setState(() {
      _all = normalized;
      _applyFilters();
      _loading = false;
    });
  }

  Map<String, dynamic> _demo(
    String name,
    int price,
    String category,
    String image,
  ) {
    return {
      'id': name.hashCode.toString(),
      'name': name,
      'price': price,
      'category': category,
      'image': image,
      'rating': 4.6,
      'sold': 100 + Random().nextInt(400),
      'images': [image],
      'desc': 'Osmile 精選商品，支援健康與安全守護。',
    };
  }

  Map<String, dynamic> _normalizeProduct(Map<String, dynamic> raw) {
    final id =
        (raw['id'] ?? raw['productId'] ?? raw['sku'] ?? raw.hashCode).toString();

    final name =
        (raw['name'] ?? raw['title'] ?? raw['productName'] ?? '商品').toString();

    final price = _toInt(raw['price'] ?? raw['amount'] ?? raw['salePrice'] ?? 0);

    final category = (raw['category'] ?? raw['type'] ?? '全部').toString();

    String image = (raw['image'] ?? raw['imageUrl'] ?? '').toString();
    final imagesRaw = raw['images'];
    final List<String> images = [];
    if (imagesRaw is List) {
      for (final e in imagesRaw) {
        final s = e.toString().trim();
        if (s.isNotEmpty) images.add(s);
      }
    }
    if (image.trim().isEmpty && images.isNotEmpty) image = images.first;
    if (image.trim().isEmpty) image = '';

    final rating = _toDouble(raw['rating'] ?? 4.6, fallback: 4.6);
    final sold =
        _toInt(raw['sold'] ?? raw['sales'] ?? (80 + Random().nextInt(420)));
    final desc = (raw['desc'] ?? raw['description'] ?? '').toString();

    return {
      ...raw,
      'id': id,
      'name': name,
      'price': price,
      'category': category,
      'image': image,
      'images': images.isEmpty && image.isNotEmpty ? [image] : images,
      'rating': rating,
      'sold': sold,
      'desc': desc,
    };
  }

  int _toInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().replaceAll(',', '')) ?? fallback;
  }

  double _toDouble(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '')) ?? fallback;
  }

  // ======================================================
  // ✅ 篩選 / 排序
  // ======================================================
  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();
    List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(_all);

    if (_selectedCategory != '全部') {
      list = list
          .where((p) => (p['category'] ?? '').toString() == _selectedCategory)
          .toList();
    }

    if (q.isNotEmpty) {
      list = list.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final desc = (p['desc'] ?? '').toString().toLowerCase();
        return name.contains(q) || desc.contains(q);
      }).toList();
    }

    list.sort((a, b) {
      switch (_sort) {
        case _SortType.hot:
          return _toInt(b['sold']).compareTo(_toInt(a['sold']));
        case _SortType.priceAsc:
          return _toInt(a['price']).compareTo(_toInt(b['price']));
        case _SortType.priceDesc:
          return _toInt(b['price']).compareTo(_toInt(a['price']));
        case _SortType.newest:
          return (b['id'] ?? '')
              .toString()
              .compareTo((a['id'] ?? '').toString());
      }
    });

    _view = list;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1300),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ======================================================
  // ✅ Banner：串接 App 控制中心 + Banner 列表（本版不使用 snapshots）
  // ======================================================
  Widget _buildBannerArea() {
    return _ShopBannerCarousel(
      products: _all,
      onOpenProduct: (productId) async {
        final found = _all.firstWhere(
          (p) => (p['id'] ?? '').toString() == productId,
          orElse: () => const <String, dynamic>{},
        );
        if (found.isEmpty) {
          _toast('找不到商品：$productId');
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductDetailPage(product: found)),
        );
        if (mounted) setState(() {});
      },
      onOpenRoute: (route) async {
        if (route.trim().isEmpty) return;
        if (!mounted) return;
        try {
          await Navigator.pushNamed(context, route);
        } catch (_) {
          _toast('無法前往：$route');
        }
      },
    );
  }

  // ======================================================
  // ✅ UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    final ws = context.watch<WishlistService>();
    final favCount = ws.count;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('商城', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0.3,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '我的收藏',
            onPressed: () async {
              if (!_ensureLogin(message: '登入後才能查看收藏')) return;
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesPage()),
              );
              if (mounted) setState(() {});
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.favorite_outline_rounded),
                if (favCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$favCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await context.read<WishlistService>().init();
          } catch (_) {}
          await _loadProducts();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
          children: [
            // ✅ 後台 Banner（可關閉）
            _buildBannerArea(),
            const SizedBox(height: 10),

            _buildSearchBar(),
            const SizedBox(height: 8),
            _buildCategoryChips(),
            const SizedBox(height: 8),
            _buildSortRow(),
            const SizedBox(height: 10),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_view.isEmpty)
              _buildEmpty()
            else
              _buildGrid(ws),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 46),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.search_off_rounded,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            '找不到商品',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text('請換個關鍵字或分類試試',
              style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onChanged: (_) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                if (!mounted) return;
                setState(() => _applyFilters());
              });
            },
            decoration: InputDecoration(
              hintText: '搜尋商品（名稱 / 描述）',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: () => setState(() => _applyFilters()),
          icon: const Icon(Icons.tune_rounded),
          style: IconButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _categories.map((c) {
          final sel = _selectedCategory == c;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(c),
              selected: sel,
              selectedColor: _brand,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: sel ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (_) {
                setState(() {
                  _selectedCategory = c;
                  _applyFilters();
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSortRow() {
    String label(_SortType t) {
      switch (t) {
        case _SortType.hot:
          return '熱門';
        case _SortType.newest:
          return '最新';
        case _SortType.priceAsc:
          return '價格低→高';
        case _SortType.priceDesc:
          return '價格高→低';
      }
    }

    return Row(
      children: [
        Text(
          '共 ${_view.length} 件',
          style:
              const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<_SortType>(
              value: _sort,
              items: _SortType.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(label(t)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _sort = v;
                  _applyFilters();
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(WishlistService ws) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final crossAxisCount = w >= 980 ? 4 : (w >= 680 ? 3 : 2);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _view.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.74,
          ),
          itemBuilder: (_, i) {
            final p = _view[i];
            final id = (p['id'] ?? '').toString();
            final isFav = ws.isInWishlist(id);
            final buying = _buyingProductId == id;

            return _ProductCard(
              product: p,
              isFavorite: isFav,
              isBuying: buying,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProductDetailPage(product: p)),
                );
                if (mounted) setState(() {});
              },
              onFavoriteToggle: () => _toggleFavorite(ws, p),
              onBuyNow: () => _buyNow(p),
            );
          },
        );
      },
    );
  }
}

/// ======================================================
/// ✅ Banner Widget（本檔自帶，避免你缺檔編譯失敗）
/// - 讀 app_config/app_center.bannerEnabled
/// - 讀 shop_config/banners.items
/// ✅ 本版：不用 snapshots，改 get() + Timer 輪詢，避免 Web ca9/b815
/// ======================================================
class _ShopBannerCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final Future<void> Function(String productId) onOpenProduct;
  final Future<void> Function(String route) onOpenRoute;

  const _ShopBannerCarousel({
    required this.products,
    required this.onOpenProduct,
    required this.onOpenRoute,
  });

  @override
  State<_ShopBannerCarousel> createState() => _ShopBannerCarouselState();
}

class _ShopBannerCarouselState extends State<_ShopBannerCarousel> {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _appCenterRef =>
      _db.collection('app_config').doc('app_center');

  DocumentReference<Map<String, dynamic>> get _bannerRef =>
      _db.collection('shop_config').doc('banners');

  final PageController _pc = PageController();
  Timer? _auto;
  Timer? _poll;
  int _idx = 0;

  // ✅ 由後台讀回來的狀態（全部走 get，不用 watch）
  bool _bannerEnabled = true;
  List<_BannerItem> _items = const [];
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    _loadOnce();
    // ✅ 輪詢：你要更省就拉到 15~30 秒
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _loadOnce(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _auto?.cancel();
    _pc.dispose();
    super.dispose();
  }

  bool _asBool(dynamic v, {bool fallback = true}) {
    if (v == null) return fallback;
    return v == true;
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  List<_BannerItem> _parseItems(Map<String, dynamic> doc) {
    final enabled = _asBool(doc['enabled'], fallback: true);
    if (!enabled) return const [];

    final list =
        (doc['items'] as List?) ?? (doc['banners'] as List?) ?? const [];
    final items = <_BannerItem>[];

    for (final e in list) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final item = _BannerItem.fromMap(m);
      if (!item.enabled) continue;
      items.add(item);
    }

    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
  }

  void _startAutoIfNeeded(int length) {
    _auto?.cancel();
    if (length <= 1) return;

    _auto = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_idx + 1) % length;
      _pc.animateToPage(
        next,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _loadOnce({bool silent = false}) async {
    try {
      // 1) app_center.bannerEnabled
      final appSnap = await _appCenterRef.get();
      final appData = appSnap.data() ?? const <String, dynamic>{};
      final bannerEnabled =
          _asBool(appData['bannerEnabled'], fallback: true);

      // 2) shop_config/banners.items
      final bSnap = await _bannerRef.get();
      final bData = bSnap.data() ?? const <String, dynamic>{};
      final items = _parseItems(bData);

      if (!mounted) return;

      setState(() {
        _bannerEnabled = bannerEnabled;
        _items = items;
        _loadedOnce = true;
        if (_idx >= _items.length) _idx = 0;
      });

      _startAutoIfNeeded(items.length);
    } catch (_) {
      // ✅ 讀不到 / 權限錯誤：不崩，採 fallback
      if (!mounted) return;
      if (!silent || !_loadedOnce) {
        setState(() {
          _bannerEnabled = true;
          _items = const [];
          _loadedOnce = true;
          _idx = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedOnce) {
      // 第一次 load 時不要留空白大區塊
      return const SizedBox.shrink();
    }

    if (!_bannerEnabled) return const SizedBox.shrink();
    if (_items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _pc,
              itemCount: _items.length,
              onPageChanged: (i) => setState(() => _idx = i),
              itemBuilder: (_, i) {
                final b = _items[i];
                return _BannerCard(
                  item: b,
                  onTap: () async {
                    if (b.productId.isNotEmpty) {
                      await widget.onOpenProduct(b.productId);
                      return;
                    }
                    if (b.route.isNotEmpty) {
                      await widget.onOpenRoute(b.route);
                    }
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_items.length, (i) {
            final sel = i == _idx;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: sel ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: sel ? Colors.black87 : Colors.black26,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BannerItem {
  final String id;
  final bool enabled;
  final int order;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String route;
  final String productId;

  const _BannerItem({
    required this.id,
    required this.enabled,
    required this.order,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.route,
    required this.productId,
  });

  factory _BannerItem.fromMap(Map<String, dynamic> m) {
    String s(dynamic v) => (v ?? '').toString().trim();
    int i(dynamic v, [int fb = 0]) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(s(v)) ?? fb;
    }

    return _BannerItem(
      id: s(m['id']).isEmpty ? 'b_${m.hashCode}' : s(m['id']),
      enabled: m['enabled'] != false,
      order: i(m['order'], 0),
      title: s(m['title']),
      subtitle: s(m['subtitle']),
      imageUrl: s(m['imageUrl']).isEmpty ? s(m['image']) : s(m['imageUrl']),
      route: s(m['route']),
      productId: s(m['productId']),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final _BannerItem item;
  final VoidCallback onTap;

  const _BannerCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImg = item.imageUrl.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImg)
            Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade300,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined,
                    color: Colors.grey),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade800, Colors.grey.shade500],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),

          // 漸層遮罩提升文字可讀性
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.55),
                  Colors.black.withOpacity(0.10),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.title.isNotEmpty)
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    if (item.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: const Text('立即查看',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.7),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: const Text('了解更多',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ======================================================
/// 商品卡片（含：收藏動畫 + 立即購買）
/// ======================================================
class _ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final bool isFavorite;
  final bool isBuying;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onBuyNow;

  const _ProductCard({
    required this.product,
    required this.isFavorite,
    required this.isBuying,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.onBuyNow,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _toDouble(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '')) ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final name = (p['name'] ?? '商品').toString();
    final price = (p['price'] ?? 0).toString();
    final image = (p['image'] ?? '').toString();
    final rating = _toDouble(p['rating'], fallback: 4.6);

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.35,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(14)),
                    child: image.isEmpty
                        ? Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(Icons.image_outlined,
                                color: Colors.grey),
                          )
                        : Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined,
                                  color: Colors.grey),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.18).animate(
                      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
                    ),
                    child: IconButton(
                      onPressed: () {
                        _ctrl.forward(from: 0).then((_) => _ctrl.reverse());
                        widget.onFavoriteToggle();
                      },
                      icon: Icon(
                        widget.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color:
                            widget.isFavorite ? Colors.redAccent : Colors.white,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.30),
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'NT\$$price',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.star_rounded,
                          color: Colors.orangeAccent, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onTap,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blueGrey,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('查看',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: widget.isBuying ? null : widget.onBuyNow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: widget.isBuying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('立即購買',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
