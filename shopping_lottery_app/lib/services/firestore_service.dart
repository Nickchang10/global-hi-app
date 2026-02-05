import 'package:flutter/material.dart';

/// 🤝 FriendService — 好友 + 聊天 + 動態整合服務
class FriendService extends ChangeNotifier {
  FriendService._internal();
  static final FriendService instance = FriendService._internal();

  // 🧑‍🤝‍🧑 假資料：好友列表
  final List<Map<String, dynamic>> _friends = [
    {"name": "小明", "status": "在線中", "avatar": "assets/images/avatar1.png"},
    {"name": "小華", "status": "離線", "avatar": "assets/images/avatar2.png"},
    {"name": "Lumi 鐵粉", "status": "正在直播", "avatar": "assets/images/avatar3.png"},
  ];

  // 💬 聊天資料
  final Map<String, List<Map<String, dynamic>>> _chats = {
    "小明": [
      {"from": "小明", "text": "哈囉～你最近抽到什麼？", "time": DateTime.now().subtract(const Duration(minutes: 2))},
      {"from": "我", "text": "抽到 ED1000！爽爆 🎉", "time": DateTime.now().subtract(const Duration(minutes: 1))},
    ],
  };

  // 🧱 好友動態牆資料（模擬）
  final List<Map<String, dynamic>> _friendPosts = [
    {
      "user": "小明",
      "content": "今天開箱 ED1000 超帥！💙",
      "time": DateTime.now().subtract(const Duration(hours: 2)),
      "likes": 14,
      "comments": ["帥！", "哪裡買？"],
      "image": "assets/images/live_cover_ed1000.png"
    },
    {
      "user": "Lumi 鐵粉",
      "content": "Lumi 2 睡眠監測真的很準 😴",
      "time": DateTime.now().subtract(const Duration(hours: 5)),
      "likes": 23,
      "comments": ["我也覺得！", "買爆"],
      "image": "assets/images/live_cover_lumi2.png"
    },
  ];

  // --- Getters ---
  List<Map<String, dynamic>> get friends => List.unmodifiable(_friends);
  List<Map<String, dynamic>> get friendPosts => List.unmodifiable(_friendPosts);
  List<Map<String, dynamic>> getChat(String name) =>
      List<Map<String, dynamic>>.from(_chats[name] ?? []);

  // --- 核心功能 ---
  void sendMessage(String name, String from, String text) {
    if (text.trim().isEmpty) return;
    _chats.putIfAbsent(name, () => []);
    _chats[name]!.add({
      "from": from,
      "text": text.trim(),
      "time": DateTime.now(),
    });
    notifyListeners();
  }

  void addFriend(String name) {
    if (_friends.any((f) => f["name"] == name)) return;
    _friends.add({
      "name": name,
      "status": "剛加入",
      "avatar": "assets/images/avatar_new.png",
    });
    notifyListeners();
  }

  void removeFriend(String name) {
    _friends.removeWhere((f) => f["name"] == name);
    notifyListeners();
  }
}
