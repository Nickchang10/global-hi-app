import 'package:flutter/material.dart';

/// 📊 管理所有貼文的互動（讚數、留言、排行榜、發文）
class InteractionProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _posts = [
    {
      "id": 1,
      "name": "小明",
      "avatar": "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e",
      "text": "換購健康手環成功～",
      "image": "https://images.unsplash.com/photo-1605296867304-46d5465a13f1",
      "likes": 42,
      "comments": <String>[],
    },
    {
      "id": 2,
      "name": "小美",
      "avatar": "https://images.unsplash.com/photo-1599566150163-29194dcaad36",
      "text": "今天抽中 ED1000 🎉 超開心！",
      "image": "https://images.unsplash.com/photo-1606813902787-03b69a3f8b33",
      "likes": 24,
      "comments": <String>[],
    },
    {
      "id": 3,
      "name": "阿宏",
      "avatar": "https://images.unsplash.com/photo-1534528741775-53994a69daeb",
      "text": "週末和朋友參加Osmile活動，拿到折扣券啦！",
      "image": "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e",
      "likes": 15,
      "comments": <String>[],
    },
  ];

  List<Map<String, dynamic>> get posts => _posts;

  /// ❤️ 按讚／取消
  void toggleLike(int id, bool liked) {
    final post = _posts.firstWhere((e) => e["id"] == id);
    post["likes"] = (post["likes"] as int) + (liked ? 1 : -1);
    notifyListeners();
  }

  /// 💬 留言
  void addComment(int id, String comment) {
    final post = _posts.firstWhere((e) => e["id"] == id);
    (post["comments"] as List<String>).add(comment);
    notifyListeners();
  }

  /// 📝 新增貼文
  void addNewPost({
    required String name,
    required String text,
    required String image,
  }) {
    final newPost = {
      "id": DateTime.now().millisecondsSinceEpoch,
      "name": name,
      "avatar": "https://api.dicebear.com/9.x/personas/svg?seed=$name",
      "text": text,
      "image": image,
      "likes": 0,
      "comments": <String>[],
    };
    _posts.insert(0, newPost); // 新貼文放最上面
    notifyListeners();
  }

  /// 🔥 今日排行榜（根據讚數）
  List<Map<String, dynamic>> get topPosts {
    final sorted = [..._posts]..sort((a, b) => b["likes"] - a["likes"]);
    return sorted.take(3).toList();
  }

  /// 📅 本週排行榜
  List<Map<String, dynamic>> get weeklyTop {
    final sorted = [..._posts]..sort((a, b) => b["likes"] - a["likes"]);
    return sorted.take(5).toList();
  }

  /// 🌟 本月排行榜
  List<Map<String, dynamic>> get monthlyTop {
    final sorted = [..._posts]..sort((a, b) => b["likes"] - a["likes"]);
    return sorted.take(10).toList();
  }
}

