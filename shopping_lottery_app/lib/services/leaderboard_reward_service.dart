// lib/services/leaderboard_reward_service.dart
import 'dart:math';
import 'package:flutter/material.dart';

import 'firestore_mock_service.dart';
import 'notification_service.dart';

/// LeaderboardRewardService
/// - 模擬排行榜功能（依 points 排名）
/// - 提供 userPoints 快取（同步 getter: userPoints）
/// - 可觸發每日排行榜獎勵，並發出通知
class LeaderboardRewardService extends ChangeNotifier {
  LeaderboardRewardService._internal();
  static final LeaderboardRewardService instance =
      LeaderboardRewardService._internal();

  /// 排行榜資料（模擬）
  /// userId / name / points
  final List<Map<String, dynamic>> _leaderboard = [
    {"userId": "u1", "name": "小明", "points": 120},
    {"userId": "u2", "name": "Lumi 玩家", "points": 95},
    {"userId": "u3", "name": "小華", "points": 80},
    {"userId": "guest", "name": "訪客", "points": 0},
  ];

  /// 本地快取使用者積分（for UI）
  int _cachedUserPoints = 0;
  int get userPoints => _cachedUserPoints;

  /// 取得排行榜（唯讀）
  List<Map<String, dynamic>> get leaderboard =>
      List.unmodifiable(_leaderboard);

  /// 初始化（如果之後要從遠端載入可放在這裡）
  Future<void> init() async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    notifyListeners();
  }

  /// 從 FirestoreMockService 重新抓某用戶積分並快取
  Future<void> refreshUserPoints(String userId) async {
    final pts = await FirestoreMockService.instance.getPoints(userId);
    _cachedUserPoints = pts;
    notifyListeners();
  }

  /// 直接取得某用戶積分（不更新快取）
  Future<int> getUserPoints(String userId) async {
    return FirestoreMockService.instance.getPoints(userId);
  }

  /// 檢查 & 發放每日排行榜獎勵（模擬）
  /// 目前簡化為：對排行榜前 3 名，各自加上 (3 - 名次) * 20 點，
  /// 實際上因為 FirestoreMockService 是單一使用者 mock，
  /// 所以會全部加在同一個 user 上（僅示範用）。
  Future<void> checkDailyLeaderboardReward() async {
    // 依 points 由高到低排序
    _leaderboard.sort((a, b) {
      final ap = (a['points'] is num) ? (a['points'] as num).toInt() : 0;
      final bp = (b['points'] is num) ? (b['points'] as num).toInt() : 0;
      return bp.compareTo(ap);
    });

    final firestore = FirestoreMockService.instance;

    // 模擬對前 3 名發放獎勵（注意：目前 FirestoreMockService 沒有分 userId）
    for (int i = 0; i < _leaderboard.length && i < 3; i++) {
      final int award = (3 - i) * 20;
      await firestore.addPoints(award);
    }

    // 發送通知到全域 NotificationService
    NotificationService.instance.addNotification(
      title: "🏅 每日排行榜獎勵已發送",
      message: "恭喜排行榜前 3 名獲得積分獎勵 🎉",
      type: "leaderboard",
      icon: Icons.military_tech,
    );

    notifyListeners();
  }

  /// 模擬玩家「抽獎 / 互動」次數，提升排行榜積分
  void addSpin(String username) {
    final index = _leaderboard.indexWhere((u) => u["name"] == username);
    if (index != -1) {
      final current =
          (_leaderboard[index]["points"] is num) ? (_leaderboard[index]["points"] as num).toInt() : 0;
      _leaderboard[index]["points"] = current + 1;
    } else {
      _leaderboard.add({
        "userId": "u_${Random().nextInt(10000)}",
        "name": username,
        "points": 1,
      });
    }

    _leaderboard.sort((a, b) {
      final ap = (a['points'] is num) ? (a['points'] as num).toInt() : 0;
      final bp = (b['points'] is num) ? (b['points'] as num).toInt() : 0;
      return bp.compareTo(ap);
    });

    notifyListeners();
  }

  /// 回傳使用者在排行榜中的名次（1-based），沒有則回傳 -1
  int rankOf(String userId) {
    final idx = _leaderboard.indexWhere((r) => r["userId"] == userId);
    return idx == -1 ? -1 : idx + 1;
  }
}
