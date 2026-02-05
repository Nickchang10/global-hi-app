// lib/pages/cart_page.dart
// =====================================================
// ✅ CartPage - Osmile 購物車頁面（最終完整版｜含未登入檢查 + 直達付款頁）
// -----------------------------------------------------
// 功能：
// - 與 CartService（Provider + 永續化）完整整合
// - 加入購物車 / 刪除 / 數量增減 / 清空
// - 自動計算小計、總額
// - 前往結帳前檢查登入狀態，未登入導向 /login
// - 已登入則直接跳到 PaymentPage（略過 CheckoutPage）
// - 推薦商品展示、防 Overflow、SnackBar 提示
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import 'payment_page.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  String _fmt(double v) =>
      v % 1 == 0 ? 'NT\$${v.toInt()}' : 'NT\$${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final items = cart.items;
    final total = cart.totalPrice;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('購物車', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          if (items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              tooltip: '清空購物車',
              onPressed: () async {
                await cart.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('購物車已清空')),
                );
              },
            ),
        ],
      ),
      body: items.isEmpty
          ? _buildEmpty(context)
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final it = items[i];
                      final id = it['id'] ?? '';
                      final name = it['name'] ?? '未命名商品';
                      final price = ((it['price'] ?? 0) as num).toDouble();
                      final qty = (it['qty'] ?? 1) as int;
                      final totalItem = price * qty;
                      final image = it['image'] ?? '';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: image.isNotEmpty
                                    ? Image.network(
                                        image,
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _placeholder(),
                                      )
                                    : _placeholder(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _fmt(price),
                                      style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _qtyBtn(
                                          icon: Icons.remove_circle_outline,
                                          onTap: () async {
                                            final newQty = qty - 1;
                                            if (newQty <= 0) {
                                              cart.removeItem(id);
                                            } else {
                                              cart.updateQty(id, newQty);
                                            }
                                          },
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Text('$qty',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        _qtyBtn(
                                          icon: Icons.add_circle_outline,
                                          onTap: () async {
                                            cart.updateQty(id, qty + 1);
                                          },
                                        ),
                                        const Spacer(),
                                        Text(
                                          _fmt(totalItem),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent),
                                onPressed: () async {
                                  cart.removeItem(id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('已移除 $name')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _buildSummaryCard(total),
                _buildRecommend(context, cart),
                _buildBottomBar(context, total, cart),
              ],
            ),
    );
  }

  Widget _placeholder() => Container(
        width: 90,
        height: 90,
        color: Colors.grey.shade200,
        child:
            const Icon(Icons.image_not_supported, color: Colors.grey, size: 32),
      );

  Widget _qtyBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 22),
      ),
    );
  }

  Widget _buildSummaryCard(double total) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            _summaryRow('商品小計', _fmt(total)),
            _summaryRow('運費', total == 0 ? 'NT\$0' : '免運'),
            const Divider(),
            _summaryRow('應付總額', _fmt(total), highlight: true),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: highlight ? Colors.black : Colors.grey[700],
                      fontWeight:
                          highlight ? FontWeight.bold : FontWeight.w500))),
          Text(value,
              style: TextStyle(
                  color: highlight ? Colors.redAccent : Colors.black87,
                  fontSize: highlight ? 17 : 14,
                  fontWeight:
                      highlight ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  /// ✅ 推薦商品
  Widget _buildRecommend(BuildContext context, CartService cart) {
    final demo = [
      {
        'id': 'osmile_band',
        'name': 'Osmile 智慧手環',
        'price': 1290.0,
        'image': 'https://cdn-icons-png.flaticon.com/512/1548/1548682.png',
      },
      {
        'id': 'sos_watch',
        'name': 'SOS 求救定位錶',
        'price': 1780.0,
        'image': 'https://cdn-icons-png.flaticon.com/512/1830/1830795.png',
      },
      {
        'id': 'kid_watch',
        'name': '兒童防走失手錶',
        'price': 1590.0,
        'image': 'https://cdn-icons-png.flaticon.com/512/3208/3208720.png',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('你可能會喜歡',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: demo.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final p = demo[i];
                return _buildProductCard(context, p, cart);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
      BuildContext context, Map<String, dynamic> p, CartService cart) {
    final id = p['id'].toString();
    final name = p['name'].toString();
    final price = (p['price'] as num).toDouble();
    final image = p['image'].toString();

    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              image,
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 100,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_not_supported,
                    color: Colors.grey, size: 30),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('NT\$${price.toInt()}',
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold)),
                  SizedBox(
                    width: double.infinity,
                    height: 30,
                    child: ElevatedButton(
                      onPressed: () async {
                        await cart.addItem({
                          'id': id,
                          'name': name,
                          'price': price,
                          'qty': 1,
                          'image': image,
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$name 已加入購物車')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('加入購物車',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 底部「前往結帳」→ 登入檢查 + 直接跳 PaymentPage
  Widget _buildBottomBar(
      BuildContext context, double total, CartService cart) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('小計',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  Text(_fmt(total),
                      style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                ],
              ),
            ),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: total == 0
                      ? null
                      : () async {
                          final auth = AuthService.instance;
                          if (!auth.loggedIn) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('請先登入再結帳')),
                            );
                            Navigator.pushNamed(context, '/login');
                            return;
                          }

                          final items = cart.items;
                          final orderId =
                              'ord.${DateTime.now().millisecondsSinceEpoch}';
                          final summary = {
                            'orderId': orderId,
                            'items': items,
                            'subtotal': total,
                            'shipping': 0,
                            'discount': 0,
                            'total': total,
                          };

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentPage(
                                orderId: orderId,
                                totalAmount: total,
                                orderSummary: summary,
                              ),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('前往結帳',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 90, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('購物車是空的',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('快去挑選喜歡的商品吧！',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('返回首頁逛逛'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
