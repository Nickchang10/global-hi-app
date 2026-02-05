// lib/controllers/locale_controller.dart
//
// ✅ LocaleController（多國語系控制器・最終正式版｜自訂 AppLocalizations）
// ------------------------------------------------------------
// 功能：
// - 跟隨系統語言（_locale = null）
// - 記憶使用者選擇（SharedPreferences）
// - 手動切換語言（AppLocalizations.supportedLocales）
// - 提供語言顯示名稱（可用於設定頁）
// - main() 先 await ensureLoaded()，避免 build 期間 notifyListeners
// ------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

class LocaleController extends ChangeNotifier {
  static const String _kPrefsKey = 'selected_locale'; // e.g. system / en / zh_TW

  Locale? _locale; // null = follow system
  Locale? get locale => _locale;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// ✅ 所有支援語系（直接沿用 AppLocalizations）
  List<Locale> get supportedLocales => AppLocalizations.supportedLocales;

  /// ✅ 目前語言代碼（system / en / zh_TW）
  String get currentCode {
    final l = _locale;
    if (l == null) return 'system';

    final cc = (l.countryCode ?? '').trim();
    if (cc.isNotEmpty) return '${l.languageCode}_$cc';
    return l.languageCode;
  }

  /// ✅ 啟動初始化：main() 先 await 再 runApp()
  /// - 若已載入則直接 return
  /// - 不在此 notify（因 main 已 await）
  Future<void> ensureLoaded() async {
    if (_loaded) return;

    final prefs = await SharedPreferences.getInstance();
    final code = (prefs.getString(_kPrefsKey) ?? 'system').trim();

    if (code.isEmpty || code == 'system') {
      _locale = null;
    } else {
      _locale = _parseLocaleCode(code);
    }

    _loaded = true;
  }

  /// ✅ 設定特定語言（會持久化）
  Future<void> setLocale(Locale locale) async {
    _locale = _normalize(locale);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, _encode(_locale!));

    notifyListeners();
  }

  /// ✅ 改回跟隨系統語言（會持久化）
  Future<void> useSystemLocale() async {
    _locale = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, 'system');

    notifyListeners();
  }

  /// ✅ 允許用字串 code 切換（system / en / zh_TW / zh_CN）
  /// - 若不在 supportedLocales，仍會設定成功，但 UI 可能會 fallback
  Future<void> trySetByCode(String code) async {
    final c = code.trim();
    if (c.isEmpty || c == 'system') {
      await useSystemLocale();
      return;
    }
    final loc = _parseLocaleCode(c);
    await setLocale(loc);
  }

  /// ✅ 顯示名稱：統一走 AppLocalizations.getLocaleLabel（若有）
  /// - 若你未提供 getLocaleLabel，也會 fallback 使用內建 map
  String getLocaleLabel(Locale? locale) {
    if (locale == null) return '跟隨系統';

    // 如果你的 AppLocalizations 有提供靜態 getLocaleLabel，就優先用它
    // ignore: unnecessary_null_comparison
    try {
      return AppLocalizations.getLocaleLabel(locale);
    } catch (_) {
      // fallback to internal mapping
      final code = _encode(_normalize(locale));
      return _fallbackLabel(code);
    }
  }

  /// ✅ 目前語言顯示名稱
  String get currentLocaleLabel => getLocaleLabel(_locale);

  // ------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------

  /// 將 Locale 統一成我們常用的形式（例如 zh_TW / zh_CN）
  Locale _normalize(Locale l) {
    final lang = l.languageCode.trim();
    final cc = (l.countryCode ?? '').trim();

    if (lang == 'zh') {
      final upper = cc.toUpperCase();
      if (upper == 'TW') return const Locale('zh', 'TW');
      if (upper == 'CN') return const Locale('zh', 'CN');
      // 若沒給 country，就保持 zh（讓系統 fallback）
      return const Locale('zh');
    }

    if (cc.isEmpty) return Locale(lang);
    return Locale(lang, cc);
  }

  String _encode(Locale l) {
    final cc = (l.countryCode ?? '').trim();
    if (cc.isNotEmpty) return '${l.languageCode}_$cc';
    return l.languageCode;
  }

  Locale _parseLocaleCode(String code) {
    // 支援：
    // - en
    // - zh_TW
    // - zh-TW（languageTag）
    // - zh_TW（underscore）
    final c = code.replaceAll('-', '_').trim();

    if (c.contains('_')) {
      final parts = c.split('_');
      final lang = parts.isNotEmpty ? parts[0] : c;
      final cc = parts.length >= 2 ? parts[1] : null;
      if (cc == null || cc.trim().isEmpty) return _normalize(Locale(lang));
      return _normalize(Locale(lang, cc));
    }

    return _normalize(Locale(c));
  }

  String _fallbackLabel(String code) {
    switch (code) {
      case 'zh_TW':
        return '繁體中文';
      case 'zh_CN':
        return '简体中文';
      case 'en':
        return 'English';
      case 'ja':
        return '日本語';
      case 'ko':
        return '한국어';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'es':
        return 'Español';
      case 'pt':
        return 'Português';
      case 'ru':
        return 'Русский';
      case 'ar':
        return 'العربية';
      case 'hi':
        return 'हिन्दी';
      case 'th':
        return 'ไทย';
      case 'vi':
        return 'Tiếng Việt';
      case 'id':
        return 'Bahasa Indonesia';
      case 'ms':
        return 'Bahasa Melayu';
      default:
        return code;
    }
  }
}
