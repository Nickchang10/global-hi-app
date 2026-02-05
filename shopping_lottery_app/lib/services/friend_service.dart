import 'package:flutter/material.dart';

/// 🤝 FriendService — 好友、聊天、群組、積分整合服務
class FriendService extends ChangeNotifier {
  FriendService._internal();
  static final FriendService instance = FriendService._internal();

  // ========================================
  // 🧑‍🤝‍🧑 好友列表
  // ========================================
  final List<Map<String, dynamic>> _friends = [
    {"name": "小明", "status": "在線中", "avatar": "assets/images/avatar1.png", "points": 120},
    {"name": "小華", "status": "離線", "avatar": "assets/images/avatar2.png", "points": 90},
    {"name": "Lumi 鐵粉", "status": "直播中", "avatar": "assets/images/avatar3.png", "points": 300},
  ];

  // ========================================
  // 💬 聊天室（私訊）
  // ========================================
  final Map<String, List<Map<String, dynamic>>> _chats = {
    "小明": [
      {"from": "小明", "text": "哈囉！最近有抽獎嗎？", "time": DateTime.now().subtract(const Duration(minutes: 3))},
      {"from": "我", "text": "剛抽到 ED1000！超爽🔥", "time": DateTime.now().subtract(const Duration(minutes: 1))},
    ],
  };

  // ========================================
  // 👥 群組聊天室（模擬）
  // ========================================
  final List<Map<String, dynamic>> _groups = [
    {
      "id": "group1",
      "name": "ED1000 開箱群",
      "members": ["小明", "我", "Lumi 鐵粉"],
      "messages": [
        {"from": "小明", "text": "今天直播超棒！", "time": DateTime.now().subtract(const Duration(minutes: 6))},
        {"from": "Lumi 鐵粉", "text": "我也看了😍", "time": DateTime.now().subtract(const Duration(minutes: 4))},
      ]
    }
  ];

  // ========================================
  // 🎁 禮物中心（送禮、記錄）
  // ========================================
  final List<Map<String, dynamic>> _giftHistory = [];

  // ========================================
  // 🕹️ 積分系統
  // ========================================
  int totalPoints = 200;

  // ========================================
  // 🔍 對外 Getter
  // ========================================
  List<Map<String, dynamic>> get friends => List.unmodifiable(_friends);
  List<Map<String, dynamic>> get groups => List.unmodifiable(_groups);
  List<Map<String, dynamic>> get gifts => List.unmodifiable(_giftHistory);

  List<Map<String, dynamic>> getChat(String name) =>
      List<Map<String, dynamic>>.from(_chats[name] ?? []);

  // ========================================
  // 🗨️ 聊天功能
  // ========================================
  void sendMessage(String name, String from, String text) {
    if (text.trim().isEmpty) return;
    _chats.putIfAbsent(name, () => []);
    _chats[name]!.add({"from": from, "text": text, "time": DateTime.now()});
    _addPoints(1); // 每聊天加積分
    notifyListeners();
  }

  void sendGroupMessage(String groupId, String from, String text) {
    final group = _groups.firstWhere((g) => g["id"] == groupId, orElse: () => {});
    if (group.isEmpty || text.trim().isEmpty) return;
    (group["messages"] as List).add({
      "from": from,
      "text": text,
      "time": DateTime.now(),
    });
    _addPoints(2);
    notifyListeners();
  }

  // ========================================
  // 🎁 禮物互動
  // ========================================
  void sendGift(String to, String giftName, int value) {
    _giftHistory.add({
      "to": to,
      "gift": giftName,
      "value": value,
      "time": DateTime.now(),
    });
    totalPoints -= value;
    notifyListeners();
  }

  // ========================================
  // 🏆 積分系統邏輯
  // ========================================
  void _addPoints(int value) {
    totalPoints += value;
    notifyListeners();
  }

  void redeemPoints(int cost) {
    if (totalPoints >= cost) totalPoints -= cost;
    notifyListeners();
  }

  // ========================================
  // ➕ 好友管理
  // ========================================
  void addFriend(String name) {
    if (_friends.any((f) => f["name"] == name)) return;
    _friends.add({
      "name": name,
      "status": "剛加入",
      "avatar": "assets/images/avatar_new.png",
      "points": 0,
    });
    notifyListeners();
  }

  void removeFriend(String name) {
    _friends.removeWhere((f) => f["name"] == name);
    notifyListeners();
  }
}
