import 'package:flutter/material.dart';
import 'package:translator/translator.dart';
import 'language_service.dart';

/// 🌍 TranslationService：多語翻譯系統
///
/// 功能：
/// - 支援 Google 翻譯 API
/// - 自動偵測來源語言
/// - 翻譯成當前選擇語系
/// - 支援雙語顯示模式
class TranslationService with ChangeNotifier {
  static final TranslationService instance = TranslationService._internal();
  TranslationService._internal();

  final GoogleTranslator _translator = GoogleTranslator();
  bool _dualDisplay = true;

  bool get dualDisplay => _dualDisplay;
  void toggleDualDisplay() {
    _dualDisplay = !_dualDisplay;
    notifyListeners();
  }

  /// 自動偵測並翻譯
  Future<Map<String, String>> translate(String text) async {
    if (text.trim().isEmpty) {
      return {"original": text, "translated": text};
    }

    try {
      final langCode = LanguageService().locale.languageCode;
      final translation =
          await _translator.translate(text, to: langCode);
      return {
        "original": text,
        "translated": translation.text,
      };
    } catch (e) {
      debugPrint("🌐 翻譯錯誤: $e");
      return {"original": text, "translated": text};
    }
  }
}
