// lib/widgets/common_appbar.dart
import 'package:flutter/material.dart';
import '../pages/cart_page.dart';
import '../pages/notification_page.dart';

PreferredSizeWidget buildCommonAppBar(BuildContext context, String title) {
  return AppBar(
    backgroundColor: Colors.blueAccent,
    centerTitle: true,
    elevation: 0,
    title: Text(
      title,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartPage()),
          );
        },
      ),
      IconButton(
        icon: const Icon(Icons.notifications_none, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          );
        },
      ),
    ],
  );
}
