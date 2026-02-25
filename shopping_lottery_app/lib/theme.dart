// lib/theme.dart
import 'package:flutter/material.dart';

/// ✅ AppTheme（完整版｜可編譯｜修正 background deprecated）
/// ------------------------------------------------------------
/// - 移除 ColorScheme.fromSeed(background: ...)（background 已 deprecated）
/// - Scaffold 背景色改用 scaffoldBackgroundColor 控制
/// - 其他：CardThemeData / DialogThemeData / withValues(alpha)
class AppTheme {
  AppTheme._();

  static const Color brand = Color(0xFF3D6AF2);
  static const Color appBg = Color(0xFFF6F8FB);

  static ThemeData get theme => light();

  static ThemeData light() {
    final cs = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.light,
      surface: Colors.white,
      // ❌ background: appBg, // deprecated → 移除
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,

      // ✅ 由 ThemeData 控制 app 背景
      scaffoldBackgroundColor: appBg,

      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),

      cardTheme: CardThemeData(
        elevation: 1,
        color: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: Colors.black.withValues(alpha: 0.06),
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brand, width: 1.6),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black.withValues(alpha: 0.88),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: brand,
        unselectedItemColor: Colors.black.withValues(alpha: 0.55),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: brand.withValues(alpha: 0.08),
        selectedColor: brand.withValues(alpha: 0.16),
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: brand.withValues(alpha: 0.20)),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: Colors.black.withValues(alpha: 0.70),
        textColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand,
          side: BorderSide(color: brand.withValues(alpha: 0.35)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final cs = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: const Color(0xFF0E1116),

      cardTheme: CardThemeData(
        elevation: 1,
        color: const Color(0xFF151A22),
        surfaceTintColor: const Color(0xFF151A22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF151A22),
        surfaceTintColor: const Color(0xFF151A22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}
