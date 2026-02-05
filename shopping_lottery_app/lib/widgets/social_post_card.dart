// lib/widgets/social_post_card.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:osmile_shopping_app/services/social_service.dart';

/// 🧱 Osmile 貼文卡元件（完整版）
///
/// 功能：
/// ✅ 多圖輪播 / 圓角卡片設計
/// ✅ 按讚動畫 / 即時更新
/// ✅ 留言 / 刪除留言
/// ✅ 顯示時間、留言數
/// ✅ 適用於 SocialPage
class SocialPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final int index;

  const SocialPostCard({
    super.key,
    required this.post,
    required this.index,
  });

  @override
  State<SocialPostCard> createState() => _SocialPostCardState();
}

class _SocialPostCardState extends State<SocialPostCard>
    with SingleTickerProviderStateMixin {
  final TextEditingController _commentCtrl = TextEditingController();
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialService>();
    final post = widget.post;

    final user = post["user"] ?? "Osmile 用戶";
    final content = post["content"] ?? "";
    final time = DateFormat("MM/dd HH:mm").format(post["time"]);
    final likes = post["likes"] ?? 0;
    final isLiked = post["isLiked"] ?? false;
    final comments = List<String>.from(post["comments"] ?? []);
    final images = List<String>.from(post["images"] ?? []);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👤 用戶名稱 + 時間
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Text(
                    user.isNotEmpty ? user[0] : "?",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Text(time,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),

            // 🖼️ 多圖輪播
            if (images.isNotEmpty)
              SizedBox(
                height: 220,
                child: PageView.builder(
                  controller: PageController(viewportFraction: 0.9),
                  itemCount: images.length,
                  itemBuilder: (_, i) {
                    final img = images[i];
                    final isFile = img.startsWith('/');
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: isFile
                            ? Image.file(File(img), fit: BoxFit.cover)
                            : Image.asset(
                                img,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.image_not_supported,
                                      size: 80, color: Colors.grey),
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),

            if (content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  content,
                  style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.black87,
                      fontWeight: FontWeight.w400),
                ),
              ),

            const SizedBox(height: 8),

            // ❤️ 按讚 / 留言列
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    context.read<SocialService>().toggleLike(widget.index);
                    _animCtrl.forward(from: 0.0);
                  },
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.redAccent : Colors.grey,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text("$likes",
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, color: Colors.black87)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.comment_outlined,
                      color: Colors.blueAccent),
                  onPressed: () => _openCommentSheet(context, comments),
                ),
                Text("${comments.length}",
                    style: const TextStyle(color: Colors.black87)),
              ],
            ),

            // 💬 顯示前兩則留言
            if (comments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: comments
                      .take(2)
                      .map((c) => Text("💬 $c",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black87)))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 💬 留言彈窗
  void _openCommentSheet(BuildContext context, List<String> comments) {
    final index = widget.index;
    final social = context.read<SocialService>();
    final ctrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("留言互動",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // 留言列表
            if (comments.isNotEmpty)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (_, i) => ListTile(
                    leading:
                        const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent),
                    title: Text(comments[i]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      onPressed: () {
                        social.removeComment(index, i);
                      },
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: "輸入留言內容...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text("送出留言"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final text = ctrl.text.trim();
                if (text.isNotEmpty) {
                  social.addComment(index, text);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
