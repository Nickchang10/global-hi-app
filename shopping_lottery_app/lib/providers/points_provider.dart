import 'package:flutter/material.dart';

/// 💎 管理使用者積分與每日任務
class PointsProvider extends ChangeNotifier {
  int _points = 0;
  bool _signedInToday = false;
  DateTime? _lastSignInDate;

  int get points => _points;
  bool get signedInToday => _signedInToday;

  /// 🔹 增加積分
  void addPoints(int value) {
    _points += value;
    notifyListeners();
  }

  /// 🔹 扣除積分（用於兌換商品）
  bool redeemPoints(int cost) {
    if (_points >= cost) {
      _points -= cost;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// 🔹 每日簽到
  void dailySignIn() {
    final today = DateTime.now();
    if (_lastSignInDate == null ||
        !_isSameDay(today, _lastSignInDate!)) {
      _points += 10;
      _signedInToday = true;
      _lastSignInDate = today;
      notifyListeners();
    }
  }

  /// 🔹 分享商品任務
  void shareProduct() {
    _points += 5;
    notifyListeners();
  }

  /// 🔹 留言互動任務
  void commentAction() {
    _points += 3;
    notifyListeners();
  }

  /// 🔹 重置簽到（午夜自動重置）
  void resetDailySignIn() {
    final today = DateTime.now();
    if (_lastSignInDate == null || !_isSameDay(today, _lastSignInDate!)) {
      _signedInToday = false;
      notifyListeners();
    }
  }

  /// 🔹 判斷日期是否為同一天
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 🔹 重置所有積分（管理用）
  void resetAll() {
    _points = 0;
    _signedInToday = false;
    _lastSignInDate = null;
    notifyListeners();
  }
}
