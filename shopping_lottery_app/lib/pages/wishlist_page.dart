// lib/pages/wishlist_page.dart
// =====================================================
// ✅ WishlistPage - 收藏清單（最終完整版｜修正 ListTile leading 爆寬問題）
// -----------------------------------------------------
// 修正：不再使用 ListTile（leading 固定尺寸）避免：
// "Leading widget consumes the entire tile width" assertion
//
// 功能：
// - 顯示收藏商品（相容多種 WishlistService 資料結構）
// - 加入購物車（相容多種 CartService 方法）
// - 移除收藏 / 清空收藏
// - 空狀態 UI
// - Web 友善：不使用 dart:io / cached_network_image
//
// ✅ 修正：withOpacity(deprecated) → withValues(alpha: ...)
// =====================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/cart_service.dart';
import '../services/wishlist_service.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  static const Color _bg = Color(0xFFF4F6F9);

  String _fmtMoney(num v) => 'NT\$${v.toStringAsFixed(0)}';

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}') ?? 0.0;
  }

  int _toInt(dynamic v, {int fallback = 1}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? fallback;
  }

  // -----------------------------------------------------
  // 讀取 wishlist items：相容 items / list / wishlist / favorites 等命名差異
  List<Map<String, dynamic>> _readWishlistItems(dynamic wishlist) {
    dynamic raw;
    try {
      raw = (wishlist as dynamic).items;
    } catch (_) {
      raw = null;
    }

    raw ??= (() {
      try {
        return (wishlist as dynamic).list;
      } catch (_) {
        return null;
      }
    })();

    raw ??= (() {
      try {
        return (wishlist as dynamic).wishlist;
      } catch (_) {
        return null;
      }
    })();

    raw ??= (() {
      try {
        return (wishlist as dynamic).favorites;
      } catch (_) {
        return null;
      }
    })();

    final out = <Map<String, dynamic>>[];

    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          out.add(Map<String, dynamic>.from(e));
        } else {
          // 嘗試讀取物件屬性
          try {
            final any = e as dynamic;
            out.add({
              'id': (any.id ?? any.productId ?? any.sku ?? '').toString(),
              'name': (any.name ?? any.title ?? '商品').toString(),
              'price': _toDouble(any.price),
              'image': (any.image ?? any.imageUrl ?? '').toString(),
              'qty': _toInt(any.qty ?? 1, fallback: 1),
            });
          } catch (_) {}
        }
      }
    }

    // 正規化（確保必要欄位）
    return out.map((p) {
      final idRaw = p['id'] ?? p['productId'] ?? p['sku'];
      final id = (idRaw == null || idRaw.toString().trim().isEmpty)
          ? 'wish_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}'
          : idRaw.toString();

      final name = (p['name'] ?? p['title'] ?? '商品').toString();
      final price = _toDouble(p['price']);
      final image = (p['image'] ?? p['imageUrl'] ?? '').toString();

      return {...p, 'id': id, 'name': name, 'price': price, 'image': image};
    }).toList();
  }

  // -----------------------------------------------------
  // CartService 加入購物車：相容 addItem(map) / addToCart(map) / addItem(named)
  Future<void> _addToCartSafe(
    BuildContext context,
    Map<String, dynamic> p,
  ) async {
    final cart = context.read<CartService>();

    final line = {
      'id': (p['id'] ?? '').toString(),
      'productId': (p['id'] ?? p['productId'] ?? '').toString(),
      'name': (p['name'] ?? p['title'] ?? '商品').toString(),
      'price': _toDouble(p['price']),
      'qty': max(1, _toInt(p['qty'] ?? 1, fallback: 1)),
      'image': (p['image'] ?? p['imageUrl'] ?? '').toString(),
    };

    final dyn = cart as dynamic;

    // 1) addItem(map)
    try {
      await dyn.addItem(line);
      return;
    } catch (_) {}

    // 2) addToCart(map)
    try {
      await dyn.addToCart(line);
      return;
    } catch (_) {}

    // 3) addItem(named args)
    try {
      await dyn.addItem(
        id: line['id'],
        name: line['name'],
        price: line['price'],
        qty: line['qty'],
        image: line['image'],
      );
      return;
    } catch (_) {}

    // 4) 最後保底：如果你 CartService 是同步方法
    try {
      dyn.addItem(line);
    } catch (_) {}
  }

  // -----------------------------------------------------
  // WishlistService 移除：相容 remove(id) / removeItem(id) / removeFromWishlist(id) / toggleWishlist(p)
  Future<void> _removeWishSafe(
    BuildContext context,
    dynamic wishlist,
    Map<String, dynamic> p,
  ) async {
    final id = (p['id'] ?? '').toString();
    final dyn = wishlist as dynamic;

    Future<void> tryCall(Future<void> Function() fn) async {
      try {
        await fn();
      } catch (_) {}
    }

    await tryCall(() async => await dyn.remove(id));
    await tryCall(() async => await dyn.removeItem(id));
    await tryCall(() async => await dyn.removeFromWishlist(id));
    await tryCall(() async => await dyn.toggleWishlist(p));

    // 同步方法保底
    try {
      dyn.remove(id);
    } catch (_) {}
    try {
      dyn.removeItem(id);
    } catch (_) {}
  }

  Future<void> _clearWishSafe(dynamic wishlist) async {
    final dyn = wishlist as dynamic;

    Future<void> tryCall(Future<void> Function() fn) async {
      try {
        await fn();
      } catch (_) {}
    }

    await tryCall(() async => await dyn.clear());
    await tryCall(() async => await dyn.clearAll());
    await tryCall(() async => await dyn.reset());

    // 同步方法保底
    try {
      dyn.clear();
    } catch (_) {}
    try {
      dyn.clearAll();
    } catch (_) {}
  }

  // -----------------------------------------------------
  Widget _img(String url) {
    const double s = 74;

    if (url.trim().isEmpty) {
      return Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          size: 26,
          color: Colors.grey,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: s,
        height: s,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported_outlined,
            size: 26,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 84, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              '目前沒有收藏商品',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '去逛逛商品，把喜歡的加入收藏吧。',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text(
                '回首頁逛逛',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistService>();
    final items = _readWishlistItems(wishlist);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('收藏', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
        actions: [
          if (items.isNotEmpty)
            IconButton(
              tooltip: '清空收藏',
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              onPressed: () async {
                await _clearWishSafe(wishlist);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已清空收藏'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
        ],
      ),
      body: items.isEmpty
          ? _empty(context)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final p = items[i];
                final name = (p['name'] ?? '商品').toString();
                final price = _toDouble(p['price']);
                final image = (p['image'] ?? '').toString();

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        // ✅ withOpacity(deprecated) → withValues(alpha: ...)
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ✅ 固定尺寸 leading
                      _img(image),
                      const SizedBox(width: 12),

                      // 文字區（可壓縮）
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _fmtMoney(price),
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      // actions（固定寬度避免擠爆）
                      SizedBox(
                        width: 96,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: '加入購物車',
                              icon: const Icon(
                                Icons.add_shopping_cart,
                                color: Colors.blueAccent,
                              ),
                              onPressed: () async {
                                await _addToCartSafe(context, p);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$name 已加入購物車'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(milliseconds: 900),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              tooltip: '移除收藏',
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () async {
                                await _removeWishSafe(context, wishlist, p);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('已移除 $name'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(milliseconds: 900),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
