// lib/services/location_service.dart
// ======================================================
// ✅ LocationService（最終整合版｜修正 desiredAccuracy deprecated｜補 tryGetCurrentPosition）
// ------------------------------------------------------
// - 使用 geolocator
// - 不再用 desiredAccuracy 參數（deprecated）
// - 改用 locationSettings（AndroidSettings/AppleSettings/WebSettings/LocationSettings）
// - 提供：init / ensurePermission / getCurrentPosition / tryGetCurrentPosition / getPositionStream
// ======================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService extends ChangeNotifier {
  LocationService._internal();
  static final LocationService instance = LocationService._internal();
  factory LocationService() => instance;

  bool _loading = false;
  bool _serviceEnabled = false;
  LocationPermission _permission = LocationPermission.denied;

  Position? _lastPosition;

  bool get loading => _loading;
  bool get serviceEnabled => _serviceEnabled;
  LocationPermission get permission => _permission;
  Position? get lastPosition => _lastPosition;

  // ======================================================
  // 初始化：檢查服務與權限（不強制一定要拿到定位）
  // ======================================================
  Future<void> init() async {
    _loading = true;
    notifyListeners();

    try {
      _serviceEnabled = await Geolocator.isLocationServiceEnabled();
      _permission = await Geolocator.checkPermission();

      if (_permission == LocationPermission.denied) {
        _permission = await Geolocator.requestPermission();
      }

      // deniedForever 不要一直 request，交給 UI 引導去設定
      //（這裡不做任何動作，只更新狀態）
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ======================================================
  // 需要時再確保：服務 & 權限
  // ======================================================
  Future<bool> ensurePermission() async {
    _serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_serviceEnabled) {
      notifyListeners();
      return false;
    }

    _permission = await Geolocator.checkPermission();

    if (_permission == LocationPermission.denied) {
      _permission = await Geolocator.requestPermission();
    }

    if (_permission == LocationPermission.deniedForever) {
      notifyListeners();
      return false;
    }

    final ok =
        _permission == LocationPermission.always ||
        _permission == LocationPermission.whileInUse;

    notifyListeners();
    return ok;
  }

  // ======================================================
  // 取得一次定位（會丟例外：給需要知道錯誤的地方用）
  // ======================================================
  Future<Position?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
    Duration? timeLimit = const Duration(seconds: 10),
  }) async {
    final ok = await ensurePermission();
    if (!ok) return null;

    final settings = _buildSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      timeLimit: timeLimit,
    );

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );

      _lastPosition = pos;
      notifyListeners();
      return pos;
    } catch (e) {
      debugPrint('[Location] getCurrentPosition error: $e');
      rethrow;
    }
  }

  // ======================================================
  // ✅ 給 SOS / UI 用：不丟例外，失敗直接回傳 null
  // ======================================================
  Future<Position?> tryGetCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
    Duration? timeLimit = const Duration(seconds: 10),
  }) async {
    try {
      return await getCurrentPosition(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        timeLimit: timeLimit,
      );
    } catch (_) {
      return null;
    }
  }

  // ======================================================
  // 監聽定位串流
  // ======================================================
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
    Duration interval = const Duration(seconds: 5),
    Duration? timeLimit,
  }) {
    // 用 Stream.fromFuture + asyncExpand，避免 async* 早退造成 lint/可讀性問題
    return Stream.fromFuture(ensurePermission()).asyncExpand((ok) {
      if (!ok) return const Stream<Position>.empty();

      final settings = _buildSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        interval: interval,
        timeLimit: timeLimit,
      );

      return Geolocator.getPositionStream(locationSettings: settings).map((
        pos,
      ) {
        _lastPosition = pos;
        notifyListeners();
        return pos;
      });
    });
  }

  // ======================================================
  // 平台化設定（取代 desiredAccuracy）
  // ======================================================
  LocationSettings _buildSettings({
    required LocationAccuracy accuracy,
    required int distanceFilter,
    Duration? interval,
    Duration? timeLimit,
  }) {
    if (kIsWeb) {
      return WebSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        timeLimit: timeLimit,
        maximumAge: const Duration(seconds: 15),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: interval ?? const Duration(seconds: 5),
        timeLimit: timeLimit,
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        timeLimit: timeLimit,
        pauseLocationUpdatesAutomatically: true,
        allowBackgroundLocationUpdates: false,
      );
    }

    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      timeLimit: timeLimit,
    );
  }

  // ======================================================
  // 系統設定快捷
  // ======================================================
  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
