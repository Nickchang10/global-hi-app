import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_mock_service.dart';
import '../widgets/reward_effect_widget.dart';

/// 🏅 成就徽章服務（解鎖 + 儲存 + 特效整合）
class AchievementService extends ChangeNotifier {
  AchievementService._internal();
  static final AchievementService instance = AchievementService._internal();

  final _firestore = FirestoreMockService.instance;

  /// 所有可解鎖成就清單
  final List<Map<String, dynamic>> _achievements = [
    {
      "id": "a1",
      "title": "初次登入",
      "desc": "第一次登入 Osmile 智慧商城",
      "icon": Icons.person_pin_circle,
      "reward": 50,
    },
    {
      "id": "a2",
      "title": "七日堅持",
      "desc": "連續登入滿 7 天",
      "icon": Icons.calendar_month,
      "reward": 100,
    },
    {
      "id": "a3",
      "title": "抽獎大師",
      "desc": "完成 10 次抽獎",
      "icon": Icons.casino_outlined,
      "reward": 150,
    },
    {
      "id": "a4",
      "title": "購物高手",
      "desc": "完成 5 筆有效訂單",
      "icon": Icons.shopping_bag_outlined,
      "reward": 200,
    },
    {
      "id": "a5",
      "title": "社群之星",
      "desc": "在社群中發表 5 次貼文",
      "icon": Icons.group_outlined,
      "reward": 100,
    },
  ];

  /// 已解鎖徽章
  final List<String> _unlocked = [];
  List<String> get unlocked => List.unmodifiable(_unlocked);

  /// 初始化
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList("unlocked_achievements") ?? [];
    _unlocked.addAll(list);
  }

  /// 所有徽章清單（包含解鎖狀態）
  List<Map<String, dynamic>> get allAchievements => _achievements.map((a) {
        final unlocked = _unlocked.contains(a["id"]);
        return {...a, "unlocked": unlocked};
      }).toList();

  /// 檢查並解鎖成就
  Future<void> unlockAchievement(BuildContext context, String id) async {
    if (_unlocked.contains(id)) return;

    final prefs = await SharedPreferences.getInstance();
    _unlocked.add(id);
    prefs.setStringList("unlocked_achievements", _unlocked);

    final ach = _achievements.firstWhere((a) => a["id"] == id);

    // 加積分
    _firestore.addPoints(ach["reward"]);
    _firestore.addNotification(
      title: "🏆 成就解鎖",
      message: "恭喜！您獲得成就「${ach["title"]}」，獲得 ${ach["reward"]} 積分！",
    );

    // 顯示動畫特效
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: RewardEffectWidget(
          animation: "reward_celebration.json",
          message: "🏅 ${ach["title"]} 已解鎖！",
        ),
      ),
    );

    notifyListeners();
  }
}
