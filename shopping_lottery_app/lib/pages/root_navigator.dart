import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/cart_service.dart';

/// ✅ RootNavigator（底部導覽｜修改後完整版）
/// ------------------------------------------------------------
/// 修正重點：
/// - 不再直接使用 cart.count（避免 undefined_getter）
/// - 改用 _cartCount(cart) 安全推導數量：
///   1) 若 CartService 有 count / itemCount / totalQuantity 取其一
///   2) 若有 items(List) 則取 items.length
///   3) 都沒有就回傳 0
///
/// ✅ 這樣不需要你先改 CartService 也能先編譯過
/// ------------------------------------------------------------
class RootNavigator extends StatefulWidget {
  const RootNavigator({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<RootNavigator> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 4);
  }

  // ✅ 安全推導購物車數量（避免直接呼叫 cart.count 編譯錯）
  int _cartCount(CartService cart) {
    final dyn = cart as dynamic;

    // 1) 常見 getter：count
    try {
      final v = dyn.count;
      if (v is int) return v;
      if (v is num) return v.toInt();
    } catch (_) {}

    // 2) 常見 getter：itemCount
    try {
      final v = dyn.itemCount;
      if (v is int) return v;
      if (v is num) return v.toInt();
    } catch (_) {}

    // 3) 常見 getter：totalQuantity
    try {
      final v = dyn.totalQuantity;
      if (v is int) return v;
      if (v is num) return v.toInt();
    } catch (_) {}

    // 4) 常見欄位：items(List)
    try {
      final v = dyn.items;
      if (v is List) return v.length;
    } catch (_) {}

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final cartCount = _cartCount(cart);

    final tabs = <Widget>[
      _placeholder('首頁（Home）'),
      _placeholder('商城（Shop）'),
      _placeholder('獎勵中心（Rewards）'),
      _placeholder('購物車（Cart）'),
      _placeholder('我的（Me）'),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: '首頁',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            label: '商城',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.redeem_outlined),
            label: '獎勵',
          ),
          BottomNavigationBarItem(
            icon: _cartBadgeIcon(cartCount),
            label: '購物車',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: '我的',
          ),
        ],
      ),
    );
  }

  Widget _cartBadgeIcon(int count) {
    if (count <= 0) return const Icon(Icons.shopping_cart_outlined);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.shopping_cart_outlined),
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(String title) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
