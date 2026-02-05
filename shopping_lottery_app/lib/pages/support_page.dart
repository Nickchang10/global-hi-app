// lib/pages/support_page.dart
// ======================================================
// ✅ Osmile 客服支援中心（AI 強化完整版）
// ------------------------------------------------------
// SupportPage：FAQ / 聯絡客服 / 問題回報
// ChatBotPage：
// - ✅ 知識庫檢索（RAG-like retrieval）
// - ✅ 意圖分類 + 信心分數 + 多輪上下文
// - ✅ 智慧建議 Quick Replies
// - ✅ 打字中指示器
// - ✅ SharedPreferences 對話保存/清除
// ======================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ======================================================
// ✅ SupportPage
// ======================================================
class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  static const Color _bg = Color(0xFFF7F8FA);

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    final ok = await canLaunchUrl(uri);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法開啟連結')),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已送出問題，我們將盡快回覆您。')),
    );

    _emailCtrl.clear();
    _msgCtrl.clear();
  }

  final List<Map<String, String>> _faqList = const [
    {
      'q': '如何綁定手錶與 App？',
      'a': '請確認藍牙已開啟，開啟 Osmile App > 點選「我的裝置」> 按「搜尋裝置」即可自動配對。'
    },
    {
      'q': 'SOS 求助訊號如何使用？',
      'a': '長按手錶右側按鍵約 3 秒，會自動發送求救通知至家人端。'
    },
    {
      'q': '如何查看我的訂單？',
      'a': '進入「我的 > 訂單」即可查看購買紀錄與出貨狀態。'
    },
    {
      'q': '退貨/退款怎麼申請？',
      'a': '請至「我的 > 訂單」點選訂單申請售後，或直接透過客服信箱/即時客服提供訂單編號協助。'
    },
    {
      'q': '保固範圍與期限？',
      'a': '一般商品提供 1 年保固（依購買憑證/序號為準）。若屬人為/進水/外力損壞，可能不在保固範圍。'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('客服支援', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.8,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContactSection(context),
            const SizedBox(height: 18),
            _buildFAQSection(),
            const SizedBox(height: 18),
            _buildFormSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0.6,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('聯絡客服', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.smart_toy_outlined, color: Colors.blueAccent),
              title: const Text('即時客服助理（AI）'),
              subtitle: const Text('智慧理解問題、提供下一步建議'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatBotPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined, color: Colors.orangeAccent),
              title: const Text('客服信箱'),
              subtitle: const Text('service@osmile.com'),
              onTap: () => _launch('mailto:service@osmile.com'),
            ),
            ListTile(
              leading: const Icon(Icons.phone_in_talk_outlined, color: Colors.green),
              title: const Text('電話客服'),
              subtitle: const Text('週一至週五 09:00 - 18:00'),
              onTap: () => _launch('tel:+886-2-1234-5678'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0.6,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('常見問題', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            ..._faqList.map((item) {
              return ExpansionTile(
                title: Text(item['q']!, style: const TextStyle(fontWeight: FontWeight.w700)),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                children: [
                  Text(item['a']!, style: const TextStyle(color: Colors.black87, height: 1.45)),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0.6,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('問題回報', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: '電子郵件',
                  hintText: '請輸入您的 Email',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return '請輸入 Email';
                  if (!s.contains('@')) return 'Email 格式不正確';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _msgCtrl,
                decoration: const InputDecoration(
                  labelText: '您的問題',
                  hintText: '請描述您遇到的問題',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return '請輸入問題內容';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitForm,
                  icon: const Icon(Icons.send),
                  label: const Text('送出問題'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================
// ✅ ChatBotPage（AI 強化）
// ======================================================

enum _Role { user, bot }

class _ChatMsg {
  final _Role role;
  final String text;
  final int ts;
  final double? confidence; // bot only
  final List<String>? sources; // bot only

  _ChatMsg({
    required this.role,
    required this.text,
    required this.ts,
    this.confidence,
    this.sources,
  });

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'text': text,
        'ts': ts,
        'confidence': confidence,
        'sources': sources,
      };

  static _ChatMsg fromJson(Map<String, dynamic> m) {
    final r = (m['role'] ?? 'user').toString();
    return _ChatMsg(
      role: r == 'bot' ? _Role.bot : _Role.user,
      text: (m['text'] ?? '').toString(),
      ts: (m['ts'] is int) ? m['ts'] as int : int.tryParse('${m['ts']}') ?? DateTime.now().millisecondsSinceEpoch,
      confidence: (m['confidence'] is num) ? (m['confidence'] as num).toDouble() : double.tryParse('${m['confidence']}'),
      sources: (m['sources'] is List) ? (m['sources'] as List).map((e) => e.toString()).toList() : null,
    );
  }
}

class _KbItem {
  final String id;
  final String title;
  final String answer;
  final List<String> keywords; // for intent + boosting
  final List<String> tags; // for suggestions/sources

  const _KbItem({
    required this.id,
    required this.title,
    required this.answer,
    required this.keywords,
    required this.tags,
  });
}

class _AiReply {
  final String text;
  final double confidence;
  final List<String> sources;
  final List<String> suggestions;
  final String? topic; // for context

  const _AiReply({
    required this.text,
    required this.confidence,
    required this.sources,
    required this.suggestions,
    this.topic,
  });
}

class _ChatContext {
  String? lastTopic; // e.g. order / warranty / sos
  String? lastOrderId;
}

class _AiEngine {
  final List<_KbItem> kb;

  _AiEngine(this.kb);

  // -------- Tokenization (supports Chinese/English roughly) --------
  List<String> _tokens(String input) {
    final s = input.toLowerCase().trim();
    if (s.isEmpty) return const [];

    final cleaned = s.replaceAll(RegExp(r'[^\w\u4e00-\u9fff]+'), ' ');
    final parts = cleaned.split(RegExp(r'\s+')).where((e) => e.trim().isNotEmpty).toList();

    final out = <String>[];
    for (final p in parts) {
      // If contains Chinese, split to chars to improve matching
      if (RegExp(r'[\u4e00-\u9fff]').hasMatch(p)) {
        for (final rune in p.runes) {
          final ch = String.fromCharCode(rune).trim();
          if (ch.isNotEmpty) out.add(ch);
        }
      } else {
        out.add(p);
      }
    }
    return out;
  }

  double _jaccard(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final sa = a.toSet();
    final sb = b.toSet();
    final inter = sa.intersection(sb).length.toDouble();
    final uni = sa.union(sb).length.toDouble();
    if (uni <= 0) return 0.0;
    return inter / uni;
  }

  String? _extractOrderId(String s) {
    // match ord_123... / ORD-... / 純數字也先抓（較保守）
    final m1 = RegExp(r'(ord[_-]\d{6,})', caseSensitive: false).firstMatch(s);
    if (m1 != null) return m1.group(1);
    final m2 = RegExp(r'\b\d{8,}\b').firstMatch(s);
    if (m2 != null) return m2.group(0);
    return null;
  }

  bool _containsAny(String s, List<String> keys) {
    for (final k in keys) {
      if (k.isEmpty) continue;
      if (s.contains(k)) return true;
    }
    return false;
  }

  _AiReply reply(String userText, _ChatContext ctx) {
    final t = userText.trim();
    final lower = t.toLowerCase();

    // 0) Greeting / small talk
    if (_containsAny(lower, const ['hi', 'hello', 'hey', '哈囉', '你好', '您好'])) {
      return _AiReply(
        text: '您好，我是 Osmile 即時客服助理。我可以協助：訂單查詢、保固/維修、SOS 使用、退貨退款、綁定與操作。請問想先處理哪一項？',
        confidence: 0.92,
        sources: const ['assistant:intro'],
        suggestions: const ['查詢訂單', '保固/維修', 'SOS 怎麼用', '退貨/退款', '綁定手錶'],
        topic: 'intro',
      );
    }

    // 1) Extract entities
    final oid = _extractOrderId(lower);
    if (oid != null) ctx.lastOrderId = oid;

    // 2) Intent first-pass (keyword)
    final isOrder = _containsAny(lower, const ['訂單', '出貨', '配送', '物流', '運送', 'order', 'shipping', 'track']);
    final isWarranty = _containsAny(lower, const ['保固', '維修', '壞掉', '故障', 'warranty', 'repair']);
    final isSos = _containsAny(lower, const ['sos', '求救', '緊急', '警報']);
    final isRefund = _containsAny(lower, const ['退貨', '退款', '退費', '退換', 'return', 'refund']);
    final isBind = _containsAny(lower, const ['綁定', '配對', '藍牙', '連線', 'pair', 'bluetooth']);

    String? topic;
    if (isOrder) topic = 'order';
    else if (isWarranty) topic = 'warranty';
    else if (isSos) topic = 'sos';
    else if (isRefund) topic = 'refund';
    else if (isBind) topic = 'bind';

    // 3) Retrieval over KB (RAG-like)
    final qTok = _tokens(lower);
    double bestScore = 0.0;
    _KbItem? best;

    for (final item in kb) {
      final docTok = _tokens('${item.title} ${item.answer} ${item.keywords.join(' ')} ${item.tags.join(' ')}');
      var score = _jaccard(qTok, docTok);

      // keyword boost
      for (final kw in item.keywords) {
        if (kw.isEmpty) continue;
        if (lower.contains(kw.toLowerCase())) score += 0.10;
      }

      // topic boost
      if (topic != null && item.tags.contains(topic)) score += 0.08;

      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }

    // 4) Context carry if user asks follow-up like "那怎麼辦/要怎麼做"
    final followUp = _containsAny(lower, const ['那', '怎麼', '如何', '要怎樣', '要怎麼', '請問', '然後', '下一步', 'help']);
    if (topic == null && followUp && ctx.lastTopic != null) {
      topic = ctx.lastTopic;
    }

    // 5) Compose reply
    // Thresholds tuned for small KB
    final confident = best != null && bestScore >= 0.22;
    final semi = best != null && bestScore >= 0.15;

    if (confident) {
      ctx.lastTopic = topic ?? best!.tags.firstOrNull;
      return _AiReply(
        text: _decorateWithOrderId(best!.answer, ctx.lastOrderId),
        confidence: min(0.95, 0.60 + bestScore),
        sources: ['kb:${best!.id}', best!.title],
        suggestions: _suggestionsForTopic(ctx.lastTopic),
        topic: ctx.lastTopic,
      );
    }

    // Semi-match: answer + ask clarifying + show options
    if (semi) {
      ctx.lastTopic = topic ?? best!.tags.firstOrNull;
      return _AiReply(
        text:
            '${_decorateWithOrderId(best!.answer, ctx.lastOrderId)}\n\n為了更精準協助，請問你要處理的是：訂單/保固/SOS/退貨退款/綁定？也可以直接貼上訂單編號（例如 ord_...）。',
        confidence: min(0.75, 0.45 + bestScore),
        sources: ['kb:${best!.id}', best!.title],
        suggestions: const ['查詢訂單', '保固/維修', 'SOS 怎麼用', '退貨/退款', '綁定手錶', '聯絡真人客服'],
        topic: ctx.lastTopic,
      );
    }

    // No match: fallback + guided options
    ctx.lastTopic = topic ?? ctx.lastTopic;
    final base = (ctx.lastTopic == null)
        ? '我目前沒有完全理解你的問題。'
        : '我可能理解為「${_topicLabel(ctx.lastTopic!)}」，但還需要一點資訊。';

    final extra = (ctx.lastTopic == 'order' && ctx.lastOrderId != null)
        ? '你提供的訂單編號是：${ctx.lastOrderId}。請問要查「出貨進度」還是「取消/退款」？'
        : '你可以改用關鍵字描述（例如：訂單出貨、保固維修、SOS、退貨退款、藍牙綁定）。';

    return _AiReply(
      text: '$base\n$extra',
      confidence: 0.28,
      sources: const ['assistant:fallback'],
      suggestions: _suggestionsForTopic(ctx.lastTopic),
      topic: ctx.lastTopic,
    );
  }

  String _decorateWithOrderId(String answer, String? orderId) {
    if (orderId == null || orderId.trim().isEmpty) return answer;
    // If answer already mentions order id, skip
    if (answer.contains(orderId)) return answer;
    // Light personalization for order topic
    if (answer.contains('訂單')) return '（訂單：$orderId）\n$answer';
    return answer;
  }

  List<String> _suggestionsForTopic(String? topic) {
    switch (topic) {
      case 'order':
        return const ['查出貨進度', '取消/退款', '如何查看訂單', '聯絡真人客服'];
      case 'warranty':
        return const ['保固範圍', '維修流程', '如何送修', '聯絡真人客服'];
      case 'sos':
        return const ['SOS 怎麼用', '通知家人設定', '常見故障排除', '聯絡真人客服'];
      case 'refund':
        return const ['退貨/退款流程', '需要哪些資料', '查看訂單', '聯絡真人客服'];
      case 'bind':
        return const ['藍牙配對', '綁定流程', '找不到裝置', '聯絡真人客服'];
      default:
        return const ['查詢訂單', '保固/維修', 'SOS 怎麼用', '退貨/退款', '綁定手錶', '聯絡真人客服'];
    }
  }

  String _topicLabel(String topic) {
    switch (topic) {
      case 'order':
        return '訂單/出貨';
      case 'warranty':
        return '保固/維修';
      case 'sos':
        return 'SOS';
      case 'refund':
        return '退貨/退款';
      case 'bind':
        return '綁定/藍牙';
      default:
        return topic;
    }
  }
}

extension _FirstOrNullExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class ChatBotPage extends StatefulWidget {
  const ChatBotPage({super.key});

  @override
  State<ChatBotPage> createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> {
  static const Color _bg = Color(0xFFF7F8FA);
  static const String _prefsKey = 'osmile_chatbot_history_v2';

  final _messages = <_ChatMsg>[];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final _typing = ValueNotifier<bool>(false);
  final _ctx = _ChatContext();

  late final _AiEngine _ai;

  @override
  void initState() {
    super.initState();
    _ai = _AiEngine(_kb());
    _loadHistory().then((_) {
      if (_messages.isEmpty) {
        _pushBot(
          '您好，我是 Osmile 即時客服助理。\n我可以協助：訂單、保固/維修、SOS、退貨退款、綁定與操作。\n\n請直接描述問題，或貼上訂單編號（例如 ord_...）。',
          confidence: 0.95,
          sources: const ['assistant:intro'],
        );
      }
      _jumpToBottom();
    });
  }

  @override
  void dispose() {
    _typing.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<_KbItem> _kb() {
    return const [
      _KbItem(
        id: 'bind_01',
        title: '手錶綁定與藍牙配對',
        answer: '請確認手機藍牙已開啟 → 進入「我的裝置」→ 搜尋裝置 → 點選配對。\n若配對不到：關閉再開啟藍牙、重啟 App/手機、手錶靠近手機，並確認未同時連到其他手機。',
        keywords: ['綁定', '配對', '藍牙', '連線', '搜尋裝置', 'pair', 'bluetooth'],
        tags: ['bind'],
      ),
      _KbItem(
        id: 'sos_01',
        title: 'SOS 緊急求助',
        answer: '長按手錶右側按鍵約 3 秒即可啟動 SOS。\n建議先在「家人/守護」設定通知對象，並確認 App 通知權限已開啟。',
        keywords: ['sos', '求救', '緊急', '通知', '家人', '守護'],
        tags: ['sos'],
      ),
      _KbItem(
        id: 'order_01',
        title: '如何查看訂單與出貨',
        answer: '請到「我的 > 訂單」查看訂單狀態與物流。\n若要協助查進度，請提供訂單編號（例如 ord_...）。',
        keywords: ['訂單', '出貨', '物流', '配送', '運送', 'order', 'shipping', 'track'],
        tags: ['order'],
      ),
      _KbItem(
        id: 'refund_01',
        title: '退貨/退款流程',
        answer: '請到「我的 > 訂單」選擇對應訂單申請售後（退貨/退款）。\n若遇到按鈕無法操作，請提供訂單編號與原因（例如：尺寸不合、商品瑕疵）。',
        keywords: ['退貨', '退款', '退費', '退換', 'return', 'refund'],
        tags: ['refund', 'order'],
      ),
      _KbItem(
        id: 'warranty_01',
        title: '保固與維修',
        answer: '一般商品提供 1 年保固（依購買憑證/序號為準）。\n若需要維修，請描述故障情況並提供序號/訂單編號，我們會引導送修流程。',
        keywords: ['保固', '維修', '故障', '壞掉', 'warranty', 'repair'],
        tags: ['warranty'],
      ),
      _KbItem(
        id: 'contact_01',
        title: '聯絡真人客服',
        answer: '若需要真人客服：\n1) 客服信箱：service@osmile.com\n2) 電話：+886-2-1234-5678（週一至週五 09:00-18:00）\n你也可以在此貼上訂單編號，我先協助整理問題重點。',
        keywords: ['真人', '客服', '聯絡', '電話', '信箱', 'support'],
        tags: ['contact'],
      ),
    ];
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final list = <_ChatMsg>[];
      for (final e in decoded) {
        if (e is Map) {
          list.add(_ChatMsg.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_messages.map((e) => e.toJson()).toList());
      await prefs.setString(_prefsKey, encoded);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}

    if (!mounted) return;
    setState(() => _messages.clear());

    _pushBot(
      '已清除對話紀錄。\n你可以直接描述問題，或貼上訂單編號（例如 ord_...）。',
      confidence: 0.90,
      sources: const ['assistant:reset'],
    );
    _jumpToBottom();
  }

  void _pushUser(String text) {
    _messages.add(
      _ChatMsg(role: _Role.user, text: text, ts: DateTime.now().millisecondsSinceEpoch),
    );
    _saveHistory();
  }

  void _pushBot(String text, {double? confidence, List<String>? sources}) {
    _messages.add(
      _ChatMsg(
        role: _Role.bot,
        text: text,
        ts: DateTime.now().millisecondsSinceEpoch,
        confidence: confidence,
        sources: sources,
      ),
    );
    _saveHistory();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    final ok = await canLaunchUrl(uri);
    if (!ok) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _handleSuggestion(String s) {
    // Map suggestions to useful actions (still purely local / safe)
    final lower = s.toLowerCase();
    if (lower.contains('真人') || lower.contains('聯絡')) {
      _pushUser('我想聯絡真人客服');
      _replyTo('我想聯絡真人客服');
      return;
    }
    if (lower.contains('電話')) {
      _launchExternal('tel:+886-2-1234-5678');
      return;
    }
    if (lower.contains('信箱')) {
      _launchExternal('mailto:service@osmile.com');
      return;
    }
    _pushUser(s);
    _replyTo(s);
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();

    setState(() {
      _pushUser(text);
    });
    _jumpToBottom();
    _replyTo(text);
  }

  void _replyTo(String userText) {
    _typing.value = true;

    // Simulate "thinking" + typing (more AI-like)
    final delay = 420 + Random().nextInt(380);
    Future.delayed(Duration(milliseconds: delay), () {
      final ai = _ai.reply(userText, _ctx);

      if (!mounted) return;
      setState(() {
        _pushBot(
          ai.text,
          confidence: ai.confidence,
          sources: ai.sources,
        );
        _typing.value = false;
      });

      _jumpToBottom();

      // After bot reply, optionally show suggestions row (UI uses ai.suggestions from last reply)
    });
  }

  @override
  Widget build(BuildContext context) {
    final lastBot = _messages.lastWhere(
      (m) => m.role == _Role.bot,
      orElse: () => _ChatMsg(role: _Role.bot, text: '', ts: 0),
    );

    final suggestions = _deriveSuggestionsFromLast(lastBot);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('即時客服助理', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.8,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            tooltip: '清除對話紀錄',
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _clearHistory,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              itemCount: _messages.length + 1,
              itemBuilder: (context, i) {
                if (i == _messages.length) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: _typing,
                    builder: (_, typing, __) {
                      if (!typing) return const SizedBox(height: 8);
                      return _TypingBubble();
                    },
                  );
                }

                final msg = _messages[i];
                final isUser = msg.role == _Role.user;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isUser) _BotAvatar(),
                      if (!isUser) const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            _ChatBubble(
                              text: msg.text,
                              isUser: isUser,
                            ),
                            if (!isUser && (msg.confidence != null || (msg.sources?.isNotEmpty ?? false)))
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: _MetaLine(
                                  confidence: msg.confidence,
                                  sources: msg.sources,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isUser) const SizedBox(width: 8),
                      if (isUser) _UserAvatar(),
                    ],
                  ),
                );
              },
            ),
          ),

          // Suggestions (AI Quick Replies)
          if (suggestions.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: suggestions.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(s, style: const TextStyle(fontWeight: FontWeight.w700)),
                        onPressed: () => _handleSuggestion(s),
                        backgroundColor: const Color(0xFFF1F5FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: BorderSide(color: Colors.blueAccent.withOpacity(0.25)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // Input bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: '輸入訊息…（可貼訂單編號 ord_...）',
                      filled: true,
                      fillColor: const Color(0xFFF6F7FA),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _deriveSuggestionsFromLast(_ChatMsg lastBot) {
    // If lastBot includes explicit topic suggestions, use engine on the fly:
    // We reconstruct by calling ai.reply with empty? Not good.
    // So we heuristically derive from text + sources.
    final text = lastBot.text.toLowerCase();
    if (text.isEmpty) return const [];

    if (text.contains('訂單') || text.contains('出貨') || text.contains('物流')) {
      return const ['查出貨進度', '取消/退款', '如何查看訂單', '聯絡真人客服'];
    }
    if (text.contains('保固') || text.contains('維修') || text.contains('送修')) {
      return const ['保固範圍', '維修流程', '如何送修', '聯絡真人客服'];
    }
    if (text.contains('sos') || text.contains('求救') || text.contains('緊急')) {
      return const ['SOS 怎麼用', '通知家人設定', '常見故障排除', '聯絡真人客服'];
    }
    if (text.contains('退貨') || text.contains('退款')) {
      return const ['退貨/退款流程', '需要哪些資料', '查看訂單', '聯絡真人客服'];
    }
    if (text.contains('綁定') || text.contains('藍牙') || text.contains('配對')) {
      return const ['藍牙配對', '綁定流程', '找不到裝置', '聯絡真人客服'];
    }

    // default
    return const ['查詢訂單', '保固/維修', 'SOS 怎麼用', '退貨/退款', '綁定手錶', '聯絡真人客服'];
  }
}

// ======================================================
// ✅ UI Components
// ======================================================

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const _ChatBubble({
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? Colors.blueAccent : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isUser ? null : Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isUser ? Colors.white : Colors.black87,
          fontSize: 15,
          height: 1.35,
          fontWeight: isUser ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final double? confidence;
  final List<String>? sources;

  const _MetaLine({this.confidence, this.sources});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (confidence != null) {
      final c = (confidence! * 100).clamp(0, 100).toStringAsFixed(0);
      parts.add('信心 $c%');
    }
    if (sources != null && sources!.isNotEmpty) {
      // keep short
      parts.add('來源：${sources!.take(1).join(', ')}');
    }

    return Text(
      parts.join(' · '),
      style: TextStyle(
        fontSize: 11.5,
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BotAvatar(),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _Dot(),
              SizedBox(width: 4),
              _Dot(delay: 120),
              SizedBox(width: 4),
              _Dot(delay: 240),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({this.delay = 0});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _a = Tween<double>(begin: 0.25, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (!mounted) return;
      _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: Colors.grey.shade600,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _BotAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 14,
      backgroundColor: Color(0xFFEEF2FF),
      child: Icon(Icons.smart_toy_outlined, size: 16, color: Colors.blueAccent),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 14,
      backgroundColor: Color(0xFFEFF6FF),
      child: Icon(Icons.person_outline, size: 16, color: Colors.blueGrey),
    );
  }
}
