import 'package:flutter/material.dart';
import 'firestore_mock_service.dart';
import 'wishlist_service.dart';

/// 模擬推薦系統（根據收藏與隨機推薦）
class RecommendationService extends ChangeNotifier {
  RecommendationService._internal();
  static final RecommendationService instance = RecommendationService._internal();

  List<Map<String, dynamic>> getRecommendedProducts() {
    final all = FirestoreMockService.instance.products;
    final favs = WishlistService.instance.wishlist;

    if (favs.isNotEmpty) {
      // 推薦同系列商品
      final keywords = favs.map((f) => f["name"].toString().split(" ").first);
      return all
          .where((p) => keywords.any((k) => p["name"].contains(k)))
          .take(4)
          .toList();
    }

    // 若無收藏，隨機推薦
    all.shuffle();
    return all.take(4).toList();
  }
}
