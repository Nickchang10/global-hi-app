import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/language_service.dart';
import '../services/ai_recommendation_service.dart';
import '../services/firestore_mock_service.dart';

/// 🧠 AI 多模態客服中心
/// - 偵測語音情緒（音調快慢、語氣特徵）
/// - 調整語音回覆語氣（安撫、活潑、正式）
/// - 後續可延伸表情偵測與鏡頭互動
class AiEmotionCenterPage extends StatefulWidget {
  const AiEmotionCenterPage({super.key});
  @override
  State<AiEmotionCenterPage> createState() => _AiEmotionCenterPageState();
}

class _AiEmotionCenterPageState extends State<AiEmotionCenterPage> {
  late FlutterTts _tts;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isThinking = false;
  String _query = "";
  String _emotion = "neutral";
  final List<Map<String, dynamic>> _chat = [];

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _speech = stt.SpeechToText();
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) {
          setState(() {
            _query = val.recognizedWords;
          });
          if (val.finalResult) {
            _detectEmotionAndRespond();
          }
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  /// 🎭 根據語音長度與關鍵詞模擬情緒辨識
  String _analyzeEmotion(String text) {
    final lower = text.toLowerCase();
    if (lower.contains("angry") || lower.contains("生氣") || lower.contains("不爽")) {
      return "angry";
    } else if (lower.contains("sad") || lower.contains("傷心") || lower.contains("難過")) {
      return "sad";
    } else if (lower.contains("happy") || lower.contains("開心") || lower.contains("棒")) {
      return "happy";
    } else if (text.length < 3) {
      return "neutral";
    } else if (text.endsWith("!") || text.contains("！")) {
      return "excited";
    }
    return "neutral";
  }

  Future<void> _detectEmotionAndRespond() async {
    final lang = Provider.of<LanguageService>(context, listen: false);
    final ai = AIRecommendationService.instance;
    final products = FirestoreMockService.instance.getMockProducts(lang.locale.languageCode);

    setState(() {
      _isListening = false;
      _isThinking = true;
      _emotion = _analyzeEmotion(_query);
      _chat.insert(0, {"from": "user", "text": _query});
    });

    String reply;
    switch (_emotion) {
      case "angry":
        reply = "我理解您現在的心情，我會盡力幫您處理這個問題。";
        break;
      case "sad":
        reply = "別難過，或許我們可以找一些讓您開心的商品。";
        break;
      case "happy":
        reply = "太好了！我很開心能幫到您～要不要看看最新優惠？";
        break;
      case "excited":
        reply = "您看起來很興奮！這裡有幾個超棒的新款推薦給您！";
        break;
      default:
        reply = "了解，我會根據您的需求進行推薦。";
    }

    final recommend = products.take(3).toList();
    _chat.insert(0, {"from": "ai", "text": reply, "emotion": _emotion, "products": recommend});
    await _speak(reply);
    setState(() => _isThinking = false);
  }

  Future<void> _speak(String text) async {
    switch (_emotion) {
      case "angry":
        await _tts.setSpeechRate(0.8);
        await _tts.setPitch(0.7);
        break;
      case "sad":
        await _tts.setSpeechRate(0.9);
        await _tts.setPitch(0.8);
        break;
      case "happy":
      case "excited":
        await _tts.setSpeechRate(1.2);
        await _tts.setPitch(1.2);
        break;
      default:
        await _tts.setSpeechRate(1.0);
        await _tts.setPitch(1.0);
    }
    await _tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.tr("ai_emotion_center")),
        backgroundColor: const Color(0xFF0059FF),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            "🎭 ${lang.tr("detected_emotion")}: ${_emotion.toUpperCase()}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: _chat.length,
              itemBuilder: (_, i) {
                final msg = _chat[i];
                final isUser = msg["from"] == "user";
                final emotion = msg["emotion"];
                Color bubbleColor = isUser
                    ? const Color(0xFF0059FF)
                    : (emotion == "happy"
                        ? Colors.lightGreen[100]!
                        : (emotion == "sad"
                            ? Colors.blue[100]!
                            : (emotion == "angry"
                                ? Colors.red[100]!
                                : Colors.grey[200]!)));
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(msg["text"],
                            style: TextStyle(
                                color: isUser ? Colors.white : Colors.black87)),
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
                                        color: Colors.amber, size: 20),
                                    const SizedBox(width: 6),
                                    Text("${p["name"]} - NT\$${p["price"]}"),
                                  ],
                                ),
                              );
                            },
                          )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isThinking)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
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
