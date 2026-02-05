import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:translator/translator.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../services/translation_service.dart';
import '../services/notification_service.dart';

/// 🎧 AI 多語語音客服系統（模擬版）
///
/// 功能：
//// - 即時語音辨識 → 翻譯 → AI 回覆 → 語音播放
//// - 可顯示雙語字幕
class AiVoiceCallPage extends StatefulWidget {
  const AiVoiceCallPage({super.key});

  @override
  State<AiVoiceCallPage> createState() => _AiVoiceCallPageState();
}

class _AiVoiceCallPageState extends State<AiVoiceCallPage> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final translator = TranslationService.instance;
  final ai = _MockAiEngine();
  bool _listening = false;
  bool _isProcessing = false;
  String _userText = '';
  String _aiText = '';

  Future<void> _startListening() async {
    if (_listening) return;
    final hasSpeech = await _speech.initialize();
    if (hasSpeech) {
      setState(() => _listening = true);
      await _speech.listen(
        localeId: _getLocaleId(),
        onResult: (res) async {
          if (res.finalResult) {
            setState(() {
              _userText = res.recognizedWords;
              _isProcessing = true;
            });
            await _processConversation(_userText);
          }
        },
      );
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _listening = false);
  }

  Future<void> _processConversation(String input) async {
    final langCode = LanguageService().locale.languageCode;
    final inputTr = await translator.translate(input);
    final aiReply = ai.generateReply(inputTr["translated"] ?? "");
    final aiTr = await translator.translate(aiReply);

    setState(() {
      _aiText = aiTr["translated"] ?? "";
      _isProcessing = false;
      _listening = false;
    });

    NotificationService.instance.addNotification(
      title: "🤖 AI Voice Assistant",
      message: aiTr["translated"] ?? "",
      icon: Icons.smart_toy_outlined,
    );

    await _tts.setLanguage(_getLocaleId());
    await _tts.setSpeechRate(0.95);
    await _tts.speak(aiTr["translated"] ?? "");
  }

  String _getLocaleId() {
    final code = LanguageService().locale.languageCode;
    switch (code) {
      case "zh": return "zh-TW";
      case "ja": return "ja-JP";
      case "ko": return "ko-KR";
      case "es": return "es-ES";
      case "fr": return "fr-FR";
      case "de": return "de-DE";
      case "th": return "th-TH";
      case "id": return "id-ID";
      default: return "en-US";
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Provider.of<LanguageService>(context).tr;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text(tr("ai_support")),
        backgroundColor: const Color(0xFF007BFF),
        actions: [
          IconButton(
            icon: const Icon(Icons.language, color: Colors.white),
            onPressed: () =>
                Provider.of<LanguageService>(context, listen: false)
                    .cycleLanguage(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSpeechBubble("🧍 ${_userText.isEmpty ? tr("type_your_message") : _userText}", true),
            const SizedBox(height: 24),
            if (_isProcessing)
              const CircularProgressIndicator(color: Colors.blueAccent),
            if (_aiText.isNotEmpty)
              _buildSpeechBubble("🤖 $_aiText", false),
            const Spacer(),
            _buildMicButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeechBubble(String text, bool user) {
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.symmetric(vertical: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: user ? Colors.blueAccent : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: user ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    return FloatingActionButton.large(
      backgroundColor: _listening ? Colors.red : Colors.blue,
      onPressed: _listening ? _stopListening : _startListening,
      child: Icon(
        _listening ? Icons.mic : Icons.mic_none,
        color: Colors.white,
        size: 36,
      ),
    );
  }
}

/// 💬 模擬 AI 回覆邏輯
class _MockAiEngine {
  String generateReply(String input) {
    final lower = input.toLowerCase();
    if (lower.contains("order") || lower.contains("出貨")) {
      return "📦 Your order is on the way and will arrive soon.";
    } else if (lower.contains("discount") || lower.contains("優惠")) {
      return "🎁 A new 20% discount is available for all members!";
    } else if (lower.contains("hello") || lower.contains("你好")) {
      return "👋 Hello! How can I help you today?";
    } else {
      return "🤖 I understand! Let me assist you with that.";
    }
  }
}
