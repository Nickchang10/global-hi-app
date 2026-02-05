import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:osmile_shopping_app/services/live_service.dart';
import 'package:osmile_shopping_app/services/cart_service.dart';
import 'package:osmile_shopping_app/services/wishlist_service.dart';
import 'package:osmile_shopping_app/services/notification_service.dart';

/// 🎥 直播詳情頁（模擬聊天室 + 商品推播）
class LiveDetailPage extends StatefulWidget {
  final Map<String, dynamic> room;

  const LiveDetailPage({super.key, required this.room});

  @override
  State<LiveDetailPage> createState() => _LiveDetailPageState();
}

class _LiveDetailPageState extends State<LiveDetailPage> {
  final _chatCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final wishlist = context.watch<WishlistService>();
    final notify = NotificationService.instance;

    final room = widget.room;
    final product = room["promotedProduct"];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("${room["host"]} 的直播"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 背景圖（模擬直播畫面）
          Positioned.fill(
            child: Image.asset(
              room["thumbnail"],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.grey[800]),
            ),
          ),

          // 直播聊天區
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildProductCard(context, product, wishlist, cart, notify),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      reverse: true,
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final msg = _messages[_messages.length - 1 - i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.person,
                                  color: Colors.white70, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  msg["text"],
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "留言...",
                            hintStyle:
                                const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 14),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: () {
                          if (_chatCtrl.text.trim().isEmpty) return;
                          setState(() {
                            _messages.add({"text": _chatCtrl.text});
                            _chatCtrl.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🛍️ 商品推播卡片
  Widget _buildProductCard(
    BuildContext context,
    Map<String, dynamic> product,
    WishlistService wishlist,
    CartService cart,
    NotificationService notify,
  ) {
    final isFav = wishlist.isInWishlist(product["id"]);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              product["image"],
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.image_not_supported),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product["name"],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text("NT\$${product["price"]}",
                    style: const TextStyle(
                        color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? Colors.red : Colors.grey),
            onPressed: () {
              if (isFav) {
                wishlist.removeFromWishlist(product["id"]);
                notify.addNotification(
                  title: "💔 已取消收藏",
                  message: "${product["name"]} 已從收藏移除",
                  type: "wishlist",
                );
              } else {
                wishlist.addToWishlist(product);
                notify.addNotification(
                  title: "💖 已加入收藏",
                  message: "收藏了 ${product["name"]}",
                  type: "wishlist",
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_shopping_cart,
                color: Colors.blueAccent),
            onPressed: () {
              cart.add({...product, "qty": 1});
              notify.addNotification(
                title: "🛒 加入購物車",
                message: "從直播中加入：${product["name"]}",
                type: "cart",
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("已加入購物車：${product["name"]}")),
              );
            },
          ),
        ],
      ),
    );
  }
}
