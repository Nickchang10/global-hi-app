import 'dart:math';

/// 🤖 AI 社群助手
///
/// 依據貼文內容提供友善留言建議（模擬版）
///
/// 未使用真實 AI API，可隨時改成 OpenAI、Gemini、Claude 等模型
class AiSocialHelper {
  static final Random _rnd = Random();

  static const _positiveReplies = [
    "哇～這看起來超棒的！",
    "好想試試看 😍",
    "感覺真的很不錯呢！",
    "恭喜入手～期待你的使用心得～",
    "超實用的感覺 👍",
    "我也有買同款，真的很好用！",
  ];

  static const _neutralReplies = [
    "看起來不錯耶～",
    "這品牌我聽過，不錯！",
    "有興趣再了解看看～",
    "原來還有這功能，長知識了！",
  ];

  static const _supportReplies = [
    "加油！你一定可以的 💪",
    "祝你順利！",
    "別擔心，一切都會更好～",
    "給你一個擁抱 🤗",
  ];

  /// 根據內容關鍵字生成留言建議
  static String suggestReply(String content) {
    final lower = content.toLowerCase();
    if (lower.contains("買") || lower.contains("商品") || lower.contains("watch")) {
      return _positiveReplies[_rnd.nextInt(_positiveReplies.length)];
    } else if (lower.contains("想問") || lower.contains("推薦")) {
      return _neutralReplies[_rnd.nextInt(_neutralReplies.length)];
    } else if (lower.contains("加油") || lower.contains("難過")) {
      return _supportReplies[_rnd.nextInt(_supportReplies.length)];
    } else {
      final all = [..._positiveReplies, ..._neutralReplies];
      return all[_rnd.nextInt(all.length)];
    }
  }
}
