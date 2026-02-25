import 'package:flutter/foundation.dart';

import 'firestore_mock_service.dart';

/// ✅ DailyRewardService（完整版｜可編譯｜已移除 FirestoreMockService.instance）
/// ------------------------------------------------------------
/// - 不依賴 FirestoreMockService.instance
/// - 支援注入 FirestoreMockService（也可預設 new 一個）
/// - 每日簽到獎勵：
///    - 以「uid + 當日」判定是否已領
///    - streak 連續天數（以最後領取日判斷）
/// - 完成後會嘗試：
///    - addPoints(uid, points)
///    - addNotification(uid, payload)
///   若 mock service 尚未實作，會自動忽略，不影響編譯與執行
/// ------------------------------------------------------------
/// ⚠️ 注意：此版本不做本地持久化（避免再引入 shared_preferences 依賴）
///     若你需要「關掉 App 再開仍保留 streak / 已領狀態」，我再幫你加可選持久化版本。
class DailyRewardService extends ChangeNotifier {
  DailyRewardService({FirestoreMockService? store})
    : _store = store ?? FirestoreMockService();

  final FirestoreMockService _store;

  bool _loading = false;
  String? _uid;

  // 以記憶體保存狀態（避免額外套件）
  final Map<String, _UserDailyRewardState> _stateByUid = {};

  bool get loading => _loading;

  /// 目前登入 uid（未 init 會是 null）
  String? get uid => _uid;

  /// 初始化 / 切換使用者
  Future<void> init({required String uid}) async {
    _uid = uid;
    _stateByUid.putIfAbsent(uid, () => _UserDailyRewardState());
    notifyListeners();
  }

  /// 取得當前狀態
  DailyRewardStatus get status {
    final u = _uid;
    if (u == null) return DailyRewardStatus.empty();

    final s = _stateByUid.putIfAbsent(u, () => _UserDailyRewardState());
    final today = _todayKey();
    final claimedToday = (s.lastClaimDayKey == today);

    return DailyRewardStatus(
      uid: u,
      dayKey: today,
      claimedToday: claimedToday,
      streak: s.streak,
      lastClaimDayKey: s.lastClaimDayKey,
      nextRewardPoints: _pointsForStreak(s.streak + (claimedToday ? 0 : 1)),
    );
  }

  /// 領取每日獎勵（回傳本次是否成功領到）
  Future<bool> claimDailyReward() async {
    final u = _uid;
    if (u == null) return false;

    final s = _stateByUid.putIfAbsent(u, () => _UserDailyRewardState());
    final today = _todayKey();

    // 已領過
    if (s.lastClaimDayKey == today) return false;

    _loading = true;
    notifyListeners();

    try {
      // streak 計算：如果昨天有領 -> streak+1；否則重置為 1
      final yesterday = _yesterdayKey();
      if (s.lastClaimDayKey == yesterday) {
        s.streak += 1;
      } else {
        s.streak = 1;
      }

      s.lastClaimDayKey = today;

      final points = _pointsForStreak(s.streak);

      // 發點 + 通知（mock service 沒實作也不會爆）
      await _tryAwardPoints(u, points);
      await _tryAddNotification(
        u,
        title: '每日簽到獎勵',
        body: '你已完成今日簽到，獲得 $points 點（連續 ${s.streak} 天）',
        type: 'daily_reward',
      );

      return true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 手動重置（debug / 測試用）
  void resetForDebug({String? uid}) {
    final u = uid ?? _uid;
    if (u == null) return;
    _stateByUid[u] = _UserDailyRewardState();
    notifyListeners();
  }

  // -------------------------
  // Internal helpers
  // -------------------------

  int _pointsForStreak(int streak) {
    // 你可依需求改規則：例如 1~7 天遞增，之後固定
    if (streak <= 1) return 10;
    if (streak == 2) return 12;
    if (streak == 3) return 14;
    if (streak == 4) return 16;
    if (streak == 5) return 18;
    if (streak == 6) return 20;
    if (streak == 7) return 25;
    return 25; // 8 天以上固定
  }

  Future<void> _tryAwardPoints(String uid, int points) async {
    final d = _store as dynamic;
    try {
      final r = d.addPoints(uid, points);
      if (r is Future) await r;
    } catch (_) {
      // mock service 沒實作 addPoints -> 忽略
    }
  }

  Future<void> _tryAddNotification(
    String uid, {
    required String title,
    required String body,
    required String type,
  }) async {
    final d = _store as dynamic;
    try {
      final payload = {
        'title': title,
        'body': body,
        'type': type,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
      };
      final r = d.addNotification(uid, payload);
      if (r is Future) await r;
    } catch (_) {
      // mock service 沒實作 addNotification -> 忽略
    }
  }

  static String _todayKey() {
    final now = DateTime.now();
    return _fmtDay(now);
  }

  static String _yesterdayKey() {
    final now = DateTime.now().subtract(const Duration(days: 1));
    return _fmtDay(now);
  }

  static String _fmtDay(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}

/// 內部用：每個 uid 的狀態
class _UserDailyRewardState {
  int streak = 0;
  String? lastClaimDayKey;
}

/// 對外用：狀態資料
@immutable
class DailyRewardStatus {
  const DailyRewardStatus({
    required this.uid,
    required this.dayKey,
    required this.claimedToday,
    required this.streak,
    required this.lastClaimDayKey,
    required this.nextRewardPoints,
  });

  final String uid;
  final String dayKey;
  final bool claimedToday;
  final int streak;
  final String? lastClaimDayKey;
  final int nextRewardPoints;

  factory DailyRewardStatus.empty() => const DailyRewardStatus(
    uid: '',
    dayKey: '',
    claimedToday: false,
    streak: 0,
    lastClaimDayKey: null,
    nextRewardPoints: 0,
  );
}
