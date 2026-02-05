import 'package:flutter/material.dart';
import 'products_page.dart';
import 'categories_page.dart';
import 'announcements_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedIndex = 0;
  final List<String> menu = ['商品管理', '商品分類', '公告管理'];

  final List<Widget> pages = [
    ProductsPage(),
    CategoriesPage(),
    AnnouncementsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Osmile 後台管理系統')),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => setState(() => selectedIndex = index),
            destinations: menu.map((e) => NavigationRailDestination(
              icon: const Icon(Icons.circle),
              label: Text(e),
            )).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: pages[selectedIndex]),
        ],
      ),
    );
  }
}
