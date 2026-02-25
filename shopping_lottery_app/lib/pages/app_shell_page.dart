import 'package:flutter/material.dart';

import 'home_page.dart'; // 你自己有的話替換
import 'products/products_page.dart'; // 你自己有的話替換
import 'member_page.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomePage(), // 沒有就先換成 Placeholder
      const ProductsPage(), // 沒有就先換成 Placeholder
      const MemberPage(),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '首頁'),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            label: '商店',
          ),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '會員'),
        ],
      ),
    );
  }
}
