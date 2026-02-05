import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../services/language_service.dart';
import '../services/ai_recommendation_service.dart';
import '../services/firestore_mock_service.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _isListening = false;
  String _query = "";
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
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
          if (val.finalResult) _searchProducts();
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _searchProducts() async {
    final lang = Provider.of<LanguageService>(context, listen: false);
    final ai = AIRecommendationService.instance;
    final all =
        FirestoreMockService.instance.getMockProducts(lang.locale.languageCode);

    _results = all
        .where((p) =>
            p["name"].toString().toLowerCase().contains(_query.toLowerCase()) ||
            p["category"].toString().toLowerCase().contains(_query.toLowerCase()))
        .toList();

    // 若找不到，回傳推薦
    if (_results.isEmpty) {
      _results = ai.getRecommendations(lang.locale.languageCode);
      await _speak(lang.tr("recommend_for_you"));
    } else {
      await _speak("${lang.tr("found")} ${_results.length} ${lang.tr("results")}");
    }

    setState(() {});
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
        title: Text(lang.tr("ai_assistant")),
        backgroundColor: const Color(0xFF0059FF),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            _query.isEmpty
                ? lang.tr("speak_prompt")
                : "🎙 ${_query}",
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _listen,
            child: CircleAvatar(
              radius: 40,
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
          Expanded(
            child: _results.isEmpty
                ? Center(child: Text(lang.tr("no_result")))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final p = _results[i];
                      return ListTile(
                        leading:
                            const Icon(Icons.watch, color: Colors.blueAccent),
                        title: Text(p["name"]),
                        subtitle: Text("NT\$${p["price"]}"),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
