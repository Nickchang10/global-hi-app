import 'package:flutter/foundation.dart';

import 'firestore_mock_service.dart';

/// ✅ MissionService（完整版｜可編譯｜已移除 FirestoreMockService.instance）
/// ------------------------------------------------------------
/// - 任務系統集中管理（每日/成就/活動任務皆可用）
/// - 不依賴 FirestoreMockService.instance（因為你目前沒有 singleton）
/// - 支援注入 FirestoreMockService（或預設 new 一個）
/// - 提供常用 API，盡量覆蓋你各種 page 可能在呼叫的方法名
/// - mock service 若尚未實作 addPoints/addNotification/saveMissionProgress 等，不會卡編譯（dynamic try/catch）
/// ------------------------------------------------------------
class MissionService extends ChangeNotifier {
  MissionService({FirestoreMockService? store})
    : _store = store ?? FirestoreMockService();

  /// ✅ 提供 service singleton（避免你其他檔案寫 MissionService.instance）
  static final MissionService instance = MissionService();

  final FirestoreMockService _store;

  String? _uid;
  bool _loading = false;
  String? _error;

  final List<AppMission> _missions = [];
  final Map<String, MissionProgress> _progressByMissionId = {};

  bool get loading => _loading;
  String? get error => _error;
  String? get uid => _uid;

  List<AppMission> get missions => List.unmodifiable(_missions);

  /// 取得某任務進度（不存在則回預設）
  MissionProgress progressOf(String missionId) {
    return _progressByMissionId[missionId] ?? MissionProgress.empty(missionId);
  }

  /// 已完成任務數
  int get completedCount =>
      _missions.where((m) => progressOf(m.id).completed).length;

  /// 未完成任務數
  int get pendingCount => _missions.length - completedCount;

  /// 初始化（指定使用者）
  Future<void> init({required String uid}) async {
    _uid = uid;
    await load();
  }

  /// 載入任務（若 FirestoreMockService 有提供 getMissions 會用它；否則用預設任務）
  Future<void> load() async {
    final u = _uid;
    if (u == null) return;

    _setLoading(true);
    _error = null;

    try {
      final fetched = await _tryFetchMissions(u);
      _missions
        ..clear()
        ..addAll(fetched);

      // 嘗試載入任務進度（若 mock 有）
      final prog = await _tryFetchProgress(u);
      _progressByMissionId
        ..clear()
        ..addAll(prog);

      // 若沒有任何 progress，就初始化預設
      if (_progressByMissionId.isEmpty) {
        for (final m in _missions) {
          _progressByMissionId[m.id] = MissionProgress.empty(m.id);
        }
      }
    } catch (e) {
      _error = e.toString();

      // fallback：至少要有任務
      if (_missions.isEmpty) {
        _missions
          ..clear()
          ..addAll(_defaultMissions());
        for (final m in _missions) {
          _progressByMissionId.putIfAbsent(
            m.id,
            () => MissionProgress.empty(m.id),
          );
        }
      }
    } finally {
      _setLoading(false);
    }
  }

  /// 重新整理（常見別名）
  Future<void> refresh() => load();
  Future<void> reload() => load();

  /// 增加任務進度（預設 +1）
  Future<void> addProgress(String missionId, {int delta = 1}) async {
    final u = _uid;
    if (u == null) return;

    final m = _missions
        .where((e) => e.id == missionId)
        .cast<AppMission?>()
        .firstOrNull;
    if (m == null) return;

    final cur = progressOf(missionId);
    if (cur.completed) return;

    final nextProgress = (cur.progress + delta).clamp(0, m.target);
    final isCompleted = nextProgress >= m.target;

    _progressByMissionId[missionId] = cur.copyWith(
      progress: nextProgress,
      completed: isCompleted,
      completedAtMs: isCompleted
          ? DateTime.now().millisecondsSinceEpoch
          : cur.completedAtMs,
    );

    notifyListeners();

    // 嘗試保存 progress（mock 若有）
    await _trySaveProgress(u, missionId, _progressByMissionId[missionId]!);

    // 完成時自動發獎（如果任務有 rewardPoints）
    if (isCompleted && m.rewardPoints > 0 && !cur.completed) {
      await _tryAwardPoints(u, m.rewardPoints);
      await _tryAddNotification(u, {
        'title': '任務完成 🎉',
        'body': '你完成了「${m.title}」，獲得 ${m.rewardPoints} 點！',
        'type': 'mission_completed',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
        'data': {'missionId': m.id, 'rewardPoints': m.rewardPoints},
      });
    }
  }

  /// 完成任務（直接設滿）
  Future<void> completeMission(String missionId) async {
    final m = _missions
        .where((e) => e.id == missionId)
        .cast<AppMission?>()
        .firstOrNull;
    if (m == null) return;
    await addProgress(missionId, delta: m.target);
  }

  /// 領取任務獎勵（若你 UI 有「按鈕領取」）
  Future<bool> claimReward(String missionId) async {
    final u = _uid;
    if (u == null) return false;

    final m = _missions
        .where((e) => e.id == missionId)
        .cast<AppMission?>()
        .firstOrNull;
    if (m == null) return false;

    final cur = progressOf(missionId);
    if (!cur.completed) return false;
    if (cur.rewardClaimed) return false;

    _progressByMissionId[missionId] = cur.copyWith(
      rewardClaimed: true,
      rewardClaimedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();

    if (m.rewardPoints > 0) {
      await _tryAwardPoints(u, m.rewardPoints);
    }

    await _tryAddNotification(u, {
      'title': '獎勵已領取',
      'body': '你已領取「${m.title}」獎勵：${m.rewardPoints} 點',
      'type': 'mission_reward_claimed',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'isRead': false,
      'data': {'missionId': m.id, 'rewardPoints': m.rewardPoints},
    });

    await _trySaveProgress(u, missionId, _progressByMissionId[missionId]!);
    return true;
  }

  /// 重置任務（debug / 測試用）
  Future<void> resetAll() async {
    final u = _uid;
    if (u == null) return;

    for (final m in _missions) {
      _progressByMissionId[m.id] = MissionProgress.empty(m.id);
      await _trySaveProgress(u, m.id, _progressByMissionId[m.id]!);
    }
    notifyListeners();
  }

  // -------------------------
  // Internal: Fetch & Save via mock (safe)
  // -------------------------

  Future<List<AppMission>> _tryFetchMissions(String uid) async {
    final d = _store as dynamic;

    // 1) mock 若有 getMissions(uid)
    try {
      final r = d.getMissions(uid);
      final data = r is Future ? await r : r;
      if (data is List) {
        final list = <AppMission>[];
        for (final e in data) {
          if (e is Map) {
            list.add(AppMission.fromMap(Map<String, dynamic>.from(e)));
          } else if (e is AppMission) {
            list.add(e);
          }
        }
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    // 2) mock 若有 missions 屬性
    try {
      final v = d.missions;
      if (v is List) {
        final list = <AppMission>[];
        for (final e in v) {
          if (e is Map) {
            list.add(AppMission.fromMap(Map<String, dynamic>.from(e)));
          } else if (e is AppMission) {
            list.add(e);
          }
        }
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    // fallback
    return _defaultMissions();
  }

  Future<Map<String, MissionProgress>> _tryFetchProgress(String uid) async {
    final d = _store as dynamic;

    // mock 若有 getMissionProgress(uid)
    try {
      final r = d.getMissionProgress(uid);
      final data = r is Future ? await r : r;

      if (data is Map) {
        final out = <String, MissionProgress>{};
        data.forEach((k, v) {
          final id = k.toString();
          if (v is Map) {
            out[id] = MissionProgress.fromMap(id, Map<String, dynamic>.from(v));
          } else if (v is MissionProgress) {
            out[id] = v;
          }
        });
        return out;
      }
    } catch (_) {}

    return {};
  }

  Future<void> _trySaveProgress(
    String uid,
    String missionId,
    MissionProgress progress,
  ) async {
    final d = _store as dynamic;

    // mock 若有 saveMissionProgress(uid, missionId, map)
    try {
      final r = d.saveMissionProgress(uid, missionId, progress.toMap());
      if (r is Future) await r;
      return;
    } catch (_) {}

    // mock 若有 setMissionProgress(uid, missionId, map)
    try {
      final r = d.setMissionProgress(uid, missionId, progress.toMap());
      if (r is Future) await r;
      return;
    } catch (_) {}

    // 沒有就忽略（不影響編譯）
  }

  Future<void> _tryAwardPoints(String uid, int points) async {
    final d = _store as dynamic;
    try {
      final r = d.addPoints(uid, points);
      if (r is Future) await r;
    } catch (_) {}
  }

  Future<void> _tryAddNotification(
    String uid,
    Map<String, dynamic> payload,
  ) async {
    final d = _store as dynamic;
    try {
      final r = d.addNotification(uid, payload);
      if (r is Future) await r;
    } catch (_) {}
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  List<AppMission> _defaultMissions() {
    // 你可依 Osmile 需求調整分類與任務內容
    return const [
      AppMission(
        id: 'signin',
        title: '每日簽到',
        description: '完成一次簽到',
        category: 'daily',
        target: 1,
        rewardPoints: 10,
      ),
      AppMission(
        id: 'browse_products',
        title: '逛逛商城',
        description: '瀏覽商品 5 次',
        category: 'daily',
        target: 5,
        rewardPoints: 15,
      ),
      AppMission(
        id: 'share_activity',
        title: '分享活動',
        description: '分享一次活動/商品給朋友',
        category: 'daily',
        target: 1,
        rewardPoints: 20,
      ),
      AppMission(
        id: 'join_lottery',
        title: '參加抽獎',
        description: '參加一次抽獎活動',
        category: 'event',
        target: 1,
        rewardPoints: 25,
      ),
    ];
  }
}

/// ✅ 任務模型（同檔提供，避免缺 model 又卡編譯）
@immutable
class AppMission {
  const AppMission({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.target,
    this.rewardPoints = 0,
    this.isActive = true,
    this.startAtMs,
    this.endAtMs,
    this.imageUrl,
    this.extra,
  });

  final String id;
  final String title;
  final String description;

  /// daily / achievement / event / points / ...
  final String category;

  final int target;
  final int rewardPoints;
  final bool isActive;

  final int? startAtMs;
  final int? endAtMs;

  final String? imageUrl;

  /// 任務額外資料（例如 deep link、商品 id、活動 id）
  final Map<String, dynamic>? extra;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'target': target,
    'rewardPoints': rewardPoints,
    'isActive': isActive,
    'startAtMs': startAtMs,
    'endAtMs': endAtMs,
    'imageUrl': imageUrl,
    'extra': extra ?? {},
  };

  factory AppMission.fromMap(Map<String, dynamic> map) {
    return AppMission(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      category: (map['category'] ?? 'daily').toString(),
      target: _toInt(map['target'], fallback: 1),
      rewardPoints: _toInt(map['rewardPoints']),
      isActive: map['isActive'] == null ? true : (map['isActive'] == true),
      startAtMs: map['startAtMs'] is int ? map['startAtMs'] as int : null,
      endAtMs: map['endAtMs'] is int ? map['endAtMs'] as int : null,
      imageUrl: map['imageUrl']?.toString(),
      extra: map['extra'] is Map
          ? Map<String, dynamic>.from(map['extra'] as Map)
          : null,
    );
  }

  static int _toInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }
}

/// ✅ 任務進度（同檔提供，避免缺 model 又卡編譯）
@immutable
class MissionProgress {
  const MissionProgress({
    required this.missionId,
    required this.progress,
    required this.completed,
    required this.completedAtMs,
    required this.rewardClaimed,
    required this.rewardClaimedAtMs,
  });

  final String missionId;
  final int progress;

  final bool completed;
  final int? completedAtMs;

  final bool rewardClaimed;
  final int? rewardClaimedAtMs;

  factory MissionProgress.empty(String missionId) => MissionProgress(
    missionId: missionId,
    progress: 0,
    completed: false,
    completedAtMs: null,
    rewardClaimed: false,
    rewardClaimedAtMs: null,
  );

  MissionProgress copyWith({
    int? progress,
    bool? completed,
    int? completedAtMs,
    bool? rewardClaimed,
    int? rewardClaimedAtMs,
  }) {
    return MissionProgress(
      missionId: missionId,
      progress: progress ?? this.progress,
      completed: completed ?? this.completed,
      completedAtMs: completedAtMs ?? this.completedAtMs,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
      rewardClaimedAtMs: rewardClaimedAtMs ?? this.rewardClaimedAtMs,
    );
  }

  Map<String, dynamic> toMap() => {
    'progress': progress,
    'completed': completed,
    'completedAtMs': completedAtMs,
    'rewardClaimed': rewardClaimed,
    'rewardClaimedAtMs': rewardClaimedAtMs,
  };

  factory MissionProgress.fromMap(String missionId, Map<String, dynamic> map) {
    return MissionProgress(
      missionId: missionId,
      progress: _toInt(map['progress']),
      completed: map['completed'] == true,
      completedAtMs: map['completedAtMs'] is int
          ? map['completedAtMs'] as int
          : null,
      rewardClaimed: map['rewardClaimed'] == true,
      rewardClaimedAtMs: map['rewardClaimedAtMs'] is int
          ? map['rewardClaimedAtMs'] as int
          : null,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

/// 小工具：firstOrNull（避免你 SDK 版本不同沒有這個）
extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
