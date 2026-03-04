import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../widgets/shop_scaffold.dart';
import '../router_adapter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

enum _HomeTab { products, lotteries }

class _HomePageState extends State<HomePage> {
  _HomeTab _tab = _HomeTab.products;

  @override
  Widget build(BuildContext context) {
    final featuredLottery = lotteries.first;

    return ShopScaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FeaturedBanner(lottery: featuredLottery),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _TabButton(
                    label: '熱門商品',
                    selected: _tab == _HomeTab.products,
                    onTap: () => setState(() => _tab = _HomeTab.products),
                  ),
                  const SizedBox(width: 8),
                  _TabButton(
                    label: '熱門抽獎',
                    selected: _tab == _HomeTab.lotteries,
                    onTap: () => setState(() => _tab = _HomeTab.lotteries),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go('/search'),
                    child: const Text('查看全部 →'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, c) {
                  final width = c.maxWidth;
                  final crossAxisCount = width >= 900
                      ? 4
                      : width >= 600
                          ? 3
                          : 2;

                  if (_tab == _HomeTab.products) {
                    // Stream products from Firestore (limit to 6 items for the home grid)
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance.collection('products').limit(6).snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final docs = snap.data?.docs ?? const [];
                        final items = docs.map((d) {
                          final data = d.data();
                          final id = d.id;
                          final name = (data['name'] ?? data['title'] ?? '').toString();
                          final price = () {
                            final v = data['price'] ?? data['salePrice'] ?? data['amount'] ?? 0;
                            if (v is int) return v;
                            if (v is double) return v.round();
                            if (v is String) return int.tryParse(v.replaceAll(',', '')) ?? 0;
                            return 0;
                          }();
                          final imageUrl = (data['imageUrl'] ?? data['image'] ?? '') as String;
                          final description = (data['desc'] ?? data['description'] ?? '') as String;
                          final store = (data['storeName'] ?? data['store'] ?? '') as String;
                          final storeId = (data['storeId'] ?? '') as String;
                          final rating = (data['rating'] is num) ? (data['rating'] as num).toDouble() : 0.0;
                          final sold = (data['sold'] is num) ? (data['sold'] as num).toInt() : 0;
                          final stock = (data['stock'] is num) ? (data['stock'] as num).toInt() : 0;

                          return Product(
                            id: id,
                            name: name,
                            price: price,
                            imageUrl: imageUrl,
                            description: description,
                            store: store.isNotEmpty ? store : '商店',
                            storeId: storeId,
                            rating: rating,
                            sold: sold,
                            stock: stock,
                          );
                        }).toList(growable: false);

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) => _ProductCard(product: items[index]),
                        );
                      },
                    );
                  }

                  // Lotteries grid (unchanged)
                  final items = lotteries.skip(1).take(6).toList(growable: false);

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _LotteryCard(lottery: items[index]),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _FeaturedBanner extends StatelessWidget {
  const _FeaturedBanner({required this.lottery});

  final Lottery lottery;

  @override
  Widget build(BuildContext context) {
    final participants = '${lottery.participants} / ${lottery.maxParticipants} 人參加';

    return InkWell(
      onTap: () => context.go('/store_lottery/${lottery.id}'),
      child: Container(
        height: 320,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: 0.40,
              child: Image.network(
                lottery.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('🎁 熱門抽獎', style: TextStyle(color: Colors.black87)),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      lottery.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '獎品價值 ${formatTwd(lottery.prizeValue)}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      participants,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/product/${product.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Container(
                  color: const Color(0xFFF3F4F6),
                  child: Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatTwd(product.price),
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '已售 ${product.sold}',
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
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

class _LotteryCard extends StatelessWidget {
  const _LotteryCard({required this.lottery});

  final Lottery lottery;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/store_lottery/${lottery.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: const Color(0xFFF3F4F6),
                      child: Image.network(
                        lottery.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('🎁 抽獎', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lottery.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lottery.prize,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lottery.participants} 人參加',
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
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
