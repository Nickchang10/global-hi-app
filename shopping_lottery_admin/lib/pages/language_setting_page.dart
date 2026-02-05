// lib/pages/language_setting_page.dart
//
// ✅ 全語系切換設定頁（AppLocalizations + LocaleController 最終正式版）
// ------------------------------------------------------------
// 功能：
// - 即時切換 App 語系（不需重啟）
// - 支援你在 AppLocalizations.supportedLocales 中列出的所有語言
// - 自動記錄使用者偏好（SharedPreferences）
// - 包含「跟隨系統」選項
// ------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/locale_controller.dart';
import '../l10n/app_localizations.dart';

class LanguageSettingPage extends StatelessWidget {
  const LanguageSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final localeCtrl = context.watch<LocaleController>();
    final currentLocale = localeCtrl.locale;

    // ✅ 全部語言列表（含系統語言）
    final locales = <Locale?>[null, ...localeCtrl.supportedLocales];

    return Scaffold(
      appBar: AppBar(
        title: Text(t.language),
        actions: [
          TextButton(
            onPressed: () async {
              await localeCtrl.useSystemLocale();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${t.apply}: ${t.systemLanguage}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
            child: Text(
              t.systemLanguage,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: locales.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final locale = locales[index];
          final label = localeCtrl.getLocaleLabel(locale);

          final isSelected = (locale == null && currentLocale == null) ||
              (locale != null &&
                  currentLocale != null &&
                  locale.languageCode == currentLocale.languageCode &&
                  (locale.countryCode ?? '') == (currentLocale.countryCode ?? ''));

          return ListTile(
            title: Text(label, style: const TextStyle(fontSize: 16)),
            trailing: Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).hintColor,
            ),
            onTap: () async {
              if (locale == null) {
                await localeCtrl.useSystemLocale();
              } else {
                await localeCtrl.setLocale(locale);
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${t.language}: ${localeCtrl.getLocaleLabel(locale)} (${t.apply})',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

