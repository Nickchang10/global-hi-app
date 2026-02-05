// lib/services/shared_preferences_service.dart
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// ======================================================
/// SharedPreferencesService
/// - 好友 / 邀請 / 每日狀態 / 週期重置（每週 or 每月）
/// - 適合搭配你目前的 InteractionPage 使用
/// ======================================================
class SharedPreferencesService {
  SharedPreferencesService._();

  static SharedPreferences? _prefs;

  // ---- keys（你可依專案調整版本號）----
  static const String kPrefsFriends = 'interaction_friends_v1';
  static const String kPrefsRequests = 'interaction_friend_requests_v1';
  static const String kPrefsInviteCode = 'interaction_my_invite_code_v1';
  static const String kPrefsDaily = 'interaction_daily_v1';

  // 週/月重置記錄 key
  static const String kPrefsLastWeeklyId = 'interaction_last_weekly_id_v1';
  static const String kPrefsLastMonthlyId = 'interaction_last_monthly_id_v1';

  // 你可能會用到的其他資料（重置時會清）
  static const List<String> kResetKeys = <String>[
    'friend_points',
    'challenge_history',
    'leaderboard_cache',
    'activity_cache',
  ];

  /// 初始化（建議在 main() 或 InteractionPage initState 先呼叫一次）
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get _sp {
    final p = _prefs;
    if (p == null) {
      throw StateError('SharedPreferencesService not initialized. Call SharedPreferencesService.init() first.');
    }
    return p;
  }

  // ======================================================
  // Invite Code
  // ======================================================

  static Future<String> getOrCreateInviteCode() async {
    await init();
    final exist = _sp.getString(kPrefsInviteCode);
    if (exist != null && exist.trim().isNotEmpty) return exist.trim();

    final code = _genInviteCode();
    await _sp.setString(kPrefsInviteCode, code);
    return code;
  }

  static String _genInviteCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // ======================================================
  // Friends
  // ======================================================

  static Future<List<FriendModel>> loadFriends({bool ensureMe = true}) async {
    await init();
    final jsonStr = _sp.getString(kPrefsFriends);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      final seeded = _seedFriends();
      if (ensureMe && seeded.every((f) => f.id != 'me')) {
        seeded.insert(0, FriendModel.me());
      }
      await saveFriends(seeded);
      return seeded;
    }

    try {
      final raw = jsonDecode(jsonStr);
      if (raw is! List) return [FriendModel.me(), ..._seedFriends().where((e) => e.id != 'me')];

      final list = raw
          .whereType<Map>()
          .map((m) => FriendModel.fromJson(m.cast<String, dynamic>()))
          .where((f) => f.id.trim().isNotEmpty)
          .toList();

      if (ensureMe && list.every((f) => f.id != 'me')) {
        list.insert(0, FriendModel.me());
      }
      return list;
    } catch (_) {
      final seeded = _seedFriends();
      if (ensureMe && seeded.every((f) => f.id != 'me')) {
        seeded.insert(0, FriendModel.me());
      }
      await saveFriends(seeded);
      return seeded;
    }
  }

  static Future<void> saveFriends(List<FriendModel> friends) async {
    await init();
    final list = friends.map((f) => f.toJson()).toList();
    await _sp.setString(kPrefsFriends, jsonEncode(list));
  }

  static List<FriendModel> _seedFriends() {
    return const [
      FriendModel(id: 'me', name: '我', initials: '我', colorValue: 0xFF1976D2, online: true),
      FriendModel(id: 'f_alice', name: 'Alice', initials: 'A', colorValue: 0xFFFF9800, online: true),
      FriendModel(id: 'f_bob', name: 'Bob', initials: 'B', colorValue: 0xFF1E88E5, online: false),
      FriendModel(id: 'f_carol', name: 'Carol', initials: 'C', colorValue: 0xFFE91E63, online: true),
      FriendModel(id: 'f_david', name: 'David', initials: 'D', colorValue: 0xFFFFC107, online: false),
      FriendModel(id: 'f_emma', name: 'Emma', initials: 'E', colorValue: 0xFFFF5722, online: true),
    ];
  }

  // ======================================================
  // Friend Requests
  // ======================================================

  static Future<List<FriendRequestModel>> loadFriendRequests({bool seedDemo = true}) async {
    await init();
    final jsonStr = _sp.getString(kPrefsRequests);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      if (!seedDemo) return [];
      final demo = [
        FriendRequestModel(
          id: 'req_demo',
          fromName: 'Ken',
          fromInitials: 'K',
          fromColorValue: 0xFF7E57C2,
          message: '一起參加健走活動嗎？',
          createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        ),
      ];
      await saveFriendRequests(demo);
      return demo;
    }

    try {
      final raw = jsonDecode(jsonStr);
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((m) => FriendRequestModel.fromJson(m.cast<String, dynamic>()))
          .where((r) => r.id.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveFriendRequests(List<FriendRequestModel> requests) async {
    await init();
    final list = requests.map((r) => r.toJson()).toList();
    await _sp.setString(kPrefsRequests, jsonEncode(list));
  }

  // ======================================================
  // Daily State
  // ======================================================

  static Future<DailyStateModel> loadDailyState({DailyStateModel? fallback}) async {
    await init();
    final jsonStr = _sp.getString(kPrefsDaily);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return fallback ?? DailyStateModel.todayDefault();
    }

    try {
      final raw = jsonDecode(jsonStr);
      if (raw is! Map) return fallback ?? DailyStateModel.todayDefault();
      final state = DailyStateModel.fromJson(raw.cast<String, dynamic>());

      // 若不是今天的資料，回到 default（但你也可以改成保留 points / streak 等）
      final today = _yyyyMmDd(DateTime.now());
      if (state.date != today) {
        return (fallback ?? DailyStateModel.todayDefault()).copyWith(
          points: state.points, // 保留累積點數（可視需求拿掉）
          streakDays: state.streakDays,
        );
      }
      return state;
    } catch (_) {
      return fallback ?? DailyStateModel.todayDefault();
    }
  }

  static Future<void> saveDailyState(DailyStateModel state) async {
    await init();
    await _sp.setString(kPrefsDaily, jsonEncode(state.toJson()));
  }

  // ======================================================
  // Weekly / Monthly Reset
  // ======================================================

  /// 每次 App 啟動或進入互動頁可呼叫：
  /// - weekly: 每週一 00:00 開新週
  /// - monthly: 每月 1 號 00:00 開新月
  static Future<ResetResult> checkAndResetIfNeeded({
    bool weekly = true,
    bool monthly = false,
    List<String>? extraResetKeys,
  }) async {
    await init();

    bool didResetWeekly = false;
    bool didResetMonthly = false;

    if (weekly) {
      final currentWeeklyId = _isoWeekId(DateTime.now()); // ex: 2025-W51
      final lastWeeklyId = _sp.getString(kPrefsLastWeeklyId);

      if (lastWeeklyId == null || lastWeeklyId != currentWeeklyId) {
        await _doReset(keys: [...kResetKeys, if (extraResetKeys != null) ...extraResetKeys], scope: ResetScope.weekly);
        await _sp.setString(kPrefsLastWeeklyId, currentWeeklyId);
        didResetWeekly = true;
      }
    }

    if (monthly) {
      final currentMonthlyId = _yyyyMm(DateTime.now()); // ex: 2025-12
      final lastMonthlyId = _sp.getString(kPrefsLastMonthlyId);

      if (lastMonthlyId == null || lastMonthlyId != currentMonthlyId) {
        await _doReset(keys: [...kResetKeys, if (extraResetKeys != null) ...extraResetKeys], scope: ResetScope.monthly);
        await _sp.setString(kPrefsLastMonthlyId, currentMonthlyId);
        didResetMonthly = true;
      }
    }

    return ResetResult(didResetWeekly: didResetWeekly, didResetMonthly: didResetMonthly);
  }

  static Future<void> _doReset({required List<String> keys, required ResetScope scope}) async {
    // 你可以按 scope 分不同 reset 策略；此版先做「清除排行榜/挑戰類資料 + 重置 daily」
    for (final k in keys) {
      await _sp.remove(k);
    }

    // daily reset（同時保留 points/streak 也可以自行調整）
    final keep = await loadDailyState(fallback: DailyStateModel.todayDefault());
    final resetDaily = DailyStateModel.todayDefault().copyWith(
      points: keep.points,
      streakDays: keep.streakDays,
    );
    await saveDailyState(resetDaily);
  }

  /// 下次「每週」重置時間（週一 00:00）
  static DateTime nextWeeklyResetAt({DateTime? now}) {
    final d = now ?? DateTime.now();
    // Dart weekday: Mon=1..Sun=7
    final daysToMon = (8 - d.weekday) % 7; // 到下個週一
    final nextMon = DateTime(d.year, d.month, d.day).add(Duration(days: daysToMon));
    // 若今天就是週一，且已過 00:00，還是要算下週一
    final isTodayMon = d.weekday == DateTime.monday;
    final base = isTodayMon ? nextMon.add(const Duration(days: 7)) : nextMon;
    return DateTime(base.year, base.month, base.day, 0, 0, 0);
  }

  /// 下次「每月」重置時間（每月 1 號 00:00）
  static DateTime nextMonthlyResetAt({DateTime? now}) {
    final d = now ?? DateTime.now();
    final firstThisMonth = DateTime(d.year, d.month, 1);
    final firstNextMonth = (d.month == 12) ? DateTime(d.year + 1, 1, 1) : DateTime(d.year, d.month + 1, 1);
    // 若已經在本月 1 號且過 00:00，仍算下月 1 號
    if (d.isAfter(firstThisMonth)) return DateTime(firstNextMonth.year, firstNextMonth.month, 1, 0, 0, 0);
    return DateTime(firstThisMonth.year, firstThisMonth.month, 1, 0, 0, 0);
  }

  // ======================================================
  // Date helpers
  // ======================================================

  static String _yyyyMmDd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _yyyyMm(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  /// ISO Week ID: "YYYY-Www"
  static String _isoWeekId(DateTime date) {
    final iso = _isoWeek(date);
    return '${iso.year}-W${iso.week.toString().padLeft(2, '0')}';
  }

  /// ISO week calculation (week starts Monday, week 1 contains Jan 4)
  static IsoWeek _isoWeek(DateTime date) {
    // Convert to UTC noon to avoid DST edge cases
    final d = DateTime.utc(date.year, date.month, date.day, 12);
    // Thursday of this week
    final thursday = d.add(Duration(days: 3 - ((d.weekday + 6) % 7)));
    final isoYear = thursday.year;
    final jan4 = DateTime.utc(isoYear, 1, 4, 12);
    final week1Thursday = jan4.add(Duration(days: 3 - ((jan4.weekday + 6) % 7)));
    final diffDays = thursday.difference(week1Thursday).inDays;
    final week = 1 + (diffDays ~/ 7);
    return IsoWeek(year: isoYear, week: week);
  }
}

// ======================================================
// Models
// ======================================================

class FriendModel {
  final String id;
  final String name;
  final String initials;
  final int colorValue;
  final bool online;

  const FriendModel({
    required this.id,
    required this.name,
    required this.initials,
    required this.colorValue,
    required this.online,
  });

  factory FriendModel.me() => const FriendModel(
        id: 'me',
        name: '我',
        initials: '我',
        colorValue: 0xFF1976D2,
        online: true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'initials': initials,
        'colorValue': colorValue,
        'online': online,
      };

  factory FriendModel.fromJson(Map<String, dynamic> m) => FriendModel(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        initials: (m['initials'] ?? '').toString(),
        colorValue: (m['colorValue'] is int) ? (m['colorValue'] as int) : 0xFF1976D2,
        online: m['online'] == true,
      );
}

class FriendRequestModel {
  final String id;
  final String fromName;
  final String fromInitials;
  final int fromColorValue;
  final String message;
  final DateTime createdAt;

  FriendRequestModel({
    required this.id,
    required this.fromName,
    required this.fromInitials,
    required this.fromColorValue,
    required this.message,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromName': fromName,
        'fromInitials': fromInitials,
        'fromColorValue': fromColorValue,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FriendRequestModel.fromJson(Map<String, dynamic> m) => FriendRequestModel(
        id: (m['id'] ?? '').toString(),
        fromName: (m['fromName'] ?? '').toString(),
        fromInitials: (m['fromInitials'] ?? '').toString(),
        fromColorValue: (m['fromColorValue'] is int) ? (m['fromColorValue'] as int) : 0xFF7E57C2,
        message: (m['message'] ?? '').toString(),
        createdAt: DateTime.tryParse((m['createdAt'] ?? '').toString()) ?? DateTime.now(),
      );
}

class DailyStateModel {
  final String date; // yyyy-MM-dd
  final bool signedToday;
  final int todayDone;
  final int points;
  final int streakDays;
  final String? pollAnswer;

  const DailyStateModel({
    required this.date,
    required this.signedToday,
    required this.todayDone,
    required this.points,
    required this.streakDays,
    required this.pollAnswer,
  });

  factory DailyStateModel.todayDefault() {
    final now = DateTime.now();
    final d =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return DailyStateModel(
      date: d,
      signedToday: false,
      todayDone: 0,
      points: 120,
      streakDays: 1,
      pollAnswer: null,
    );
  }

  DailyStateModel copyWith({
    String? date,
    bool? signedToday,
    int? todayDone,
    int? points,
    int? streakDays,
    String? pollAnswer,
  }) {
    return DailyStateModel(
      date: date ?? this.date,
      signedToday: signedToday ?? this.signedToday,
      todayDone: todayDone ?? this.todayDone,
      points: points ?? this.points,
      streakDays: streakDays ?? this.streakDays,
      pollAnswer: pollAnswer ?? this.pollAnswer,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'signedToday': signedToday,
        'todayDone': todayDone,
        'points': points,
        'streakDays': streakDays,
        'pollAnswer': pollAnswer,
      };

  factory DailyStateModel.fromJson(Map<String, dynamic> m) => DailyStateModel(
        date: (m['date'] ?? '').toString(),
        signedToday: m['signedToday'] == true,
        todayDone: (m['todayDone'] is int) ? (m['todayDone'] as int) : 0,
        points: (m['points'] is int) ? (m['points'] as int) : 0,
        streakDays: (m['streakDays'] is int) ? (m['streakDays'] as int) : 1,
        pollAnswer: m['pollAnswer']?.toString(),
      );
}

class IsoWeek {
  final int year;
  final int week;

  const IsoWeek({required this.year, required this.week});
}

enum ResetScope { weekly, monthly }

class ResetResult {
  final bool didResetWeekly;
  final bool didResetMonthly;

  const ResetResult({
    required this.didResetWeekly,
    required this.didResetMonthly,
  });
}
