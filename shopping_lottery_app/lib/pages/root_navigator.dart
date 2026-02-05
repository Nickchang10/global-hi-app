// lib/pages/root_navigator.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/cart_service.dart';
import '../services/notification_service.dart';

// 頁面
import 'home_page.dart';
import 'cart_page.dart';
import 'lottery_page.dart';
import 'live/live_list_page.dart';
import 'social_page.dart';
import 'profile_page.dart';

// 如果你有 FloatingChatBot 可一併顯示（非必要）
import '../widgets/floating_chatbot.dart';

class RootNavigator extends StatefulWidget {
  const RootNavigator({super.key});

  @override
  State<RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<RootNavigator> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    CartPage(),
    LotteryPage(),
    LiveListPage(),
    SocialPage(),
    ProfilePage(),
  ];

  final List<String> _titles = ['首頁', '購物車', '抽獎', '直播', '社群', '我的'];

  void _onTap(int idx) => setState(() => _currentIndex = idx);

  Widget _badgeIcon(IconData icon, int count) {
    if (count <= 0) return Icon(icon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white, width: 1.5)),
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartService>().count;
    final notifCount = context.watch<NotificationService>().unreadCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          // 搜尋快捷
          IconButton(
            tooltip: '搜尋',
            icon: const Icon(Icons.search),
            onPressed: () {
              // 可跳到搜尋頁或 showSearch...
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('搜尋（示範）')));
            },
          ),
          // 通知（顯示未讀數）
          IconButton(
            tooltip: '通知',
            icon: _badgeIcon(Icons.notifications, notifCount),
            onPressed: () {
              // 可跳到通知頁（若你已做）
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('進入通知中心（示範）')));
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _pages),
          // 如果你已經有 FloatingChatBot，可以把這一行打開（或改成你自己的 widget）
          // const FloatingChatBot(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey[600],
        showUnselectedLabels: true,
        onTap: _onTap,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: '首頁'),
          BottomNavigationBarItem(icon: _badgeIcon(Icons.shopping_cart, cartCount), label: '購物車'),
          const BottomNavigationBarItem(icon: Icon(Icons.casino), label: '抽獎'),
          const BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: '直播'),
          const BottomNavigationBarItem(icon: Icon(Icons.people), label: '社群'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
      // 預留一個浮動按鈕給客服或快速加購
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 例如打開智慧客服或快速下單
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Osmile 智慧客服（示範）')));
        },
        child: const Icon(Icons.headset_mic),
      ),
    );
  }
}
