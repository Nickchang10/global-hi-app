import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../router_adapter.dart';

import '../state/app_state.dart';

class ShopAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ShopAppBar({
    super.key,
    this.title,
  });

  final String? title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<AppState>().getCartItemCount();

    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      title: InkWell(
        onTap: () => context.go('/'),
        child: Text(title ?? '商店', style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      actions: [
        IconButton(
          tooltip: '搜尋',
          onPressed: () => context.go('/search'),
          icon: const Icon(Icons.search),
        ),
        IconButton(
          tooltip: '訂單',
          onPressed: () => context.go('/store_orders'),
          icon: const Icon(Icons.inventory_2_outlined),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: '購物車',
                onPressed: () => context.go('/store_cart'),
                icon: const Icon(Icons.shopping_cart_outlined),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 6,
                  top: 8,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cartCount > 99 ? '99+' : '$cartCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
