import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';

/// 🌟 全域浮動通知（含提示音 + TTS）
class GlobalNotifier {
  static final GlobalNotifier instance = GlobalNotifier._internal();
  GlobalNotifier._internal();

  OverlayEntry? _entry;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();

  /// 顯示通知（浮動卡 + 聲音）
  void show(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.notifications_active,
    Color background = Colors.blueAccent,
    Duration duration = const Duration(seconds: 3),
    bool speak = true, // 是否語音播報
  }) async {
    // 若已有顯示，先移除
    _entry?.remove();
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    // ✅ 播放提示音（優先）
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource("sounds/notify.mp3"));
    } catch (_) {}

    // ✅ TTS 語音播報（選擇性）
    if (speak) {
      await _tts.setLanguage("zh-TW");
      await _tts.setSpeechRate(0.5);
      await _tts.speak("$title。$message。");
    }

    // ✅ 建立浮動視覺提示
    _entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 20,
        right: 20,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Text(message,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: hide,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(_entry!);

    // ⏳ 自動隱藏
    Future.delayed(duration, hide);
  }

  void hide() {
    _entry?.remove();
    _entry = null;
  }
}
