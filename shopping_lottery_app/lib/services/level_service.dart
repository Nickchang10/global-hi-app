import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_mock_service.dart';

/// 🧩 用戶等級與 VIP 系統
class LevelService extends ChangeNotifier {
  LevelService._internal();
  static final LevelService instance = LevelService._internal();

  int _xp = 0;
  int get xp => _xp;

  int _level = 1;
  int get level => _level;

  /// VIP 階級（自動依等級切換）
  String get tier {
    if (_level >= 20) return "💎 Diamond VIP";
    if (_level >= 15) return "🏆 Platinum VIP";
    if (_level >= 10) return "🥇 Gold VIP";
    if (_level >= 5) return "🥈 Silver VIP";
    return "🟤 Bronze Member";
  }

  /// 下一級所需 XP
  int get nextLevelXP => (_level * 100) + 50;

  /// 初始化：從 SharedPreferences 載入
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _xp = prefs.getInt("user_xp") ?? 0;
    _level = prefs.getInt("user_level") ?? 1;
  }

  /// 增加 XP 並自動升級
  Future<void> addXP(int amount) async {
    _xp += amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("user_xp", _xp);

    // 檢查升級
    while (_xp >= nextLevelXP) {
      _xp -= nextLevelXP;
      _level++;
      await prefs.setInt("user_level", _level);
      _showLevelUpNotification();
    }

    notifyListeners();
  }

  void _showLevelUpNotification() {
    FirestoreMockService.instance.addNotification(
      title: "🎉 Level Up!",
      message: "恭喜您升級至 Lv.$_level （$tier）",
    );
  }
}
