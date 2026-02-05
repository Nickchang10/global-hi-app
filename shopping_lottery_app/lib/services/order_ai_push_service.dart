import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import 'notification_service.dart';

/// 🤖 AI 推播整合服務
/// 監聽 Firestore 訂單變化，根據狀態自動推播通知。
class OrderAIPushService {
  static final _db = FirebaseFirestore.instance;

  /// 啟動監聽所有使用者的訂單狀態變化（登入後呼叫）
  static void startListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _db
        .collection('orders')
        .doc(uid)
        .collection('items')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final data = change.doc.data();
          if (data == null) continue;

          final status = data["status"] ?? "";
          final orderId = change.doc.id;
          final total = data["total"] ?? 0;

          // 根據狀態自動推播通知
          switch (status) {
            case "已出貨":
              _pushOrderNotification(
                uid,
                title: "您的訂單已出貨 🚚",
                message: "訂單 #$orderId 正在配送途中！",
                type: "order",
              );
              break;
            case "配送中":
              _pushOrderNotification(
                uid,
                title: "訂單配送中 📦",
                message: "您的商品正在運送途中，請留意收件。",
                type: "order",
              );
              break;
            case "已完成":
              _pushOrderNotification(
                uid,
                title: "訂單已送達 🎉",
                message: "感謝您的購買！歡迎再次選購 Osmile 商品 💙",
                type: "order",
              );
              break;
            default:
              break;
          }
        }
      }
    });
  }

  /// 發送一則訂單狀態通知
  static Future<void> _pushOrderNotification(
    String uid, {
    required String title,
    required String message,
    required String type,
  }) async {
    final data = {
      "title": title,
      "message": message,
      "type": type,
      "target": "order_history",
      "unread": true,
      "time": DateTime.now(),
    };

    // ☁️ 寫入 Firestore 通知
    await FirestoreService.saveNotification(uid, data);

    // 🔔 本地即時紅點更新
    await NotificationService.instance.addNotification(
      title: title,
      message: message,
      type: type,
      target: "order_history",
    );
  }
}
