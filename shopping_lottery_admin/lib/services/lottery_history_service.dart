// lib/services/lottery_history_service.dart
class LotteryHistoryService {
  LotteryHistoryService._internal();
  static final LotteryHistoryService instance = LotteryHistoryService._internal();

  final List<Map<String, dynamic>> _records = [];

  void addRecord({required String result, required String type, required int value}) {
    _records.add({
      'result': result,
      'type': type,
      'value': value,
      'atMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // backward compat
  void add({required String result, required String type, required int value}) {
    addRecord(result: result, type: type, value: value);
  }

  void record(String result, String type, int value) {
    addRecord(result: result, type: type, value: value);
  }

  List<Map<String, dynamic>> dump() => List.unmodifiable(_records);
}
