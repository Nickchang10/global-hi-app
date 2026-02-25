// lib/utils/font_loader.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// ✅ FontLoaderUtil（字型載入/套用｜完整版｜已修 prefer_null_aware_operators）
/// ------------------------------------------------------------
/// 用途：
/// - 你的專案若會動態切換字體（例如 NotoSansTC / Roboto），可用此工具
/// - 這裡不做網路下載，只負責「套用字型名稱到 Theme」
///
/// 說明：
/// - Flutter Web/Android/iOS：只要在 pubspec.yaml 宣告 fonts，就能用 fontFamily 套用
/// - 若未宣告或找不到字型，Flutter 會 fallback 系統字體
class FontLoaderUtil {
  FontLoaderUtil._();

  /// 你可以統一在這裡維護字型 family 名稱
  static const String defaultFontFamily = 'NotoSansTC';

  /// 依你需求決定是否強制套用到所有 TextTheme
  static ThemeData applyFontToTheme(ThemeData base, {String? fontFamily}) {
    final family = (fontFamily == null || fontFamily.trim().isEmpty)
        ? defaultFontFamily
        : fontFamily.trim();

    final textTheme = _applyToTextTheme(base.textTheme, family);
    final primaryTextTheme = _applyToTextTheme(base.primaryTextTheme, family);

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
    );
  }

  /// 把字型套到 TextTheme（修正點：用 ?. 取代顯式 null 比較）
  static TextTheme _applyToTextTheme(TextTheme theme, String family) {
    TextStyle? apply(TextStyle? s) => s?.copyWith(fontFamily: family);

    // ✅ 這種寫法最常觸發 prefer_null_aware_operators：
    //    if (theme.bodyMedium != null) { ... }
    // ✅ 已改成 null-aware 的 ?. 方式
    return theme.copyWith(
      displayLarge: apply(theme.displayLarge),
      displayMedium: apply(theme.displayMedium),
      displaySmall: apply(theme.displaySmall),
      headlineLarge: apply(theme.headlineLarge),
      headlineMedium: apply(theme.headlineMedium),
      headlineSmall: apply(theme.headlineSmall),
      titleLarge: apply(theme.titleLarge),
      titleMedium: apply(theme.titleMedium),
      titleSmall: apply(theme.titleSmall),
      bodyLarge: apply(theme.bodyLarge),
      bodyMedium: apply(theme.bodyMedium),
      bodySmall: apply(theme.bodySmall),
      labelLarge: apply(theme.labelLarge),
      labelMedium: apply(theme.labelMedium),
      labelSmall: apply(theme.labelSmall),
    );
  }

  /// （可選）debug：檢查目前 Theme 字體設定
  static void debugPrintCurrentThemeFont(BuildContext context) {
    if (!kDebugMode) return;
    final t = Theme.of(context).textTheme;
    debugPrint('[Font] bodyMedium.fontFamily = ${t.bodyMedium?.fontFamily}');
  }
}
