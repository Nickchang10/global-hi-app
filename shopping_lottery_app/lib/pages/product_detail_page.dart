// lib/pages/product_detail_page.dart
// =======================================================
// ✅ ProductDetailPage（商品詳情頁｜最終整合完整版）
// -------------------------------------------------------
// - 整合 CartService / NotificationService / AuthService
// - 支援：加入購物車 / 客服彈窗 / 商品亮點 / 商品說明 / 評論
// - 若未登入點「加入購物車」會自動導向 /login
// - Web 友善，無 dart:io
// =======================================================

import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final price = p['price'] ?? 0;
    final name = p['name'] ?? '商品名稱';
    final image = p['image'] ??
        'https://via.placeholder.com/400x300.png?text=Product+Image';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_outlined),
            onPressed: () => _openServiceSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(image, height: 240, fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text('NT\$${price.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          _buildHighlightCard(p),
          const SizedBox(height: 10),
          _buildDescriptionCard(p),
          const SizedBox(height: 10),
          _buildServiceCard(context),
          const SizedBox(height: 10),
          _buildReviewCard(context, p),
        ],
      ),

      // ===== 底部加入購物車列 =====
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Text('數量：', style: TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                  ),
                  Text('$_quantity', style: const TextStyle(fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _quantity++),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: const Text('加入購物車', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onPressed: () async {
                final auth = AuthService.instance;
                if (!auth.loggedIn) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('請先登入以使用購物車功能')),
                  );
                  Navigator.pushNamed(context, '/login');
                  return;
                }
                await _showCartDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================
  // 加入購物車流程
  // =======================================================
  Future<void> _showCartDialog(BuildContext context) async {
    final cart = CartService.instance;
    final p = widget.product;

    final line = {
      'id': p['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'name': p['name'] ?? '未命名商品',
      'price': p['price'] ?? 0,
      'qty': _quantity,
      'image': p['image'],
    };

    await cart.addItem(line);

    if (!mounted) return;
    NotificationService.instance.addNotification(
      type: 'cart',
      title: '已加入購物車',
      message: '${p['name']} x$_quantity',
      icon: Icons.shopping_cart_outlined,
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('成功加入購物車'),
        content: Text('商品「${p['name']}」已加入購物車！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('繼續購物'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/cart');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            child: const Text('前往購物車'),
          ),
        ],
      ),
    );
  }

  // =======================================================
  // 客服彈窗
  // =======================================================
  void _openServiceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('客服中心',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text('電話客服'),
              subtitle: const Text('0800-000-888'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
              title: const Text('LINE 官方帳號'),
              subtitle: const Text('@osmile_support'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined, color: Colors.orange),
              title: const Text('Email 客服'),
              subtitle: const Text('service@osmile.com'),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // =======================================================
  // 商品亮點卡片
  // =======================================================
  Widget _buildHighlightCard(Map<String, dynamic> p) {
    final highlights = p['highlights'] ??
        ['防水設計', '長效電池', '支援 GPS 定位', '兒童友善材質'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('商品亮點',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...highlights.map((e) => Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Colors.green, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(e.toString())),
                ],
              )),
        ],
      ),
    );
  }

  // =======================================================
  // 商品描述卡片
  // =======================================================
  Widget _buildDescriptionCard(Map<String, dynamic> p) {
    final desc = p['description'] ??
        '這是一款專為孩童與家庭設計的智慧手錶，具備定位、安全、健康監測與緊急求助功能，讓家長更安心。';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('商品說明',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(height: 1.4)),
        ],
      ),
    );
  }

  // =======================================================
  // 售後服務卡片
  // =======================================================
  Widget _buildServiceCard(BuildContext context) {
    final services = [
      {'icon': Icons.local_shipping_outlined, 'text': '免運服務'},
      {'icon': Icons.replay_circle_filled_outlined, 'text': '7 日內退換貨'},
      {'icon': Icons.shield_outlined, 'text': '1 年保固'},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('售後服務',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...services.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(s['icon'] as IconData, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text(s['text'] as String),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // =======================================================
  // 商品評論卡片
  // =======================================================
  Widget _buildReviewCard(BuildContext context, Map<String, dynamic> p) {
    final reviews = p['reviews'] ??
        [
          {'user': '王小姐', 'comment': '小孩很喜歡，功能實用', 'rating': 5},
          {'user': '李先生', 'comment': 'GPS 定位準確，家長安心', 'rating': 4},
        ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('使用者評論',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...reviews.map((r) {
            final stars = List.generate(
              5,
              (i) => Icon(
                i < (r['rating'] ?? 0)
                    ? Icons.star
                    : Icons.star_border_outlined,
                color: Colors.amber,
                size: 18,
              ),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: stars),
                  const SizedBox(height: 2),
                  Text('${r['user'] ?? '匿名'}：${r['comment'] ?? ''}'),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
