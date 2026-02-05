// lib/services/daily_mission_service.dart
import 'package:flutter/material.dart';
import 'firestore_mock_service.dart';

class DailyMissionService extends ChangeNotifier {
  DailyMissionService._internal();
  static final DailyMissionService instance = DailyMissionService._internal();

  bool _inited = false;
  bool get inited => _inited;

  final List<Map<String, dynamic>> _missions = [
    {'id': 'm1', 'title': '每日簽到', 'completed': false, 'reward': 10},
    {'id': 'm2', 'title': '分享商品', 'completed': false, 'reward': 5},
  ];

  Future<void> init() async {
    _inited = true;
    notifyListeners();
  }

  Future<void> resetWeeklyIfNeeded() async {
    // 範例中不做自動重置
    return;
  }

  List<Map<String, dynamic>> get missions => List.unmodifiable(_missions);

  Future<void> completeMission(String id) async {
    final idx = _missions.indexWhere((m) => m['id'] == id);
    if (idx == -1) return;
    if (_missions[idx]['completed'] == true) return;

    _missions[idx]['completed'] = true;
    final reward = (_missions[idx]['reward'] is int) ? (_missions[idx]['reward'] as int) : int.tryParse('${_missions[idx]['reward']}') ?? 0;

    // FirestoreMockService.addPoints 現在是 Future<void>，可以安全 await
    try {
      await FirestoreMockService.instance.addPoints(reward);
    } catch (_) {
      // 若模擬服務有錯誤，略過
    }

    notifyListeners();
  }
}
