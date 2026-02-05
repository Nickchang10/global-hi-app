// lib/services/daily_reward_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_mock_service.dart';
import 'notification_service.dart';

/// 🎁 每日登入獎勵系統
///
/// 功能：
/// - 每日登入檢查
/// - 領取獎勵積分
/// - 通知中心提示
class DailyRewardService extends ChangeNotifier {
  DailyRewardService._internal();
  static final DailyRewardService instance = DailyRewardService._internal();

  bool _hasClaimedToday = false;

  bool get hasClaimedToday => _hasClaimedToday;

  /// ✅ 啟動時檢查今日是否已簽到
  Future<void> checkDailyReward() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final lastClaimDate = prefs.getString('lastDailyRewardDate');

    if (lastClaimDate != null) {
      final lastDate = DateTime.parse(lastClaimDate);
      _hasClaimedToday = lastDate.year == today.year &&
          lastDate.month == today.month &&
          lastDate.day == today.day;
    } else {
      _hasClaimedToday = false;
    }

    notifyListeners();
  }

  /// 🎉 領取每日積分
  Future<void> claimReward() async {
    if (_hasClaimedToday) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastDailyRewardDate', DateTime.now().toIso8601String());

    _hasClaimedToday = true;

    // 給予積分
    FirestoreMockService.instance.addPoints(10);

    NotificationService.instance.addNotification(
      title: "🎁 每日登入獎勵",
      message: "感謝登入 Osmile，已獲得 10 積分 💎",
      type: "reward",
      icon: Icons.card_giftcard,
    );

    notifyListeners();
  }

  /// 🔄 重置（開發用）
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lastDailyRewardDate');
    _hasClaimedToday = false;
    notifyListeners();
  }
}
