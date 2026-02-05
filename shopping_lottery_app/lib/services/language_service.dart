import 'package:flutter/material.dart';

/// 🌐 多語系管理服務（中 / 英 / 日）
///
/// 可在整個 App 中透過 context.watch<LanguageService>().tr(key)
/// 來自動翻譯 UI 文字。
class LanguageService extends ChangeNotifier {
  String _current = 'zh';
  String get currentLanguage => _current;

  String get currentLanguageLabel {
    switch (_current) {
      case 'en':
        return 'English';
      case 'ja':
        return '日本語';
      default:
        return '中文（繁體）';
    }
  }

  final Map<String, Map<String, String>> _localized = {
    'zh': {
      'settings': '設定',
      'appearance': '外觀',
      'dark_mode': '深色模式',
      'dark_mode_on': '目前為深色模式',
      'dark_mode_off': '目前為亮色模式',
      'language': '語言',
      'select_language': '選擇語言',
      'app_preview_title': '預覽效果',
      'app_preview_subtitle': '這裡會即時反映您的主題與語言設定。',
    },
    'en': {
      'settings': 'Settings',
      'appearance': 'Appearance',
      'dark_mode': 'Dark Mode',
      'dark_mode_on': 'Dark mode is on',
      'dark_mode_off': 'Light mode is active',
      'language': 'Language',
      'select_language': 'Select Language',
      'app_preview_title': 'Preview',
      'app_preview_subtitle': 'This preview updates in real time.',
    },
    'ja': {
      'settings': '設定',
      'appearance': '外観',
      'dark_mode': 'ダークモード',
      'dark_mode_on': '現在ダークモードです',
      'dark_mode_off': '現在ライトモードです',
      'language': '言語',
      'select_language': '言語を選択',
      'app_preview_title': 'プレビュー',
      'app_preview_subtitle': 'テーマと言語設定がリアルタイムで反映されます。',
    },
  };

  String tr(String key) => _localized[_current]?[key] ?? key;

  void setLanguage(String langCode) {
    _current = langCode;
    notifyListeners();
  }
}
