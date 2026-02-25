// lib/models/product.dart
//
// ✅ Product model（最終完整版｜可直接使用｜已移除 unused_import）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;

  // 基本
  final String title;
  final String description;
  final String categoryId;
  final List<String> images;

  // 價格
  final int price; // 原價（單位：元）
  final int salePrice; // 促銷價（0 表示無促銷）
  final String currency; // 預設 TWD

  // 庫存 / 上架
  final int stock;
  final bool isActive;

  // 供應商/廠商
  final String vendorId;
  final String vendorName;

  // 排序 / 權重
  final int sort;
  final int soldCount;

  // 時間
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.images,
    required this.price,
    required this.salePrice,
    required this.currency,
    required this.stock,
    required this.isActive,
    required this.vendorId,
    required this.vendorName,
    required this.sort,
    required this.soldCount,
    required this.createdAt,
    required this.updatedAt,
  });

  int get effectivePrice =>
      (salePrice > 0 && salePrice < price) ? salePrice : price;

  int get discountAmount =>
      (salePrice > 0 && salePrice < price) ? (price - salePrice) : 0;

  double get discountRate => (salePrice > 0 && salePrice < price && price > 0)
      ? (price - salePrice) / price
      : 0.0;

  bool get hasDiscount => discountAmount > 0;

  bool get inStock => stock > 0;

  Product copyWith({
    String? id,
    String? title,
    String? description,
    String? categoryId,
    List<String>? images,
    int? price,
    int? salePrice,
    String? currency,
    int? stock,
    bool? isActive,
    String? vendorId,
    String? vendorName,
    int? sort,
    int? soldCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      images: images ?? this.images,
      price: price ?? this.price,
      salePrice: salePrice ?? this.salePrice,
      currency: currency ?? this.currency,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      sort: sort ?? this.sort,
      soldCount: soldCount ?? this.soldCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'images': images,
      'price': price,
      'salePrice': salePrice,
      'currency': currency,
      'stock': stock,
      'isActive': isActive,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'sort': sort,
      'soldCount': soldCount,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  static Product fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      categoryId: (map['categoryId'] ?? '').toString(),
      images: (map['images'] is List)
          ? List<String>.from((map['images'] as List).map((e) => e.toString()))
          : const <String>[],
      price: _toInt(map['price'], fallback: 0),
      salePrice: _toInt(map['salePrice'], fallback: 0),
      currency: (map['currency'] ?? 'TWD').toString(),
      stock: _toInt(map['stock'], fallback: 0),
      isActive: (map['isActive'] ?? true) == true,
      vendorId: (map['vendorId'] ?? '').toString(),
      vendorName: (map['vendorName'] ?? '').toString(),
      sort: _toInt(map['sort'], fallback: 0),
      soldCount: _toInt(map['soldCount'], fallback: 0),
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  static Product fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
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
