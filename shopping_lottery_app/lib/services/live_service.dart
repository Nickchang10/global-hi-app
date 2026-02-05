// lib/services/live_service.dart
import 'package:flutter/material.dart';

class LiveSession {
  final String id;
  final String title;
  final String host;
  final String time;
  final int viewers;
  final String? image;

  LiveSession({
    required this.id,
    required this.title,
    required this.host,
    required this.time,
    required this.viewers,
    this.image,
  });
}

class LiveService extends ChangeNotifier {
  LiveService._internal();
  static final LiveService instance = LiveService._internal();

  final List<LiveSession> _sessions = [
    LiveSession(id: 'l1', title: 'Osmile 新產品直播', host: 'Alice', time: '今天 14:00', viewers: 120, image: 'https://picsum.photos/seed/live1/800/450'),
    LiveSession(id: 'l2', title: '健身鞋穿搭', host: 'Bob', time: '明天 19:30', viewers: 80, image: 'https://picsum.photos/seed/live2/800/450'),
    LiveSession(id: 'l3', title: '耳機深度解析', host: 'Carol', time: '本週五 20:00', viewers: 200, image: 'https://picsum.photos/seed/live3/800/450'),
  ];

  List<LiveSession> get sessions => List.unmodifiable(_sessions);

  /// 回傳可能為 null 的 live session（避免在找不到時拋錯）
  LiveSession? getById(String id) {
    try {
      return _sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
