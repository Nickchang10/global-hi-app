import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firestore_mock_service.dart';

/// ✅ DailyMissionService（完整版｜可編譯｜已移除 FirestoreMockService.instance 依賴）
/// ------------------------------------------------------------
/// - 不依賴 FirestoreMockService.instance
/// - 支援注入 FirestoreMockService（也可預設 new 一個）
/// - 每日任務：以「uid + 當日日期」保存進度到 SharedPreferences
/// - 完成任務後：嘗試呼叫 mock 的 addPoints / addNotification（若不存在則忽略）
/// ------------------------------------------------------------
class DailyMissionService extends ChangeNotifier {
  DailyMissionService({FirestoreMockService? store})
    : _store = store ?? FirestoreMockService();

  final FirestoreMockService _store;

  bool _loading = false;
  String? _uid;
  String _dayKey = _todayKey();

  final List<DailyMission> _missions = [];

  bool get loading => _loading;
  String? get uid => _uid;
  String get dayKey => _dayKey;
  List<DailyMission> get missions => List.unmodifiable(_missions);

  /// 初始化 / 切換使用者
  Future<void> init({required String uid}) async {
    _uid = uid;
    _dayKey = _todayKey();
    await _ensureMissionsLoaded();
  }

  /// 重新載入（例如隔天、或手動刷新）
  Future<void> reload() async {
    if (_uid == null) return;
    _dayKey = _todayKey();
    await _ensureMissionsLoaded(force: true);
  }

  /// 回傳今日任務（如果尚未 init，回傳空）
  Future<List<DailyMission>> getTodayMissions() async {
    if (_uid == null) return missions;
    await _ensureMissionsLoaded();
    return missions;
  }

  /// 針對某個任務 +progress（預設 +1）
  Future<void> addProgress(String missionId, {int delta = 1}) async {
    if (_uid == null) return;
    await _ensureMissionsLoaded();

    final idx = _missions.indexWhere((m) => m.id == missionId);
    if (idx < 0) return;

    final m = _missions[idx];
    if (m.completed) return;

    final next = m.copyWith(progress: (m.progress + delta).clamp(0, m.target));
    _missions[idx] = next;

    // 完成判斷
    if (next.progress >= next.target && !next.completed) {
      _missions[idx] = next.copyWith(
        completed: true,
        completedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await _saveToPrefs();

      // 發點 + 通知（若 mock service 沒有這些方法，也不會編譯錯）
      await _tryAwardPoints(_uid!, next.rewardPoints);
      await _tryAddNotification(
        _uid!,
        title: '每日任務完成',
        body: '你完成了「${next.title}」，獲得 ${next.rewardPoints} 點！',
        type: 'mission',
      );

      notifyListeners();
      return;
    }

    await _saveToPrefs();
    notifyListeners();
  }

  /// 直接標記完成（通常 debug 或特殊任務用）
  Future<void> markCompleted(String missionId) async {
    if (_uid == null) return;
    await _ensureMissionsLoaded();

    final idx = _missions.indexWhere((m) => m.id == missionId);
    if (idx < 0) return;

    final m = _missions[idx];
    if (m.completed) return;

    _missions[idx] = m.copyWith(
      progress: m.target,
      completed: true,
      completedAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    await _saveToPrefs();
    await _tryAwardPoints(_uid!, m.rewardPoints);
    await _tryAddNotification(
      _uid!,
      title: '每日任務完成',
      body: '你完成了「${m.title}」，獲得 ${m.rewardPoints} 點！',
      type: 'mission',
    );

    notifyListeners();
  }

  // -------------------------
  // Internal
  // -------------------------

  Future<void> _ensureMissionsLoaded({bool force = false}) async {
    if (_uid == null) return;

    // 如果已載入且不是強制，就不重複
    if (!force && _missions.isNotEmpty) return;

    _loading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _prefsKey(_uid!, _dayKey);

      final raw = prefs.getString(key);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _missions
            ..clear()
            ..addAll(
              decoded.map(
                (e) => DailyMission.fromMap(Map<String, dynamic>.from(e)),
              ),
            );
        }
      }

      // 若 prefs 沒資料 -> 建立預設任務
      if (_missions.isEmpty) {
        _missions
          ..clear()
          ..addAll(_defaultMissions());
        await _saveToPrefs();
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _saveToPrefs() async {
    if (_uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(_uid!, _dayKey);
    final data = jsonEncode(_missions.map((e) => e.toMap()).toList());
    await prefs.setString(key, data);
  }

  List<DailyMission> _defaultMissions() {
    // 你可以依產品邏輯調整（看商品、簽到、分享、下單、抽獎…）
    // ✅ 修正 prefer_const_constructors：回傳 const list（DailyMission 也會是 const 建構）
    return const <DailyMission>[
      DailyMission(
        id: 'signin',
        title: '每日簽到',
        description: '完成一次簽到',
        rewardPoints: 10,
        target: 1,
        progress: 0,
        iconCodePoint:
            0xe8d0, // Icons.check_circle_outline 的 code point（不強依賴 Icons）
      ),
      DailyMission(
        id: 'browse_products',
        title: '逛逛商城',
        description: '瀏覽商品 5 次',
        rewardPoints: 15,
        target: 5,
        progress: 0,
        iconCodePoint: 0xe59c, // Icons.storefront 的 code point（近似）
      ),
      DailyMission(
        id: 'share',
        title: '分享活動',
        description: '分享一次活動/商品給朋友',
        rewardPoints: 20,
        target: 1,
        progress: 0,
        iconCodePoint: 0xe80d, // Icons.share 的 code point（近似）
      ),
      DailyMission(
        id: 'lottery',
        title: '參加抽獎',
        description: '參加一次抽獎活動',
        rewardPoints: 25,
        target: 1,
        progress: 0,
        iconCodePoint: 0xe3d2, // Icons.casino 的 code point（近似）
      ),
    ];
  }

  Future<void> _tryAwardPoints(String uid, int points) async {
    final d = _store as dynamic;
    try {
      final r = d.addPoints(uid, points);
      if (r is Future) await r;
    } catch (_) {
      // 若 mock service 尚未實作 addPoints，直接忽略
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
      // 若 mock service 尚未實作 addNotification，直接忽略
    }
  }

  static String _prefsKey(String uid, String dayKey) =>
      'daily_missions::$uid::$dayKey';

  static String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}

/// ✅ DailyMission model（放同檔，避免你專案缺 model 又卡編譯）
@immutable
class DailyMission {
  const DailyMission({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardPoints,
    required this.target,
    required this.progress,
    this.completed = false,
    this.completedAtMs,
    this.iconCodePoint,
  });

  final String id;
  final String title;
  final String description;
  final int rewardPoints;

  final int target;
  final int progress;

  final bool completed;
  final int? completedAtMs;

  /// 不強依賴 Icons（避免 import material icons 也可以），需要 icon 時用 IconData(codePoint, fontFamily: 'MaterialIcons')
  final int? iconCodePoint;

  DailyMission copyWith({
    String? id,
    String? title,
    String? description,
    int? rewardPoints,
    int? target,
    int? progress,
    bool? completed,
    int? completedAtMs,
    int? iconCodePoint,
  }) {
    return DailyMission(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      target: target ?? this.target,
      progress: progress ?? this.progress,
      completed: completed ?? this.completed,
      completedAtMs: completedAtMs ?? this.completedAtMs,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'rewardPoints': rewardPoints,
    'target': target,
    'progress': progress,
    'completed': completed,
    'completedAtMs': completedAtMs,
    'iconCodePoint': iconCodePoint,
  };

  factory DailyMission.fromMap(Map<String, dynamic> map) {
    return DailyMission(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      rewardPoints: _toInt(map['rewardPoints']),
      target: _toInt(map['target']),
      progress: _toInt(map['progress']),
      completed: map['completed'] == true,
      completedAtMs: map['completedAtMs'] is int
          ? map['completedAtMs'] as int
          : null,
      iconCodePoint: map['iconCodePoint'] is int
          ? map['iconCodePoint'] as int
          : null,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
