// lib/models/cart_item.dart
import 'product.dart';

/// 購物車項目：
/// - 綁定一個商品 [product]
/// - [qty] 數量
/// - 可選擇顏色 / 版本 / 套餐等規格
class CartItem {
  final ProductModel product;
  int qty;

  /// 使用者選擇的顏色（若有）
  final String? selectedColor;

  /// 使用者選擇的版本（若有）
  final String? selectedVersion;

  /// 使用者選擇的方案 / 套餐（若有）
  final String? selectedPackage;

  CartItem({
    required this.product,
    this.qty = 1,
    this.selectedColor,
    this.selectedVersion,
    this.selectedPackage,
  });

  CartItem copyWith({
    ProductModel? product,
    int? qty,
    String? selectedColor,
    String? selectedVersion,
    String? selectedPackage,
  }) {
    return CartItem(
      product: product ?? this.product,
      qty: qty ?? this.qty,
      selectedColor: selectedColor ?? this.selectedColor,
      selectedVersion: selectedVersion ?? this.selectedVersion,
      selectedPackage: selectedPackage ?? this.selectedPackage,
    );
  }
}
