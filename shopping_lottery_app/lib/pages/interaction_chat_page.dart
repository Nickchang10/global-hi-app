import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Osmile 客服互動中心（最終完整版）
/// 功能包含：
/// - 智慧模擬客服回覆
/// - 語音輸入按鈕（示範）
/// - 評價回饋視窗
/// - 客服輸入中動畫
/// - 品牌化藍白 UI
class InteractionChatPage extends StatefulWidget {
  const InteractionChatPage({super.key});

  @override
  State<InteractionChatPage> createState() => _InteractionChatPageState();
}

class _InteractionChatPageState extends State<InteractionChatPage> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _dateFmt = DateFormat('HH:mm');

  bool _isTyping = false;
  bool _hasRated = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      _addSystemMessage("您好，這裡是 Osmile 客服中心，很高興為您服務！");
    });
  }

  void _addUserMessage(String text) {
    if (text.trim().isEmpty) return;
    final msg = _ChatMessage(text: text.trim(), isUser: true, time: DateTime.now());
    setState(() {
      _messages.add(msg);
      _controller.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    // 模擬客服延遲回覆
    Future.delayed(const Duration(seconds: 1), () {
      _addSystemMessage(_mockReply(text));
    });
  }

  void _addSystemMessage(String text) {
    final msg = _ChatMessage(text: text, isUser: false, time: DateTime.now());
    setState(() {
      _messages.add(msg);
      _isTyping = false;
    });
    _scrollToBottom();

    // 若客服主動結尾，顯示評價彈窗
    if (text.contains('感謝') || text.contains('祝您有美好的一天')) {
      Future.delayed(const Duration(milliseconds: 600), _showRatingDialog);
    }
  }

  String _mockReply(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('出貨') || lower.contains('訂單')) {
      return '訂單出貨時間約 1~2 個工作天，出貨後會自動通知您。';
    } else if (lower.contains('退款')) {
      return '退款處理需 3~5 個工作天完成，將退回原支付方式。';
    } else if (lower.contains('抽獎')) {
      return '抽獎活動可於「互動中心」或「抽獎頁」進行，每次需 50 積分。';
    } else if (lower.contains('積分')) {
      return '積分可用於抽獎或折抵金額，目前活動：滿 500 元贈一次抽獎。';
    } else if (lower.contains('優惠') || lower.contains('折扣')) {
      return '目前優惠活動：全館滿 NT\$500 折 NT\$50，歡迎選購！';
    } else {
      return '了解，您的問題我已回報相關部門，我們將盡快通知您，感謝您的耐心。';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  void _showRatingDialog() {
    if (_hasRated) return;
    showDialog<void>(
      context: context,
      builder: (context) {
        int rating = 0;
        return AlertDialog(
          title: const Text('請評價此次客服服務'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final filled = i < rating;
                  return IconButton(
                    icon: Icon(
                      filled ? Icons.star_rounded : Icons.star_border_rounded,
                      color: filled ? Colors.amber : Colors.grey,
                      size: 32,
                    ),
                    onPressed: () => setState(() => rating = i + 1),
                  );
                }),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _hasRated = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('感謝您的回饋！')),
                );
              },
              child: const Text('送出'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.4,
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircleAvatar(
              radius: 14,
              backgroundImage: AssetImage('assets/images/support_avatar.png'),
            ),
            SizedBox(width: 8),
            Text('Osmile 客服中心',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            if (_isTyping)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: _TypingIndicator(),
              ),
            const Divider(height: 1),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // 訊息清單
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg.isUser;
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 3),
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage:
                          const AssetImage('assets/images/support_avatar.png'),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: const BoxConstraints(maxWidth: 280),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.blueAccent : Colors.grey.shade200,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 0),
                      bottomRight: Radius.circular(isUser ? 0 : 16),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _dateFmt.format(msg.time),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 輸入區
  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.mic_none_rounded, color: Colors.grey),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('語音輸入功能示範中')),
                );
              },
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (v) => _addUserMessage(v),
                decoration: InputDecoration(
                  hintText: '輸入訊息...',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: '發送訊息',
              icon: const Icon(Icons.send_rounded, color: Colors.blueAccent),
              onPressed: () => _addUserMessage(_controller.text),
            ),
          ],
        ),
      ),
    );
  }
}

/// 聊天訊息資料模型
class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  _ChatMessage({required this.text, required this.isUser, required this.time});
}

/// 客服「正在輸入中」動畫效果
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return FadeTransition(
          opacity: Tween(begin: 0.2, end: 1.0)
              .chain(CurveTween(curve: Interval(i * 0.2, 1.0)))
              .animate(_controller),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: Colors.grey, shape: BoxShape.circle),
          ),
        );
      }),
    );
  }
}
