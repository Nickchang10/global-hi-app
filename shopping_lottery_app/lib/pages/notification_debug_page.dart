// lib/pages/notification_debug_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:osmile_shopping_app/services/notification_service.dart';
import 'home_page.dart';

class NotificationDebugPage extends StatelessWidget {
  const NotificationDebugPage({super.key});

  void _send(BuildContext context,
      {required String title,
      required String message,
      required String type,
      String? target}) {
    NotificationService.instance.addNotification(
      title: title,
      message: message,
      type: type,
      target: target,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ 已送出通知：$title")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notify = context.watch<NotificationService>();
    final total = notify.notifications.length;
    final unread = notify.notifications.where((n) => n["unread"]).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("🔧 通知測試工具"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          if (notify.hasUnread)
            TextButton(
              onPressed: () => notify.markAllRead(),
              child: const Text("全部已讀", style: TextStyle(color: Colors.white)),
            )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.notifications_active, color: Colors.blue),
              title: Text("目前共有 $total 筆通知"),
              subtitle: Text("其中 $unread 筆未讀"),
            ),
          ),
          const SizedBox(height: 16),
          _buildButton(context, "🎉 活動優惠通知", Icons.campaign, Colors.orange,
              () => _send(context,
                  title: "聖誕活動開跑！",
                  message: "全館 8 折＋滿額贈 50 積分！",
                  type: "event")),
          _buildButton(context, "📦 訂單狀態更新", Icons.local_shipping, Colors.blue,
              () => _send(context,
                  title: "訂單出貨通知",
                  message: "訂單 #A001 已交由物流出貨",
                  type: "order")),
          _buildButton(context, "🏆 積分入帳通知", Icons.star, Colors.amber,
              () => _send(context,
                  title: "積分獎勵",
                  message: "完成每日任務，獲得 20 積分！",
                  type: "points")),
          _buildButton(context, "💖 收藏優惠通知", Icons.favorite, Colors.pink,
              () => _send(context,
                  title: "收藏商品降價！",
                  message: "Lumi 智慧手錶優惠中！",
                  type: "wishlist")),
          _buildButton(context, "🎰 抽獎通知", Icons.casino, Colors.purple,
              () => _send(context,
                  title: "抽獎中獎啦！",
                  message: "獲得 100 積分與折價券～",
                  type: "lottery")),
          _buildButton(context, "⚙️ 系統公告", Icons.system_update, Colors.teal,
              () => _send(context,
                  title: "維護公告",
                  message: "今晚 2:00 - 4:00 系統暫停服務",
                  type: "system")),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.home),
              label: const Text("回首頁"),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomePage()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(BuildContext context, String title, IconData icon,
      Color color, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: const Icon(Icons.send),
        onTap: onTap,
      ),
    );
  }
}
