import 'package:flutter/material.dart';
import 'firestore_mock_service.dart';

/// 🤖 模擬 AI 推薦引擎（根據使用者行為資料做偏好建模）
class AIRecommendationService extends ChangeNotifier {
  static final AIRecommendationService instance = AIRecommendationService._internal();
  AIRecommendationService._internal();

  // 使用者行為記錄
  final Map<String, int> _categoryScores = {
    "watch": 0,
    "kids": 0,
    "health": 0,
    "sport": 0,
  };

  // 行為加權
  final Map<String, int> _weights = {
    "click": 1,
    "favorite": 3,
    "cart": 5,
    "purchase": 10,
  };

  /// 記錄行為（例如：點擊、收藏、購買）
  void recordAction(String category, String action) {
    if (!_categoryScores.containsKey(category)) return;
    _categoryScores[category] =
        (_categoryScores[category] ?? 0) + (_weights[action] ?? 0);
    notifyListeners();
  }

  /// 回傳依據偏好排序的推薦商品
  List<Map<String, dynamic>> getRecommendations(String langCode) {
    final products =
        FirestoreMockService.instance.getMockProducts(langCode);

    // 根據行為偏好分數排序
    products.sort((a, b) {
      final scoreA = _categoryScores[a["category"]] ?? 0;
      final scoreB = _categoryScores[b["category"]] ?? 0;
      return scoreB.compareTo(scoreA);
    });

    // 取前 3 筆推薦
    return products.take(3).toList();
  }

  /// 重置學習資料（可用於測試或登出時）
  void reset() {
    for (var key in _categoryScores.keys) {
      _categoryScores[key] = 0;
    }
    notifyListeners();
  }
}
