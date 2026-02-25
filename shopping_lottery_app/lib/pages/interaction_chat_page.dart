// lib/pages/interaction_chat_page.dart
//
// ✅ InteractionChatPage（聊天室｜最終完整版｜可直接使用｜已修正 invalid_constant）
// - ✅ 修正：不能用 const 建立包含 DateTime.now() 的物件
//   → 移除 _ChatMessage.me/_ChatMessage.bot 的 const，以及初始訊息清單的 const
// - ✅ 保留：prefer_initializing_formals（this.text / this.createdAt / this.isMe）
// - 無額外套件依賴（只用 Flutter SDK）
// - 內建示範聊天室：可送訊息、可自動回覆（demo bot）

import 'dart:async';
import 'package:flutter/material.dart';

class InteractionChatPage extends StatefulWidget {
  const InteractionChatPage({super.key});

  static const routeName = '/chat';

  @override
  State<InteractionChatPage> createState() => _InteractionChatPageState();
}

class _InteractionChatPageState extends State<InteractionChatPage> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<_ChatMessage> _messages = <_ChatMessage>[
    _ChatMessage.bot('歡迎來到 Osmile 聊天室 👋'),
    _ChatMessage.bot('這是示範頁：你可以直接輸入訊息測試 UI。'),
  ];

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (!mounted) return;
      // 讓右側清除按鈕能即時出現/消失
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _scrollToBottom({bool animate = true}) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (!mounted) return;
    if (!_scrollCtrl.hasClients) return;

    final pos = _scrollCtrl.position.maxScrollExtent;
    if (animate) {
      await _scrollCtrl.animateTo(
        pos,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _scrollCtrl.jumpTo(pos);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _ctrl.clear();

    setState(() {
      _messages.add(_ChatMessage.me(text));
    });

    await _scrollToBottom();

    // demo：模擬機器人回覆
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    final reply = _autoReply(text);
    setState(() {
      _messages.add(_ChatMessage.bot(reply));
      _sending = false;
    });

    await _scrollToBottom();
  }

  String _autoReply(String text) {
    final t = text.toLowerCase();
    if (t.contains('優惠') || t.contains('coupon')) {
      return '優惠券可在結帳頁選擇套用（示範）。\n你也可以到「我的優惠券」查看可用折抵。';
    }
    if (t.contains('訂單') || t.contains('order')) {
      return '訂單查詢：到「我的 → 訂單」即可查看狀態（示範）。';
    }
    if (t.contains('退') || t.contains('換') || t.contains('refund')) {
      return '退換貨：請提供訂單編號與原因，我們會協助處理（示範）。';
    }
    if (t.contains('sos')) {
      return 'SOS：可在手錶上長按/按鍵觸發求救並通知家長端（示範）。';
    }
    return '收到 ✅（示範回覆）\n你可以輸入：優惠/訂單/退換貨/SOS 來看不同回覆。';
  }

  void _clearChat() {
    setState(() {
      _messages
        ..clear()
        ..add(_ChatMessage.bot('聊天室已清空（示範）'));
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('聊天室'),
        actions: [
          IconButton(
            tooltip: '清空',
            onPressed: _clearChat,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('尚無訊息'))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) =>
                        _MessageBubble(msg: _messages[i], cs: cs),
                  ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              decoration: const InputDecoration(
                                hintText: '輸入訊息…',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_ctrl.text.isNotEmpty)
                            IconButton(
                              tooltip: '清除',
                              onPressed: () => _ctrl.clear(),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                        _sending ? '送出中' : '送出',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.msg, required this.cs});

  final _ChatMessage msg;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isMe;

    final bubbleColor = isMe ? cs.primaryContainer : Colors.white;
    final textColor = isMe ? cs.onPrimaryContainer : Colors.black87;

    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                const CircleAvatar(
                  radius: 14,
                  child: Icon(Icons.support_agent, size: 16),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isMe ? Colors.transparent : Colors.black12,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      color: textColor,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 8),
                const CircleAvatar(
                  radius: 14,
                  child: Icon(Icons.person, size: 16),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            msg.timeLabel,
            style: const TextStyle(color: Colors.black45, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final bool isMe;
  final String text;
  final DateTime createdAt;

  /// ✅ prefer_initializing_formals
  _ChatMessage({
    required this.isMe,
    required this.text,
    required this.createdAt,
  });

  /// ⚠️ 這裡不能 const，因為 DateTime.now() 不是 compile-time constant
  factory _ChatMessage.me(String text) =>
      _ChatMessage(isMe: true, text: text, createdAt: DateTime.now());

  factory _ChatMessage.bot(String text) =>
      _ChatMessage(isMe: false, text: text, createdAt: DateTime.now());

  String get timeLabel {
    final h = createdAt.hour.toString().padLeft(2, '0');
    final m = createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
