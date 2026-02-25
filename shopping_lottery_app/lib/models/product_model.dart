// lib/models/product.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// 商品資料模型：
/// - 支援標籤 / 收藏 / 評分 / 評價數
/// - 支援 quantity（購物車數量）
/// - 支援 categoryId（分類）等欄位
class ProductModel {
  final String id;
  final String title;
  final String subtitle;
  final String brand;

  /// 分類 ID（例如：smart_watch / kids_watch / band / social）
  final String categoryId;

  /// 價格
  final int price;
  final int? oldPrice; // 有折扣才顯示

  /// 圖片列表
  final List<String> images;

  /// 主要圖片（第一張）
  String get image => images.isNotEmpty ? images.first : "";

  /// 庫存
  final int stock;

  /// 商品描述
  final String description;

  /// 建立時間（用於排序：新品 / 熱銷）
  final DateTime createdAt;

  /// 熱度分數（熱銷程度）
  final int hotScore;

  /// 標籤：新品 / 熱銷 / 特價 / 好友推薦...
  final List<String> tags;

  /// 篩選用：顏色 / 版本
  final String color;
  final String version;

  /// 規格選項
  final List<String> colorOptions;
  final List<String> versionOptions;
  final List<String> packageOptions;

  /// 收藏狀態（商品列表裡會直接切換）
  bool isFavorite;

  /// 評分與評價數（商品詳情頁用）
  final double rating;
  final int reviewCount;

  /// 購物車數量
  final int quantity;

  ProductModel({
    required this.id,
    required this.title,
    this.subtitle = "",
    this.brand = "",
    required this.categoryId,
    required this.price,
    this.oldPrice,
    required this.images,
    this.stock = 0,
    this.description = "",
    required this.createdAt,
    this.hotScore = 0,
    this.tags = const [],
    this.color = "",
    this.version = "",
    this.colorOptions = const [],
    this.versionOptions = const [],
    this.packageOptions = const [],
    this.isFavorite = false,
    this.rating = 4.5,
    this.reviewCount = 0,
    this.quantity = 1,
  });

  /// 是否有折扣（oldPrice 大於 price 才算）
  bool get hasDiscount => oldPrice != null && oldPrice! > price;

  /// 折扣金額（元）
  int get discountAmount => hasDiscount ? (oldPrice! - price) : 0;

  /// 方便在 Provider 裡做「+1 / -1 / 更新部分欄位」
  ProductModel copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? brand,
    String? categoryId,
    int? price,
    int? oldPrice,
    List<String>? images,
    int? stock,
    String? description,
    DateTime? createdAt,
    int? hotScore,
    List<String>? tags,
    String? color,
    String? version,
    List<String>? colorOptions,
    List<String>? versionOptions,
    List<String>? packageOptions,
    bool? isFavorite,
    double? rating,
    int? reviewCount,
    int? quantity,
  }) {
    return ProductModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      brand: brand ?? this.brand,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      images: images ?? this.images,
      stock: stock ?? this.stock,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      hotScore: hotScore ?? this.hotScore,
      tags: tags ?? this.tags,
      color: color ?? this.color,
      version: version ?? this.version,
      colorOptions: colorOptions ?? this.colorOptions,
      versionOptions: versionOptions ?? this.versionOptions,
      packageOptions: packageOptions ?? this.packageOptions,
      isFavorite: isFavorite ?? this.isFavorite,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      quantity: quantity ?? this.quantity,
    );
  }

  /// 轉成 Map（方便之後接 API / 本地儲存）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'brand': brand,
      'categoryId': categoryId,
      'price': price,
      'oldPrice': oldPrice,
      'images': images,
      'stock': stock,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'hotScore': hotScore,
      'tags': tags,
      'color': color,
      'version': version,
      'colorOptions': colorOptions,
      'versionOptions': versionOptions,
      'packageOptions': packageOptions,
      'isFavorite': isFavorite,
      'rating': rating,
      'reviewCount': reviewCount,
      'quantity': quantity,
    };
  }

  /// 從 Map 建立（配合 API 回傳）
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      brand: (json['brand'] ?? '').toString(),
      categoryId: (json['categoryId'] ?? '').toString(),
      price: _toInt(json['price'], fallback: 0),
      oldPrice: json['oldPrice'] == null
          ? null
          : _toInt(json['oldPrice'], fallback: 0),
      images: (json['images'] is List)
          ? List<String>.from((json['images'] as List).map((e) => e.toString()))
          : const [],
      stock: _toInt(json['stock'], fallback: 0),
      description: (json['description'] ?? '').toString(),
      createdAt: _toDateTime(json['createdAt']) ?? DateTime.now(),
      hotScore: _toInt(json['hotScore'], fallback: 0),
      tags: (json['tags'] is List)
          ? List<String>.from((json['tags'] as List).map((e) => e.toString()))
          : const [],
      color: (json['color'] ?? '').toString(),
      version: (json['version'] ?? '').toString(),
      colorOptions: (json['colorOptions'] is List)
          ? List<String>.from(
              (json['colorOptions'] as List).map((e) => e.toString()),
            )
          : const [],
      versionOptions: (json['versionOptions'] is List)
          ? List<String>.from(
              (json['versionOptions'] as List).map((e) => e.toString()),
            )
          : const [],
      packageOptions: (json['packageOptions'] is List)
          ? List<String>.from(
              (json['packageOptions'] as List).map((e) => e.toString()),
            )
          : const [],
      isFavorite: (json['isFavorite'] ?? false) == true,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      reviewCount: _toInt(json['reviewCount'], fallback: 0),
      quantity: _toInt(json['quantity'], fallback: 1).clamp(1, 999999),
    );
  }

  /// ✅ Firestore：寫入用 Map（createdAt 用 Timestamp，避免字串排序問題）
  Map<String, dynamic> toFirestoreMap({bool includeId = false}) {
    final map = <String, dynamic>{
      'title': title,
      'subtitle': subtitle,
      'brand': brand,
      'categoryId': categoryId,
      'price': price,
      'oldPrice': oldPrice,
      'images': images,
      'stock': stock,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'hotScore': hotScore,
      'tags': tags,
      'color': color,
      'version': version,
      'colorOptions': colorOptions,
      'versionOptions': versionOptions,
      'packageOptions': packageOptions,
      'isFavorite': isFavorite,
      'rating': rating,
      'reviewCount': reviewCount,
      'quantity': quantity,
    };
    if (includeId) map['id'] = id;
    return map;
  }

  /// ✅ Firestore：從 Document 讀取（createdAt 支援 Timestamp / String）
  factory ProductModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ProductModel.fromFirestoreMap(doc.id, data);
  }

  /// ✅ Firestore：從 Map 讀取（id 由 docId 傳入）
  factory ProductModel.fromFirestoreMap(String id, Map<String, dynamic> data) {
    return ProductModel(
      id: id,
      title: (data['title'] ?? '').toString(),
      subtitle: (data['subtitle'] ?? '').toString(),
      brand: (data['brand'] ?? '').toString(),
      categoryId: (data['categoryId'] ?? '').toString(),
      price: _toInt(data['price'], fallback: 0),
      oldPrice: data['oldPrice'] == null
          ? null
          : _toInt(data['oldPrice'], fallback: 0),
      images: (data['images'] is List)
          ? List<String>.from((data['images'] as List).map((e) => e.toString()))
          : const [],
      stock: _toInt(data['stock'], fallback: 0),
      description: (data['description'] ?? '').toString(),
      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
      hotScore: _toInt(data['hotScore'], fallback: 0),
      tags: (data['tags'] is List)
          ? List<String>.from((data['tags'] as List).map((e) => e.toString()))
          : const [],
      color: (data['color'] ?? '').toString(),
      version: (data['version'] ?? '').toString(),
      colorOptions: (data['colorOptions'] is List)
          ? List<String>.from(
              (data['colorOptions'] as List).map((e) => e.toString()),
            )
          : const [],
      versionOptions: (data['versionOptions'] is List)
          ? List<String>.from(
              (data['versionOptions'] as List).map((e) => e.toString()),
            )
          : const [],
      packageOptions: (data['packageOptions'] is List)
          ? List<String>.from(
              (data['packageOptions'] as List).map((e) => e.toString()),
            )
          : const [],
      isFavorite: (data['isFavorite'] ?? false) == true,
      rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
      reviewCount: _toInt(data['reviewCount'], fallback: 0),
      quantity: _toInt(data['quantity'], fallback: 1).clamp(1, 999999),
    );
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
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  @override
  String toString() {
    return 'ProductModel(id: $id, title: $title, price: $price, quantity: $quantity, isFavorite: $isFavorite)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// ✅ 相容別名：讓其他地方若用 Product 也能直接編譯
typedef Product = ProductModel;
