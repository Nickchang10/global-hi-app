// lib/widgets/product_card.dart
import 'package:flutter/material.dart';

class ProductCard extends StatelessWidget {
  final String name;
  final int price;
  final String image;

  /// 點整張卡片（進商品詳情）
  final VoidCallback onTap;

  /// 右側加入購物車（可選）
  final VoidCallback? onAdd;

  /// 顯示用：商品描述（可選）
  final String? description;

  /// 顯示用：角標（可選，例：免運 / 熱賣）
  final String? tag;

  /// 圖片來源：true=asset / false=network
  final bool isAssetImage;

  /// 右下角顯示「加入購物車」按鈕（避免功能重複時可關閉）
  final bool showAddButton;

  /// 圓角
  final double radius;

  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    required this.image,
    required this.onTap,
    this.onAdd,
    this.description,
    this.tag,
    this.isAssetImage = true,
    this.showAddButton = true,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceText = 'NT\$${price.toString()}';
    final hasDesc = (description ?? '').trim().isNotEmpty;
    final hasTag = (tag ?? '').trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // image
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(radius),
                  bottomLeft: Radius.circular(radius),
                ),
                child: Stack(
                  children: [
                    _buildImage(),
                    if (hasTag)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _TagBadge(text: tag!.trim()),
                      ),
                  ],
                ),
              ),

              // content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (hasDesc) ...[
                        Text(
                          description!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          Text(
                            priceText,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          if (showAddButton)
                            IconButton(
                              tooltip: '加入購物車',
                              onPressed: onAdd,
                              icon: Icon(
                                Icons.add_shopping_cart_outlined,
                                color: (onAdd == null) ? Colors.grey.shade400 : theme.iconTheme.color,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    const w = 104.0;
    const h = 104.0;

    if (isAssetImage) {
      return Image.asset(
        image,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imageFallback(w, h),
      );
    }

    return Image.network(
      image,
      width: w,
      height: h,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _imageSkeleton(w, h);
      },
      errorBuilder: (_, __, ___) => _imageFallback(w, h),
    );
  }

  Widget _imageSkeleton(double w, double h) {
    return Container(
      width: w,
      height: h,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: Colors.grey.shade400),
    );
  }

  Widget _imageFallback(double w, double h) {
    return Container(
      width: w,
      height: h,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
    );
  }
}

class _TagBadge extends StatelessWidget {
  final String text;
  const _TagBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final isFreeShip = text.contains('免運');
    final bg = isFreeShip ? Colors.green : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
