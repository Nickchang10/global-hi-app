// lib/models/cart_item.dart
//
// ✅ CartItem model（最終完整版｜可直接使用｜已修正 ProductModel 未定義）
// ------------------------------------------------------------
// - 對應產品 Product（lib/models/product.dart）
// - 支援基本序列化、copyWith、計算小計
// - 可用於 Provider/CartService/Firestore 存取

import 'package:cloud_firestore/cloud_firestore.dart';
import 'product.dart';

class CartItem {
  final String id; // cart item id（可用 productId 或 uuid）
  final String productId;

  // 產品快照（下單/加入購物車時的資訊），避免之後產品改價造成購物車資訊混亂
  final String title;
  final String image;
  final int unitPrice; // 加入時單價（建議用 Product.effectivePrice）
  final String currency;

  // 數量
  final int qty;

  // 廠商
  final String vendorId;
  final String vendorName;

  // 時間（可選）
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CartItem({
    required this.id,
    required this.productId,
    required this.title,
    required this.image,
    required this.unitPrice,
    required this.currency,
    required this.qty,
    required this.vendorId,
    required this.vendorName,
    required this.createdAt,
    required this.updatedAt,
  });

  int get subtotal => unitPrice * qty;

  CartItem copyWith({
    String? id,
    String? productId,
    String? title,
    String? image,
    int? unitPrice,
    String? currency,
    int? qty,
    String? vendorId,
    String? vendorName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      title: title ?? this.title,
      image: image ?? this.image,
      unitPrice: unitPrice ?? this.unitPrice,
      currency: currency ?? this.currency,
      qty: qty ?? this.qty,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 從 Product 建立 CartItem（最常用）
  factory CartItem.fromProduct({required Product product, required int qty}) {
    return CartItem(
      id: product.id, // 也可改 uuid；用 product.id 可避免同商品重複加入變多筆
      productId: product.id,
      title: product.title,
      image: product.images.isNotEmpty ? product.images.first : '',
      unitPrice: product.effectivePrice,
      currency: product.currency,
      qty: qty,
      vendorId: product.vendorId,
      vendorName: product.vendorName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'title': title,
      'image': image,
      'unitPrice': unitPrice,
      'currency': currency,
      'qty': qty,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  static CartItem fromMap(String id, Map<String, dynamic> map) {
    return CartItem(
      id: id,
      productId: (map['productId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      image: (map['image'] ?? '').toString(),
      unitPrice: _toInt(map['unitPrice'], fallback: 0),
      currency: (map['currency'] ?? 'TWD').toString(),
      qty: _toInt(map['qty'], fallback: 1).clamp(1, 999999),
      vendorId: (map['vendorId'] ?? '').toString(),
      vendorName: (map['vendorName'] ?? '').toString(),
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  static CartItem fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return fromMap(doc.id, data);
  }

  static int _toInt(dynamic v, {required int fallback}) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
