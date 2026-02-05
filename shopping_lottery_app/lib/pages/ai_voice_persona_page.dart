import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import 'package:translator/translator.dart';
import '../services/language_service.dart';
import '../services/translation_service.dart';
import '../services/firestore_mock_service.dart';
import '../services/notification_service.dart';

/// 🎭 AI 真人語音客服中心
/// 功能：
/// - 可切換客服角色（溫柔女聲 / 專業男聲 / 活潑少女 / 機械語氣）
/// - 根據使用者語氣自動調整 AI 回覆情緒
/// - 雙語字幕顯示 + 雲端同步
class AiVoicePersonaPage extends StatefulWidget {
  const AiVoicePersonaPage({super.key});

  @override
  State<AiVoicePersonaPage> createState() => _AiVoicePersonaPageState();
}

class _AiVoicePersonaPageState extends State<AiVoicePersonaPage> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final translator = TranslationService.instance;
  final mock = FirestoreMockService.instance;
  final notifier = NotificationService.instance;
  bool _listening = false;
  bool _isProcessing = false;
  String _userText = '';
  String _aiText = '';
  String _selectedPersona = "💁‍♀️ 溫柔客服 Emily";

  final List<String> personas = [
    "💁‍♀️ 溫柔客服 Emily",
    "👨‍💼 專業客服 Alex",
    "🎀 活潑少女 Yumi",
    "🤖 機械語音 Bot-X",
  ];

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
    final emotion = _detectEmotion(inputTr["translated"] ?? "");
    final aiReply = _generateReply(inputTr["translated"] ?? "", emotion);
    final aiTr = await translator.translate(aiReply);

    setState(() {
      _aiText = aiTr["translated"] ?? "";
      _isProcessing = false;
      _listening = false;
    });

    // ✅ 儲存對話紀錄（模擬雲同步）
    mock.addAiMessage({
      "from": _selectedPersona,
      "text": aiTr["translated"] ?? "",
      "emotion": emotion,
      "time": DateTime.now(),
    });

    notifier.addNotification(
      title: "$_selectedPersona 回覆",
      message: aiTr["translated"] ?? "",
      icon: Icons.support_agent_outlined,
    );

    await _speak(aiTr["translated"] ?? "", emotion);
  }

  /// 🧠 模擬 AI 情緒分析
  String _detectEmotion(String text) {
    final lower = text.toLowerCase();
    if (lower.contains("thank") || lower.contains("謝謝")) return "friendly";
    if (lower.contains("angry") || lower.contains("氣")) return "apologetic";
    if (lower.contains("refund") || lower.contains("退")) return "serious";
    return "neutral";
  }

  /// 💬 根據情緒與角色產生回覆
  String _generateReply(String input, String emotion) {
    if (_selectedPersona.contains("Emily")) {
      return switch (emotion) {
        "friendly" => "💕 感謝您的鼓勵，我會繼續努力協助您喔！",
        "apologetic" => "😔 很抱歉造成不便，讓我幫您查查看。",
        "serious" => "📦 已收到您的退貨申請，我們將盡快處理。",
        _ => "💁‍♀️ 這邊幫您確認一下，請稍等片刻喔～"
      };
    } else if (_selectedPersona.contains("Alex")) {
      return switch (emotion) {
        "friendly" => "👍 感謝您的理解，祝您有美好的一天。",
        "apologetic" => "我們非常重視此問題，會立即協助處理。",
        "serious" => "我已通知後台確認，請稍後查看最新通知。",
        _ => "您好，這邊是 Alex，請問有什麼我能協助的嗎？"
      };
    } else if (_selectedPersona.contains("Yumi")) {
      return switch (emotion) {
        "friendly" => "🌸 太棒了！聽到你這樣說我超開心～",
        "apologetic" => "嗚嗚～對不起啦，我幫你查查 😢",
        "serious" => "嗯嗯～我馬上幫你確認喔 💪",
        _ => "嘿嘿～有什麼我可以幫你的嗎？💬"
      };
    } else {
      return "🤖 處理中，請稍候……您的請求已記錄。";
    }
  }

  /// 🔊 語音播放（根據角色語氣）
  Future<void> _speak(String text, String emotion) async {
    await _tts.setLanguage(_getLocaleId());
    await _tts.setSpeechRate(0.9);
    await _tts.setPitch(
      _selectedPersona.contains("Yumi")
          ? 1.3
          : _selectedPersona.contains("Emily")
              ? 1.1
              : _selectedPersona.contains("Alex")
                  ? 0.9
                  : 1.0,
    );
    await _tts.speak(text);
  }

  String _getLocaleId() {
    final code = LanguageService().locale.languageCode;
    switch (code) {
      case "zh":
        return "zh-TW";
      case "ja":
        return "ja-JP";
      case "ko":
        return "ko-KR";
      case "es":
        return "es-ES";
      case "fr":
        return "fr-FR";
      case "de":
        return "de-DE";
      case "th":
        return "th-TH";
      case "id":
        return "id-ID";
      default:
        return "en-US";
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
      appBar: AppBar(
        title: Text("${tr("ai_support")} (Voice Personas)"),
        backgroundColor: const Color(0xFF007BFF),
        actions: [
          IconButton(
            icon: const Icon(Icons.language, color: Colors.white),
            onPressed: () => Provider.of<LanguageService>(context, listen: false).cycleLanguage(),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F7FB),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButton<String>(
              value: _selectedPersona,
              items: personas.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Text(p),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedPersona = v!),
            ),
            const SizedBox(height: 20),
            _buildBubble("🧍 $_userText", true),
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            _buildBubble("$_selectedPersona: $_aiText", false),
            const Spacer(),
            _buildMicButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(String text, bool user) {
    if (text.trim().isEmpty) return const SizedBox();
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: user ? Colors.blueAccent : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: user ? Colors.white : Colors.black87,
            fontSize: 15,
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
