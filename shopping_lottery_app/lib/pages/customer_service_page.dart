import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

/// 💬 Osmile 智慧語音客服（安全模擬版）
///
/// ✅ 語音辨識 + 語音播報
/// ✅ 模擬 AI 對話（可離線運作）
/// ✅ 真人客服切換
/// ✅ 影片教學 + 現代 UI
class CustomerServicePage extends StatefulWidget {
  const CustomerServicePage({super.key});

  @override
  State<CustomerServicePage> createState() => _CustomerServicePageState();
}

class _CustomerServicePageState extends State<CustomerServicePage>
    with SingleTickerProviderStateMixin {
  late FlutterTts _tts;
  late stt.SpeechToText _speech;
  late VideoPlayerController _videoController;

  bool _isListening = false;
  bool _isVideoReady = false;
  bool _showHumanButton = false;
  String _lastWords = "";
  String _aiAnswer = "";

  final List<String> _faq = [
    "這款手錶有防水嗎？",
    "保固多久？",
    "如何退貨？",
    "有 GPS 定位功能嗎？",
    "支援血氧或心率偵測嗎？",
  ];

  @override
  void initState() {
    super.initState();

    _tts = FlutterTts();
    _tts.setLanguage("zh-TW");
    _tts.setSpeechRate(0.45);
    _speech = stt.SpeechToText();

    // 初始化影片
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse('https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
    )
      ..initialize().then((_) {
        if (mounted) setState(() => _isVideoReady = true);
        _videoController.play();
      });
  }

  @override
  void dispose() {
    _tts.stop();
    _speech.stop();
    _videoController.dispose();
    super.dispose();
  }

  // ──────────────────────────────
  // 🧠 模擬 AI 回答邏輯（離線）
  // ──────────────────────────────
  Future<String> _getAIResponse(String question) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final q = question.toLowerCase();
    if (q.contains("防水")) return "這款手錶具備 IP68 防水等級，可日常使用。";
    if (q.contains("保固")) return "我們提供一年原廠保固，請保留購買證明。";
    if (q.contains("退貨")) return "7 天內可申請退換貨，客服會協助處理。";
    if (q.contains("定位")) return "Osmile 智慧手錶支援 GPS 即時定位與家長連線功能。";
    if (q.contains("心率") || q.contains("血氧")) return "有的！內建心率與血氧偵測功能。";
    return "這個問題我可能需要真人客服協助您。";
  }

  Future<void> _askAI(String question) async {
    setState(() {
      _aiAnswer = "思考中...";
      _showHumanButton = false;
    });

    final answer = await _getAIResponse(question);
    setState(() {
      _aiAnswer = answer;
      if (answer.contains("真人客服")) _showHumanButton = true;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("AI 客服：$answer")));
    _tts.speak(answer);
  }

  // ──────────────────────────────
  // 🎙️ 語音辨識
  // ──────────────────────────────
  Future<void> _startListening() async {
    final available = await _speech.initialize(
      onStatus: (s) {
        if (s == "notListening" && mounted) setState(() => _isListening = false);
      },
      onError: (_) => setState(() => _isListening = false),
    );

    if (!available) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("請開啟麥克風權限。")));
      return;
    }

    setState(() {
      _isListening = true;
      _lastWords = "";
    });

    _speech.listen(
      localeId: 'zh_TW',
      onResult: (r) => setState(() => _lastWords = r.recognizedWords),
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
    if (_lastWords.trim().isNotEmpty) _askAI(_lastWords);
  }

  // ──────────────────────────────
  // ☎️ 真人客服跳轉
  // ──────────────────────────────
  Future<void> _contactHumanSupport() async {
    const url = "https://lin.ee/xxxxxx"; // ← 請替換為你的官方 Line 連結
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  // ──────────────────────────────
  // 🎨 介面設計
  // ──────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("🤖 智慧客服中心"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🎬 影片教學
          if (_isVideoReady)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: _videoController.value.aspectRatio,
                child: VideoPlayer(_videoController),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),

          const SizedBox(height: 20),

          // 📋 常見問題
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("📋 常見問題",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _faq
                        .map((q) => ActionChip(
                              label: Text(q),
                              backgroundColor: Colors.blue.shade50,
                              onPressed: () => _askAI(q),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 🎙️ 語音問答
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isListening
                        ? "🎧 正在聽您說話中..."
                        : (_lastWords.isEmpty
                            ? "點擊右側麥克風開始語音詢問"
                            : "您說：$_lastWords"),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _isListening ? Colors.redAccent : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  heroTag: "mic-btn",
                  backgroundColor: _isListening ? Colors.redAccent : Colors.blueAccent,
                  onPressed: _isListening ? _stopListening : _startListening,
                  child: Icon(_isListening ? Icons.mic : Icons.mic_none),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 💬 AI 回覆
          if (_aiAnswer.isNotEmpty)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Text(_aiAnswer,
                  style: const TextStyle(fontSize: 15, color: Colors.black87)),
            ),

          const SizedBox(height: 16),

          // ☎️ 真人客服
          if (_showHumanButton)
            ElevatedButton.icon(
              icon: const Icon(Icons.support_agent),
              label: const Text("聯絡真人客服"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: _contactHumanSupport,
            ),
        ],
      ),
    );
  }
}
