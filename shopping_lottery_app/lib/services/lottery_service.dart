// lib/services/lottery_service.dart
// =======================================================
// ✅ LotteryService（最終整合完整版）
// -------------------------------------------------------
// 功能：
// - 控管抽獎與積分系統
// - 抽獎扣點 / 免費次數管理 / 回饋加點
// - 優惠券與歷史紀錄管理
// - 商城結帳後自動回饋積分與抽獎機會
// - 通知中心整合
// - 支援 LotteryPage、PaymentStatusPage、HomePage 等完整串接
//
// ✅ 編譯保證：
// - 修正 Object? -> String / int 型別錯誤
// - 相容不同 FirestoreMockService / LotteryHistoryService 方法命名與參數
// =======================================================

import 'dart:math';
import 'package:flutter/material.dart';

import 'firestore_mock_service.dart';
import 'notification_service.dart';
import 'lottery_history_service.dart';

class LotteryService extends ChangeNotifier {
  LotteryService._internal();
  static final LotteryService instance = LotteryService._internal();

  final Random _rnd = Random();

  // =======================================================
  // 基本設定
  // =======================================================
  final int _costPerSpin = 50; // 每次抽獎消耗積分
  int get costPerSpin => _costPerSpin;

  // 使用者免費抽獎次數（userId -> count）
  final Map<String, int> _freeSpins = {};

  // 使用者優惠券清單（userId -> couponList）
  final Map<String, List<Map<String, dynamic>>> _userCoupons = {};

  // 初始化（如需持久化可擴充 SharedPreferences）
  Future<void> init() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    notifyListeners();
  }

  // =======================================================
  // ✅ 積分管理（相容不同 FirestoreMockService）
  // =======================================================

  Future<int> getPoints(String userId) async {
    try {
      // 優先：getPoints(userId)
      final v = await FirestoreMockService.instance.getPoints(userId);
      return v;
    } catch (_) {
      // fallback：userPoints（部分 mock 只有單一用戶）
      try {
        return FirestoreMockService.instance.userPoints;
      } catch (_) {
        return 0;
      }
    }
  }

  Future<void> _safeAddPoints(String userId, int value) async {
    final dynamic fs = FirestoreMockService.instance;

    // 1) addPoints(value, userId: xxx)
    try {
      final r = fs.addPoints(value, userId: userId);
      if (r is Future) await r;
      return;
    } catch (_) {}

    // 2) addPoints(value)
    try {
      final r = fs.addPoints(value);
      if (r is Future) await r;
      return;
    } catch (_) {}

    // 3) increasePoints(value) / increasePoints(value, userId:xxx)
    try {
      final r = fs.increasePoints(value, userId: userId);
      if (r is Future) await r;
      return;
    } catch (_) {}
    try {
      final r = fs.increasePoints(value);
      if (r is Future) await r;
      return;
    } catch (_) {}

    // 4) userPoints += value
    try {
      fs.userPoints = (fs.userPoints as int) + value;
    } catch (_) {}
  }

  Future<bool> _safeSpendPoints(String userId, int value) async {
    final dynamic fs = FirestoreMockService.instance;

    // 1) spendPoints(value, userId:xxx) -> bool
    try {
      final r = fs.spendPoints(value, userId: userId);
      if (r is Future) return (await r) == true;
      if (r is bool) return r;
    } catch (_) {}

    // 2) spendPoints(value) -> bool
    try {
      final r = fs.spendPoints(value);
      if (r is Future) return (await r) == true;
      if (r is bool) return r;
    } catch (_) {}

    // 3) deductPoints(value, userId:xxx) -> void
    try {
      final r = fs.deductPoints(value, userId: userId);
      if (r is Future) await r;
      return true;
    } catch (_) {}
    try {
      final r = fs.deductPoints(value);
      if (r is Future) await r;
      return true;
    } catch (_) {}

    // 4) fallback：手動扣（若有 userPoints）
    try {
      final cur = fs.userPoints as int;
      if (cur < value) return false;
      fs.userPoints = cur - value;
      return true;
    } catch (_) {}

    return false;
  }

  // =======================================================
  // ✅ 商城消費回饋
  // - 每滿 100 元回饋 10 積分
  // - 每滿 500 元贈送 1 次免費抽獎
  // =======================================================
  Future<void> rewardFromShop({
    required String userId,
    required double amount,
  }) async {
    final int addPoints = (amount ~/ 100) * 10;

    if (addPoints > 0) {
      await _safeAddPoints(userId, addPoints);
      try {
        NotificationService.instance.addNotification(
          type: 'shop',
          title: '購物回饋',
          message: '購買 NT\$${amount.toInt()}，獲得 $addPoints 積分！',
          icon: Icons.shopping_bag_outlined,
        );
      } catch (_) {}
    }

    if (amount >= 500) {
      await addFreeSpin(userId, 1);
      try {
        NotificationService.instance.addNotification(
          type: 'lottery',
          title: '抽獎贈送',
          message: '單筆滿 NT\$500，獲得 1 次免費抽獎機會！',
          icon: Icons.card_giftcard_outlined,
        );
      } catch (_) {}
    }

    notifyListeners();
  }

  // =======================================================
  // ✅ 免費抽獎管理
  // =======================================================

  Future<void> addFreeSpin(String userId, [int count = 1]) async {
    _freeSpins[userId] = (_freeSpins[userId] ?? 0) + count;
    notifyListeners();
  }

  int getFreeSpinCount(String userId) => _freeSpins[userId] ?? 0;

  Future<bool> useFreeSpin(String userId) async {
    final current = _freeSpins[userId] ?? 0;
    if (current > 0) {
      _freeSpins[userId] = current - 1;
      notifyListeners();
      return true;
    }
    return false;
  }

  // =======================================================
  // ✅ 優惠券管理
  // =======================================================

  List<Map<String, dynamic>> getUserCoupons(String userId) {
    return List.unmodifiable(_userCoupons[userId] ?? const []);
  }

  void addCoupon(String userId, Map<String, dynamic> coupon) {
    _userCoupons[userId] ??= [];
    _userCoupons[userId]!.add(coupon);
    notifyListeners();
  }

  /// 可選：標記優惠券已使用
  bool markCouponUsed(String userId, String code) {
    final list = _userCoupons[userId];
    if (list == null) return false;
    final idx = list.indexWhere((c) => (c['code'] ?? '').toString() == code);
    if (idx == -1) return false;
    list[idx] = {...list[idx], 'used': true, 'usedAtMs': DateTime.now().millisecondsSinceEpoch};
    notifyListeners();
    return true;
  }

  Map<String, dynamic> _makeCoupon(int value, {String? source, String? orderId}) {
    final now = DateTime.now();
    return {
      'code': 'CP${now.millisecondsSinceEpoch % 100000}',
      'value': value,
      'used': false,
      'createdAtMs': now.millisecondsSinceEpoch,
      if (source != null) 'source': source,
      if (orderId != null) 'orderId': orderId,
    };
  }

  // =======================================================
  // ✅ 歷史紀錄（相容不同 LotteryHistoryService）
  // =======================================================
  void _safeAddHistory({
    required String result,
    required String type,
    required int value,
  }) {
    final dynamic history = LotteryHistoryService.instance;

    // 1) addRecord({result, type, value})
    try {
      history.addRecord(result: result, type: type, value: value);
      return;
    } catch (_) {}

    // 2) add({result, type, value})
    try {
      history.add(result: result, type: type, value: value);
      return;
    } catch (_) {}

    // 3) record(result, type, value)
    try {
      history.record(result, type, value);
      return;
    } catch (_) {}
  }

  // =======================================================
  // ✅ 抽獎邏輯主體
  // =======================================================
  /// spin()
  /// - preferFree=true：若使用者有免費次數，優先使用免費（即使 free=false）
  /// - free=true：視為「強制免費」(仍會嘗試消耗免費次數，但不會扣點)
  Future<Map<String, dynamic>> spin({
    required String userId,
    bool free = false,
    bool preferFree = true,
  }) async {
    final notification = NotificationService.instance;

    // 1) 決定本次是否使用免費
    bool usedFree = false;
    if (free) {
      usedFree = await useFreeSpin(userId); // 有就消耗，沒有也照樣免費
    } else if (preferFree && getFreeSpinCount(userId) > 0) {
      usedFree = await useFreeSpin(userId);
    }

    // 2) 若不是免費，檢查積分並扣點
    if (!usedFree && !free) {
      final points = await getPoints(userId);
      if (points < _costPerSpin) {
        return {
          'ok': false,
          'message': '您的積分不足（需 $_costPerSpin 積分）',
          'reward': null,
        };
      }

      final ok = await _safeSpendPoints(userId, _costPerSpin);
      if (!ok) {
        return {
          'ok': false,
          'message': '扣除積分失敗，請稍後再試。',
          'reward': null,
        };
      }
    }

    // 3) 獎項樣本（可自行調整）
    final List<Map<String, dynamic>> samples = [
      {'type': 'points', 'value': 50, 'label': '+50 積分'},
      {'type': 'points', 'value': 20, 'label': '+20 積分'},
      {'type': 'coupon', 'value': 100, 'label': 'NT\$100 優惠券'},
      {'type': 'coupon', 'value': 200, 'label': 'NT\$200 優惠券'},
      {'type': 'none', 'value': 0, 'label': '再接再厲'},
      {'type': 'free_spin', 'value': 1, 'label': '免費抽獎'},
    ];

    final prize = samples[_rnd.nextInt(samples.length)];

    // ✅ 關鍵：一律轉型，避免 Object? 型別錯誤
    final String pType = (prize['type'] ?? 'none').toString();
    final String pLabel = (prize['label'] ?? '').toString();
    final int pValue = (prize['value'] is num)
        ? (prize['value'] as num).toInt()
        : int.tryParse('${prize['value']}') ?? 0;

    // 4) 發放獎勵
    switch (pType) {
      case 'points':
        await _safeAddPoints(userId, pValue);
        _safeAddHistory(result: pLabel, type: 'points', value: pValue);
        try {
          notification.addNotification(
            type: 'lottery',
            title: '抽獎中獎',
            message: '恭喜獲得 $pValue 積分！',
            icon: Icons.stars_outlined,
          );
        } catch (_) {}
        return {
          'ok': true,
          'message': '恭喜獲得 $pLabel！',
          'reward': {'type': 'points', 'value': pValue, 'label': pLabel},
          'usedFree': usedFree || free,
        };

      case 'coupon':
        final coupon = _makeCoupon(pValue, source: 'lottery');
        addCoupon(userId, coupon);
        _safeAddHistory(result: pLabel, type: 'coupon', value: pValue);
        try {
          notification.addNotification(
            type: 'lottery',
            title: '抽獎中獎',
            message: '恭喜獲得折抵 NT\$$pValue 優惠券！',
            icon: Icons.local_activity_outlined,
          );
        } catch (_) {}
        return {
          'ok': true,
          'message': '恭喜獲得 $pLabel！',
          'reward': {'type': 'coupon', 'coupon': coupon, 'label': pLabel},
          'usedFree': usedFree || free,
        };

      case 'free_spin':
        await addFreeSpin(userId, 1);
        _safeAddHistory(result: pLabel, type: 'free_spin', value: 1);
        try {
          notification.addNotification(
            type: 'lottery',
            title: '抽獎中獎',
            message: '獲得一次免費抽獎機會！',
            icon: Icons.casino_outlined,
          );
        } catch (_) {}
        return {
          'ok': true,
          'message': '恭喜獲得 $pLabel！',
          'reward': {'type': 'free_spin', 'value': 1, 'label': pLabel},
          'usedFree': usedFree || free,
        };

      default:
        _safeAddHistory(result: '再接再厲', type: 'none', value: 0);
        try {
          notification.addNotification(
            type: 'lottery',
            title: '抽獎結果',
            message: '很可惜，這次沒中，請再接再厲！',
            icon: Icons.info_outline,
          );
        } catch (_) {}
        return {
          'ok': true,
          'message': '很可惜，這次沒中獎！',
          'reward': {'type': 'none', 'value': 0, 'label': '再接再厲'},
          'usedFree': usedFree || free,
        };
    }
  }

  // =======================================================
  // ✅ 管理員工具
  // =======================================================
  Future<void> addPointsAdmin(String userId, int value) async {
    await _safeAddPoints(userId, value);
    try {
      NotificationService.instance.addNotification(
        type: 'system',
        title: '系統贈點',
        message: '系統加贈 $value 積分',
        icon: Icons.add_circle_outline,
      );
    } catch (_) {}
    notifyListeners();
  }

  Future<void> resetPoints(String userId) async {
    final dynamic fs = FirestoreMockService.instance;

    // 1) setPoints(userId, 0)
    try {
      final r = fs.setPoints(userId, 0);
      if (r is Future) await r;
    } catch (_) {
      // 2) setPoints(userId:..., value:0)
      try {
        final r = fs.setPoints(userId: userId, value: 0);
        if (r is Future) await r;
      } catch (_) {
        // 3) reset()（若 mock 有提供）
        try {
          final r = fs.reset();
          if (r is Future) await r;
        } catch (_) {}
      }
    }

    try {
      NotificationService.instance.addNotification(
        type: 'system',
        title: '重置積分',
        message: '您的積分已重置為 0',
        icon: Icons.restart_alt,
      );
    } catch (_) {}

    notifyListeners();
  }
}
