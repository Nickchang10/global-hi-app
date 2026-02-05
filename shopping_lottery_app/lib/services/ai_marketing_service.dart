import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import 'notification_service.dart';

/// 🤖 AI 行銷推播服務
/// 根據使用者購買紀錄，自動推播個人化商品推薦通知。
class AIMarketingService {
  static final _db = FirebaseFirestore.instance;

  /// 🔹 啟動推薦檢查
  /// （可在登入後自動呼叫，或定期執行）
  static Future<void> checkAndRecommend() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // 1️⃣ 讀取該使用者最近的訂單資料
    final ordersSnapshot = await _db
        .collection('orders')
        .doc(uid)
        .collection('items')
        .orderBy('time', descending: true)
        .limit(5)
        .get();

    if (ordersSnapshot.docs.isEmpty) return;

    // 2️⃣ 建立簡單的「偏好類別」統計
    final Map<String, int> categoryCount = {};
    for (var doc in ordersSnapshot.docs) {
      final data = doc.data();
      final items = List<Map<String, dynamic>>.from(data["items"]);
      for (var item in items) {
        final category = item["category"] ?? "其他";
        categoryCount[category] = (categoryCount[category] ?? 0) + 1;
      }
    }

    // 3️⃣ 找出使用者最常購買的類別
    final topCategory = (categoryCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;

    // 4️⃣ 根據類別產生推薦內容
    final suggestion = _generateSuggestion(topCategory);

    // 5️⃣ 發送推薦通知
    await _pushRecommendation(uid, suggestion);
  }

  /// 🔹 產生推薦文案
  static Map<String, String> _generateSuggestion(String category) {
    switch (category) {
      case "健康手錶":
        return {
          "title": "專屬推薦 💙 健康手錶新款上市！",
          "message": "根據您的使用習慣，我們推薦最新 Osmile Watch Pro。點擊查看更多！"
        };
      case "按摩槍":
        return {
          "title": "運動後放鬆神器來了 💪",
          "message": "喜愛按摩產品的您，別錯過全新 ED1000 超靜音按摩槍優惠中！"
        };
      case "居家照護":
        return {
          "title": "家人健康守護提案 🏡",
          "message": "依據您的購買紀錄，我們推薦 Osmile Care 居家健康組。"
        };
      default:
        return {
          "title": "Osmile 精選優惠 🎁",
          "message": "為您推薦多款限時熱銷商品，立即前往了解更多！"
        };
    }
  }

  /// 🔹 寫入推薦通知（同步雲端 + 本地紅點）
  static Future<void> _pushRecommendation(
      String uid, Map<String, String> suggestion) async {
    final data = {
      "title": suggestion["title"],
      "message": suggestion["message"],
      "type": "promo",
      "target": "home",
      "unread": true,
      "time": DateTime.now(),
    };

    // ☁️ 寫入 Firestore
    await FirestoreService.saveNotification(uid, data);

    // 🔔 同步本地通知紅點
    await NotificationService.instance.addNotification(
      title: data["title"]!,
      message: data["message"]!,
      type: "promo",
      target: "home",
    );
  }
}
