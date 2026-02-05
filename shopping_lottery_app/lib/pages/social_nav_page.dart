// lib/pages/social_nav_page.dart

import 'package:flutter/material.dart';
import 'package:osmile_shopping_app/pages/social_page.dart';
import 'package:osmile_shopping_app/pages/search_page.dart';
import 'package:osmile_shopping_app/pages/profile_page.dart';

/// 🌐 Osmile 社群專區（底部分頁導航版）
///
/// 分頁：
/// 1️⃣ 動態牆（SocialPage）
/// 2️⃣ 搜尋（SearchPage）
/// 3️⃣ 個人（ProfilePage）
class SocialNavPage extends StatefulWidget {
  const SocialNavPage({super.key});

  @override
  State<SocialNavPage> createState() => _SocialNavPageState();
}

class _SocialNavPageState extends State<SocialNavPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    SocialPage(),
    SearchPage(),
    ProfilePage(),
  ];

  final List<String> _titles = const [
    "動態牆",
    "搜尋",
    "我的",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            label: "動態",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: "搜尋",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "我的",
          ),
        ],
      ),
    );
  }
}
