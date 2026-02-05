// lib/pages/search_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:osmile_shopping_app/services/search_service.dart';
import 'package:osmile_shopping_app/services/social_service.dart';
import 'package:osmile_shopping_app/widgets/social_post_card.dart';

/// 🔍 全域搜尋頁（商品 / 貼文 / 好友）
///
/// 功能：
/// - 即時搜尋（onChanged）
/// - 顯示三類結果
/// - 支援圖片預覽 / 點貼文開詳細
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  Map<String, List<Map<String, dynamic>>> _results = {
    "products": [],
    "posts": [],
    "friends": [],
  };

  void _performSearch(String keyword) {
    if (keyword.trim().isEmpty) {
      setState(() {
        _results = {
          "products": [],
          "posts": [],
          "friends": [],
        };
      });
      return;
    }

    final result = SearchService.instance.search(keyword);
    setState(() => _results = result);
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialService>();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: "搜尋商品、貼文、好友...",
            border: InputBorder.none,
          ),
          onChanged: _performSearch,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _performSearch('');
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 🛍️ 商品結果
            if (_results["products"]!.isNotEmpty)
              _Section(
                title: "🛍️ 商品",
                child: Column(
                  children: _results["products"]!
                      .map(
                        (p) => ListTile(
                          leading: const Icon(Icons.shopping_bag),
                          title: Text(p["name"] ?? "未命名商品"),
                          subtitle: Text("數量：${p["count"] ?? 1}"),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        ),
                      )
                      .toList(),
                ),
              ),

            // 💬 貼文結果
            if (_results["posts"]!.isNotEmpty)
              _Section(
                title: "💬 貼文",
                child: Column(
                  children: _results["posts"]!.map((post) {
                    final index = social.posts.indexOf(post);
                    final images = List<String>.from(post["images"] ?? []);
                    final firstImage =
                        images.isNotEmpty ? File(images.first) : null;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: ListTile(
                        leading: firstImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  firstImage,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.chat_bubble_outline),
                        title: Text(post["user"] ?? "訪客"),
                        subtitle: Text(
                          post["content"] ?? "",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          // 點開貼文詳情
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => Padding(
                              padding: EdgeInsets.only(
                                bottom: MediaQuery.of(context).viewInsets.bottom,
                              ),
                              child: SingleChildScrollView(
                                child: SocialPostCard(
                                  post: post,
                                  index: index,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

            // 👥 好友結果
            if (_results["friends"]!.isNotEmpty)
              _Section(
                title: "👥 好友",
                child: Column(
                  children: _results["friends"]!
                      .map(
                        (f) => ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(f["name"] ?? ""),
                          trailing: const Icon(Icons.chat_bubble_outline),
                        ),
                      )
                      .toList(),
                ),
              ),

            if (_results["products"]!.isEmpty &&
                _results["posts"]!.isEmpty &&
                _results["friends"]!.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  "輸入關鍵字以搜尋 🔍",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 📦 可重用區塊樣式
class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: const Border(
          top: BorderSide(color: Colors.black12),
          bottom: BorderSide(color: Colors.black12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
