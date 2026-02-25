// lib/services/ai_support_service.dart
//
// ✅ AiSupportService（AI 客服服務｜可編譯完整版）
// ------------------------------------------------------------
// - ✅ 移除未使用 import: firestore_mock_service.dart（修正 unused_import）
// - 兩段式回覆：
//   1) 先查 Firestore FAQ / Knowledge Base（可選）
//   2) 找不到則回預設客服引導
// - 可選擇把每次對話紀錄寫入 Firestore（support_conversations）
//
// Firestore 建議結構（你可用後台維護）：
// faqs/{docId}
//   - q: String
//   - a: String
//   - tags: Array<String> (optional)
//   - isActive: bool (default true)
//   - updatedAt: Timestamp
//
// knowledge_base/{docId}
//   - title: String
//   - content: String
//   - keywords: Array<String> (optional)
//   - isActive: bool (default true)
//
// support_conversations/{docId}
//   - uid: String? (optional)
//   - question: String
//   - answer: String
//   - source: String  // faq / kb / fallback
//   - createdAt: Timestamp
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AiSupportReply {
  final String answer;
  final String source; // faq / kb / fallback
  final String? matchedId;

  const AiSupportReply({
    required this.answer,
    required this.source,
    this.matchedId,
  });

  Map<String, dynamic> toJson() => {
    'answer': answer,
    'source': source,
    'matchedId': matchedId,
  };
}

class AiSupportService {
  AiSupportService._();

  static final AiSupportService instance = AiSupportService._();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ✅ 主入口：輸入使用者訊息，回傳 AI/客服回覆
  Future<AiSupportReply> reply({
    required String message,
    bool saveToFirestore = true,
  }) async {
    final q = message.trim();
    if (q.isEmpty) {
      return const AiSupportReply(
        answer: '我有在這裡～請告訴我你遇到的問題（例如：訂單、付款、優惠券、點數、抽獎、保固）。',
        source: 'fallback',
      );
    }

    // 1) 優先查 FAQ（最常用）
    final faq = await _matchFaq(q);
    if (faq != null) {
      if (saveToFirestore) {
        await _saveConversation(
          question: q,
          answer: faq.answer,
          source: faq.source,
        );
      }
      return faq;
    }

    // 2) 再查 knowledge base（較長內容）
    final kb = await _matchKnowledgeBase(q);
    if (kb != null) {
      if (saveToFirestore) {
        await _saveConversation(
          question: q,
          answer: kb.answer,
          source: kb.source,
        );
      }
      return kb;
    }

    // 3) fallback
    final fallback = AiSupportReply(
      answer: _fallbackAnswer(q),
      source: 'fallback',
    );

    if (saveToFirestore) {
      await _saveConversation(
        question: q,
        answer: fallback.answer,
        source: fallback.source,
      );
    }
    return fallback;
  }

  // -------------------------
  // FAQ matching
  // -------------------------
  Future<AiSupportReply?> _matchFaq(String q) async {
    try {
      // ✅ 為避免索引/排序問題：只抓 isActive 的前 N 筆，前端做比對
      final snap = await _fs
          .collection('faqs')
          .where('isActive', isEqualTo: true)
          .limit(200)
          .get();

      if (snap.docs.isEmpty) return null;

      final normQ = _norm(q);
      int bestScore = 0;
      QueryDocumentSnapshot<Map<String, dynamic>>? best;

      for (final d in snap.docs) {
        final data = d.data();
        final qq = _s(data['q']).trim();
        final aa = _s(data['a']).trim();
        if (qq.isEmpty || aa.isEmpty) continue;

        final score = _score(normQ, _norm(qq), tags: _stringList(data['tags']));
        if (score > bestScore) {
          bestScore = score;
          best = d;
        }
      }

      // 門檻：太低就視為沒命中
      if (best == null || bestScore < 2) return null;

      final data = best.data();
      return AiSupportReply(
        answer: _s(data['a']).trim(),
        source: 'faq',
        matchedId: best.id,
      );
    } catch (_) {
      return null;
    }
  }

  // -------------------------
  // Knowledge base matching
  // -------------------------
  Future<AiSupportReply?> _matchKnowledgeBase(String q) async {
    try {
      final snap = await _fs
          .collection('knowledge_base')
          .where('isActive', isEqualTo: true)
          .limit(200)
          .get();

      if (snap.docs.isEmpty) return null;

      final normQ = _norm(q);
      int bestScore = 0;
      QueryDocumentSnapshot<Map<String, dynamic>>? best;

      for (final d in snap.docs) {
        final data = d.data();
        final title = _s(data['title']).trim();
        final content = _s(data['content']).trim();
        if (title.isEmpty && content.isEmpty) continue;

        final kw = _stringList(data['keywords']);
        final score = _score(normQ, _norm('$title $content'), tags: kw);
        if (score > bestScore) {
          bestScore = score;
          best = d;
        }
      }

      if (best == null || bestScore < 2) return null;

      final data = best.data();
      final title = _s(data['title']).trim();
      final content = _s(data['content']).trim();

      // ✅ 回覆不要太長：截斷到 600 字（你可自行調整）
      final full = (title.isNotEmpty ? '【$title】\n' : '') + content;
      final answer = full.length > 600 ? '${full.substring(0, 600)}…' : full;

      return AiSupportReply(answer: answer, source: 'kb', matchedId: best.id);
    } catch (_) {
      return null;
    }
  }

  // -------------------------
  // Save conversation
  // -------------------------
  Future<void> _saveConversation({
    required String question,
    required String answer,
    required String source,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      await _fs.collection('support_conversations').add({
        'uid': uid,
        'question': question,
        'answer': answer,
        'source': source,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // 靜默失敗，不影響 UX
    }
  }

  // -------------------------
  // Helpers
  // -------------------------
  String _fallbackAnswer(String q) {
    // 你可以針對 Osmile 常見問題加更精準分流
    final n = _norm(q);

    if (n.contains('退款') || n.contains('退貨')) {
      return '看起來你在詢問退貨/退款。\n\n請提供：訂單編號、購買時間、商品名稱、原因，我會引導你完成處理。';
    }
    if (n.contains('付款') || n.contains('支付') || n.contains('刷卡')) {
      return '付款遇到問題嗎？\n\n請告訴我：付款方式（信用卡/轉帳/其他）、錯誤訊息截圖文字、訂單編號，我幫你排查。';
    }
    if (n.contains('優惠券') || n.contains('折扣') || n.contains('coupon')) {
      return '優惠券使用問題我可以協助。\n\n請提供：優惠券代碼（如有）、結帳商品、顯示的提示訊息，我幫你判斷是否符合條件。';
    }
    if (n.contains('點數') || n.contains('積分')) {
      return '點數相關我可以協助。\n\n你想查：點數餘額、點數入帳、點數兌換，還是點數不足？請描述一下情況。';
    }
    if (n.contains('抽獎') || n.contains('福袋') || n.contains('lottery')) {
      return '抽獎/福袋活動我可以幫你查規則與資格。\n\n請提供：活動名稱或活動頁截圖文字、你的參與方式（下單/任務/點數）。';
    }

    return '我了解了。\n\n請補充：你遇到的功能頁面（例如：結帳/付款/訂單/優惠券/點數/抽獎）、發生時間、以及畫面提示訊息（或截圖文字），我會更快定位問題。';
  }

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  List<String> _stringList(dynamic v) {
    if (v is List) {
      return v.map((e) => _s(e).trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  /// 簡單 scoring：關鍵字命中 + tag 命中
  int _score(String qNorm, String targetNorm, {List<String> tags = const []}) {
    int score = 0;

    // 句子片段命中（粗略）
    if (targetNorm.contains(qNorm)) score += 3;
    if (qNorm.contains(targetNorm) && targetNorm.length >= 4) score += 2;

    // token 命中：把 q 拆一些短 token（避免過度計算）
    final tokens = _tokens(qNorm);
    for (final t in tokens) {
      if (t.length < 2) continue;
      if (targetNorm.contains(t)) score += 1;
    }

    // tags / keywords 命中加權
    for (final tag in tags) {
      final tn = _norm(tag);
      if (tn.isEmpty) continue;
      if (qNorm.contains(tn)) score += 2;
    }

    return score;
  }

  List<String> _tokens(String qNorm) {
    // 粗拆：中文沒有空白，用滑動片段補強；英文用字母數字分段
    final byWord = qNorm
        .split(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (byWord.isNotEmpty) return byWord;

    // fallback：滑動取片段
    final out = <String>[];
    for (int i = 0; i < qNorm.length; i++) {
      final end = (i + 3 <= qNorm.length) ? i + 3 : qNorm.length;
      out.add(qNorm.substring(i, end));
    }
    return out;
  }
}
