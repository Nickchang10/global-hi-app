import 'dart:async';
import 'dart:math';
import 'notification_service.dart';

/// 📡 模擬 Firebase Cloud Messaging 推播引擎
class PushEmulator {
  static Timer? _timer;
  static final Random _random = Random();

  static final List<Map<String, String>> _sampleEvents = [
    {
      "title": "Osmile ED1000 降價通知",
      "message": "您關注的智慧手錶 ED1000 今日限時 NT\$2490！🔥",
      "type": "AI 推薦"
    },
    {
      "title": "訂單已出貨",
      "message": "您的訂單 #A231120 已交由黑貓宅急便配送中 🚚",
      "type": "訂單通知"
    },
    {
      "title": "系統公告",
      "message": "感謝支持 Osmile！本週維護時間：週三凌晨 1:00-3:00。",
      "type": "系統公告"
    },
  ];

  static void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 20), (timer) {
      final event = _sampleEvents[_random.nextInt(_sampleEvents.length)];
      NotificationService.instance.addNotification(
        title: event["title"]!,
        message: event["message"]!,
        type: event["type"]!,
      );
    });
  }

  static void stop() {
    _timer?.cancel();
  }
}
