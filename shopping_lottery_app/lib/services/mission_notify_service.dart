import 'package:flutter/foundation.dart';

import 'firestore_mock_service.dart';

/// ✅ MissionNotifyService（完整版｜可編譯｜已移除 FirestoreMockService.instance）
/// ------------------------------------------------------------
/// 目的：
/// - 任務/活動相關通知統一由這裡推送（寫入 mock 通知中心 / 發點）
/// - 不依賴 FirestoreMockService.instance（因為你目前沒有 singleton）
/// - mock service 若尚未實作 addNotification/addPoints 也不會爆（dynamic try/catch）
///
/// 常見用法：
/// - init(uid)
/// - missionCompleted(...), missionProgress(...), dailyReset(...), push(...)
/// ------------------------------------------------------------
class MissionNotifyService extends ChangeNotifier {
  MissionNotifyService({FirestoreMockService? store})
    : _store = store ?? FirestoreMockService();

  /// （可選）提供一個 service singleton，避免你其他頁面寫成 MissionNotifyService.instance 又報錯
  static final MissionNotifyService instance = MissionNotifyService();

  final FirestoreMockService _store;

  String? _uid;
  bool _loading = false;

  bool get loading => _loading;
  String? get uid => _uid;

  /// 最近推送的通知（純記憶體，方便 debug 或 UI 顯示；不依賴其他 service）
  final List<Map<String, dynamic>> _recent = [];
  List<Map<String, dynamic>> get recent => List.unmodifiable(_recent);

  /// 初始化 / 切換使用者
  Future<void> init({required String uid}) async {
    _uid = uid;
    notifyListeners();
  }

  /// 推送通用通知（寫入 mock 通知中心）
  Future<void> push({
    String? uid,
    required String title,
    required String body,
    String type = 'mission',
    Map<String, dynamic>? data,
  }) async {
    final u = uid ?? _uid;
    if (u == null) return;

    _loading = true;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'title': title,
        'body': body,
        'type': type,
        'data': data ?? {},
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
      };

      _recent.insert(0, payload);
      if (_recent.length > 50) _recent.removeLast();

      await _tryAddNotification(u, payload);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 任務進度通知（例如 +1 / 已達成門檻）
  Future<void> missionProgress({
    String? uid,
    required String missionId,
    required String missionTitle,
    required int progress,
    required int target,
  }) async {
    final pct = target <= 0
        ? 0
        : ((progress / target) * 100).clamp(0, 100).toInt();
    await push(
      uid: uid,
      title: '任務進度更新',
      body: '「$missionTitle」進度 $progress / $target（$pct%）',
      type: 'mission_progress',
      data: {
        'missionId': missionId,
        'progress': progress,
        'target': target,
        'percent': pct,
      },
    );
  }

  /// 任務完成通知 + 發點（若 points=0 則只通知不發點）
  Future<void> missionCompleted({
    String? uid,
    required String missionId,
    required String missionTitle,
    int rewardPoints = 0,
  }) async {
    final u = uid ?? _uid;
    if (u == null) return;

    if (rewardPoints > 0) {
      await _tryAwardPoints(u, rewardPoints);
    }

    await push(
      uid: u,
      title: '任務完成 🎉',
      body: rewardPoints > 0
          ? '你完成了「$missionTitle」，獲得 $rewardPoints 點！'
          : '你完成了「$missionTitle」！',
      type: 'mission_completed',
      data: {'missionId': missionId, 'rewardPoints': rewardPoints},
    );
  }

  /// 每日重置 / 新任務上線（給任務中心用）
  Future<void> dailyReset({
    String? uid,
    String title = '每日任務更新',
    String body = '新的每日任務已刷新，快去完成拿點數吧！',
  }) async {
    await push(
      uid: uid,
      title: title,
      body: body,
      type: 'mission_daily_reset',
      data: {'dayKey': _todayKey()},
    );
  }

  /// 清除 recent（不影響 Firestore/Mock）
  void clearRecent() {
    _recent.clear();
    notifyListeners();
  }

  // -------------------------
  // Internal (safe dynamic)
  // -------------------------

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
    String uid,
    Map<String, dynamic> payload,
  ) async {
    final d = _store as dynamic;
    try {
      final r = d.addNotification(uid, payload);
      if (r is Future) await r;
    } catch (_) {
      // mock service 沒實作 addNotification -> 忽略
    }
  }

  static String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}
