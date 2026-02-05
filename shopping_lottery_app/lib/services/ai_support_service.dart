import 'dart:async';
import 'package:flutter/material.dart';
import 'firestore_mock_service.dart';

/// 🤖 AI 智慧客服服務模擬
/// 支援自動回覆、模擬打字延遲、以及常見問答邏輯
class AISupportService extends ChangeNotifier {
  static final AISupportService instance = AISupportService._internal();
  AISupportService._internal();

  final List<Map<String, dynamic>> _messages = [];
  final StreamController<List<Map<String, dynamic>>> _controller =
      StreamController.broadcast();

  Stream<List<Map<String, dynamic>>> get messageStream => _controller.stream;

  void sendUserMessage(String text) {
    if (text.trim().isEmpty) return;
    _messages.add({
      "sender": "user",
      "text": text.trim(),
      "time": DateTime.now(),
    });
    _controller.add(List.from(_messages));

    // 模擬延遲 AI 回覆
    Future.delayed(const Duration(seconds: 1), () {
      _generateAIResponse(text);
    });
  }

  /// 🔹 AI 回覆邏輯
  void _generateAIResponse(String query) {
    String reply = "抱歉，我還在學習這個問題 😅";

    final lower = query.toLowerCase();
    if (lower.contains("訂單") || lower.contains("出貨")) {
      reply = "📦 您的訂單已在模擬系統中出貨，請於 1-2 天內留意通知。";
    } else if (lower.contains("抽獎") || lower.contains("中獎")) {
      reply = "🎰 抽獎功能可每日一次！前往『抽獎頁』即可參加～";
    } else if (lower.contains("登入") || lower.contains("註冊")) {
      reply = "🔐 若遇到登入問題，請確認網路狀態或重新啟動應用程式。";
    } else if (lower.contains("安全") || lower.contains("防火牆")) {
      reply = "🛡️ 系統目前運作正常，所有連線皆經加密保護。";
    } else if (lower.contains("優惠") || lower.contains("活動")) {
      reply = "🎉 近期活動：全館穿戴裝置 85 折優惠中！";
    } else if (lower.contains("客服") || lower.contains("人工")) {
      reply = "👩‍💻 我是智慧客服，若需人工支援，可於週一至週五 09:00–18:00 聯絡我們。";
    } else if (lower.contains("感謝") || lower.contains("謝謝")) {
      reply = "😊 很高興能幫到您！如有問題隨時再問我～";
    }

    _messages.add({
      "sender": "ai",
      "text": reply,
      "time": DateTime.now(),
    });
    _controller.add(List.from(_messages));
    notifyListeners();
  }

  void clearChat() {
    _messages.clear();
    _controller.add([]);
  }

  List<Map<String, dynamic>> get history => List.unmodifiable(_messages);

  void disposeService() {
    _controller.close();
  }
}
