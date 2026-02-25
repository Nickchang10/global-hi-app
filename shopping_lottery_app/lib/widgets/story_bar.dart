import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/social_service.dart';

/// ✅ StoryBar（完整版｜修正 SocialFriend -> String 型別錯誤）
///
/// - 來源：SocialService.friends
/// - 點擊事件：
///    - onTapFriendId(String uid)
///    - onTapFriend(SocialFriend friend)
class StoryBar extends StatelessWidget {
  const StoryBar({
    super.key,
    this.height = 104,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.onTapFriendId,
    this.onTapFriend,
    this.showName = true,
  });

  final double height;
  final EdgeInsets padding;

  /// ✅ 若你原本頁面只想拿 uid（String），用這個
  final ValueChanged<String>? onTapFriendId;

  /// ✅ 若你想拿整個 friend 物件，用這個
  final ValueChanged<SocialFriend>? onTapFriend;

  final bool showName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: padding,
        child: Consumer<SocialService>(
          builder: (context, social, _) {
            final friends = social.friends;

            if (social.loading && friends.isEmpty) {
              return _loadingRow();
            }

            if (friends.isEmpty) {
              return _emptyRow();
            }

            return ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: friends.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final f = friends[index];

                // ✅ 修正重點：不要把 SocialFriend 當 String 傳
                // - uid 是 String
                // - photoUrl/imageUrl 是 String?
                // - name/displayName 是 String
                return _StoryFriendItem(
                  uid: f.uid,
                  name: f.displayName,
                  photoUrl: f.photoUrl,
                  showName: showName,
                  onTap: () {
                    onTapFriendId?.call(f.uid);
                    onTapFriend?.call(f);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _loadingRow() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, __) => const _SkeletonStory(),
    );
  }

  Widget _emptyRow() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Text('目前沒有好友動態', style: TextStyle(color: Colors.grey)),
    );
  }
}

class _StoryFriendItem extends StatelessWidget {
  const _StoryFriendItem({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.onTap,
    required this.showName,
  });

  final String uid;
  final String name;
  final String? photoUrl;
  final VoidCallback onTap;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = (photoUrl != null && photoUrl!.trim().isNotEmpty);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12),
              ),
              child: ClipOval(
                child: hasPhoto
                    ? Image.network(
                        photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _initialAvatar(name),
                      )
                    : _initialAvatar(name),
              ),
            ),
            if (showName) ...[
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _initialAvatar(String name) {
    final initial = name.trim().isEmpty ? ' ' : name.trim().characters.first;
    return Container(
      color: Colors.black12,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SkeletonStory extends StatelessWidget {
  const _SkeletonStory();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 72,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SkeletonCircle(size: 56),
          SizedBox(height: 8),
          _SkeletonBar(width: 56, height: 10),
        ],
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFE9E9E9),
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9E9E9),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
