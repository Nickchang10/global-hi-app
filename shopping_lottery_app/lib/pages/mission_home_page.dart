import 'package:flutter/material.dart';

// ✅ 子頁面匯入
import 'package:osmile_shopping_app/pages/mission_center_page.dart';
import 'package:osmile_shopping_app/pages/mission_history_page.dart';
import 'package:osmile_shopping_app/pages/mission_dashboard_page.dart';

/// 🎯 MissionHomePage（任務系統總頁）
///
/// 功能：
/// ✅ 整合任務中心、任務紀錄、任務統計儀表板
/// ✅ 使用 BottomNavigationBar 分頁切換
/// ✅ 每頁自動保持狀態（IndexedStack）
/// ✅ 與任務通知 MissionNotifyService 自動連動
class MissionHomePage extends StatefulWidget {
  const MissionHomePage({super.key});

  @override
  State<MissionHomePage> createState() => _MissionHomePageState();
}

class _MissionHomePageState extends State<MissionHomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    MissionCenterPage(),
    MissionHistoryPage(),
    MissionDashboardPage(),
  ];

  final List<String> _titles = [
    "🎯 任務中心",
    "📜 任務紀錄",
    "📊 任務儀表板",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.flag_circle_outlined),
            label: "任務",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: "紀錄",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: "統計",
          ),
        ],
      ),
    );
  }
}
