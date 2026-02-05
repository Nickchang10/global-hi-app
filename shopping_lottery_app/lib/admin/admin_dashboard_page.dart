import 'package:flutter/material.dart';
import '../services/firestore_mock_service.dart';
import '../services/points_service.dart';
import '../services/notification_service.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mock = FirestoreMockService.instance;
    final points = PointsService.instance;
    final notifications = NotificationService.instance;

    final orderCount = mock.orders.length;
    final totalSales = mock.orders.fold<double>(
        0, (sum, o) => sum + (o["total"] as num).toDouble());
    final totalUsers = 1284; // 模擬用戶數
    final missionDone = points.history.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Osmile 管理後台"),
        backgroundColor: const Color(0xFF007BFF),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statCard("💰 今日銷售額", "NT\$${totalSales.toStringAsFixed(0)}"),
          _statCard("🧾 訂單數量", "$orderCount 筆"),
          _statCard("👥 活躍用戶", "$totalUsers 位"),
          _statCard("🏅 任務完成數", "$missionDone 次"),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/adminPushCenter'),
            icon: const Icon(Icons.notifications),
            label: const Text("推播中心"),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007BFF),
                foregroundColor: Colors.white),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/adminProducts'),
            icon: const Icon(Icons.inventory_2),
            label: const Text("商品管理"),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28A745),
                foregroundColor: Colors.white),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/adminMissions'),
            icon: const Icon(Icons.analytics),
            label: const Text("任務統計"),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        trailing: Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF007BFF))),
      ),
    );
  }
}
