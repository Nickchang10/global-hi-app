import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/notification_service.dart';

class OrderProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _orders = [];

  List<Map<String, dynamic>> get orders => List.unmodifiable(_orders);

  void addOrder({
    required List<Map<String, dynamic>> items,
    required double total,
    required String payment,
  }) {
    final orderId = DateTime.now().millisecondsSinceEpoch.toString();
    final order = {
      "id": orderId,
      "date": DateTime.now(),
      "items": items,
      "total": total,
      "payment": payment,
      "status": "待出貨",
    };

    _orders.insert(0, order);
    notifyListeners();

    // 🕒 模擬 60 秒後自動變為「已出貨」
    Timer(const Duration(seconds: 60), () {
      _updateStatus(orderId, "已出貨");
      // 🔔 通知中心推播
      NotificationService.instance.addNotification(
        title: "訂單出貨通知 🚚",
        message: "您的訂單 #$orderId 已出貨，請注意查收。",
        type: "order",
        icon: Icons.local_shipping,
      );
    });
  }

  void _updateStatus(String orderId, String newStatus) {
    final index = _orders.indexWhere((o) => o["id"] == orderId);
    if (index != -1) {
      _orders[index]["status"] = newStatus;
      notifyListeners();
    }
  }
}
