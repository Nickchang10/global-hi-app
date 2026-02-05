import 'dart:math';

class PromotionService {
  static final List<Map<String, dynamic>> _promoPool = [
    {
      "title": "Osmile 智慧手錶 ED1000",
      "type": "降價通知",
      "message": "您上次詢問的 ED1000 現在特價中 🔥 NT\$2980 → NT\$2490！",
      "image": "https://picsum.photos/id/1010/200",
    },
    {
      "title": "Osmile FitPro 手環",
      "type": "新色上市",
      "message": "FitPro 手環推出新色『天空藍』💙 現在開放預購！",
      "image": "https://picsum.photos/id/1025/200",
    },
    {
      "title": "Osmile GoAir 無線耳機",
      "type": "活動中",
      "message": "GoAir 耳機現正參與 11.11 雙倍積分活動 🎁",
      "image": "https://picsum.photos/id/1031/200",
    },
  ];

  /// 模擬隨機回傳一則優惠（如果有記憶關鍵字匹配）
  static Map<String, dynamic>? getPromotion(String keyword) {
    final relatedPromos =
        _promoPool.where((p) => p["title"].contains(keyword)).toList();
    if (relatedPromos.isEmpty) return null;

    final random = Random();
    return relatedPromos[random.nextInt(relatedPromos.length)];
  }
}
