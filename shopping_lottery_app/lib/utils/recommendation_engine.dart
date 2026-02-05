import 'dart:math';

class RecommendationEngine {
  final Random _random = Random();

  final Map<String, int> _interestScores = {
    "手錶": 5,
    "運動": 3,
    "時尚": 4,
    "健康": 2,
  };

  // ✅ 新增：好友影響力（由 FriendProvider 注入）
  Map<String, int> friendInfluence = {};

  final List<Map<String, dynamic>> _allVideos = [
    {
      "url": "https://samplelib.com/lib/preview/mp4/sample-20s.mp4",
      "user": "Leo",
      "caption": "Osmile Sport Watch 🏋️‍♀️ 專為運動族打造",
      "product": "Osmile X10",
      "tag": "運動",
      "price": 2990,
    },
    {
      "url": "https://samplelib.com/lib/preview/mp4/sample-30s.mp4",
      "user": "Mina",
      "caption": "健康手環測血氧超準 ✅",
      "product": "FitGo S",
      "tag": "健康",
      "price": 1890,
    },
    {
      "url": "https://samplelib.com/lib/preview/mp4/sample-40s.mp4",
      "user": "小美",
      "caption": "Osmile 時尚穿搭錶 💅",
      "product": "Osmile F2",
      "tag": "時尚",
      "price": 2590,
    },
  ];

  /// ✅ 新版 AI + 社交融合推薦邏輯
  List<Map<String, dynamic>> getRecommendedVideos({int count = 3}) {
    final weighted = <Map<String, dynamic>>[];

    for (final v in _allVideos) {
      final tag = v["tag"];
      final user = v["user"];

      final aiWeight = (_interestScores[tag] ?? 1);
      final friendWeight = (friendInfluence[user] ?? 0);

      final totalWeight = aiWeight + friendWeight;
      for (int i = 0; i < totalWeight; i++) {
        weighted.add(v);
      }
    }

    weighted.shuffle(_random);
    return weighted.take(count).toList();
  }

  void recordInteraction(String tag) {
    _interestScores[tag] = (_interestScores[tag] ?? 0) + 1;
  }
}
