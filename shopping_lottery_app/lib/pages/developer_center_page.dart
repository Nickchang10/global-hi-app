// lib/pages/developer_center_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:osmile_shopping_app/pages/home_page.dart';
import 'package:osmile_shopping_app/pages/notification_debug_page.dart';
import 'package:osmile_shopping_app/pages/order_debug_page.dart';
import 'package:osmile_shopping_app/pages/lottery_debug_page.dart';

import 'package:osmile_shopping_app/services/firestore_mock_service.dart';
import 'package:osmile_shopping_app/services/cart_service.dart';
import 'package:osmile_shopping_app/services/order_service.dart';
import 'package:osmile_shopping_app/services/notification_service.dart';

/// 🧩 Osmile 開發測試中心（Developer Playground）
///
/// 功能：
/// ✅ 通知測試工具
/// ✅ 訂單模擬流程
/// ✅ 抽獎模擬中獎/失敗
/// ✅ 一鍵模擬整個購物 → 結帳 → 發通知 → 積分入帳
/// ✅ 頁面頂端顯示目前積分 + 未讀通知數
class DeveloperCenterPage extends StatelessWidget {
  const DeveloperCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.watch<FirestoreMockService>();
    final notify = context.watch<NotificationService>();
    final cart = CartService.instance;
    final order = OrderService.instance;

    final int points = firestore.userPoints;
    final int unreadCount =
        notify.notifications.where((n) => n["unread"] == true).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("🧩 開發測試中心"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: "回首頁",
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF6F7FB),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🧮 頂端狀態摘要：目前積分 + 未讀通知
          _buildStatusSummary(points, unreadCount),
          const SizedBox(height: 16),

          // 標題 Header
          _buildHeader(),
          const SizedBox(height: 16),

          // 🔔 通知測試工具
          _buildToolCard(
            context,
            icon: Icons.notifications_active,
            color: Colors.blueAccent,
            title: "🔔 通知測試工具",
            desc: "測試活動 / 訂單 / 積分 / 收藏 / 系統類通知",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationDebugPage()),
            ),
          ),

          // 📦 訂單模擬流程
          _buildToolCard(
            context,
            icon: Icons.receipt_long,
            color: Colors.green,
            title: "📦 訂單模擬流程",
            desc: "建立假訂單、手動更新狀態並觸發通知",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrderDebugPage()),
            ),
          ),

          // 🎰 抽獎模擬工具
          _buildToolCard(
            context,
            icon: Icons.casino,
            color: Colors.purple,
            title: "🎰 抽獎模擬工具",
            desc: "模擬中獎與失敗通知，測試紅點與中獎邏輯",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LotteryDebugPage()),
            ),
          ),

          // 🛒 一鍵模擬整個購物流程
          _buildToolCard(
            context,
            icon: Icons.shopping_cart_checkout,
            color: Colors.orange,
            title: "🛒 模擬購物流程",
            desc: "自動加入商品 → 結帳 → 建立訂單 → 發通知 → 積分 +30",
            onTap: () {
              final firestoreInstance = FirestoreMockService.instance;
              final notifyInstance = NotificationService.instance;

              // 取得商品
              final sampleProduct = firestoreInstance.products.isNotEmpty
                  ? firestoreInstance.products.first
                  : null;

              if (sampleProduct == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("⚠️ 沒有商品資料可供測試，請檢查 FirestoreMockService")));
                return;
              }

              // 加入購物車
              cart.clear();
              cart.add(sampleProduct);

              // 建立假訂單
              final newOrder = order.createMockOrder();

              // 加 30 積分
              firestoreInstance.addPoints(30);

              // 通知使用者
              notifyInstance.addNotification(
                title: "🛍️ 模擬購物完成",
                message: "已自動建立訂單 #${newOrder["id"]}，並獲得 30 積分！",
                type: "order",
              );

              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    "✅ 模擬購物完成：訂單 ${newOrder["id"]} 已建立，積分 +30，通知已送出"),
                duration: const Duration(seconds: 3),
              ));
            },
          ),

          const SizedBox(height: 30),
          Center(
            child: Text(
              "👨‍💻 此開發中心提供各模擬功能，\n"
              "動作將同步至通知中心與紅點顯示。",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔢 頂端狀態摘要：顯示目前積分 + 未讀通知數
  Widget _buildStatusSummary(int points, int unreadCount) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // 積分區塊
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(Icons.star, color: Colors.orange, size: 22),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "目前積分",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      "$points 分",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Container(
            width: 1,
            height: 32,
            color: Colors.grey[300],
          ),
          const SizedBox(width: 12),

          // 未讀通知區塊
          Expanded(
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(Icons.notifications_active,
                          color: Colors.blueAccent, size: 22),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: CircleAvatar(
                          radius: 8,
                          backgroundColor: Colors.red,
                          child: Text(
                            unreadCount > 9 ? "9+" : "$unreadCount",
                            style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "未讀通知",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      unreadCount == 0 ? "目前無未讀" : "$unreadCount 則未讀",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: unreadCount == 0
                            ? Colors.green
                            : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 頁面標題 Header
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: const [
          Icon(Icons.developer_mode, color: Colors.white, size: 42),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Osmile 開發測試中心\nDeveloper Playground",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  /// 共用工具卡片
  Widget _buildToolCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc, style: const TextStyle(color: Colors.black54)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
