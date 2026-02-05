// lib/widgets/favorite_button.dart
// =======================================================
// ✅ FavoriteButton - 收藏按鈕（即時同步版）
// - 即時更新愛心狀態（Provider 通知）
// - 同步 FavoritesPage 收藏列表
// - Flutter Web / Android / iOS 通用
// =======================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wishlist_service.dart';

class FavoriteButton extends StatelessWidget {
  final Map<String, dynamic> product;
  final double iconSize;

  const FavoriteButton({
    super.key,
    required this.product,
    this.iconSize = 26,
  });

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistService>();
    final bool isFavorite = wishlist.isInWishlist(product['id'].toString());

    return IconButton(
      tooltip: isFavorite ? '移除收藏' : '加入收藏',
      iconSize: iconSize,
      icon: Icon(
        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: isFavorite ? Colors.redAccent : Colors.grey,
      ),
      onPressed: () async {
        await context.read<WishlistService>().toggleWishlist(product);

        final msg = isFavorite ? '已移除收藏' : '已加入收藏';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 1100),
          ),
        );
      },
    );
  }
}
