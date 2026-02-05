import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_mock_service.dart';
import 'level_service.dart';

/// 🎯 每日任務與寶箱系統
class MissionService extends ChangeNotifier {
  static final MissionService _instance = MissionService._internal();
  static MissionService get instance => _instance;
  MissionService._internal();

  final firestore = FirestoreMockService.instance;
  final level = LevelService.instance;

  /// 當日任務清單
  final List<Map<String, dynamic>> _missions = [
    {"id": "login", "title": "每日登入", "rewardXP": 20, "done": false},
    {"id": "lottery", "title": "參加一次抽獎", "rewardXP": 30, "done": false},
    {"id": "cart", "title": "完成一次購物", "rewardXP": 40, "done": false},
    {"id": "share", "title": "分享一次商品", "rewardXP": 25, "done": false},
  ];

  bool _chestOpened = false;
  DateTime _lastReset = DateTime.now();

  List<Map<String, dynamic>> get missions => List.unmodifiable(_missions);
  bool get chestOpened => _chestOpened;

  /// 初始化
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _chestOpened = prefs.getBool("chest_opened") ?? false;

    final lastDateStr = prefs.getString("mission_date");
    if (lastDateStr != null) {
      final lastDate = DateTime.parse(lastDateStr);
      if (!_isSameDay(lastDate, DateTime.now())) _resetDailyMissions();
    }
    for (final m in _missions) {
      m["done"] = prefs.getBool("mission_${m["id"]}") ?? false;
    }
    notifyListeners();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 完成任務
  Future<void> completeMission(String id) async {
    final mission = _missions.firstWhere((m) => m["id"] == id);
    if (mission["done"]) return;

    mission["done"] = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("mission_${id}", true);

    await level.addXP(mission["rewardXP"]);
    firestore.addNotification(
      title: "🎯 任務完成",
      message: "完成「${mission["title"]}」，獲得 ${mission["rewardXP"]} XP！",
    );

    notifyListeners();
  }

  /// 是否全部完成
  bool get allMissionsCompleted =>
      _missions.every((m) => m["done"] == true);

  /// 開啟寶箱
  Future<void> openChest() async {
    if (!allMissionsCompleted || _chestOpened) return;
    _chestOpened = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("chest_opened", true);

    await level.addXP(100);
    firestore.addNotification(
      title: "🎁 恭喜開啟寶箱！",
      message: "您額外獲得 100 XP！",
    );

    notifyListeners();
  }

  /// 重置每日任務
  Future<void> _resetDailyMissions() async {
    for (final m in _missions) {
      m["done"] = false;
    }
    _chestOpened = false;
    _lastReset = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    for (final m in _missions) {
      await prefs.remove("mission_${m["id"]}");
    }
    await prefs.setBool("chest_opened", false);
    await prefs.setString("mission_date", DateTime.now().toIso8601String());

    notifyListeners();
  }
}
