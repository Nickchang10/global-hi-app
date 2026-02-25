import 'package:flutter/foundation.dart';

import 'firestore_mock_service.dart';

/// ✅ DailySigninService（完整版｜可編譯｜已移除 FirestoreMockService.instance）
/// ------------------------------------------------------------
/// - 不依賴 FirestoreMockService.instance
/// - 支援注入 FirestoreMockService（也可預設 new 一個）
/// - 每日簽到：
///    - 以「uid + 當日」判定是否已簽
///    - streak 連續天數（以最後簽到日判斷）
/// - 簽到成功後會嘗試：
///    - addPoints(uid, points)
///    - addNotification(uid, payload)
///   若 mock service 尚未實作，會自動忽略，不影響編譯與執行
/// ------------------------------------------------------------
/// ⚠️ 本版本使用記憶體保存（不依賴 shared_preferences）
///    若你要「關 App 再開仍保存 streak/簽到狀態」，我再給你持久化版本。
class DailySigninService extends ChangeNotifier {
  DailySigninService({FirestoreMockService? store})
    : _store = store ?? FirestoreMockService();

  final FirestoreMockService _store;

  bool _loading = false;
  String? _uid;

  final Map<String, _UserSigninState> _stateByUid = {};

  bool get loading => _loading;
  String? get uid => _uid;

  /// 初始化 / 切換使用者
  Future<void> init({required String uid}) async {
    _uid = uid;
    _stateByUid.putIfAbsent(uid, () => _UserSigninState());
    notifyListeners();
  }

  /// 今日是否已簽到
  bool get signedInToday {
    final u = _uid;
    if (u == null) return false;
    final s = _stateByUid.putIfAbsent(u, () => _UserSigninState());
    return s.lastSigninDayKey == _todayKey();
  }

  /// 連續簽到天數
  int get streakDays {
    final u = _uid;
    if (u == null) return 0;
    final s = _stateByUid.putIfAbsent(u, () => _UserSigninState());
    return s.streak;
  }

  /// 今日簽到可拿到的點數（如果已簽，回 0）
  int get todayRewardPoints {
    if (signedInToday) return 0;
    final nextStreak = streakDays == 0 ? 1 : (streakDays + 1);
    return _pointsForStreak(nextStreak);
  }

  /// 對外狀態（方便 UI 一次拿完）
  DailySigninStatus get status {
    final u = _uid;
    if (u == null) return DailySigninStatus.empty();

    final s = _stateByUid.putIfAbsent(u, () => _UserSigninState());
    final today = _todayKey();
    final claimedToday = (s.lastSigninDayKey == today);

    return DailySigninStatus(
      uid: u,
      dayKey: today,
      signedInToday: claimedToday,
      streak: s.streak,
      lastSigninDayKey: s.lastSigninDayKey,
      nextRewardPoints: claimedToday ? 0 : _pointsForStreak(_calcNextStreak(s)),
    );
  }

  /// ✅ 執行簽到（成功回傳 result.success=true，並給 points/streak）
  Future<DailySigninResult> signIn() async {
    final u = _uid;
    if (u == null) {
      return const DailySigninResult(success: false, points: 0, streak: 0);
    }

    final s = _stateByUid.putIfAbsent(u, () => _UserSigninState());
    final today = _todayKey();

    // 已簽過
    if (s.lastSigninDayKey == today) {
      return DailySigninResult(success: false, points: 0, streak: s.streak);
    }

    _loading = true;
    notifyListeners();

    try {
      // streak 計算：昨天有簽 -> streak+1；否則重置為 1
      final yesterday = _yesterdayKey();
      if (s.lastSigninDayKey == yesterday) {
        s.streak += 1;
      } else {
        s.streak = 1;
      }

      s.lastSigninDayKey = today;

      final points = _pointsForStreak(s.streak);

      await _tryAwardPoints(u, points);
      await _tryAddNotification(
        u,
        title: '每日簽到成功',
        body: '你已完成今日簽到，獲得 $points 點（連續 ${s.streak} 天）',
        type: 'daily_signin',
      );

      return DailySigninResult(success: true, points: points, streak: s.streak);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ---- 常見別名（避免你 UI/舊碼呼叫不同方法名又報 undefined_method） ----
  Future<DailySigninResult> checkIn() => signIn();
  Future<DailySigninResult> signin() => signIn();
  Future<DailySigninResult> claimDailySignin() => signIn();
  Future<DailySigninResult> claim() => signIn();

  /// debug：重置某個 uid 或當前 uid 的狀態
  void resetForDebug({String? uid}) {
    final u = uid ?? _uid;
    if (u == null) return;
    _stateByUid[u] = _UserSigninState();
    notifyListeners();
  }

  // -------------------------
  // Internal helpers
  // -------------------------

  int _calcNextStreak(_UserSigninState s) {
    final today = _todayKey();
    if (s.lastSigninDayKey == today) return s.streak;
    final yesterday = _yesterdayKey();
    if (s.lastSigninDayKey == yesterday) return s.streak + 1;
    return 1;
  }

  int _pointsForStreak(int streak) {
    // 你可依需求調整規則：1~7 天遞增，之後固定
    if (streak <= 1) return 10;
    if (streak == 2) return 12;
    if (streak == 3) return 14;
    if (streak == 4) return 16;
    if (streak == 5) return 18;
    if (streak == 6) return 20;
    if (streak == 7) return 25;
    return 25;
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

  static String _todayKey() => _fmtDay(DateTime.now());

  static String _yesterdayKey() =>
      _fmtDay(DateTime.now().subtract(const Duration(days: 1)));

  static String _fmtDay(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}

/// 內部：每個 uid 的簽到狀態
class _UserSigninState {
  int streak = 0;
  String? lastSigninDayKey;
}

/// 對外：狀態
@immutable
class DailySigninStatus {
  const DailySigninStatus({
    required this.uid,
    required this.dayKey,
    required this.signedInToday,
    required this.streak,
    required this.lastSigninDayKey,
    required this.nextRewardPoints,
  });

  final String uid;
  final String dayKey;
  final bool signedInToday;
  final int streak;
  final String? lastSigninDayKey;
  final int nextRewardPoints;

  factory DailySigninStatus.empty() => const DailySigninStatus(
    uid: '',
    dayKey: '',
    signedInToday: false,
    streak: 0,
    lastSigninDayKey: null,
    nextRewardPoints: 0,
  );
}

/// 簽到結果（給 UI 顯示 toast / dialog）
@immutable
class DailySigninResult {
  const DailySigninResult({
    required this.success,
    required this.points,
    required this.streak,
  });

  final bool success;
  final int points;
  final int streak;
}
