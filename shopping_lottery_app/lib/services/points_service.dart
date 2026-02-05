import 'package:flutter/material.dart';
import 'notification_service.dart';

/// 🪙 積分模擬系統
class PointsService extends ChangeNotifier {
  PointsService._internal();
  static final PointsService instance = PointsService._internal();

  int _points = 0;
  final List<Map<String, dynamic>> _history = [];

  int get points => _points;
  List<Map<String, dynamic>> get history => List.unmodifiable(_history);

  /// 增加積分
  void addPoints(int amount, String reason) {
    _points += amount;
    _history.insert(0, {
      "reason": reason,
      "amount": amount,
      "time": DateTime.now(),
    });

    NotificationService.instance.addNotification(
      title: "🎯 任務完成",
      message: "您獲得 $amount 積分：$reason",
      icon: Icons.emoji_events,
    );
    notifyListeners();
  }

  /// 扣除積分
  bool spendPoints(int amount, String item) {
    if (_points < amount) return false;
    _points -= amount;
    _history.insert(0, {
      "reason": "兌換 $item",
      "amount": -amount,
      "time": DateTime.now(),
    });

    NotificationService.instance.addNotification(
      title: "🎁 兌換成功",
      message: "您使用 $amount 積分兌換了 $item！",
      icon: Icons.card_giftcard,
    );
    notifyListeners();
    return true;
  }

  void reset() {
    _points = 0;
    _history.clear();
    notifyListeners();
  }
}
