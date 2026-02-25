import 'package:flutter/material.dart';

import 'point_shop_page.dart';

/// ✅ PointsMallPage（點數商城入口頁｜修改後完整版）
/// ------------------------------------------------------------
/// ✅ 修正重點：
/// - 移除 FirestoreMockService.userPoints 依賴（解掉 undefined_getter）
/// - 直接導向已修正版 PointShopPage（FirebaseAuth + Firestore）
///
/// 用途：
/// - 如果專案內還有舊路由指向 /points/mall 或 PointsMallPage
///   這頁可以當作「相容層」，避免你同時維護兩份商城頁面。
/// ------------------------------------------------------------
class PointsMallPage extends StatelessWidget {
  const PointsMallPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ 直接使用你已修好的點數商城頁
    return const PointShopPage();
  }
}
