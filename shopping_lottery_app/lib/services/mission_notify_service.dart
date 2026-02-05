import 'package:flutter/material.dart';
import 'package:osmile_shopping_app/services/firestore_mock_service.dart';
import 'package:osmile_shopping_app/services/notification_service.dart';

/// 🎯 MissionNotifyService
/// 任務 + 成就 + 排行榜 綜合更新中心
///
/// 功能：
/// ✅ 任務完成時加積分、發通知
/// ✅ 徽章解鎖同步至排行榜分數
/// ✅ 每次觸發都可更新 FirestoreMockService 與 NotificationService
class MissionNotifyService extends ChangeNotifier {
  MissionNotifyService._internal();
  static final MissionNotifyService instance = MissionNotifyService._internal();

  final List<Map<String, dynamic>> _missionLogs = [];

  List<Map<String, dynamic>> get missionLogs => List.unmodifiable(_missionLogs);

  /// 🏆 完成任務後加分與提示
  void completeMission({
    required String title,
    required int points,
  }) {
    final firestore = FirestoreMockService.instance;
    final notify = NotificationService.instance;

    firestore.addPoints(points);
    notify.addNotification(
      title: "🎯 任務完成",
      message: "你完成了「$title」，獲得 $points 積分！",
      type: "mission",
    );

    _missionLogs.insert(0, {
      "title": title,
      "points": points,
      "time": DateTime.now().toString(),
    });

    notifyListeners();
  }

  /// 🏅 徽章解鎖同步排行榜
  void syncBadgeToLeaderboard({
    required String badgeTitle,
    required int points,
  }) {
    final firestore = FirestoreMockService.instance;
    final notify = NotificationService.instance;

    firestore.addPoints(points);
    notify.addNotification(
      title: "🏅 成就同步",
      message: "你的徽章「$badgeTitle」提升了排行榜積分！+${points}",
      type: "leaderboard",
    );

    _missionLogs.insert(0, {
      "title": "徽章成就同步：$badgeTitle",
      "points": points,
      "time": DateTime.now().toString(),
    });

    notifyListeners();
  }

  /// 🔄 刷新紀錄（模擬用）
  void clearLogs() {
    _missionLogs.clear();
    notifyListeners();
  }
}
