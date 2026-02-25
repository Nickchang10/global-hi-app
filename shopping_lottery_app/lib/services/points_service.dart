import 'package:flutter/foundation.dart';

import 'firestore_mock_service.dart';
import 'mock_fcm_service.dart';

/// ✅ PointsService（點數服務｜完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正重點：
/// - 所有需要 type 的地方都提供預設值，避免 missing_required_argument
/// - 不依賴 FirestoreMockService.instance（你的 mock 沒有 singleton）
/// - 若 FirestoreMockService 未實作方法，會 fallback 用記憶體資料，不影響編譯
/// - 內建交易紀錄與通知推送（mock_fcm_service 的 type 已可選）
/// ------------------------------------------------------------
class PointsService extends ChangeNotifier {
  PointsService({FirestoreMockService? store, MockFcmService? fcm})
    : _store = store ?? FirestoreMockService(),
      _fcm = fcm ?? MockFcmService.instance;

  static final PointsService instance = PointsService();

  final FirestoreMockService _store;
  final MockFcmService _fcm;

  String? _uid;
  bool _loading = false;
  String? _error;

  int _balance = 0;
  final List<PointsTxn> _txns = [];

  bool get loading => _loading;
  String? get error => _error;
  String? get uid => _uid;

  int get balance => _balance;
  List<PointsTxn> get history => List.unmodifiable(_txns);

  /// 初始化（指定使用者）
  Future<void> init({required String uid}) async {
    _uid = uid;
    await load();
  }

  /// 載入點數（若 mock 有提供 getUserPoints / userPoints 等就用，否則用本地 balance）
  Future<void> load() async {
    final u = _uid;
    if (u == null) return;

    _setLoading(true);
    _error = null;

    try {
      final points = await _tryFetchPoints(u);
      _balance = points;

      // 如果 mock 有歷史紀錄可取，就取；沒有就保留本地
      final list = await _tryFetchHistory(u);
      if (list.isNotEmpty) {
        _txns
          ..clear()
          ..addAll(list);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refresh() => load();

  // ------------------------------------------------------------
  // 核心操作
  // ------------------------------------------------------------

  /// 加點（type 預設 earn）
  Future<void> addPoints(
    int points, {
    String reason = '點數入帳',
    String type = 'earn', // ✅ 預設值，避免缺參數
    Map<String, dynamic>? data,
    bool notify = true,
  }) async {
    final u = _uid;
    if (u == null) return;

    if (points <= 0) return;

    _balance += points;

    final txn = PointsTxn(
      id: _genId(),
      uid: u,
      delta: points,
      reason: reason,
      type: type, // ✅ 永遠有值
      data: data ?? const {},
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    _txns.insert(0, txn);
    if (_txns.length > 300) _txns.removeLast();

    notifyListeners();

    await _tryPersistAddPoints(u, points, txn);

    if (notify) {
      await _fcm.pushToUser(
        u,
        title: '點數入帳 +$points',
        body: reason,
        type: 'points', // ✅ 這裡也明確傳 type，兼容所有舊版本
        data: {
          'delta': points,
          'reason': reason,
          'txnId': txn.id,
          'txnType': type,
          ...?data,
        },
      );
    }
  }

  /// 扣點（type 預設 spend）
  Future<bool> spendPoints(
    int points, {
    String reason = '點數扣除',
    String type = 'spend', // ✅ 預設值
    Map<String, dynamic>? data,
    bool notify = true,
  }) async {
    final u = _uid;
    if (u == null) return false;

    if (points <= 0) return false;
    if (_balance < points) return false;

    _balance -= points;

    final txn = PointsTxn(
      id: _genId(),
      uid: u,
      delta: -points,
      reason: reason,
      type: type, // ✅ 永遠有值
      data: data ?? const {},
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    _txns.insert(0, txn);
    if (_txns.length > 300) _txns.removeLast();

    notifyListeners();

    await _tryPersistSpendPoints(u, points, txn);

    if (notify) {
      await _fcm.pushToUser(
        u,
        title: '點數扣除 -$points',
        body: reason,
        type: 'points',
        data: {
          'delta': -points,
          'reason': reason,
          'txnId': txn.id,
          'txnType': type,
          ...?data,
        },
      );
    }

    return true;
  }

  /// 轉贈點數（type 預設 transfer）
  Future<bool> transferPoints({
    required String toUserId,
    required int points,
    String reason = '點數轉贈',
    String type = 'transfer', // ✅ 預設值
    Map<String, dynamic>? data,
  }) async {
    final from = _uid;
    if (from == null) return false;
    if (toUserId.trim().isEmpty) return false;
    if (points <= 0) return false;
    if (_balance < points) return false;

    // 扣自己
    final ok = await spendPoints(
      points,
      reason: '$reason（轉出給 $toUserId）',
      type: type,
      data: {'to': toUserId, ...?data},
      notify: true,
    );
    if (!ok) return false;

    // 嘗試讓 mock store 對方也入帳（若 mock 有能力）
    await _tryPersistTransferToOther(
      toUserId,
      points,
      from: from,
      reason: reason,
      type: type,
      data: data,
    );

    // 對方通知（若你想要）
    await _fcm.pushToUser(
      toUserId,
      title: '收到點數 +$points',
      body: '$reason（來自 $from）',
      type: 'points',
      data: {
        'delta': points,
        'from': from,
        'reason': reason,
        'txnType': type,
        ...?data,
      },
    );

    return true;
  }

  /// 清除本地歷史（debug）
  void clearLocalHistory() {
    _txns.clear();
    notifyListeners();
  }

  // ------------------------------------------------------------
  // Internal: safe dynamic calls (避免 mock 沒方法就炸)
  // ------------------------------------------------------------

  Future<int> _tryFetchPoints(String uid) async {
    final d = _store as dynamic;

    // 1) getUserPoints(uid)
    try {
      final r = d.getUserPoints(uid);
      final v = r is Future ? await r : r;
      final n = _toInt(v);
      return n;
    } catch (_) {}

    // 2) userPoints[uid]
    try {
      final m = d.userPoints;
      if (m is Map && m.containsKey(uid)) {
        return _toInt(m[uid]);
      }
    } catch (_) {}

    // 3) points / balance
    try {
      final v = d.points;
      return _toInt(v);
    } catch (_) {}

    return _balance;
  }

  Future<List<PointsTxn>> _tryFetchHistory(String uid) async {
    final d = _store as dynamic;

    // 1) getPointsHistory(uid)
    try {
      final r = d.getPointsHistory(uid);
      final v = r is Future ? await r : r;
      if (v is List) {
        return v
            .map(
              (e) => e is PointsTxn
                  ? e
                  : (e is Map
                        ? PointsTxn.fromMap(Map<String, dynamic>.from(e))
                        : null),
            )
            .whereType<PointsTxn>()
            .toList();
      }
    } catch (_) {}

    return const [];
  }

  Future<void> _tryPersistAddPoints(
    String uid,
    int points,
    PointsTxn txn,
  ) async {
    final d = _store as dynamic;

    // mock 若有 addPoints(uid, points)
    try {
      final r = d.addPoints(uid, points);
      if (r is Future) await r;
    } catch (_) {}

    // mock 若有 addPointsTxn(uid, map)
    try {
      final r = d.addPointsTxn(uid, txn.toMap());
      if (r is Future) await r;
    } catch (_) {}
  }

  Future<void> _tryPersistSpendPoints(
    String uid,
    int points,
    PointsTxn txn,
  ) async {
    final d = _store as dynamic;

    // mock 若有 spendPoints(uid, points)
    try {
      final r = d.spendPoints(uid, points);
      if (r is Future) await r;
    } catch (_) {}

    // 或沿用 addPoints(uid, -points)
    try {
      final r = d.addPoints(uid, -points);
      if (r is Future) await r;
    } catch (_) {}

    try {
      final r = d.addPointsTxn(uid, txn.toMap());
      if (r is Future) await r;
    } catch (_) {}
  }

  Future<void> _tryPersistTransferToOther(
    String toUserId,
    int points, {
    required String from,
    required String reason,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    final d = _store as dynamic;

    // 讓對方入帳（如果 mock 支援）
    try {
      final r = d.addPoints(toUserId, points);
      if (r is Future) await r;
    } catch (_) {}

    // 若 mock 支援 addPointsTxn(toUserId, map)
    try {
      final txn = PointsTxn(
        id: _genId(),
        uid: toUserId,
        delta: points,
        reason: '$reason（來自 $from）',
        type: type,
        data: {'from': from, ...?data},
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      final r = d.addPointsTxn(toUserId, txn.toMap());
      if (r is Future) await r;
    } catch (_) {}
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String _genId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final r = (ts % 100000).toString().padLeft(5, '0');
    return 'ptx_$ts$r';
  }
}

/// ✅ 點數交易紀錄（同檔提供，避免缺 model 又卡編譯）
@immutable
class PointsTxn {
  const PointsTxn({
    required this.id,
    required this.uid,
    required this.delta,
    required this.reason,
    required this.type,
    required this.data,
    required this.createdAtMs,
  });

  final String id;
  final String uid;

  /// 正數＝入帳，負數＝扣除
  final int delta;

  /// 顯示給使用者看的原因
  final String reason;

  /// ✅ 類型：earn / spend / transfer / adjust / reward ...
  final String type;

  final Map<String, dynamic> data;
  final int createdAtMs;

  Map<String, dynamic> toMap() => {
    'id': id,
    'uid': uid,
    'delta': delta,
    'reason': reason,
    'type': type,
    'data': data,
    'createdAtMs': createdAtMs,
  };

  factory PointsTxn.fromMap(Map<String, dynamic> map) {
    return PointsTxn(
      id: (map['id'] ?? '').toString(),
      uid: (map['uid'] ?? '').toString(),
      delta: _toInt(map['delta']),
      reason: (map['reason'] ?? '').toString(),
      type: (map['type'] ?? 'adjust').toString(), // ✅ fallback 預設
      data: map['data'] is Map
          ? Map<String, dynamic>.from(map['data'] as Map)
          : const {},
      createdAtMs: _toInt(map['createdAtMs']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
