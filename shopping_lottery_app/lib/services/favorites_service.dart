// lib/services/favorites_service.dart
import 'package:flutter/foundation.dart';

/// 簡單的收藏管理 service
/// 管理商品 (products) 與貼文 (posts) 的收藏列表（在示範中以 Map 表示）
class FavoritesService extends ChangeNotifier {
  final List<Map<String, dynamic>> _products = [];
  final List<Map<String, dynamic>> _posts = [];

  // 取用(只讀拷貝)
  List<Map<String, dynamic>> get products => List.unmodifiable(_products);
  List<Map<String, dynamic>> get posts => List.unmodifiable(_posts);

  int get productCount => _products.length;
  int get postCount => _posts.length;

  // 商品
  bool isProductFavorited(String id) => _products.any((p) => p['id'] == id);

  void addProduct(Map<String, dynamic> product) {
    if (product['id'] == null) return;
    if (!isProductFavorited(product['id'])) {
      _products.insert(0, Map<String, dynamic>.from(product));
      notifyListeners();
    }
  }

  void removeProduct(String id) {
    _products.removeWhere((p) => p['id'] == id);
    notifyListeners();
  }

  void toggleProduct(Map<String, dynamic> product) {
    final id = product['id'];
    if (id == null) return;
    if (isProductFavorited(id)) {
      removeProduct(id);
    } else {
      addProduct(product);
    }
  }

  // 貼文
  bool isPostFavorited(Object id) => _posts.any((p) => p['id'] == id);

  void addPost(Map<String, dynamic> post) {
    if (post['id'] == null) return;
    if (!isPostFavorited(post['id'])) {
      _posts.insert(0, Map<String, dynamic>.from(post));
      notifyListeners();
    }
  }

  void removePost(Object id) {
    _posts.removeWhere((p) => p['id'] == id);
    notifyListeners();
  }

  void togglePost(Map<String, dynamic> post) {
    final id = post['id'];
    if (id == null) return;
    if (isPostFavorited(id)) {
      removePost(id);
    } else {
      addPost(post);
    }
  }

  // 清空（示範）
  void clearAll() {
    _products.clear();
    _posts.clear();
    notifyListeners();
  }
}
