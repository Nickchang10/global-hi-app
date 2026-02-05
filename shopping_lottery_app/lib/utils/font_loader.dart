import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ✅ 用於自動偵測字型檔是否存在
/// 若不存在，則自動回退使用系統字型
class SafeFontLoader {
  static bool _customFontAvailable = false;

  static Future<void> initialize() async {
    try {
      final data =
          await rootBundle.load('assets/fonts/NotoSansTC-Regular.otf');
      if (data.lengthInBytes > 0) {
        _customFontAvailable = true;
        debugPrint("✅ 已載入字型：NotoSansTC-Regular.otf");
      }
    } catch (e) {
      _customFontAvailable = false;
      debugPrint(
          "⚠️ 找不到字型 assets/fonts/NotoSansTC-Regular.otf，將使用系統字型。");
    }
  }

  /// 🎨 回傳可安全使用的文字樣式
  static TextStyle textStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color color = Colors.black,
  }) {
    if (_customFontAvailable) {
      return TextStyle(
        fontFamily: 'NotoSansTC',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    } else {
      // 🧠 使用 GoogleFonts 提供的 NotoSansTC 雲端字型作為替代方案
      return GoogleFonts.notoSansTc(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    }
  }

  /// 供外部檢查狀態
  static bool get isCustomFontLoaded => _customFontAvailable;
}
