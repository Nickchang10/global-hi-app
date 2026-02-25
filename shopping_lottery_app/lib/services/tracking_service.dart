// lib/services/tracking_service.dart
// ======================================================
// ✅ TrackingService（最終整合版｜Web 可編譯 + Mobile 可定位）
// ------------------------------------------------------
// 功能：
// - lastLocal / lastRemote
// - 歷史軌跡 history（可畫 polyline）
// - SharedPreferences 永續化（Web/Chrome 也可用）
// - geolocator 14.x 相容（LocationSettings 不用 const）
// - 提供 startLocalTracking() / stopLocalTracking()
// - 提供 setRemoteLocation()（手錶或伺服端同步位置）
// - 可呼叫 clearHistory()
// ------------------------------------------------------
// 相依：geolocator ^14.x、shared_preferences ^2.x
// Web：自動跳過 geolocator 實體追蹤，改用 Mock（避免權限/插件差異）
// ======================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ⚠️ 你必須在 pubspec.yaml 加上 geolocator 才能 resolve：
// geolocator: ^14.x
import 'package:geolocator/geolocator.dart';

/// ======================================================
/// ✅ 模型：TrackingPoint
/// ======================================================
class TrackingPoint {
  final double lat;
  final double lng;
  final DateTime time;
  final String source; // local / remote / history / mock

  const TrackingPoint({
    required this.lat,
    required this.lng,
    required this.time,
    required this.source,
  });

  Map<String, dynamic> toMap() => {
    'lat': lat,
    'lng': lng,
    'time': time.millisecondsSinceEpoch,
    'source': source,
  };

  factory TrackingPoint.fromMap(Map<String, dynamic> m) {
    DateTime dt = DateTime.now();
    final t = m['time'];

    if (t is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(t);
    } else if (t is num) {
      dt = DateTime.fromMillisecondsSinceEpoch(t.toInt());
    } else if (t is String) {
      final ms = int.tryParse(t);
      if (ms != null) {
        dt = DateTime.fromMillisecondsSinceEpoch(ms);
      } else {
        final iso = DateTime.tryParse(t);
        if (iso != null) dt = iso;
      }
    }

    // ✅ local identifier 不能用底線開頭：把 _toDouble 改名
    double toDoubleVal(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim()) ?? 0.0;
      return double.tryParse('$v') ?? 0.0;
    }

    return TrackingPoint(
      lat: toDoubleVal(m['lat']),
      lng: toDoubleVal(m['lng']),
      time: dt,
      source: (m['source'] ?? 'history').toString(),
    );
  }
}

/// ======================================================
/// ✅ TrackingService
/// ======================================================
class TrackingService extends ChangeNotifier {
  TrackingService._internal();
  static final TrackingService instance = TrackingService._internal();
  factory TrackingService() => instance;

  static const String _prefsKey = 'osmile_tracking_v2';

  bool _inited = false;
  bool get inited => _inited;

  TrackingPoint? lastLocal;
  TrackingPoint? lastRemote;

  final List<TrackingPoint> history = []; // 用來畫 polyline

  bool _tracking = false;
  bool get tracking => _tracking;

  StreamSubscription<Position>? _posSub;

  // Web mock
  Timer? _mockTimer;
  final Random _rnd = Random();

  // ======================================================
  // 初始化 & 永續化
  // ======================================================
  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);

      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);

        if (decoded is Map) {
          final map = decoded.map((k, v) => MapEntry(k.toString(), v));

          final ll = map['lastLocal'];
          final lr = map['lastRemote'];
          final h = map['history'];

          if (ll is Map) {
            lastLocal = TrackingPoint.fromMap(Map<String, dynamic>.from(ll));
          }
          if (lr is Map) {
            lastRemote = TrackingPoint.fromMap(Map<String, dynamic>.from(lr));
          }
          if (h is List) {
            history
              ..clear()
              ..addAll(
                h.whereType<Map>().map(
                  (e) => TrackingPoint.fromMap(Map<String, dynamic>.from(e)),
                ),
              );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[TrackingService] Load error: $e');
      }
    }

    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{
        'lastLocal': lastLocal?.toMap(),
        'lastRemote': lastRemote?.toMap(),
        'history': history.map((e) => e.toMap()).toList(),
      };
      await prefs.setString(_prefsKey, jsonEncode(data));
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[TrackingService] Save error: $e');
      }
    }
  }

  // ======================================================
  // 權限與定位（Mobile only）
  // ======================================================
  Future<bool> ensurePermission() async {
    if (kIsWeb) return true;

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return false;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) return false;
      if (perm == LocationPermission.deniedForever) return false;

      return true;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[TrackingService] ensurePermission error: $e');
      }
      return false;
    }
  }

  // ======================================================
  // 開始追蹤
  // ======================================================
  Future<void> startLocalTracking({
    int distanceFilter = 5,
    LocationAccuracy accuracy = LocationAccuracy.best,
  }) async {
    await init();

    // Web：直接走 mock（穩定、可展示、避免 plugin/權限差異）
    if (kIsWeb) {
      _startMockTracking();
      return;
    }

    final ok = await ensurePermission();
    if (!ok) return;

    _tracking = true;
    notifyListeners();

    // geolocator 14.x：LocationSettings 不要 const
    final settings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    );

    await _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) async {
        _updateLocal(lat: pos.latitude, lng: pos.longitude, source: 'local');
        await _save();
        notifyListeners();
      },
      onError: (e) async {
        if (kDebugMode) {
          // ignore: avoid_print
          print('[TrackingService] getPositionStream error: $e');
        }
        // 出錯就先停掉，避免一直噴
        await stopLocalTracking();
      },
    );
  }

  // ======================================================
  // 更新 local + history
  // ======================================================
  void _updateLocal({
    required double lat,
    required double lng,
    required String source,
  }) {
    final now = DateTime.now();
    final point = TrackingPoint(lat: lat, lng: lng, time: now, source: source);
    lastLocal = point;

    // 同步進 history（用於 polyline）
    history.add(
      TrackingPoint(lat: lat, lng: lng, time: now, source: 'history'),
    );

    // 控制 history 長度，避免爆
    if (history.length > 500) {
      history.removeRange(0, history.length - 500);
    }
  }

  // ======================================================
  // Web：模擬追蹤（Taipei 周邊漂移）
  // ======================================================
  void _startMockTracking() {
    if (_tracking) return;

    _tracking = true;
    notifyListeners();

    // 若本來有 lastLocal 就從該點延續，否則台北 101
    double lat = lastLocal?.lat ?? 25.0330;
    double lng = lastLocal?.lng ?? 121.5654;

    _mockTimer?.cancel();
    _mockTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      // 產生微小漂移
      final dLat = (_rnd.nextDouble() - 0.5) * 0.001; // 約 ±0.0005
      final dLng = (_rnd.nextDouble() - 0.5) * 0.001;

      lat += dLat;
      lng += dLng;

      _updateLocal(lat: lat, lng: lng, source: 'mock');
      await _save();
      notifyListeners();
    });
  }

  // ======================================================
  // 停止追蹤
  // ======================================================
  Future<void> stopLocalTracking() async {
    _tracking = false;

    await _posSub?.cancel();
    _posSub = null;

    _mockTimer?.cancel();
    _mockTimer = null;

    notifyListeners();
  }

  // ======================================================
  // 遠端位置更新（來自設備或 API）
  // ======================================================
  Future<void> setRemoteLocation({
    required String deviceId,
    required double lat,
    required double lng,
    DateTime? time,
    bool appendToHistory = true,
  }) async {
    await init();

    lastRemote = TrackingPoint(
      lat: lat,
      lng: lng,
      time: time ?? DateTime.now(),
      source: 'remote',
    );

    if (appendToHistory) {
      history.add(
        TrackingPoint(
          lat: lat,
          lng: lng,
          time: DateTime.now(),
          source: 'history',
        ),
      );
      if (history.length > 500) {
        history.removeRange(0, history.length - 500);
      }
    }

    await _save();
    notifyListeners();
  }

  // ======================================================
  // 清除歷史
  // ======================================================
  Future<void> clearHistory() async {
    history.clear();
    await _save();
    notifyListeners();
  }
}
