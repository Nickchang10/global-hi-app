import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ AIConversationPage（AI 對話頁｜最終完整版｜可編譯）
/// ------------------------------------------------------------
/// Firestore:
/// - users/{uid}/ai_chats/{chatId}
///   - title (String)
///   - createdAt / updatedAt (Timestamp)
/// - users/{uid}/ai_chats/{chatId}/messages/{messageId}
///   - role: 'user' | 'assistant'
///   - text: String
///   - createdAt: Timestamp
///   - meta: Map（可選）
///
/// 會嘗試讀取「啟用中的 AI 情境」：
/// - users/{uid}/ai_contexts (where isActive==true limit 1)
///   - title/content/isActive/updatedAt/createdAt
///
/// 會嘗試讀取商品作為推薦基礎：
/// - products (where isActive==true)
///   - name/description/price/imageUrl/categoryId/tags/isActive/updatedAt/createdAt
///
/// ✅ Lints:
/// - curly_braces_in_flow_control_structures：if 一律大括號
/// - withOpacity deprecated：改用 withValues(alpha: ...)
/// - async gap context：先取 messenger / navigator + mounted 防護
class AIConversationPage extends StatefulWidget {
  const AIConversationPage({super.key, this.chatId, this.title});

  /// 可指定 chatId；不指定則使用 'default'
  final String? chatId;

  /// AppBar title；不指定則顯示 'AI 對話'
  final String? title;

  @override
  State<AIConversationPage> createState() => _AIConversationPageState();
}

class _AIConversationPageState extends State<AIConversationPage> {
  final _fs = FirebaseFirestore.instance;

  final _inputCtrl = TextEditingController();
  final _listCtrl = ScrollController();

  String? _chatId;
  bool _booting = true;

  bool _sending = false;

  // 供規則式回覆使用
  String _activeContextText = '';
  List<_ProductDoc> _products = [];

  Timer? _debounceReload;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _debounceReload?.cancel();
    _inputCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Firestore refs
  // -------------------------
  CollectionReference<Map<String, dynamic>> _chatCol(String uid) =>
      _fs.collection('users').doc(uid).collection('ai_chats');

  DocumentReference<Map<String, dynamic>> _chatDoc(String uid, String chatId) =>
      _chatCol(uid).doc(chatId);

  CollectionReference<Map<String, dynamic>> _msgCol(
    String uid,
    String chatId,
  ) => _chatDoc(uid, chatId).collection('messages');

  // -------------------------
  // Boot / Load context & products
  // -------------------------
  Future<void> _boot() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _booting = false;
        _chatId = null;
      });
      return;
    }

    final chatId = (widget.chatId == null || widget.chatId!.trim().isEmpty)
        ? 'default'
        : widget.chatId!.trim();

    setState(() {
      _chatId = chatId;
      _booting = true;
    });

    try {
      // ensure chat doc exists
      final now = FieldValue.serverTimestamp();
      await _chatDoc(user.uid, chatId).set(<String, dynamic>{
        'title': widget.title ?? 'AI 對話',
        'updatedAt': now,
        'createdAt': now,
      }, SetOptions(merge: true));

      await _reloadContextAndProducts(user.uid);

      if (!mounted) {
        return;
      }
      setState(() => _booting = false);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _booting = false);
      _snack('初始化失敗：$e');
    }
  }

  Future<void> _reloadContextAndProducts(String uid) async {
    // 防止使用者連點刷新
    _debounceReload?.cancel();
    _debounceReload = Timer(const Duration(milliseconds: 120), () async {
      await _loadActiveContext(uid);
      await _loadProducts();
    });
  }

  Future<void> _loadActiveContext(String uid) async {
    try {
      final snap = await _fs
          .collection('users')
          .doc(uid)
          .collection('ai_contexts')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        _activeContextText = '';
        if (mounted) {
          setState(() {});
        }
        return;
      }

      final d = snap.docs.first.data();
      final title = (d['title'] ?? '').toString().trim();
      final content = (d['content'] ?? d['prompt'] ?? d['text'] ?? '')
          .toString()
          .trim();

      _activeContextText = [
        if (title.isNotEmpty) '【情境】$title',
        if (content.isNotEmpty) content,
      ].join('\n');

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // 沒有也不影響對話
      _activeContextText = '';
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadProducts() async {
    // 讀 products：先 updatedAt，失敗再 createdAt，再失敗就不排序
    try {
      final snap = await _fs
          .collection('products')
          .where('isActive', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .limit(300)
          .get();
      _products = snap.docs.map((d) => _ProductDoc.fromDoc(d)).toList();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      try {
        final snap = await _fs
            .collection('products')
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(300)
            .get();
        _products = snap.docs.map((d) => _ProductDoc.fromDoc(d)).toList();
        if (mounted) {
          setState(() {});
        }
      } catch (_) {
        try {
          final snap = await _fs
              .collection('products')
              .where('isActive', isEqualTo: true)
              .limit(300)
              .get();
          _products = snap.docs.map((d) => _ProductDoc.fromDoc(d)).toList();
          if (mounted) {
            setState(() {});
          }
        } catch (_) {
          _products = [];
          if (mounted) {
            setState(() {});
          }
        }
      }
    }
  }

  // -------------------------
  // UI helpers
  // -------------------------
  void _snack(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _scrollToBottom() {
    if (!_listCtrl.hasClients) {
      return;
    }
    _listCtrl.animateTo(
      _listCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  // -------------------------
  // Send message
  // -------------------------
  Future<void> _send() async {
    if (_sending) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final chatId = _chatId;

    if (user == null || chatId == null) {
      _snack('請先登入');
      return;
    }

    final text = _inputCtrl.text.trim();
    if (text.isEmpty) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context); // ✅ async 前先取出

    setState(() => _sending = true);
    _inputCtrl.clear();

    try {
      final now = FieldValue.serverTimestamp();

      // 寫入 user message
      await _msgCol(
        user.uid,
        chatId,
      ).add(<String, dynamic>{'role': 'user', 'text': text, 'createdAt': now});

      // 更新 chat metadata
      await _chatDoc(user.uid, chatId).set(<String, dynamic>{
        'updatedAt': now,
        'lastText': text,
      }, SetOptions(merge: true));

      // 產生 assistant 回覆（規則式）
      final reply = await _generateAssistantReply(user.uid, text);

      await _msgCol(user.uid, chatId).add(<String, dynamic>{
        'role': 'assistant',
        'text': reply.text,
        'createdAt': FieldValue.serverTimestamp(),
        if (reply.meta.isNotEmpty) 'meta': reply.meta,
      });

      await _chatDoc(user.uid, chatId).set(<String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'lastText': reply.text,
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }
      setState(() => _sending = false);

      // 讓 list builder 有時間 render 後再滾到底
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToBottom();
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text('送出失敗：$e')));
    }
  }

  // -------------------------
  // Assistant logic (rule-based)
  // -------------------------
  Future<_AssistantReply> _generateAssistantReply(
    String uid,
    String userText,
  ) async {
    // 你也可以改成呼叫雲端 function / OpenAI API
    final q = userText.trim().toLowerCase();

    // tokens
    final tokens = q
        .split(RegExp(r'\s+|,|，|、|/|\|'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final context = _activeContextText.trim();

    // 若沒有商品資料，就先給通用回覆
    if (_products.isEmpty) {
      final base = StringBuffer();
      base.writeln('我收到你的需求：$userText');
      if (context.isNotEmpty) {
        base.writeln('\n我會依目前啟用的情境設定來協助你。');
      }
      base.writeln('\n目前商品資料尚未載入或沒有上架商品。你可以：');
      base.writeln('1) 到後台上架商品（products.isActive=true）');
      base.writeln('2) 或稍後按右上角重新整理再試一次');
      return _AssistantReply(base.toString(), meta: <String, dynamic>{});
    }

    // scoring
    final scored = <_Scored<_ProductDoc>>[];
    for (final p in _products) {
      final hay = [
        p.name,
        p.description,
        p.categoryId,
        ...p.tags,
      ].join(' ').toLowerCase();

      int score = 0;
      for (final t in tokens) {
        if (hay.contains(t)) {
          score += 3;
        }
      }

      // 弱規則加權（可自行擴充）
      if (q.contains('長輩') || q.contains('老人')) {
        if (hay.contains('sos') ||
            hay.contains('照護') ||
            hay.contains('定位') ||
            hay.contains('手錶')) {
          score += 2;
        }
      }
      if (q.contains('小孩') || q.contains('兒童') || q.contains('學生')) {
        if (hay.contains('sos') || hay.contains('定位') || hay.contains('防走失')) {
          score += 2;
        }
      }
      if (q.contains('sos') || q.contains('求救')) {
        if (hay.contains('sos') || hay.contains('求救')) {
          score += 2;
        }
      }
      if (q.contains('便宜') || q.contains('預算') || q.contains('省')) {
        // 價格越低稍微加分
        if (p.price > 0) {
          score += (p.price < 2000)
              ? 2
              : (p.price < 5000)
              ? 1
              : 0;
        }
      }

      if (score > 0) {
        scored.add(_Scored(p, score));
      }
    }

    scored.sort((a, b) {
      final s = b.score.compareTo(a.score);
      if (s != 0) {
        return s;
      }
      // 分數相同：價格較低優先（更貼近「預算」直覺）
      return a.item.price.compareTo(b.item.price);
    });

    final top = scored.take(5).map((e) => e.item).toList();

    final sb = StringBuffer();
    sb.writeln('我收到你的需求：$userText');

    if (context.isNotEmpty) {
      sb.writeln('\n（已套用目前啟用情境）');
    }

    if (top.isEmpty) {
      sb.writeln('\n目前沒有找到高度匹配的商品。你可以補充：');
      sb.writeln('- 預算範圍（例如 3000 內）');
      sb.writeln('- 想要的功能（SOS / 定位 / 來電 / 防走失）');
      sb.writeln('- 使用族群（長輩 / 小孩 / 一般）');
      return _AssistantReply(sb.toString(), meta: <String, dynamic>{});
    }

    sb.writeln('\n我先推薦你這幾個：');
    for (int i = 0; i < top.length; i++) {
      final p = top[i];
      final priceText = p.price <= 0 ? '價格未設定' : 'NT\$ ${p.price}';
      sb.writeln(
        '${i + 1}. ${p.name.isEmpty ? '(未命名商品)' : p.name}（$priceText）',
      );
      if (p.categoryId.trim().isNotEmpty) {
        sb.writeln('   - 類別：${p.categoryId}');
      }
      if (p.description.trim().isNotEmpty) {
        final d = p.description.trim();
        sb.writeln('   - ${d.length > 60 ? '${d.substring(0, 60)}…' : d}');
      }
    }

    sb.writeln('\n你比較在意：價格、功能（SOS/定位）、或外觀/續航？我可以再幫你縮小到 1~2 款。');

    return _AssistantReply(
      sb.toString(),
      meta: <String, dynamic>{
        'recommendedProductIds': top.map((e) => e.id).toList(),
      },
    );
  }

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final chatId = _chatId;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title ?? 'AI 對話')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('請先登入才能使用', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushNamed('/login'),
                  child: const Text('前往登入'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_booting || chatId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title ?? 'AI 對話')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'AI 對話'),
        actions: [
          IconButton(
            tooltip: '重新載入情境/商品',
            onPressed: () => _reloadContextAndProducts(user.uid),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _topInfoBar(cs),
          const Divider(height: 1),
          Expanded(
            child: _messageList(uid: user.uid, chatId: chatId),
          ),
          const Divider(height: 1),
          _inputBar(cs),
        ],
      ),
    );
  }

  Widget _topInfoBar(ColorScheme cs) {
    final hasCtx = _activeContextText.trim().isNotEmpty;
    final productCount = _products.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chipPill(
                  cs,
                  hasCtx ? '情境：已啟用' : '情境：未啟用',
                  hasCtx ? cs.primary : cs.outline,
                ),
                _chipPill(cs, '商品：$productCount', cs.secondary),
              ],
            ),
          ),
          if (hasCtx)
            IconButton(
              tooltip: '查看啟用情境',
              onPressed: () => _showContextDetail(),
              icon: const Icon(Icons.info_outline),
            ),
        ],
      ),
    );
  }

  Widget _chipPill(ColorScheme cs, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSurface,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _showContextDetail() async {
    final ctx = _activeContextText.trim();
    if (ctx.isEmpty) {
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('目前啟用情境'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Text(ctx, style: const TextStyle(height: 1.4)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Widget _messageList({required String uid, required String chatId}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _msgCol(
        uid,
        chatId,
      ).orderBy('createdAt', descending: false).limit(300).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('讀取失敗：${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        final msgs = docs.map((d) => _ChatMessage.fromDoc(d)).toList();

        if (msgs.isEmpty) {
          return _emptyConversation();
        }

        // 滾到底（僅在列表更新時）
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollToBottom();
          }
        });

        return ListView.builder(
          controller: _listCtrl,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          itemCount: msgs.length,
          itemBuilder: (context, i) => _bubble(msgs[i]),
        );
      },
    );
  }

  Widget _emptyConversation() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 72, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('開始和 AI 對話吧', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonal(
                  onPressed: () {
                    _inputCtrl.text = '我想找適合長輩的手錶，有 SOS 和定位';
                    setState(() {});
                  },
                  child: const Text('長輩 SOS 定位'),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    _inputCtrl.text = '預算 3000 內，有推薦嗎？';
                    setState(() {});
                  },
                  child: const Text('預算 3000'),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    _inputCtrl.text = '給小孩用，要防走失與定位';
                    setState(() {});
                  },
                  child: const Text('小孩 防走失'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(_ChatMessage m) {
    final cs = Theme.of(context).colorScheme;

    final isUser = m.role == 'user';
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final bg = isUser
        ? cs.primary.withValues(alpha: 0.14)
        : cs.surfaceContainerHighest.withValues(alpha: 0.75);

    final border = isUser
        ? cs.primary.withValues(alpha: 0.25)
        : cs.outline.withValues(alpha: 0.25);

    final textColor = cs.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Text(
              m.text,
              style: TextStyle(color: textColor, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar(ColorScheme cs) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  // ✅ curly braces lint：必用大括號
                  if (!_sending) {
                    _send();
                  }
                },
                decoration: InputDecoration(
                  hintText: '輸入訊息（例如：要 SOS、要定位、預算 3000）',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_sending ? '送出中' : '送出'),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------
// Models
// -------------------------
class _ChatMessage {
  final String id;
  final String role; // user/assistant
  final String text;

  _ChatMessage({required this.id, required this.role, required this.text});

  factory _ChatMessage.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    return _ChatMessage(
      id: doc.id,
      role: (d['role'] ?? 'user').toString(),
      text: (d['text'] ?? '').toString(),
    );
  }
}

class _AssistantReply {
  final String text;
  final Map<String, dynamic> meta;
  _AssistantReply(this.text, {required this.meta});
}

class _Scored<T> {
  final T item;
  final int score;
  _Scored(this.item, this.score);
}

class _ProductDoc {
  final String id;
  final String name;
  final String description;
  final num price;
  final String imageUrl;
  final bool isActive;
  final String categoryId;
  final List<String> tags;

  _ProductDoc({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.isActive,
    required this.categoryId,
    required this.tags,
  });

  static num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  static bool _asBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is String) {
      final t = v.toLowerCase().trim();
      if (t == 'true') return true;
      if (t == 'false') return false;
    }
    return fallback;
  }

  static List<String> _asStringList(dynamic v) {
    if (v == null) return <String>[];
    if (v is List) {
      return v
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    if (v is String && v.trim().isNotEmpty) return <String>[v.trim()];
    return <String>[];
  }

  factory _ProductDoc.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return _ProductDoc(
      id: doc.id,
      name: (d['name'] ?? d['title'] ?? '').toString(),
      description: (d['description'] ?? d['desc'] ?? '').toString(),
      price: _asNum(d['price'] ?? d['amount'] ?? 0),
      imageUrl: (d['imageUrl'] ?? d['coverUrl'] ?? d['image'] ?? '').toString(),
      isActive: _asBool(d['isActive'] ?? d['active'], fallback: true),
      categoryId: (d['categoryId'] ?? d['category'] ?? '').toString(),
      tags: _asStringList(d['tags']),
    );
  }
}
