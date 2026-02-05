// lib/services/lottery_history_service.dart
import 'package:flutter/material.dart';

class LotteryHistoryService extends ChangeNotifier {
  LotteryHistoryService._internal();
  static final LotteryHistoryService instance = LotteryHistoryService._internal();

  final List<Map<String, dynamic>> _records = [];

  List<Map<String, dynamic>> get records => List.unmodifiable(_records);

  /// 新增一筆抽獎紀錄
  void addRecord({
    required String result,
    required String type,
    required int value,
  }) {
    final record = {
      'result': result,
      'type': type,
      'value': value,
      'time': DateTime.now(),
    };
    _records.insert(0, record);
    notifyListeners();
  }

  /// 清除所有紀錄
  void clear() {
    _records.clear();
    notifyListeners();
  }
}
