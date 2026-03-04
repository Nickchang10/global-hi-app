import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../widgets/shop_scaffold.dart';
import '../router_adapter.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

enum _SearchTab { products, lotteries }

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  _SearchTab _tab = _SearchTab.products;

  @override
  void initState() {
    super.initState();
    // Auto focus: handled by autofocus on TextField.
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _controller.text.trim().toLowerCase();
    // lotteries remain from mock data
    final filteredLotteries = lotteries.where((l) => l.name.toLowerCase().contains(q)).toList();

    // products from Firestore will be computed inside widget
    Widget productGrid() {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? const [];
          final list = docs.map((d) {
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

            return Product(
              id: id,
              name: name,
              price: price,
              imageUrl: imageUrl,
              description: '',
              store: (data['storeName'] ?? data['store'] ?? '').toString(),
              storeId: (data['storeId'] ?? '').toString(),
              rating: (data['rating'] is num) ? (data['rating'] as num).toDouble() : 0.0,
              sold: (data['sold'] is num) ? (data['sold'] as num).toInt() : 0,
              stock: (data['stock'] is num) ? (data['stock'] as num).toInt() : 0,
            );
          }).where((p) => p.name.toLowerCase().contains(q)).toList(growable: false);

          if (list.isEmpty) {
            return const Center(child: Text('沒有找到相關結果', style: TextStyle(color: Colors.black54)));
          }
          return LayoutBuilder(
            builder: (context, c) {
              final width = c.maxWidth;
              final crossAxisCount = width >= 900
                  ? 5
                  : width >= 700
                      ? 4
                      : 2;

              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: list.length,
                itemBuilder: (context, index) => _ProductResultCard(product: list[index]),
              );
            },
          );
        },
      );
    }

    final itemsWidget = _tab == _SearchTab.products ? productGrid() : LayoutBuilder(
              builder: (context, c) {
                final width = c.maxWidth;
                final crossAxisCount = width >= 900
                    ? 5
                    : width >= 700
                        ? 4
                        : 2;

                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: filteredLotteries.length,
                  itemBuilder: (context, index) => _LotteryResultCard(lottery: filteredLotteries[index]),
                );
              },
            );

    return ShopScaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search bar
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '搜尋商品或抽獎活動...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                suffixIcon: q.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _controller.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                _TabChip(
                  label: '商品',
                  selected: _tab == _SearchTab.products,
                  onTap: () => setState(() => _tab = _SearchTab.products),
                ),
                const SizedBox(width: 8),
                _TabChip(
                  label: '抽獎 (${filteredLotteries.length})',
                  selected: _tab == _SearchTab.lotteries,
                  onTap: () => setState(() => _tab = _SearchTab.lotteries),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Expanded(
              child: itemsWidget,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
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

class _ProductResultCard extends StatelessWidget {
  const _ProductResultCard({required this.product});

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
                child: Image.network(
                  product.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatTwd(product.price),
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
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

class _LotteryResultCard extends StatelessWidget {
  const _LotteryResultCard({required this.lottery});

  final Lottery lottery;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/lottery/${lottery.id}'),
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
                    Image.network(
                      lottery.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('🎁', style: TextStyle(fontSize: 11)),
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
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lottery.prize,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 12),
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
