// lib/pages/explore_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:osmile_shopping_app/services/social_service.dart';
import 'package:osmile_shopping_app/widgets/social_post_card.dart';

/// 🔥 熱門探索頁
/// 顯示按讚最多的貼文
class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialService>();
    final posts = [...social.posts]..sort((a, b) {
      final int likeA = a["likes"] ?? 0;
      final int likeB = b["likes"] ?? 0;
      return likeB.compareTo(likeA);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("🔥 熱門探索"),
        centerTitle: true,
      ),
      body: posts.isEmpty
          ? const Center(child: Text("目前沒有熱門貼文 😅"))
          : ListView.builder(
              itemCount: posts.length,
              itemBuilder: (_, i) => SocialPostCard(post: posts[i], index: i),
            ),
    );
  }
}
