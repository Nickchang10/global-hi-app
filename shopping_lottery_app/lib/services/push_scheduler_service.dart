import 'dart:async';
import 'package:flutter/foundation.dart';

import 'mock_fcm_service.dart';

/// ✅ PushSchedulerService（推播排程｜完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正重點：
/// - ✅ 修正 library_private_types_in_public_api：
///   jobs getter 回傳型別改為公開型別 PushJob（原 _PushJob）
/// - 所有 schedule/push API 的 type 都不再 required（避免 missing_required_argument）
/// - 內建預設 type = 'general'
/// - 使用 MockFcmService 發送（你已修成 type 可選也不會炸）
/// - 支援：一次性排程、週期排程、取消、立即觸發、列出任務
/// ------------------------------------------------------------
class PushSchedulerService extends ChangeNotifier {
  PushSchedulerService._();

  static final PushSchedulerService instance = PushSchedulerService._();

  final MockFcmService _fcm = MockFcmService.instance;

  final Map<String, PushJob> _jobs = {};
  Timer? _tick;

  bool _started = false;

  /// ✅ 這裡回傳 public type（避免 lint）
  List<PushJob> get jobs =>
      _jobs.values.toList()
        ..sort((a, b) => a.nextRunAtMs.compareTo(b.nextRunAtMs));

  /// 啟動排程器（可多次呼叫，不會重複啟動）
  void start() {
    if (_started) return;
    _started = true;

    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _pump());
  }

  void stop() {
    _tick?.cancel();
    _tick = null;
    _started = false;
  }

  /// ✅ 一次性排程（到點觸發一次後移除）
  /// type ✅ 不再 required
  String scheduleOnce({
    required String uid,
    required String title,
    required String body,
    required DateTime runAt,
    String? type, // ✅ 可選
    Map<String, dynamic>? data,
  }) {
    start();
    final id = _genId('job');
    _jobs[id] = PushJob(
      id: id,
      uid: uid,
      title: title,
      body: body,
      type: _normType(type),
      data: data ?? const {},
      nextRunAtMs: runAt.millisecondsSinceEpoch,
      intervalMs: 0,
      enabled: true,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
    return id;
  }

  /// ✅ 週期排程（每 interval 觸發）
  /// type ✅ 不再 required
  String scheduleRecurring({
    required String uid,
    required String title,
    required String body,
    required Duration interval,
    DateTime? firstRunAt,
    String? type, // ✅ 可選
    Map<String, dynamic>? data,
  }) {
    start();
    final id = _genId('job');
    final now = DateTime.now();
    final first = firstRunAt ?? now.add(interval);

    _jobs[id] = PushJob(
      id: id,
      uid: uid,
      title: title,
      body: body,
      type: _normType(type),
      data: data ?? const {},
      nextRunAtMs: first.millisecondsSinceEpoch,
      intervalMs: interval.inMilliseconds,
      enabled: true,
      createdAtMs: now.millisecondsSinceEpoch,
    );
    notifyListeners();
    return id;
  }

  /// ✅ 立刻推送（不排程）
  /// type ✅ 不再 required
  Future<void> pushNow({
    required String uid,
    required String title,
    required String body,
    String? type, // ✅ 可選
    Map<String, dynamic>? data,
  }) async {
    await _fcm.pushToUser(
      uid,
      title: title,
      body: body,
      type: _normType(type),
      data: data ?? const {},
    );
  }

  /// 啟用/停用任務
  void setEnabled(String jobId, bool enabled) {
    final j = _jobs[jobId];
    if (j == null) return;
    _jobs[jobId] = j.copyWith(enabled: enabled);
    notifyListeners();
  }

  /// 取消任務
  void cancel(String jobId) {
    _jobs.remove(jobId);
    notifyListeners();
  }

  /// 清空全部
  void clear() {
    _jobs.clear();
    notifyListeners();
  }

  /// 內部：檢查到期任務並觸發
  Future<void> _pump() async {
    if (_jobs.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final due = _jobs.values
        .where((j) => j.enabled && j.nextRunAtMs <= nowMs)
        .toList();
    if (due.isEmpty) return;

    for (final j in due) {
      try {
        await _fcm.pushToUser(
          j.uid,
          title: j.title,
          body: j.body,
          type: j.type,
          data: {'jobId': j.id, 'scheduledAtMs': j.nextRunAtMs, ...j.data},
        );
      } catch (_) {
        // mock 推播失敗就略過，不讓 scheduler crash
      }

      // 一次性：移除；週期：更新 nextRun
      if (j.intervalMs <= 0) {
        _jobs.remove(j.id);
      } else {
        _jobs[j.id] = j.copyWith(nextRunAtMs: j.nextRunAtMs + j.intervalMs);
      }
    }

    notifyListeners();
  }

  String _normType(String? type) {
    final t = (type ?? '').trim();
    return t.isEmpty ? 'general' : t;
  }

  String _genId(String prefix) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final r = (ts % 100000).toString().padLeft(5, '0');
    return '${prefix}_$ts$r';
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

@immutable
class PushJob {
  const PushJob({
    required this.id,
    required this.uid,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.nextRunAtMs,
    required this.intervalMs,
    required this.enabled,
    required this.createdAtMs,
  });

  final String id;
  final String uid;
  final String title;
  final String body;

  /// ✅ general / mission / order / promo / points ...
  final String type;

  final Map<String, dynamic> data;

  /// 下一次觸發時間（ms）
  final int nextRunAtMs;

  /// 週期（ms），0 表示一次性
  final int intervalMs;

  final bool enabled;
  final int createdAtMs;

  PushJob copyWith({
    String? id,
    String? uid,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? data,
    int? nextRunAtMs,
    int? intervalMs,
    bool? enabled,
    int? createdAtMs,
  }) {
    return PushJob(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      nextRunAtMs: nextRunAtMs ?? this.nextRunAtMs,
      intervalMs: intervalMs ?? this.intervalMs,
      enabled: enabled ?? this.enabled,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }
}
