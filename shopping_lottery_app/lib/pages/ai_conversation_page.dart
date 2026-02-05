import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../services/language_service.dart';
import '../services/ai_recommendation_service.dart';
import '../services/firestore_mock_service.dart';
import '../services/translation_service.dart';

class AiConversationPage extends StatefulWidget {
  const AiConversationPage({super.key});

  @override
  State<AiConversationPage> createState() => _AiConversationPageState();
}

class _AiConversationPageState extends State<AiConversationPage> {
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _isListening = false;
  bool _isThinking = false;
  String _input = "";
  final List<Map<String, dynamic>> _chat = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
  }

  Future<void> _listen() async {
    if (!_isListening) {
      final available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) {
          setState(() => _input = val.recognizedWords);
          if (val.finalResult) {
            _processQuery();
          }
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _processQuery() async {
    if (_input.isEmpty) return;
    final lang = Provider.of<LanguageService>(context, listen: false);
    final translator = TranslationService();
    final ai = AIRecommendationService.instance;
    final mock = FirestoreMockService.instance;

    setState(() {
      _isListening = false;
      _isThinking = true;
      _chat.insert(0, {"from": "user", "text": _input});
    });

    // 🔍 翻譯成英文以利意圖分析
    final translated = await translator.translate(_input, to: "en");
    final lower = translated.toLowerCase();
    String reply;
    List<Map<String, dynamic>> products = [];

    if (lower.contains("cheap") || lower.contains("cheapest") || lower.contains("便宜")) {
      products = mock.getMockProducts(lang.locale.languageCode);
      products.sort((a, b) => a["price"].compareTo(b["price"]));
      reply = "${lang.tr("found")} ${products.length} ${lang.tr("results")}，${lang.tr("recommend_for_you")}";
    } else if (lower.contains("compare") || lower.contains("difference") || lower.contains("差別")) {
      reply = lang.tr("compare_reply");
    } else if (lower.contains("recommend") || lower.contains("推薦")) {
      products = ai.getRecommendations(lang.locale.languageCode);
      reply = lang.tr("recommend_for_you");
    } else {
      reply = lang.tr("generic_reply");
    }

    // 回覆
    _chat.insert(0, {"from": "ai", "text": reply, "products": products});
    await _speak(reply);

    setState(() => _isThinking = false);
  }

  Future<void> _speak(String text) async {
    await _tts.setLanguage("zh-TW");
    await _tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.tr("ai_conversation")),
        backgroundColor: const Color(0xFF0059FF),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: _chat.length,
              itemBuilder: (_, i) {
                final msg = _chat[i];
                final isUser = msg["from"] == "user";
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF0059FF)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg["text"],
                          style: TextStyle(
                              color:
                                  isUser ? Colors.white : Colors.black87),
                        ),
                        if (msg["products"] != null)
                          ...List.generate(
                            (msg["products"] as List).length.clamp(0, 3),
                            (idx) {
                              final p = msg["products"][idx];
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.watch,
                                        size: 20, color: Colors.amber),
                                    const SizedBox(width: 6),
                                    Expanded(
                                        child: Text(
                                            "${p["name"]} - NT\$${p["price"]}",
                                            style: const TextStyle(
                                                color: Colors.black87))),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isThinking)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _listen,
            child: CircleAvatar(
              radius: 38,
              backgroundColor:
                  _isListening ? Colors.redAccent : const Color(0xFF0059FF),
              child: Icon(
                _isListening ? Icons.hearing : Icons.mic,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
