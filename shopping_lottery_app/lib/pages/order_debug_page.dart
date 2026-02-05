// lib/pages/order_debug_page.dart

import 'package:flutter/material.dart';
import 'package:osmile_shopping_app/services/order_service.dart';
import 'package:osmile_shopping_app/services/notification_service.dart';

/// 📦 訂單模擬測試頁
/// 可建立假訂單、手動切換狀態並觸發通知
class OrderDebugPage extends StatefulWidget {
  const OrderDebugPage({super.key});

  @override
  State<OrderDebugPage> createState() => _OrderDebugPageState();
}

class _OrderDebugPageState extends State<OrderDebugPage> {
  final orderService = OrderService.instance;
  final notify = NotificationService.instance;

  @override
  Widget build(BuildContext context) {
    final orders = orderService.orders;

    return Scaffold(
      appBar: AppBar(
        title: const Text("📦 訂單測試工具"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add_box_outlined),
            label: const Text("建立假訂單"),
            onPressed: () {
              final order = orderService.createMockOrder();
              notify.addNotification(
                title: "🧾 訂單建立成功",
                message: "您的訂單 ${order["id"]} 已成立",
                type: "order",
              );
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          ...orders.map((o) => Card(
                child: ListTile(
                  title: Text("訂單 #${o["id"]}"),
                  subtitle: Text("狀態：${o["status"]}"),
                  trailing: ElevatedButton(
                    onPressed: () {
                      final newStatus = orderService.advanceStatus(o);
                      notify.addNotification(
                        title: "📦 訂單狀態更新",
                        message: "訂單 ${o["id"]} 已更新為「$newStatus」",
                        type: "order",
                      );
                      setState(() {});
                    },
                    child: const Text("更新狀態"),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
