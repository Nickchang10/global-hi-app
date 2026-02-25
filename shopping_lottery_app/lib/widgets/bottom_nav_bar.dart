// lib/widgets/bottom_nav_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/badge_service.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = context.watch<BadgeService>();
    final hasNotification = badge.hasUnreadNotifications;

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (i) {
        onTap(i);
        if (i == 3) {
          // 若進入個人主頁，清空社群紅點
          badge.clearSocial();
        }
      },
      selectedItemColor: Colors.blueAccent,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      items: [
        _navItem(Icons.home, "首頁", 0),
        _navItem(Icons.people, "社群", 1, badgeCount: badge.socialCount),
        _navItem(Icons.shopping_cart, "購物車", 2, badgeCount: badge.cartCount),
        _navItem(Icons.person, "我的", 3, showDot: hasNotification),
      ],
    );
  }

  BottomNavigationBarItem _navItem(
    IconData icon,
    String label,
    int index, {
    int badgeCount = 0,
    bool showDot = false,
  }) {
    Widget iconWidget = Icon(icon);

    if (badgeCount > 0 || showDot) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon),
          Positioned(
            right: -6,
            top: -2,
            child: Container(
              padding: badgeCount > 0
                  ? const EdgeInsets.symmetric(horizontal: 5, vertical: 2)
                  : const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeCount > 0 ? badgeCount.toString() : "",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return BottomNavigationBarItem(icon: iconWidget, label: label);
  }
}
