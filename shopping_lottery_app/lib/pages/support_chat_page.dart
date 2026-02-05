import 'package:flutter/material.dart';

/// 💬 Osmile 客服聊天模擬頁面（完整版整合商品自動帶入）
class SupportChatPage extends StatefulWidget {
  final String? productName;
  final String? productImage;

  const SupportChatPage({
    super.key,
    this.productName,
    this.productImage,
  });

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 300), () {
      _addMessage("客服小幫手", "您好～這裡是 Osmile 官方客服 🤖\n請問需要什麼協助呢？");

      // 若從商品頁帶入商品名稱
      if (widget.productName != null) {
        _addMessage("我", "您好，我想詢問關於 ${widget.productName} 的問題～", fromUser: true);
        Future.delayed(const Duration(seconds: 1), () {
          _autoReply(widget.productName!);
        });
      }

      // 若從商品頁帶入圖片
      if (widget.productImage != null) {
        _addImagePreview(widget.productImage!);
      }
    });
  }

  /// ✉️ 新增訊息
  void _addMessage(String sender, String text, {bool fromUser = false}) {
    setState(() {
      _messages.add({
        "sender": sender,
        "text": text,
        "fromUser": fromUser,
        "time": TimeOfDay.now(),
        "isImage": false,
      });
    });
    _scrollToBottom();
  }

  /// 🖼️ 插入圖片預覽
  void _addImagePreview(String imagePath) {
    setState(() {
      _messages.add({
        "sender": "我",
        "fromUser": true,
        "time": TimeOfDay.now(),
        "isImage": true,
        "image": imagePath,
      });
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 🤖 自動回覆邏輯
  void _autoReply(String text) async {
    String reply = "感謝您的訊息，我們會儘快回覆您 🙏";

    final lower = text.toLowerCase();
    if (lower.contains("價格") || lower.contains("多少")) {
      reply = "您可在商品詳情頁查看最新售價喔 💰";
    } else if (lower.contains("維修") || lower.contains("保固")) {
      reply = "Osmile 智慧手錶享有一年保固，如需維修請附上購買證明 🧾";
    } else if (lower.contains("出貨") || lower.contains("物流")) {
      reply = "平均出貨時間為 1～2 個工作天 🚚";
    } else if (lower.contains("ed1000")) {
      reply = "ED1000 是我們的旗艦款，支援健康監測與 SOS 功能 💪";
    } else if (lower.contains("lumi")) {
      reply = "Lumi 系列主打輕盈與長效電池 🔋";
    }

    setState(() => _isTyping = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    setState(() => _isTyping = false);

    _addMessage("客服小幫手", reply);
  }

  /// 🚀 傳送訊息
  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _addMessage("我", text, fromUser: true);
    _controller.clear();
    _autoReply(text);
  }

  /// ⚡ 快速回覆
  void _sendQuick(String text) {
    _addMessage("我", text, fromUser: true);
    _autoReply(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9F1FF),
      appBar: AppBar(
        title: const Text("💬 Osmile 客服中心"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          // 📩 聊天訊息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(10),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (_, i) {
                if (_isTyping && i == _messages.length) {
                  return const TypingBubble();
                }

                final msg = _messages[i];
                final fromUser = msg["fromUser"] as bool;
                final isImage = msg["isImage"] == true;

                return Align(
                  alignment:
                      fromUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: fromUser
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!fromUser)
                          const CircleAvatar(
                            radius: 18,
                            backgroundImage:
                                AssetImage("assets/images/customer_service.png"),
                          ),
                        if (!fromUser) const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            decoration: BoxDecoration(
                              color: fromUser
                                  ? Colors.blueAccent
                                  : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(fromUser ? 14 : 4),
                                topRight: Radius.circular(fromUser ? 4 : 14),
                                bottomLeft: const Radius.circular(14),
                                bottomRight: const Radius.circular(14),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(10),
                            child: isImage
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.asset(
                                      msg["image"],
                                      width: 160,
                                      height: 160,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Text(
                                    msg["text"],
                                    style: TextStyle(
                                      color: fromUser
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                        if (fromUser) const SizedBox(width: 8),
                        if (fromUser)
                          const CircleAvatar(
                            radius: 18,
                            backgroundImage:
                                AssetImage("assets/images/user_avatar.png"),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 🟦 快速回覆選項
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              children: [
                _quickButton("查詢價格 💰"),
                _quickButton("出貨時間 🚚"),
                _quickButton("產品保固 🧾"),
                _quickButton("ED1000 功能 💡"),
              ],
            ),
          ),

          const Divider(height: 1),

          // 🧭 底部輸入區
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: "輸入訊息...",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.blueAccent,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                      onPressed: _sendMessage,
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

  Widget _quickButton(String text) {
    return GestureDetector(
      onTap: () => _sendQuick(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blueAccent.shade100),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.blueAccent, fontSize: 13),
        ),
      ),
    );
  }
}

/// 打字中動畫
class TypingBubble extends StatelessWidget {
  const TypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 18,
          backgroundImage:
              AssetImage("assets/images/customer_service.png"),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Dot(),
              SizedBox(width: 4),
              Dot(),
              SizedBox(width: 4),
              Dot(),
            ],
          ),
        ),
      ],
    );
  }
}

/// 動態點點動畫
class Dot extends StatefulWidget {
  const Dot({super.key});

  @override
  State<Dot> createState() => _DotState();
}

class _DotState extends State<Dot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
          ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: const CircleAvatar(radius: 3, backgroundColor: Colors.grey),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
