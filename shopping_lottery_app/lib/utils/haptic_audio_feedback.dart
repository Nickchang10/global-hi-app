// lib/utils/haptic_audio_feedback.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

/// ======================================================
/// ✅ HapticAudioFeedback（震動 + 音效）最終完整版
/// ------------------------------------------------------
/// - 全域開關：setEnabled / setMuted / setVolume
/// - 方法齊全：feedback / success / warning / error / selection
/// - Web/不支援裝置：自動 try/catch 忽略
/// - 音效避免重疊：用佇列串接 stop->play，避免多次點擊競態
///
/// 需要的 assets（pubspec 已宣告 assets/audio/）：
/// - assets/audio/win.mp3
/// - assets/audio/spin.mp3（選用）
/// - assets/audio/error.mp3（選用）
/// - assets/audio/warning.mp3（選用）
///
/// 使用方式（建議）
/// - 按鈕：HapticAudioFeedback.feedback();
/// - 成功：HapticAudioFeedback.success();
/// - 警告：HapticAudioFeedback.warning();
/// - 失敗：HapticAudioFeedback.error();
/// - Chip 選取：HapticAudioFeedback.selection();
/// ======================================================
class HapticAudioFeedback {
  HapticAudioFeedback._();

  static final AudioPlayer _player = AudioPlayer();

  static bool _enabled = true;
  static bool _muted = false;
  static double _volume = 1.0;

  // 用來避免 stop/play 競態：所有播放串成一條 Future 鏈
  static Future<void> _playChain = Future<void>.value();

  // （可選）初始化一次：設定音量、避免某些平台首次延遲
  static bool _inited = false;
  static Future<void> init() async {
    if (_inited) return;
    _inited = true;

    try {
      await _player.setVolume(_volume.clamp(0.0, 1.0));
    } catch (_) {}

    // 注意：不要在 init() 主動 play，避免 Web 沒有 user gesture 被擋
  }

  // -----------------------
  // Global toggles
  // -----------------------
  static void setEnabled(bool v) => _enabled = v;
  static bool get isEnabled => _enabled;

  static void setMuted(bool v) => _muted = v;
  static bool get isMuted => _muted;

  static Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    try {
      await _player.setVolume(_volume);
    } catch (_) {}
  }

  // -----------------------
  // Public APIs
  // -----------------------

  /// 一般提示（按鈕/通知）
  static Future<void> feedback() async {
    if (!_enabled) return;
    await init();
    await _lightHaptic();
    await _playQueued('audio/win.mp3');
  }

  /// 成功（結帳成功/抽獎中獎）
  static Future<void> success() async {
    if (!_enabled) return;
    await init();
    await _mediumHaptic();
    await _playQueued('audio/win.mp3');
  }

  /// 警告（清空/刪除等風險操作）
  static Future<void> warning() async {
    if (!_enabled) return;
    await init();
    await _vibrate();
    await _playQueuedWithFallback('audio/warning.mp3', fallback: 'audio/win.mp3');
  }

  /// 錯誤（付款失敗/不足）
  static Future<void> error() async {
    if (!_enabled) return;
    await init();
    await _heavyHaptic();
    await _playQueuedWithFallback('audio/error.mp3', fallback: 'audio/win.mp3');
  }

  /// 選取（切換 filter / chip）
  static Future<void> selection() async {
    if (!_enabled) return;
    await init();
    await _selectionClick();
    // selection 不一定要播音效（你要也可以打開下一行）
    // await _playQueued('audio/spin.mp3');
  }

  /// 你若想給抽獎「轉盤」專用音效（選用）
  static Future<void> spin() async {
    if (!_enabled) return;
    await init();
    await _selectionClick();
    await _playQueuedWithFallback('audio/spin.mp3', fallback: 'audio/win.mp3');
  }

  // -----------------------
  // Haptics
  // -----------------------
  static Future<void> _lightHaptic() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static Future<void> _mediumHaptic() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static Future<void> _heavyHaptic() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  static Future<void> _vibrate() async {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }

  static Future<void> _selectionClick() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  // -----------------------
  // Audio helpers (Queued)
  // -----------------------

  static Future<void> _playQueued(String assetRelativePath) {
    if (_muted) return Future<void>.value();

    final p = _normalizeAssetPath(assetRelativePath);

    // Web：通常需要 user gesture 才能播放；這裡不做額外處理，讓使用者互動觸發即可
    // 串接佇列：避免 stop/play 同時多次呼叫導致例外或重疊
    _playChain = _playChain.then((_) async {
      try {
        await _player.stop();
      } catch (_) {}
      try {
        await _player.setVolume(_volume.clamp(0.0, 1.0));
      } catch (_) {}
      try {
        await _player.play(AssetSource(p));
      } catch (_) {}
    });

    return _playChain;
  }

  static Future<void> _playQueuedWithFallback(
    String assetRelativePath, {
    required String fallback,
  }) async {
    if (_muted) return;

    final primary = _normalizeAssetPath(assetRelativePath);
    final fb = _normalizeAssetPath(fallback);

    _playChain = _playChain.then((_) async {
      try {
        await _player.stop();
      } catch (_) {}

      try {
        await _player.setVolume(_volume.clamp(0.0, 1.0));
      } catch (_) {}

      try {
        await _player.play(AssetSource(primary));
      } catch (_) {
        try {
          await _player.stop();
        } catch (_) {}
        try {
          await _player.play(AssetSource(fb));
        } catch (_) {}
      }
    });

    await _playChain;
  }

  /// 允許你傳入 "assets/audio/win.mp3" 或 "audio/win.mp3"
  /// audioplayers 的 AssetSource 需要的是相對於 assets root 的路徑
  static String _normalizeAssetPath(String input) {
    var p = input.trim();
    if (p.startsWith('/')) p = p.substring(1);
    if (p.startsWith('assets/')) p = p.substring('assets/'.length);
    return p;
  }

  // -----------------------
  // Optional cleanup
  // -----------------------
  static Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
