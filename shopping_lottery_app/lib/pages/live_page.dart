import 'package:flutter/material.dart';
import 'package:osmile_shopping_app/services/cart_service.dart';
import 'package:osmile_shopping_app/services/notification_service.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  final cart = CartService.instance;
  final notify = NotificationService.instance;
  final List<Map<String, String>> messages = [
    {"user": "小美", "msg": "主播好美！😍"},
    {"user": "阿豪", "msg": "那隻手錶有折扣嗎？"},
  ];

  final TextEditingController _msgCtrl = TextEditingController();

  final liveProducts = [
    {"id": 10, "name": "直播限定手錶", "price": 2990, "image": "assets/watch_live.png"},
    {"id": 11, "name": "限時折扣手環", "price": 1490, "image": "assets/watch2.png"},
  ];

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        messages.add({"user": "我", "msg": text});
      });
      _msgCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📺 Osmile Live 直播中"),
        backgroundColor: Colors.pinkAccent,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              alignment: Alignment.bottomLeft,
              children: [
                Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: const Text(
                    "🎥 現場直播中：健康穿戴特賣！",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    height: 100,
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final msg = messages[messages.length - 1 - i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            "${msg["user"]}: ${msg["msg"]}",
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  const Text("💎 推薦商品",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...liveProducts.map((p) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: Image.asset(p["image"]!,
                              width: 60, height: 60, fit: BoxFit.cover),
                          title: Text(p["name"]!),
                          subtitle: Text("NT\$${p["price"]}"),
                          trailing: ElevatedButton(
                            onPressed: () {
                              cart.add(p);
                              notify.addNotification(
                                title: "🛒 加入購物車",
                                message: "${p["name"]} 已加入購物車！",
                                type: "cart",
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text("${p["name"]} 已加入購物車")),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.pinkAccent),
                            child: const Text("加入購物車"),
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ),
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "留言互動...",
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.pinkAccent),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
