// lib/models/product.dart

import 'package:flutter/foundation.dart';

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
}

/// 讓原本使用 `Product` 的地方不用全部改，
/// 直接當成別名使用即可。
typedef Product = ProductModel;
