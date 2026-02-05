import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';

import '../services/language_service.dart';
import '../services/firestore_mock_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class AiSupportPage extends StatefulWidget {
  const AiSupportPage({super.key});

  @override
  State<AiSupportPage> createState() => _AiSupportPageState();
}

class _AiSupportPageState extends State<AiSupportPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isThinking = false;

  late FlutterTts _tts;
  late stt.SpeechToText _speech;
  bool _isListening = false;

  final mock = FirestoreMockService.instance;
  final notifier = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _speech = stt.SpeechToText();
    _messages.addAll(mock.aiMessages);
  }

  /// 🗣️ 語音辨識啟動
  Future<void> _startListening(LanguageService lang) async {
    if (!_isListening) {
      final available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        await _speech.listen(
          localeId: lang.locale.languageCode,
          onResult: (result) {
            _controller.text = result.recognizedWords;
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      await _speech.stop();
    }
  }

  /// 🔊 語音播報（多語）
  Future<void> _speak(String text, String langCode) async {
    await _tts.setLanguage(_ttsLocale(langCode));
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.9);
    await _tts.speak(text);
  }

  /// 🎯 語系對應表
  String _ttsLocale(String langCode) {
    switch (langCode) {
      case 'zh':
        return "zh-TW";
      case 'ja':
        return "ja-JP";
      case 'ko':
        return "ko-KR";
      case 'es':
        return "es-ES";
      case 'fr':
        return "fr-FR";
      case 'de':
        return "de-DE";
      case 'id':
        return "id-ID";
      default:
        return "en-US";
    }
  }

  /// 傳送文字訊息
  Future<void> _sendMessage(LanguageService lang) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final userMsg = {
      "from": "user",
      "text": text,
      "time": DateTime.now(),
    };

    setState(() {
      _messages.insert(0, userMsg);
      _controller.clear();
      _isThinking = true;
    });

    mock.addAiMessage(userMsg);

    await Future.delayed(const Duration(seconds: 1));

    final aiReply = _mockAiResponse(text, lang.locale.languageCode);
    final aiMsg = {
      "from": "ai",
      "text": aiReply,
      "time": DateTime.now(),
    };

    setState(() {
      _isThinking = false;
      _messages.insert(0, aiMsg);
    });

    mock.addAiMessage(aiMsg);

    notifier.addNotification(
      title: "🤖 ${lang.tr("ai_support")}",
      message: aiReply,
      icon: Icons.smart_toy_outlined,
      showOverlay: true,
    );

    await _speak(aiReply, lang.locale.languageCode);
  }

  /// 模擬 AI 智慧回覆
  String _mockAiResponse(String msg, String langCode) {
    final lower = msg.toLowerCase();
    if (lower.contains("出貨") || lower.contains("ship")) {
      return _langText(langCode, "您的訂單已出貨，預計兩天內送達。", "Your order has been shipped and will arrive soon.");
    } else if (lower.contains("折價券") || lower.contains("discount")) {
      return _langText(langCode, "目前有滿千折百活動，您可在積分商城兌換更多優惠券。", "Currently, spend 1000 get 100 off promotion is available!");
    } else if (lower.contains("客服") || lower.contains("support")) {
      return _langText(langCode, "若需人工客服，請於週一至週五 09:00–18:00 聯繫我們。", "Our live support is available Monday–Friday 9am–6pm.");
    } else if (lower.contains("退貨") || lower.contains("refund")) {
      return _langText(langCode, "請於收到商品後 7 日內登入會員中心申請退貨。", "Please apply for a refund within 7 days in your account.");
    } else if (lower.contains("點數") || lower.contains("points")) {
      return _langText(langCode, "您的積分可至積分商城兌換商品。", "Your reward points can be redeemed in the points mall.");
    } else {
      return _langText(langCode, "了解，我會將您的問題轉交給人工客服處理喔。", "Got it, I’ll forward your issue to our support team.");
    }
  }

  /// 多語對應
  String _langText(String code, String zh, String en) {
    switch (code) {
      case 'zh':
        return zh;
      default:
        return en;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final user = AuthService.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.tr("ai_support")),
        backgroundColor: const Color(0xFF007BFF),
        actions: [
          IconButton(
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? Colors.redAccent : Colors.white,
            ),
            tooltip: _isListening ? lang.tr("stop") : lang.tr("speak_now"),
            onPressed: () => _startListening(lang),
          ),
        ],
      ),
      body: user == null
          ? Center(child: Text(lang.tr("please_login_first")))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg["from"] == "user";
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFF007BFF)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg["text"],
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_isThinking)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(lang.tr("listening")),
                      ],
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: lang.tr("speak_now"),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFF007BFF)),
                        onPressed: _isThinking ? null : () => _sendMessage(lang),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
