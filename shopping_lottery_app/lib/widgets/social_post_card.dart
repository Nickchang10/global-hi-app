// lib/widgets/social_post_card.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ SocialPostCard（社群貼文卡片｜完整版｜可編譯）
/// ------------------------------------------------------------
/// 支援：
/// - 顯示貼文作者、內容、時間
/// - 顯示圖片（可選）
/// - Like / Comment（可選回呼）
///
/// Firestore 建議欄位：
/// social_posts/{postId}
///   - authorName: String
///   - authorAvatarUrl: String (optional)
///   - content: String
///   - imageUrl: String (optional)
///   - likeCount: num
///   - commentCount: num
///   - createdAt: Timestamp
///   - likedUids: List<String> (optional)
class SocialPostCard extends StatelessWidget {
  const SocialPostCard({
    super.key,
    required this.postId,
    required this.data,
    this.onTap,
    this.onCommentTap,
    this.onLikeChanged,
    this.compact = false,
  });

  final String postId;
  final Map<String, dynamic> data;

  final VoidCallback? onTap;
  final VoidCallback? onCommentTap;

  /// 外部接手按讚寫入
  final Future<void> Function(bool liked)? onLikeChanged;

  final bool compact;

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  int _toInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  DateTime? _asDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '—';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final authorName = _s(data['authorName'], '匿名');
    final avatarUrl = _s(data['authorAvatarUrl'], '');
    final content = _s(data['content'], '');
    final imageUrl = _s(data['imageUrl'], '');

    final likeCount = _toInt(data['likeCount'], fallback: 0);
    final commentCount = _toInt(data['commentCount'], fallback: 0);
    final createdAt = _asDate(data['createdAt']);

    final user = FirebaseAuth.instance.currentUser;
    final likedUids = (data['likedUids'] is List)
        ? (data['likedUids'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final isLiked = user != null && likedUids.contains(user.uid);

    final pad = compact ? 12.0 : 14.0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(authorName, avatarUrl, _fmtTime(createdAt)),
              if (content.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  content,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
              if (imageUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                _imageBlock(imageUrl),
              ],
              const SizedBox(height: 10),
              _actionsRow(
                context: context,
                liked: isLiked,
                likeCount: likeCount,
                commentCount: commentCount,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(String name, String avatarUrl, String timeText) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.blueAccent.withValues(alpha: 0.10),
          backgroundImage: avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl.isNotEmpty
              ? null
              : Text(
                  name.isNotEmpty ? name.substring(0, 1) : '?',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.more_horiz, color: Colors.grey.shade600),
      ],
    );
  }

  Widget _imageBlock(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(url, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionsRow({
    required BuildContext context,
    required bool liked,
    required int likeCount,
    required int commentCount,
  }) {
    return Row(
      children: [
        _pill(
          icon: liked ? Icons.favorite : Icons.favorite_border,
          label: '$likeCount',
          iconColor: liked ? Colors.redAccent : Colors.grey.shade700,
          onTap: () => _toggleLike(context, liked: liked, likeCount: likeCount),
        ),
        const SizedBox(width: 10),
        _pill(
          icon: Icons.mode_comment_outlined,
          label: '$commentCount',
          iconColor: Colors.grey.shade700,
          onTap: onCommentTap,
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.blueAccent.withValues(alpha: 0.14),
            ),
          ),
          child: const Text(
            '分享',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike(
    BuildContext context, {
    required bool liked,
    required int likeCount,
  }) async {
    // ✅ 修正 use_build_context_synchronously：
    // 在任何 await 前先取得 messenger，後面都不要再用 context
    final messenger = ScaffoldMessenger.maybeOf(context);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      messenger?.showSnackBar(const SnackBar(content: Text('請先登入才能按讚')));
      return;
    }

    // 外部接手
    if (onLikeChanged != null) {
      try {
        await onLikeChanged!.call(!liked);
      } catch (e) {
        messenger?.showSnackBar(SnackBar(content: Text('按讚失敗：$e')));
      }
      return;
    }

    // 預設：直接寫 Firestore
    final fs = FirebaseFirestore.instance;
    final ref = fs.collection('social_posts').doc(postId);

    try {
      await fs.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;

        final d = snap.data() as Map<String, dynamic>;
        final list = (d['likedUids'] is List)
            ? (d['likedUids'] as List).map((e) => e.toString()).toList()
            : <String>[];

        final currentCount = _toInt(d['likeCount'], fallback: likeCount);

        if (liked) {
          list.remove(user.uid);
          tx.update(ref, {
            'likedUids': list,
            'likeCount': (currentCount - 1).clamp(0, 1 << 30),
          });
        } else {
          if (!list.contains(user.uid)) list.add(user.uid);
          tx.update(ref, {'likedUids': list, 'likeCount': currentCount + 1});
        }
      });
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('按讚失敗：$e')));
    }
  }
}
