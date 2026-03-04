import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/shop_scaffold.dart';
import '../router_adapter.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.id,
  });

  final String id;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final _db = FirebaseFirestore.instance;
  
  Map<String, dynamic>? _productData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      final snap = await _db.collection('products').doc(widget.id).get();
      if (mounted) {
        setState(() {
          if (snap.exists) {
            _productData = snap.data();
          } else {
            _error = '商品不存在';
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '載入失敗：$e';
          _loading = false;
        });
      }
    }
  }

  String _getString(dynamic v, {String fallback = ''}) {
    if (v is String) return v;
    return fallback;
  }

  int _getInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.replaceAll(',', '')) ?? fallback;
    return fallback;
  }

  double _getDouble(dynamic v, {double fallback = 0.0}) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  List<String> _getImageList(dynamic v) {
    if (v is List) {
      return v.map((e) => _getString(e)).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ShopScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _productData == null) {
      return ShopScaffold(
        body: Center(child: Text(_error ?? '商品不存在')),
      );
    }

    final data = _productData!;
    final name = _getString(data['name'], fallback: _getString(data['title'], fallback: '未命名商品'));
    final price = _getInt(data['price'] ?? data['salePrice'] ?? data['amount']);
    final imageUrl = _getString(data['imageUrl'] ?? data['image']);
    final images = _getImageList(data['images']);
    final description = _getString(data['desc'] ?? data['description'] ?? data['subtitle']);
    final storeId = _getString(data['storeId']);
    final storeName = _getString(data['storeName'], fallback: '商店');
    final stock = _getInt(data['stock']);
    final rating = _getDouble(data['rating']);
    final sold = _getInt(data['sold']);
    final officialWebsite = _getString(data['officialWebsite']);

    final appState = context.watch<AppState>();

    // 使用 mock 数据中的相关抽獎（因為不是從 Firestore 存的）
    final relatedLotteries = lotteries.where((l) {
      final byStore = l.storeId == storeId;
      return byStore;
    }).toList(growable: false);

    // 建構虛擬 Product 物件以相容購物車邏輯
    final mockProduct = Product(
      id: widget.id,
      name: name,
      price: price,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : (images.isNotEmpty ? images.first : ''),
      description: description,
      stock: stock,
      rating: rating,
      sold: sold,
      storeId: storeId,
      store: storeName,
      officialWebsite: officialWebsite.isNotEmpty ? officialWebsite : null,
    );

    final combinedReviews = <Review>[
      ...appState.userReviews.where((r) => r.productId == widget.id),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return ShopScaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, size: 20),
                label: const Text('返回'),
                style: TextButton.styleFrom(alignment: Alignment.centerLeft),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.network(
                          mockProduct.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 14,
                            runSpacing: 8,
                            children: [
                              _MetaChip(icon: Icons.star, iconColor: Colors.amber, text: rating.toStringAsFixed(1)),
                              _MetaChip(text: '已售 $sold'),
                              _MetaChip(text: '庫存 $stock'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            formatTwd(price),
                            style: const TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(description.isNotEmpty ? description : '（無描述）', style: const TextStyle(color: Colors.black87)),
                          ),
                          const SizedBox(height: 12),

                          if (officialWebsite.isNotEmpty)
                            _LinkTile(
                              icon: Icons.open_in_new,
                              label: '查看官方網站',
                              onTap: () => _launchUrl(officialWebsite),
                            ),

                          if (relatedLotteries.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text('相關抽獎活動', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            ...relatedLotteries.map((l) => _RelatedLotteryTile(lottery: l)),
                          ],

                          const SizedBox(height: 16),
                          InkWell(
                            onTap: storeId.isNotEmpty ? () => context.go('/store_shop/$storeId') : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.store_outlined, color: Colors.black54),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('商店', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                        const SizedBox(height: 2),
                                        Text(storeName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                                  onPressed: () {
                                    context.read<AppState>().addToCart(mockProduct);
                                    context.go('/store_cart');
                                  },
                                  child: const Text('加入購物車'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () {
                                    context.read<AppState>().addToCart(mockProduct);
                                    context.go('/store_checkout');
                                  },
                                  child: const Text('立即購買'),
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
              const SizedBox(height: 12),

              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('買家評論 (${combinedReviews.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      if (combinedReviews.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text('尚無評論', style: TextStyle(color: Colors.black54)),
                          ),
                        )
                      else
                        Column(
                          children: combinedReviews
                              .map((r) => _ReviewTile(review: r))
                              .toList(growable: false),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    this.icon,
    this.iconColor,
    required this.text,
  });

  final IconData? icon;
  final Color? iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: iconColor ?? Colors.black54),
          const SizedBox(width: 4),
        ],
        Text(text, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
}

class _RelatedLotteryTile extends StatelessWidget {
  const _RelatedLotteryTile({required this.lottery});

  final Lottery lottery;

  String _reqText() {
    switch (lottery.requirement.type) {
      case LotteryRequirementType.purchase:
        return '購滿 ${formatTwd(lottery.requirement.minAmount ?? 0)} 參加';
      case LotteryRequirementType.share:
        return '分享活動參加';
      case LotteryRequirementType.free:
        return '免費參加';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.go('/lottery/${lottery.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE9D5FF)),
            gradient: const LinearGradient(
              colors: [Color(0xFFF5F3FF), Color(0xFFFDF2F8)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lottery.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(_reqText(), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              const Text('查看 →', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF60A5FA),
            child: Text(
              review.userName.isNotEmpty ? review.userName.substring(0, 1) : 'U',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(review.userName, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    ...List.generate(5, (i) {
                      final filled = i < review.rating;
                      return Icon(
                        Icons.star,
                        size: 14,
                        color: filled ? Colors.amber : Colors.black26,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(formatDateYmd(review.date), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(review.comment, style: const TextStyle(color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
