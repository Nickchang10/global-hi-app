import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/shop_scaffold.dart';
import '../router_adapter.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

// helpers copied from main orders page
int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.replaceAll(',', '').trim()) ?? 0;
  return 0;
}

DateTime _toDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  return DateTime.fromMillisecondsSinceEpoch(0);
}

Order _orderFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data() ?? <String, dynamic>{};

  final itemsRaw = m['items'];
  final items = <CartItem>[];
  if (itemsRaw is List) {
    for (final e in itemsRaw) {
      if (e is Map) {
        final pid = (e['productId'] ?? '').toString();
        final name = (e['nameSnapshot'] ?? '').toString();
        final price = _toInt(e['priceSnapshot'] ?? 0);
        final imageUrl = (e['imageUrl'] ?? '').toString();
        final qty = _toInt(e['quantity'] ?? e['qty'] ?? 1);
        items.add(CartItem(
          product: Product(
            id: pid,
            name: name,
            price: price,
            imageUrl: imageUrl,
            store: (e['storeName'] ?? '').toString(),
            storeId: (e['storeId'] ?? '').toString(),
            rating: 0,
            sold: 0,
            description: '',
            stock: 0,
          ),
          quantity: qty,
        ));
      }
    }
  }

  final total = _toInt(m['total'] ?? 0);

  // shipping fee may be stored directly or under pricing map
  int shippingFee = 0;
  if (m.containsKey('shippingFee')) {
    shippingFee = _toInt(m['shippingFee']);
  } else {
    final pr = m['pricing'];
    if (pr is Map) {
      shippingFee = _toInt(pr['shippingFee'] ?? pr['shipping'] ?? pr['freight']);
    }
  }

  final createdAtRaw = m['createdAt'];
  final date = createdAtRaw is Timestamp ? createdAtRaw.toDate() : DateTime.now();
  final statusStr = (m['status'] ?? 'completed').toString().toLowerCase();
  final status = switch (statusStr) {
    'shipping' || 'shipped' => OrderStatus.shipping,
    'cancelled' => OrderStatus.cancelled,
    _ => OrderStatus.completed,
  };

  return Order(
    id: d.id,
    items: items,
    total: total,
    shippingFee: shippingFee,
    date: date,
    status: status,
  );
}

class _OrdersPageState extends State<OrdersPage> {
  String? _reviewingProductId;
  int _rating = 5;
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return ShopScaffold(
        body: const Center(child: Text('請先登入')),
      );
    }

    final q = FirebaseFirestore.instance
        .collection('orders')
        .where('uid', isEqualTo: uid)
        .limit(50);

    return ShopScaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('讀取訂單失敗：\n${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs.toList();
          docs.sort((a, b) {
            final da = _toDate(a.data()['createdAt']);
            final db = _toDate(b.data()['createdAt']);
            return db.compareTo(da);
          });

          final orders = docs.map(_orderFromDoc).toList(growable: false);

          if (orders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 80, color: Colors.black.withOpacity(0.2)),
                    const SizedBox(height: 12),
                    const Text('尚無訂單記錄', style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go('/'),
                      child: const Text('開始購物'),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.arrow_back, size: 20),
                    label: const Text('返回首頁'),
                    style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                  ),
                  const SizedBox(height: 8),
                  const Text('我的訂單', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),

                  Column(
                    children: orders
                        .map((o) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _OrderCard(
                                order: o,
                                reviewingProductId: _reviewingProductId,
                                rating: _rating,
                                commentController: _commentCtrl,
                                onStartReview: (productId) {
                                  setState(() {
                                    _reviewingProductId = productId;
                                    _rating = 5;
                                    _commentCtrl.clear();
                                  });
                                },
                                onCancelReview: () {
                                  setState(() {
                                    _reviewingProductId = null;
                                    _rating = 5;
                                    _commentCtrl.clear();
                                  });
                                },
                                onRatingChanged: (v) => setState(() => _rating = v),
                                onSubmitReview: (productId, productName) => _submitReview(context, productId, productName),
                              ),
                            ))
                        .toList(growable: false),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _submitReview(BuildContext context, String productId, String productName) {
    final comment = _commentCtrl.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入評論內容')));
      return;
    }

    context.read<AppState>().addReview(
          Review(
            id: 'review-${DateTime.now().millisecondsSinceEpoch}',
            productId: productId,
            userName: '我',
            rating: _rating,
            comment: comment,
            date: DateTime.now(),
          ),
        );

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('評論已送出！')));

    setState(() {
      _reviewingProductId = null;
      _rating = 5;
      _commentCtrl.clear();
    });
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.reviewingProductId,
    required this.rating,
    required this.commentController,
    required this.onStartReview,
    required this.onCancelReview,
    required this.onRatingChanged,
    required this.onSubmitReview,
  });

  final Order order;
  final String? reviewingProductId;
  final int rating;
  final TextEditingController commentController;
  final ValueChanged<String> onStartReview;
  final VoidCallback onCancelReview;
  final ValueChanged<int> onRatingChanged;
  final void Function(String productId, String productName) onSubmitReview;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final statusText = switch (order.status) {
      OrderStatus.completed => '已完成',
      OrderStatus.shipping => '配送中',
      OrderStatus.cancelled => '已取消',
    };

    final statusColor = switch (order.status) {
      OrderStatus.completed => Colors.green,
      OrderStatus.shipping => Colors.orange,
      OrderStatus.cancelled => Colors.red,
    };

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('訂單編號：${order.id}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('訂單日期：${formatDateZhTw(order.date)}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                ...order.items.map((item) {
                  final p = item.product;
                  final hasReviewed = state.hasReviewed(p.id);
                  final showReviewButton = order.status == OrderStatus.completed && !hasReviewed && reviewingProductId != p.id;
                  final showingForm = reviewingProductId == p.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => context.go('/product/${p.id}'),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  p.imageUrl,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(width: 70, height: 70, color: const Color(0xFFF3F4F6)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: () => context.go('/product/${p.id}'),
                                    child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text('數量：${item.quantity} | ${formatTwd(p.price)}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                  const SizedBox(height: 6),
                                  if (showReviewButton)
                                    TextButton.icon(
                                      onPressed: () => onStartReview(p.id),
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('撰寫評論'),
                                      style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                                    ),
                                  if (hasReviewed)
                                    const Text('✓ 已評論', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(formatTwd(p.price * item.quantity), style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),

                        if (showingForm)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('撰寫評論 - ${p.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 10),
                                  const Text('評分', style: TextStyle(fontSize: 12)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: List.generate(5, (i) {
                                      final star = i + 1;
                                      final filled = star <= rating;
                                      return IconButton(
                                        onPressed: () => onRatingChanged(star),
                                        icon: Icon(Icons.star, color: filled ? Colors.amber : Colors.black26, size: 30),
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text('評論內容', style: TextStyle(fontSize: 12)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: commentController,
                                    maxLines: 4,
                                    decoration: InputDecoration(
                                      hintText: '分享您的使用心得...',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      FilledButton(
                                        onPressed: () => onSubmitReview(p.id, p.name),
                                        child: const Text('送出評論'),
                                      ),
                                      const SizedBox(width: 10),
                                      OutlinedButton(
                                        onPressed: onCancelReview,
                                        child: const Text('取消'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),

                const Divider(height: 18),
                // shipping fee row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('運費', style: TextStyle(fontSize: 14, color: Colors.black54)),
                    Text(formatTwd(order.shippingFee), style: const TextStyle(fontSize: 14, color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('訂單總計', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(formatTwd(order.total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.red)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
