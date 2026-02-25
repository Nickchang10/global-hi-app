// lib/pages/support/support_page.dart
import 'package:flutter/material.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('客服 / 功能入口')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _tile(
            context,
            '商品',
            '查看商品列表',
            Icons.storefront_outlined,
            '/products',
          ),
          _tile(context, '購物車', '查看購物車', Icons.shopping_cart_outlined, '/cart'),
          _tile(context, '結帳', '前往結帳', Icons.lock_outline, '/checkout'),
          _tile(
            context,
            '訂單',
            '查看我的訂單',
            Icons.receipt_long_outlined,
            '/orders',
          ),
          _tile(
            context,
            '通知中心',
            '查看通知',
            Icons.notifications_outlined,
            '/notifications',
          ),
          _tile(
            context,
            'SOS 求救',
            '定位 + 建立 SOS 事件',
            Icons.warning_amber_rounded,
            '/sos',
          ),
          _tile(context, '登入', '登入/匿名登入', Icons.login, '/login'),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    String title,
    String sub,
    IconData icon,
    String route,
  ) {
    return Card(
      elevation: 1,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(sub),
        onTap: () => Navigator.of(context).pushNamed(route),
      ),
    );
  }
}
