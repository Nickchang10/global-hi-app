import 'package:flutter/material.dart';

/// 🛍️ 商品服務（本地模擬）
class ProductService extends ChangeNotifier {
  ProductService._internal();
  static final ProductService instance = ProductService._internal();

  final List<Map<String, dynamic>> _products = [
    {
      "id": "p001",
      "name": "Osmile Lumi 智慧手錶",
      "price": 3990,
      "stock": 25,
      "image": "assets/images/lumi_watch.png",
      "description": "健康監測、防走失、緊急SOS，一錶守護全家人。",
      "tags": ["智慧穿戴", "安全守護"]
    },
    {
      "id": "p002",
      "name": "ED1000 智能護理錶",
      "price": 5990,
      "stock": 18,
      "image": "assets/images/ed1000.png",
      "description": "醫療級心率監測，支援長者定位與藍牙通話。",
      "tags": ["健康照護", "熱門商品"]
    },
    {
      "id": "p003",
      "name": "Osmile Care 智慧手環",
      "price": 2490,
      "stock": 40,
      "image": "assets/images/osmile_band.png",
      "description": "輕巧耐用，適合日常運動與健康紀錄。",
      "tags": ["日常運動", "新上市"]
    },
  ];

  List<Map<String, dynamic>> get allProducts => List.unmodifiable(_products);

  Map<String, dynamic>? getProductById(String id) =>
      _products.firstWhere((p) => p["id"] == id, orElse: () => {});
}
