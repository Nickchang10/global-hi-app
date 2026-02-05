/// 🧠 AI Emotion Engine
/// Phase 20：AI 情緒辨識與語氣調整系統
///
/// 功能：
/// - analyzeEmotion(text): 分析文字情緒（positive / negative / anxious / neutral）
/// - generateEmotionalReply(userText, baseReply): 根據情緒調整回覆語氣
///
/// ✅ 純本地邏輯，無需連線 / 第三方套件
class AIEmotionEngine {
  AIEmotionEngine._internal();
  static final AIEmotionEngine instance = AIEmotionEngine._internal();

  /// 情緒標籤：
  /// positive：正向
  /// negative：負向 / 生氣
  /// anxious：焦慮 / 擔心
  /// neutral：中性
  String analyzeEmotion(String? text) {
    if (text == null) return "neutral";

    final content = text.toLowerCase().trim();
    if (content.isEmpty) return "neutral";

    int positive = 0;
    int negative = 0;
    int anxious = 0;

    // ✅ 中英文簡單關鍵字規則（可之後再擴充）
    final positiveWords = <String>[
      "thank", "thanks", "good", "great", "nice", "love",
      "棒", "喜歡", "感謝", "謝謝", "太好了", "讚", "滿意",
    ];

    final negativeWords = <String>[
      "bad", "hate", "angry", "angry", "terrible", "shit",
      "爛", "壞", "氣", "生氣", "不爽", "差", "失望", "不滿意", "垃圾",
    ];

    final anxiousWords = <String>[
      "worry", "worried", "anxious", "scared", "afraid",
      "擔心", "緊張", "焦慮", "怕", "不安", "不知道怎麼辦", "急",
    ];

    for (final w in positiveWords) {
      if (content.contains(w.toLowerCase())) positive++;
    }
    for (final w in negativeWords) {
      if (content.contains(w.toLowerCase())) negative++;
    }
    for (final w in anxiousWords) {
      if (content.contains(w.toLowerCase())) anxious++;
    }

    // 若完全沒有命中關鍵字，視為中性
    if (positive == 0 && negative == 0 && anxious == 0) {
      return "neutral";
    }

    // 比較強度，誰分數高就是哪個情緒
    if (anxious >= negative && anxious >= positive) {
      return "anxious";
    } else if (negative >= positive && negative >= anxious) {
      return "negative";
    } else if (positive >= negative && positive >= anxious) {
      return "positive";
    }

    return "neutral";
  }

  /// 🎭 根據使用者情緒，調整 AI 回覆語氣
  ///
  /// [userText]：使用者原始訊息
  /// [baseReply]：原本的標準回覆內容（例如：「您的訂單已出貨…」）
  String generateEmotionalReply(String userText, String baseReply) {
    final emotion = analyzeEmotion(userText);

    switch (emotion) {
      case "positive":
        // 正向：一起開心、保持活潑語氣
        return "🥰 感謝你的回饋！\n$baseReply";

      case "negative":
        // 負向：先道歉、安撫情緒，再給解決方案
        return "😢 很抱歉讓你有這樣的感受，我會協助你一起處理。\n$baseReply";

      case "anxious":
        // 焦慮：先安撫、降低緊張感，再慢慢說明
        return "😌 先別擔心，我一步一步說明給你聽，好嗎？\n$baseReply";

      default:
        // 中性：一般友善語氣
        return "🙂 $baseReply";
    }
  }
}
