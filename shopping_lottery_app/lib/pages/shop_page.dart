import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ✅ ShopPage（商城總覽｜修改後完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正重點：
/// - ✅ 移除任何 `orderSummary:` named parameter 呼叫（避免 undefined_named_parameter）
/// - ✅ 結帳改用 Navigator.pushNamed('/checkout', arguments: orderSummary)
/// - ✅ 不依賴 CartService / 其它外部 service（先讓專案編譯過）
/// - ✅ 修正 lint：withOpacity(deprecated) → withValues(alpha: ...)
/// - ✅ 修正 lint：prefer_const_declarations（final const list → const list）
///
/// Firestore 建議資料：
/// - products collection:
///   - name: String
///   - price: num
///   - imageUrl: String
///   - isActive: bool
/// ------------------------------------------------------------
class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final _fs = FirebaseFirestore.instance;

  // 簡易購物車（本頁記憶體）
  final Map<String, _CartItem> _cart = {};

  num get _total {
    num sum = 0;
    for (final it in _cart.values) {
      sum += (it.price * it.qty);
    }
    return sum;
  }

  int get _count {
    int c = 0;
    for (final it in _cart.values) {
      c += it.qty;
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('商城'),
        actions: [
          IconButton(
            tooltip: '搜尋',
            onPressed: () => _pushNamedSafe('/search'),
            icon: const Icon(Icons.search),
          ),
          Stack(
            children: [
              IconButton(
                tooltip: '購物車',
                onPressed: _openCartSheet,
                icon: const Icon(Icons.shopping_cart_outlined),
              ),
              if (_count > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$_count',
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
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _headline(),
            const SizedBox(height: 12),
            _productGrid(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _headline() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.storefront_outlined, color: Colors.blueAccent),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '精選商品',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productGrid() {
    final q = _fs
        .collection('products')
        .where('isActive', isEqualTo: true)
        .limit(50);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _cardError('商品讀取失敗：${snap.error}');
        }
        if (!snap.hasData) {
          return _cardLoading(height: 260);
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _productsFallback();
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.76,
          ),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final d = doc.data();
            final id = doc.id;
            final name = (d['name'] ?? '商品').toString();
            final imageUrl = (d['imageUrl'] ?? '').toString();
            final price = (d['price'] ?? 0);

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _pushNamedSafe('/product/$id'),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              )
                            : Container(
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
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
                          Text(
                            'NT\$ $price',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonal(
                              onPressed: () => _addToCart(
                                id: id,
                                name: name,
                                price: (price is num)
                                    ? price
                                    : num.tryParse(price.toString()) ?? 0,
                                imageUrl: imageUrl,
                              ),
                              child: const Text('加入購物車'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '共 $_count 件  •  合計 NT\$ ${_total.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _count == 0 ? null : _goCheckout,
              child: const Text('去結帳'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- cart ops ----------------

  void _addToCart({
    required String id,
    required String name,
    required num price,
    required String imageUrl,
  }) {
    setState(() {
      final existing = _cart[id];
      if (existing == null) {
        _cart[id] = _CartItem(
          id: id,
          name: name,
          price: price,
          qty: 1,
          imageUrl: imageUrl,
        );
      } else {
        _cart[id] = existing.copyWith(qty: existing.qty + 1);
      }
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已加入購物車：$name')));
  }

  void _removeOne(String id) {
    setState(() {
      final it = _cart[id];
      if (it == null) return;
      if (it.qty <= 1) {
        _cart.remove(id);
      } else {
        _cart[id] = it.copyWith(qty: it.qty - 1);
      }
    });
  }

  void _deleteItem(String id) {
    setState(() => _cart.remove(id));
  }

  void _openCartSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        final items = _cart.values.toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shopping_cart_outlined),
                    SizedBox(width: 8),
                    Text(
                      '購物車',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('購物車是空的'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final it = items[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueAccent.withValues(
                              alpha: 0.12,
                            ),
                            child: Text(
                              it.name.isNotEmpty
                                  ? it.name.substring(0, 1)
                                  : 'P',
                            ),
                          ),
                          title: Text(
                            it.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text('NT\$ ${it.price}  •  x${it.qty}'),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: '減少',
                                onPressed: () => _removeOne(it.id),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              IconButton(
                                tooltip: '刪除',
                                onPressed: () => _deleteItem(it.id),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '合計 NT\$ ${_total.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    FilledButton(
                      onPressed: items.isEmpty
                          ? null
                          : () {
                              Navigator.pop(context);
                              _goCheckout();
                            },
                      child: const Text('去結帳'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ 不再使用 orderSummary: named parameter
  Future<void> _goCheckout() async {
    final orderSummary = <String, dynamic>{
      'items': _cart.values
          .map(
            (e) => {
              'id': e.id,
              'name': e.name,
              'price': e.price,
              'qty': e.qty,
              'imageUrl': e.imageUrl,
            },
          )
          .toList(),
      'total': _total,
      'count': _count,
      'currency': 'TWD',
      'createdAt': DateTime.now().toIso8601String(),
    };

    try {
      await Navigator.of(
        context,
      ).pushNamed('/checkout', arguments: orderSummary);
    } catch (_) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('尚未註冊 /checkout 路由'),
          content: Text('已準備 orderSummary（arguments）但無法導航。\n\n$orderSummary'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _pushNamedSafe(String route) async {
    try {
      await Navigator.of(context).pushNamed(route);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('路由未註冊：$route')));
    }
  }

  // ---------------- ui helpers ----------------

  Widget _cardLoading({required double height}) {
    return SizedBox(
      height: height,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _cardError(String msg) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
      ),
    );
  }

  Widget _productsFallback() {
    // ✅ prefer_const_declarations：final + const → const
    const items = [
      {'id': 'demo1', 'name': 'Osmile Watch', 'price': 2990},
      {'id': 'demo2', 'name': '健康服務月費', 'price': 199},
      {'id': 'demo3', 'name': '錶帶配件', 'price': 390},
      {'id': 'demo4', 'name': '充電底座', 'price': 490},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '（products 尚未設定，先用 fallback）',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.76,
          ),
          itemBuilder: (_, i) {
            final it = items[i];
            final id = it['id']!.toString();
            final name = it['name']!.toString();
            final price = (it['price'] as num);

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(Icons.inventory_2_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'NT\$ $price',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: () => _addToCart(
                          id: id,
                          name: name,
                          price: price,
                          imageUrl: '',
                        ),
                        child: const Text('加入購物車'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CartItem {
  const _CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.qty,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final num price;
  final int qty;
  final String imageUrl;

  _CartItem copyWith({int? qty}) {
    return _CartItem(
      id: id,
      name: name,
      price: price,
      qty: qty ?? this.qty,
      imageUrl: imageUrl,
    );
  }
}
