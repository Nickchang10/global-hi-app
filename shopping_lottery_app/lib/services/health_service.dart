// lib/services/health_service.dart
// ======================================================
// ✅ HealthService（最終整合完整版）
// ------------------------------------------------------
// - ✅ init()：載入本機快取、綁定 BLE 變化（修正 main.dart 呼叫 init() 的編譯錯）
// - 模擬健康數據：步數 / 睡眠 / 心率 / 血壓 / 積分 / 電量
// - startLocalSync(userId)：啟動模擬資料流（Web/Chrome 可用）
// - stop()：停止（保留最後一次數值供 UI 顯示）
// - syncFromCloud(userId)：模擬雲端同步（刷新一次資料）
// - SharedPreferences 永續化（Web/Chrome 也可用）
// - 與 DevicePage 顯示欄位完全相容
// ======================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bluetooth_service.dart';

class HealthService extends ChangeNotifier {
  HealthService._internal();
  static final HealthService instance = HealthService._internal();
  factory HealthService() => instance;

  static const String _kPrefsKey = 'os_health_v1';

  // =========================
  // 狀態（DevicePage/HealthPage 會用到）
  // =========================
  bool online = false;
  String lastSource = 'none'; // Web 模擬 / BLE / 雲端 / 本機模擬 / none
  DateTime? lastUpdated;

  int steps = 0;
  double sleepHours = 0.0;
  int heartRate = 0;
  String bp = '—';
  int battery = 100;
  int points = 0;

  // =========================
  // internal
  // =========================
  bool _inited = false;
  bool get inited => _inited;

  String? _currentUserId;
  Timer? _mockTimer;
  final Random _rnd = Random();

  bool _bleListenerBound = false;

  // ======================================================
  // ✅ init（修正 main.dart: h.init() 不存在）
  // ======================================================
  Future<void> init({bool force = false}) async {
    if (_inited && !force) return;
    _inited = true;

    // 1) 綁定 BLE 變化（只綁一次）
    _bindBleIfNeeded();

    // 2) 讀 prefs
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final m = decoded.map((k, v) => MapEntry(k.toString(), v));

          online = m['online'] == true;
          lastSource = (m['lastSource'] ?? lastSource).toString();

          final t = m['lastUpdated'];
          if (t is int) lastUpdated = DateTime.fromMillisecondsSinceEpoch(t);
          if (t is num) lastUpdated = DateTime.fromMillisecondsSinceEpoch(t.toInt());
          if (t is String) {
            final ms = int.tryParse(t);
            if (ms != null) lastUpdated = DateTime.fromMillisecondsSinceEpoch(ms);
            final iso = DateTime.tryParse(t);
            if (iso != null) lastUpdated = iso;
          }

          steps = _asInt(m['steps'], fallback: steps);
          sleepHours = _asDouble(m['sleepHours'], fallback: sleepHours);
          heartRate = _asInt(m['heartRate'], fallback: heartRate);
          bp = (m['bp'] ?? bp).toString();
          points = _asInt(m['points'], fallback: points);
          battery = _asInt(m['battery'], fallback: battery).clamp(0, 100);

          _currentUserId = (m['userId'] ?? _currentUserId)?.toString();
        }
      }
    } catch (_) {
      // 忽略快取讀取錯誤
    }

    // 3) 電量以 BLE 最新為準（若 BLE 有提供）
    _pullBatteryFromBle();

    notifyListeners();
  }

  // ======================================================
  // 模擬同步（本機/手錶）
  // ======================================================
  Future<void> startLocalSync(String userId) async {
    await init();

    _currentUserId = userId;

    // 先停舊的 timer
    await _stopTimerOnly();

    online = true;
    lastSource = kIsWeb
        ? 'Web 模擬'
        : (BluetoothService.instance.isConnected ? 'BLE' : '本機模擬');
    lastUpdated = DateTime.now();
    notifyListeners();

    // 每 3 秒推一次資料（你可自行調整）
    _mockTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      _generateMockData();
      await _save();
    });
  }

  Future<void> stop() async {
    // 停止資料流
    await _stopTimerOnly();

    // online 變 false，但保留數值（讓 UI 仍可顯示最後一次資料）
    online = false;
    lastSource = 'none';
    notifyListeners();

    await _save();
  }

  Future<void> _stopTimerOnly() async {
    _mockTimer?.cancel();
    _mockTimer = null;
  }

  // ======================================================
  // 雲端同步（模板）
  // ======================================================
  Future<void> syncFromCloud(String userId) async {
    await init();
    _currentUserId = userId;

    // 模擬雲端延遲
    await Future<void>.delayed(const Duration(milliseconds: 650));

    // 雲端同步：刷新一次（你之後接 Firestore/API 時改這段）
    _generateMockData(from: '雲端');
    await _save();
  }

  // ======================================================
  // 公用工具（可選）
  // ======================================================
  Future<void> resetAll({bool keepBattery = true}) async {
    await init();

    final b = battery;

    steps = 0;
    sleepHours = 0.0;
    heartRate = 0;
    bp = '—';
    points = 0;
    lastUpdated = DateTime.now();
    lastSource = 'reset';

    if (keepBattery) battery = b;

    notifyListeners();
    await _save();
  }

  // ======================================================
  // internal: BLE 監聽/電量同步
  // ======================================================
  void _bindBleIfNeeded() {
    if (_bleListenerBound) return;
    _bleListenerBound = true;

    // HealthService 是 singleton，通常不 dispose；因此只綁一次即可
    BluetoothService.instance.addListener(_onBleChanged);
  }

  void _onBleChanged() {
    // 只處理電量（避免反覆重算健康數據）
    final prev = battery;
    _pullBatteryFromBle();

    if (battery != prev) {
      // 若同步中，來源顯示更貼近實際
      if (online && !kIsWeb && BluetoothService.instance.isConnected) {
        lastSource = 'BLE';
      }
      lastUpdated ??= DateTime.now();
      notifyListeners();
    }
  }

  void _pullBatteryFromBle() {
    final bleBattery = BluetoothService.instance.batteryLevel;
    battery = bleBattery.clamp(0, 100);
  }

  // ======================================================
  // internal: mock generator
  // ======================================================
  void _generateMockData({String? from}) {
    // 步數遞增：50~200
    steps += 50 + _rnd.nextInt(151);

    // 睡眠：6.0~8.0（保留 1 位）
    sleepHours = 6.0 + _rnd.nextDouble() * 2.0;
    sleepHours = double.parse(sleepHours.toStringAsFixed(1));

    // 心率：60~99
    heartRate = 60 + _rnd.nextInt(40);

    // 血壓：SYS 110~125 / DIA 70~82
    final sys = 110 + _rnd.nextInt(16);
    final dia = 70 + _rnd.nextInt(13);
    bp = '$sys/$dia';

    // 電量：以 BLE 為主；若 BLE 不可用則緩慢下降
    final bleBattery = BluetoothService.instance.batteryLevel;
    if (BluetoothService.instance.isConnected || kIsWeb) {
      battery = bleBattery.clamp(0, 100);
    } else {
      battery = max(0, battery - (_rnd.nextBool() ? 0 : 1));
    }

    // 積分：每次 +1~5
    points += 1 + _rnd.nextInt(5);

    lastUpdated = DateTime.now();
    lastSource = from ?? '模擬';
    notifyListeners();
  }

  // ======================================================
  // persist
  // ======================================================
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{
        'online': online,
        'lastSource': lastSource,
        'lastUpdated': lastUpdated?.millisecondsSinceEpoch,
        'steps': steps,
        'sleepHours': sleepHours,
        'heartRate': heartRate,
        'bp': bp,
        'battery': battery,
        'points': points,
        'userId': _currentUserId,
      };
      await prefs.setString(_kPrefsKey, jsonEncode(data));
    } catch (_) {
      // 忽略存檔錯誤
    }
  }

  // ======================================================
  // helpers
  // ======================================================
  int _asInt(dynamic v, {required int fallback}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  double _asDouble(dynamic v, {required double fallback}) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }
}
