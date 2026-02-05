// lib/l10n/app_localizations.dart
//
// ✅ AppLocalizations（正式完整可編譯版）
// ------------------------------------------------------------
// - 不使用 gen-l10n，不需 ARB 或 l10n.yaml
// - 含所有頁面用到的字串
// - 含 getLocaleLabel()
// - 支援 RTL 語言（阿拉伯文）
// ------------------------------------------------------------

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static const supportedLocales = [
    Locale('en'),
    Locale('zh', 'TW'),
    Locale('zh', 'CN'),
    Locale('ja'),
    Locale('ko'),
    Locale('fr'),
    Locale('de'),
    Locale('es'),
    Locale('pt'),
    Locale('ru'),
    Locale('ar'),
    Locale('hi'),
    Locale('th'),
    Locale('vi'),
    Locale('id'),
    Locale('ms'),
  ];

  static const delegate = _AppLocalizationsDelegate();

  static const localizationsDelegates = [
    delegate,
    DefaultWidgetsLocalizations.delegate,
    DefaultMaterialLocalizations.delegate,
    DefaultCupertinoLocalizations.delegate,
  ];

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const _values = {
    'en': {
      'appTitle': 'Osmile Admin',
      'dashboard': 'Dashboard',
      'products': 'Products',
      'categories': 'Categories',
      'notifications': 'Notifications',
      'reports': 'Reports',
      'logout': 'Logout',
      'role': 'Role',
      'language': 'Language',
      'systemLanguage': 'System Language',
      'followSystem': 'Follow System',
      'confirm': 'Confirm',
      'cancel': 'Cancel',
      'apply': 'Apply',
      'notLoggedIn': 'Not Logged In',
    },
    'zh_TW': {
      'appTitle': 'Osmile 管理後台',
      'dashboard': '儀表板',
      'products': '商品管理',
      'categories': '分類管理',
      'notifications': '通知中心',
      'reports': '報表分析',
      'logout': '登出',
      'role': '角色',
      'language': '語言',
      'systemLanguage': '系統語言',
      'followSystem': '跟隨系統',
      'confirm': '確認',
      'cancel': '取消',
      'apply': '套用',
      'notLoggedIn': '尚未登入',
    },
    'zh_CN': {
      'appTitle': 'Osmile 管理后台',
      'dashboard': '仪表板',
      'products': '商品管理',
      'categories': '分类管理',
      'notifications': '通知中心',
      'reports': '报表分析',
      'logout': '登出',
      'role': '角色',
      'language': '语言',
      'systemLanguage': '系统语言',
      'followSystem': '跟随系统',
      'confirm': '确认',
      'cancel': '取消',
      'apply': '应用',
      'notLoggedIn': '尚未登录',
    },
    'ar': {
      'appTitle': 'Osmile المسؤول',
      'dashboard': 'لوحة التحكم',
      'products': 'المنتجات',
      'categories': 'الفئات',
      'notifications': 'الإشعارات',
      'reports': 'التقارير',
      'logout': 'تسجيل الخروج',
      'role': 'الدور',
      'language': 'اللغة',
      'systemLanguage': 'لغة النظام',
      'followSystem': 'اتباع النظام',
      'confirm': 'تأكيد',
      'cancel': 'إلغاء',
      'apply': 'تطبيق',
      'notLoggedIn': 'لم يتم تسجيل الدخول',
    },
  };

  // ============================================================
  // Helper
  // ============================================================
  String _key(Locale l) {
    if (l.languageCode == 'zh') {
      if ((l.countryCode ?? '').toUpperCase() == 'TW') return 'zh_TW';
      if ((l.countryCode ?? '').toUpperCase() == 'CN') return 'zh_CN';
    }
    return l.languageCode;
  }

  String t(String key) {
    final lk = _key(locale);
    return _values[lk]?[key] ?? _values['en']?[key] ?? key;
  }

  // ============================================================
  // Getter（所有頁面呼叫的字串）
  // ============================================================
  String get appTitle => t('appTitle');
  String get dashboard => t('dashboard');
  String get products => t('products');
  String get categories => t('categories');
  String get notifications => t('notifications');
  String get reports => t('reports');
  String get logout => t('logout');
  String get role => t('role');
  String get language => t('language');
  String get systemLanguage => t('systemLanguage');
  String get followSystem => t('followSystem');
  String get confirm => t('confirm');
  String get cancel => t('cancel');
  String get apply => t('apply');
  String get notLoggedIn => t('notLoggedIn');

  // ============================================================
  // 顯示語言名稱
  // ============================================================
  static String getLocaleLabel(Locale locale) {
    final map = {
      'en': 'English',
      'zh_TW': '繁體中文',
      'zh_CN': '简体中文',
      'ar': 'العربية',
    };
    final code = locale.languageCode == 'zh'
        ? (locale.countryCode == 'TW' ? 'zh_TW' : 'zh_CN')
        : locale.languageCode;
    return map[code] ?? code;
  }

  // ============================================================
  // RTL 支援
  // ============================================================
  TextDirection get textDirection =>
      ['ar', 'he', 'fa', 'ur'].contains(locale.languageCode)
          ? TextDirection.rtl
          : TextDirection.ltr;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales
          .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(_) => false;
}
