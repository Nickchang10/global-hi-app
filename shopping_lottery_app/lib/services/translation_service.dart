import 'package:flutter/foundation.dart';

/// ✅ TranslationService（翻譯服務｜完整版｜可編譯｜無第三方套件）
/// ------------------------------------------------------------
/// 修正重點：
/// - ❌ 移除 package:translator/translator.dart（你專案沒安裝）
/// - ✅ 提供「可編譯可用」的翻譯 Stub：
///    - translate(): 先用快取/簡易字典，不命中就回傳原文
///    - translateBatch(): 批次
///    - detectLanguage(): 簡易判斷（中/英/unknown）
/// - ✅ 提供 unnamed constructor（避免你之前 new TranslationService() 報錯）
/// - ✅ 提供 singleton instance（方便全域使用）
/// ------------------------------------------------------------
class TranslationService extends ChangeNotifier {
  TranslationService();

  /// 如果其他頁面用 TranslationService.instance
  static final TranslationService instance = TranslationService();

  bool _enabled = true;
  bool _loading = false;
  String? _error;

  bool get enabled => _enabled;
  bool get loading => _loading;
  String? get error => _error;

  /// 翻譯快取：key = "$from->$to::$text"
  final Map<String, String> _cache = {};

  /// 簡易字典（可自行擴充）
  /// - 目的：讓 UI/流程先跑得起來，不依賴外部 API
  final Map<String, Map<String, String>> _basicDict = {
    // en -> zh-TW
    'en->zh-tw': {
      'hello': '你好',
      'hi': '嗨',
      'thank you': '謝謝',
      'thanks': '謝謝',
      'order': '訂單',
      'payment': '付款',
      'success': '成功',
      'failed': '失敗',
      'coupon': '優惠券',
      'lottery': '抽獎',
      'points': '積分',
      'settings': '設定',
      'profile': '個人檔案',
      'logout': '登出',
      'login': '登入',
    },
    // zh-TW -> en
    'zh-tw->en': {
      '你好': 'Hello',
      '謝謝': 'Thank you',
      '訂單': 'Order',
      '付款': 'Payment',
      '成功': 'Success',
      '失敗': 'Failed',
      '優惠券': 'Coupon',
      '抽獎': 'Lottery',
      '積分': 'Points',
      '設定': 'Settings',
      '登出': 'Logout',
      '登入': 'Login',
    },
  };

  /// 開關翻譯功能（有些頁面可能想直接顯示原文）
  void setEnabled(bool value) {
    _enabled = value;
    notifyListeners();
  }

  void clearCache() {
    _cache.clear();
    notifyListeners();
  }

  /// ✅ 翻譯文字（Stub 版）
  /// - from: 'auto' / 'en' / 'zh-TW'
  /// - to:   'zh-TW' / 'en' ...
  Future<String> translate(
    String text, {
    String from = 'auto',
    String to = 'zh-TW',
    bool useCache = true,
  }) async {
    final raw = text;
    final input = raw.trim();
    if (input.isEmpty) return raw;

    if (!_enabled) return raw;

    _setLoading(true);
    _error = null;

    try {
      final fromNorm = _normLang(from == 'auto' ? detectLanguage(input) : from);
      final toNorm = _normLang(to);

      // 同語言不翻
      if (fromNorm == toNorm) return raw;

      final cacheKey = '$fromNorm->$toNorm::$input';
      if (useCache && _cache.containsKey(cacheKey)) {
        return _cache[cacheKey]!;
      }

      // 先字典
      final dictKey = '${fromNorm.toLowerCase()}->${toNorm.toLowerCase()}';
      final dict = _basicDict[dictKey];
      if (dict != null) {
        final hit =
            dict[input.toLowerCase()] ??
            dict[input] ??
            dict[_capitalize(input)];
        if (hit != null) {
          if (useCache) _cache[cacheKey] = hit;
          return hit;
        }
      }

      // 沒命中：先回傳原文（你要真的翻譯再接 API）
      if (useCache) _cache[cacheKey] = raw;
      return raw;
    } catch (e) {
      _error = e.toString();
      return raw;
    } finally {
      _setLoading(false);
    }
  }

  /// ✅ 批次翻譯
  Future<List<String>> translateBatch(
    List<String> texts, {
    String from = 'auto',
    String to = 'zh-TW',
    bool useCache = true,
  }) async {
    final out = <String>[];
    for (final t in texts) {
      out.add(await translate(t, from: from, to: to, useCache: useCache));
    }
    return out;
  }

  /// ✅ 簡易語言判斷：有中文就當 zh-TW；純 ASCII 當 en；其他 unknown
  String detectLanguage(String text) {
    final s = text.trim();
    if (s.isEmpty) return 'unknown';

    // 有 CJK 字元 => zh-TW
    final hasCJK = RegExp(r'[\u4E00-\u9FFF]').hasMatch(s);
    if (hasCJK) return 'zh-TW';

    // 基本 ASCII => en
    final isAscii = RegExp(r'^[\x00-\x7F\s\p{P}]+$', unicode: true).hasMatch(s);
    if (isAscii) return 'en';

    return 'unknown';
  }

  // ------------------------------------------------------------
  // Internal helpers
  // ------------------------------------------------------------

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  String _normLang(String lang) {
    final l = lang.trim().toLowerCase();
    if (l == 'zh' ||
        l == 'zh_tw' ||
        l == 'zh-tw' ||
        l == 'zh-hant' ||
        l == 'zh_hant') {
      return 'zh-TW';
    }
    if (l == 'en' || l.startsWith('en-')) return 'en';
    if (l == 'auto') return 'auto';
    if (l.isEmpty) return 'unknown';
    // 保留原樣（例如 ja、ko、fr）
    return lang;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
