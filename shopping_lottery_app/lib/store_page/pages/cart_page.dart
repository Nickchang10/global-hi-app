import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/shop_scaffold.dart';
import '../router_adapter.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final cart = appState.cart;
    final total = appState.getTotalPrice();

    if (cart.isEmpty) {
      return ShopScaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.black.withOpacity(0.2)),
                const SizedBox(height: 12),
                const Text('購物車是空的', style: TextStyle(fontSize: 20, color: Colors.black54)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('開始購物'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ShopScaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('購物車', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...cart.map((item) {
                final product = item.product;
                final canMinus = item.quantity > 1;
                final canPlus = item.quantity < product.stock;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => context.go('/product/${product.id}'),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                product.imageUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: const Color(0xFFF3F4F6)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () => context.go('/product/${product.id}'),
                                  child: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(height: 6),
                                Text(formatTwd(product.price), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: const Color(0xFFE5E7EB)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            onPressed: canMinus ? () => context.read<AppState>().updateQuantity(product.id, item.quantity - 1) : null,
                                            icon: const Icon(Icons.remove, size: 18),
                                          ),
                                          SizedBox(
                                            width: 36,
                                            child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                                          ),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            onPressed: canPlus ? () => context.read<AppState>().updateQuantity(product.id, item.quantity + 1) : null,
                                            icon: const Icon(Icons.add, size: 18),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () => context.read<AppState>().removeFromCart(product.id),
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      tooltip: '移除',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatTwd(product.price * item.quantity),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('商品總計', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          Text(formatTwd(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('運費', style: TextStyle(color: Colors.black54)),
                          Text('免運', style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('總計', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          Text(formatTwd(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.red)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => context.go('/store_checkout'),
                        child: const SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: Center(child: Text('前往結帳', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
