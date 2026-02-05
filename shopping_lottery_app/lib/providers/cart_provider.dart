import 'package:flutter/foundation.dart';

/// 管理購物車內容的全域 Provider
class CartProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _items = [];

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);

  double get total =>
      _items.fold(0, (sum, item) => sum + item["price"] * item["qty"]);

  void addItem(Map<String, dynamic> product) {
    // 如果購物車內已有該商品，就增加數量
    final index = _items.indexWhere((p) => p["name"] == product["name"]);
    if (index != -1) {
      _items[index]["qty"] += 1;
    } else {
      _items.add(product);
    }
    notifyListeners();
  }

  void removeItem(String name) {
    _items.removeWhere((p) => p["name"] == name);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
