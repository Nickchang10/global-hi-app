import 'package:flutter/material.dart';

/// ✅ ProductCard（商品卡片｜完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正重點：
/// - ✅ 新增 named parameter: `margin`
/// - ✅ 移除 withOpacity（lint: deprecated_member_use）
/// ------------------------------------------------------------
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.margin,
    this.onTap,
    this.onAddToCart,
    this.onFavorite,
    this.showFavorite = true,
    this.isFavorite = false,
    this.showAddToCart = true,
    this.elevation = 1.5,
    this.borderRadius = 14,
    this.imageHeight = 120,
    this.badgeText,
  });

  /// 商品資料（Map 或 model 都可）
  final dynamic product;

  /// ✅ 修正：外部常用 ProductCard(margin: ...)；這裡要定義
  final EdgeInsetsGeometry? margin;

  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final VoidCallback? onFavorite;

  final bool showFavorite;
  final bool isFavorite;
  final bool showAddToCart;

  final double elevation;
  final double borderRadius;
  final double imageHeight;

  /// 可選：左上角 badge（例如：熱賣/新品）
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final title =
        _pickString(product, const ['title', 'name', 'productName']) ?? '未命名商品';
    final subtitle =
        _pickString(product, const ['subtitle', 'brief', 'desc']) ?? '';
    final imageUrl = _pickString(product, const [
      'imageUrl',
      'image',
      'coverUrl',
      'thumbUrl',
    ]);
    final price =
        _pickNum(product, const ['salePrice', 'price', 'amount']) ?? 0;

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: Card(
            elevation: elevation,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _imageBlock(context, imageUrl),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (showFavorite)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isFavorite
                                    ? Colors.redAccent
                                    : Colors.grey,
                                size: 20,
                              ),
                              onPressed: onFavorite,
                              tooltip: '收藏',
                            ),
                        ],
                      ),
                      if (subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            _formatPrice(price),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          if (showAddToCart)
                            FilledButton.tonalIcon(
                              onPressed: onAddToCart,
                              icon: const Icon(
                                Icons.add_shopping_cart,
                                size: 18,
                              ),
                              label: const Text('加入'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageBlock(BuildContext context, String? imageUrl) {
    return SizedBox(
      height: imageHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null && imageUrl.trim().isNotEmpty)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _imageFallback(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
            )
          else
            _imageFallback(),
          if (badgeText != null && badgeText!.trim().isNotEmpty)
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  // ✅ 0.55 -> alpha=140
                  color: const Color.fromARGB(140, 0, 0, 0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      // ✅ grey 500 + alpha 31（0.12）
      color: const Color.fromARGB(31, 158, 158, 158),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 42, color: Colors.grey),
      ),
    );
  }

  // -----------------------
  // Helpers（容錯取值）
  // -----------------------

  String _formatPrice(num price) {
    final v = price.toDouble();
    if (v % 1 == 0) return 'NT\$${v.toInt()}';
    return 'NT\$${v.toStringAsFixed(2)}';
  }

  String? _pickString(dynamic obj, List<String> keys) {
    final v = _pick(obj, keys);
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  num? _pickNum(dynamic obj, List<String> keys) {
    final v = _pick(obj, keys);
    if (v == null) return null;
    if (v is num) return v;
    final s = v.toString().trim();
    return num.tryParse(s);
  }

  dynamic _pick(dynamic obj, List<String> keys) {
    if (obj == null) return null;

    // Map
    if (obj is Map) {
      for (final k in keys) {
        if (obj.containsKey(k)) return obj[k];
      }
    }

    // 嘗試 toJson()
    try {
      // ignore: avoid_dynamic_calls
      final v = (obj as dynamic).toJson();
      if (v is Map) {
        for (final k in keys) {
          if (v.containsKey(k)) return v[k];
        }
      }
    } catch (_) {}

    // 最後 fallback：常見 getter（dynamic）
    for (final k in keys) {
      try {
        // ignore: avoid_dynamic_calls
        final v = _dynamicGetter(obj, k);
        if (v != null) return v;
      } catch (_) {}
    }

    return null;
  }

  dynamic _dynamicGetter(dynamic obj, String key) {
    switch (key) {
      case 'title':
        // ignore: avoid_dynamic_calls
        return obj.title;
      case 'name':
      case 'productName':
        // ignore: avoid_dynamic_calls
        return obj.name;
      case 'subtitle':
      case 'brief':
      case 'desc':
        // ignore: avoid_dynamic_calls
        return obj.subtitle;
      case 'imageUrl':
      case 'image':
      case 'coverUrl':
      case 'thumbUrl':
        // ignore: avoid_dynamic_calls
        return obj.imageUrl;
      case 'salePrice':
        // ignore: avoid_dynamic_calls
        return obj.salePrice;
      case 'price':
      case 'amount':
        // ignore: avoid_dynamic_calls
        return obj.price;
      default:
        return null;
    }
  }
}
