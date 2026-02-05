import 'dart:math';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

/// 🎉 限時活動抽獎（需完成社群任務）
class EventLotteryService extends ChangeNotifier {
  static final EventLotteryService instance = EventLotteryService._internal();
  EventLotteryService._internal();

  final _rand = Random();
  bool _isActive = false;

  List<Map<String, dynamic>> _participants = []; // 用戶名單
  DateTime? _eventEndTime;

  bool get isActive => _isActive;
  DateTime? get eventEndTime => _eventEndTime;
  List<Map<String, dynamic>> get participants =>
      List.unmodifiable(_participants);

  // --------------------------------------------
  // 🕓 啟動活動
  // --------------------------------------------
  void startEvent({required DateTime endTime}) {
    _isActive = true;
    _eventEndTime = endTime;
    _participants.clear();
    notifyListeners();
  }

  // --------------------------------------------
  // 🛑 結束活動
  // --------------------------------------------
  void endEvent() {
    _isActive = false;
    _eventEndTime = null;
    notifyListeners();
  }

  // --------------------------------------------
  // ✅ 登錄參加者（模擬：完成按讚+留言+分享）
  // --------------------------------------------
  void registerParticipant(String name) {
    if (!_isActive) return;

    if (_participants.any((p) => p["name"] == name)) return;

    _participants.add({"name": name, "time": DateTime.now()});
    notifyListeners();
  }

  // --------------------------------------------
  // 🏆 抽出中獎者（隨機）
  // --------------------------------------------
  Map<String, dynamic>? drawWinner() {
    if (_participants.isEmpty) return null;

    final winner = _participants[_rand.nextInt(_participants.length)];

    final prizePool = [
      {"name": "iPhone 16 Pro", "value": "iphone16", "weight": 5},
      {"name": "Dyson 吹風機", "value": "dyson_hair", "weight": 5},
      {"name": "Osmile 智慧手錶", "value": "ed1000", "weight": 10},
      {"name": "現金禮券 \$5000", "value": "cash5000", "weight": 3},
    ];

    final prize = prizePool[_rand.nextInt(prizePool.length)];

    NotificationService.instance.addNotification(
      title: "🎉 活動中獎公告",
      message: "${winner['name']} 抽中 ${prize['name']}！",
      type: "event",
    );

    return {"winner": winner, "prize": prize};
  }
}
