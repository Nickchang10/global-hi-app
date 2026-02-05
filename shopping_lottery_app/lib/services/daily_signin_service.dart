import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_mock_service.dart';
import 'level_service.dart';

/// 🔥 簽到 + 連續登入獎勵服務
class DailySignInService extends ChangeNotifier {
  static final DailySignInService _instance = DailySignInService._internal();
  static DailySignInService get instance => _instance;
  DailySignInService._internal();

  final firestore = FirestoreMockService.instance;
  final level = LevelService.instance;

  bool _hasSignedInToday = false;
  int _streak = 0;
  DateTime? _lastSignIn;

  bool get hasSignedInToday => _hasSignedInToday;
  int get streak => _streak;

  /// 初始化：讀取紀錄
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _streak = prefs.getInt("signin_streak") ?? 0;
    final last = prefs.getString("signin_last");

    if (last != null) {
      _lastSignIn = DateTime.tryParse(last);
      _hasSignedInToday = _isSameDay(_lastSignIn!, DateTime.now());
      if (!_isSameDay(_lastSignIn!, DateTime.now()) &&
          !_isYesterday(_lastSignIn!)) {
        // 若中斷超過一天，歸零
        _streak = 0;
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// 🔔 簽到功能
  Future<void> signInToday() async {
    if (_hasSignedInToday) return;

    _streak++;
    _hasSignedInToday = true;
    _lastSignIn = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("signin_streak", _streak);
    await prefs.setString("signin_last", _lastSignIn!.toIso8601String());

    // 🎁 計算加乘獎勵（例如連續越久 XP 越多）
    int xpReward = 20 + (_streak * 5);
    await level.addXP(xpReward);

    firestore.addNotification(
      title: "🔥 簽到成功！",
      message: "連續簽到 $_streak 天，獲得 $xpReward XP！",
    );

    notifyListeners();
  }
}
