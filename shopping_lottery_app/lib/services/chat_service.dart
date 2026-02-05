// lib/services/chat_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool fromUser;
  final int ts;
  ChatMessage({required this.id, required this.text, required this.fromUser, required this.ts});
  Map<String, dynamic> toMap() => {'id': id, 'text': text, 'fromUser': fromUser, 'ts': ts};
  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(id: m['id'] ?? '', text: m['text'] ?? '', fromUser: m['fromUser'] ?? false, ts: (m['ts'] is int) ? m['ts'] : int.tryParse('${m['ts']}') ?? 0);
}

class ChatService extends ChangeNotifier {
  ChatService._internal();
  static final ChatService instance = ChatService._internal();

  static const String _kKey = 'osmile_chat_v1';
  final List<ChatMessage> _messages = [];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey) ?? '';
    if (raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _messages.clear();
        for (final e in list) if (e is Map) _messages.add(ChatMessage.fromMap(Map<String, dynamic>.from(e)));
      } catch (_) {}
    }
    notifyListeners();
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  Future<void> send(String text, {bool fromUser = true}) async {
    final m = ChatMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), text: text, fromUser: fromUser, ts: DateTime.now().millisecondsSinceEpoch);
    _messages.insert(0, m);
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(_messages.map((m) => m.toMap()).toList()));
  }

  void clear() {
    _messages.clear();
    _save();
    notifyListeners();
  }
}
