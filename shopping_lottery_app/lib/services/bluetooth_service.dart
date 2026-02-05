// lib/services/bluetooth_service.dart
// ======================================================
// ✅ BluetoothService（最終整合版）
// ------------------------------------------------------
// - Web 模式：模擬搜尋/連線/斷線
// - Mobile 模式：預留 MethodChannel(osmile/ble)
// - 提供 deviceName、isConnected、batteryLevel
// - 可被 DevicePage / HealthService 使用
// ======================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BluetoothService extends ChangeNotifier {
  BluetoothService._internal();
  static final BluetoothService instance = BluetoothService._internal();
  factory BluetoothService() => instance;

  static const _channel = MethodChannel('osmile/ble');

  bool _connected = false;
  String? _deviceName;
  int _battery = 100;

  bool get isConnected => _connected;
  String? get deviceName => _deviceName;
  int get batteryLevel => _battery;

  StreamSubscription? _mockTimer;

  // ======================================================
  // 模擬連線
  // ======================================================
  Future<void> scanAndConnect({String preferredName = 'Osmile'}) async {
    if (kIsWeb) {
      // 模擬：1.5 秒連線成功
      await Future.delayed(const Duration(seconds: 2));
      _deviceName = '$preferredName Watch';
      _connected = true;
      _startBatteryMock();
      notifyListeners();
    } else {
      // Mobile 實機：呼叫原生 MethodChannel
      try {
        final name = await _channel.invokeMethod<String>('scanAndConnect', {
          'preferredName': preferredName,
        });
        _deviceName = name ?? preferredName;
        _connected = true;
        notifyListeners();
      } catch (e) {
        debugPrint('[BLE] scanAndConnect error: $e');
        rethrow;
      }
    }
  }

  Future<void> disconnect() async {
    if (kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 500));
      _connected = false;
      _deviceName = null;
      _mockTimer?.cancel();
      notifyListeners();
    } else {
      try {
        await _channel.invokeMethod('disconnect');
        _connected = false;
        _deviceName = null;
        _mockTimer?.cancel();
        notifyListeners();
      } catch (e) {
        debugPrint('[BLE] disconnect error: $e');
      }
    }
  }

  // ======================================================
  // 模擬電量變化
  // ======================================================
  void _startBatteryMock() {
    _mockTimer?.cancel();
    _mockTimer = Stream.periodic(const Duration(seconds: 5)).listen((_) {
      if (!_connected) return;
      _battery = (_battery - 1).clamp(5, 100);
      if (_battery == 5) _battery = 100;
      notifyListeners();
    });
  }

  void dispose() {
    _mockTimer?.cancel();
    super.dispose();
  }
}
