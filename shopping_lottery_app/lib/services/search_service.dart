import 'package:flutter/material.dart';
import 'firestore_mock_service.dart';
import 'social_service.dart';

/// 🔎 搜尋服務（模擬版）
///
/// 支援：
/// - 搜尋商品（購物系統）
/// - 搜尋貼文（社群）
/// - 搜尋好友（社群）
///
/// 未使用任何外部 API，全在本地模擬。
class SearchService extends ChangeNotifier {
  SearchService._internal();
  static final SearchService instance = SearchService._internal();

  /// 🔍 搜尋方法
  Map<String, List<Map<String, dynamic>>> search(String keyword) {
    keyword = keyword.trim().toLowerCase();

    // 🛍️ 搜尋商品
    final products = FirestoreMockService.instance.cartItems
        .where((p) =>
            (p["name"] ?? "").toString().toLowerCase().contains(keyword))
        .toList();

    // 💬 搜尋貼文
    final posts = SocialService.instance.posts
        .where((p) =>
            (p["content"] ?? "").toString().toLowerCase().contains(keyword))
        .toList();

    // 👥 搜尋好友
    final friends = SocialService.instance.friends
        .where((f) => f.toLowerCase().contains(keyword))
        .map((f) => {"name": f})
        .toList();

    return {
      "products": products,
      "posts": posts,
      "friends": friends,
    };
  }
}
