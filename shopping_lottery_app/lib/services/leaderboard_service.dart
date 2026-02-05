// lib/services/leaderboard_service.dart
import 'package:flutter/material.dart';

import 'firestore_mock_service.dart';
import 'level_service.dart';
import 'notification_service.dart';

/// 🌍 排行榜與勳章系統
class LeaderboardService extends ChangeNotifier {
  LeaderboardService._internal();
  static final LeaderboardService _instance = LeaderboardService._internal();
  static LeaderboardService get instance => _instance;

  /// 目前暫時沒用到，但保留，之後可以改成真正從雲端同步排行榜
  final FirestoreMockService firestore = FirestoreMockService.instance;

  /// 使用既有的 LevelService 取得目前使用者 XP
  final LevelService level = LevelService.instance;

  /// 假資料的玩家排行（之後可改為 API / Firestore）
  final List<Map<String, dynamic>> _players = [
    {"name": "Alice", "xp": 1230},
    {"name": "Ben", "xp": 980},
    {"name": "Chris", "xp": 720},
    {"name": "Diana", "xp": 600},
    {"name": "Evan", "xp": 420},
  ];

  /// 排行榜：會自動把 "You" 加進去，依 xp 由高到低排序
  List<Map<String, dynamic>> get leaderboard {
    final all = List<Map<String, dynamic>>.from(_players);
    all.add({
      "name": "You",
      "xp": level.xp, // 直接讀取等級服務的 XP
    });
    all.sort((a, b) {
      final axp = (a["xp"] is num) ? (a["xp"] as num).toInt() : 0;
      final bxp = (b["xp"] is num) ? (b["xp"] as num).toInt() : 0;
      return bxp.compareTo(axp);
    });
    return all;
  }

  /// 根據 XP 回傳徽章文字
  String getBadge(int xp) {
    if (xp >= 2000) return "💎 Diamond";
    if (xp >= 1200) return "🏆 Platinum";
    if (xp >= 800) return "🥇 Gold";
    if (xp >= 400) return "🥈 Silver";
    return "🥉 Bronze";
  }

  /// 取得目前使用者的徽章
  String get currentUserBadge => getBadge(level.xp);

  /// 當升級或 XP 變化時，可以呼叫這個方法推送通知
  void notifyLevelUp(String badge) {
    // 丟到全域通知中心，跟訂單、會員等通知統一顯示
    NotificationService.instance.addNotification(
      title: "🎖️ 恭喜升級徽章！",
      message: "您已獲得 $badge 勳章稱號！",
      type: "level", // 類型名稱可在通知頁做分類
      icon: Icons.military_tech,
    );

    // 若未來要把勳章存回雲端，可以利用 firestore 做同步
    // 例如：firestore.saveUserBadge(userId, badge);
  }
}
