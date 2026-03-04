import 'package:flutter/material.dart';

/// Router adapter to provide go_router-like API using Navigator
extension RouterAdapter on BuildContext {
  /// Navigate to a route
  void go(String route, {Object? extra}) {
    // Parse route and navigate accordingly
    if (route == '/') {
      // Go back to home/store main page
      while (Navigator.of(this).canPop()) {
        Navigator.of(this).pop();
      }
    } else if (route.startsWith('/product/')) {
      // Extract product ID from route like "/product/123"
      final id = route.replaceFirst('/product/', '');
      Navigator.of(this).pushNamed('/product', arguments: {'productId': id});
    } else if (route.startsWith('/lottery/')) {
      // Extract lottery ID from route like "/lottery/123" or "/store_lottery/123"
      final id = route.replaceFirst(RegExp(r'^/store_lottery/|^/lottery/'), '');
      Navigator.of(this).pushNamed('/store_lottery', arguments: {'id': id});
    } else if (route == '/store_lottery') {
      Navigator.of(this).pushNamed('/store_lottery');
    } else if (route.startsWith('/store_lottery/')) {
      final id = route.replaceFirst('/store_lottery/', '');
      Navigator.of(this).pushNamed('/store_lottery', arguments: {'id': id});
    } else if (route.startsWith('/store/')) {
      // Extract store ID from route like "/store/123" → redirect to new /store_shop/{id}
      final id = route.replaceFirst('/store/', '');
      Navigator.of(this).pushNamed('/store_shop', arguments: {'id': id});
    } else if (route.startsWith('/store_shop/')) {
      final id = route.replaceFirst('/store_shop/', '');
      Navigator.of(this).pushNamed('/store_shop', arguments: {'id': id});
    } else if (route == '/search') {
      Navigator.of(this).pushNamed('/search');
    } else if (route == '/checkout') {
      // within store pages, checkout should go to store_checkout
      Navigator.of(this).pushNamed('/store_checkout');
    } else if (route == '/orders') {
      Navigator.of(this).pushNamed('/orders');
    } else if (route == '/lottery-history') {
      Navigator.of(this).pushNamed('/store_lottery_history');
    } else if (route.startsWith('/lottery-history/')) {
      final id = route.replaceFirst('/lottery-history/', '');
      Navigator.of(this).pushNamed('/store_lottery_history', arguments: {'id': id});
    } else if (route == '/store_lottery_history') {
      Navigator.of(this).pushNamed('/store_lottery_history');
    } else if (route.startsWith('/store_lottery_history/')) {
      final id = route.replaceFirst('/store_lottery_history/', '');
      Navigator.of(this).pushNamed('/store_lottery_history', arguments: {'id': id});
    } else if (route == '/lottery-reveal') {
      Navigator.of(this).pushNamed('/lottery-reveal');
    } else if (route.startsWith('/lottery-reveal/')) {
      final id = route.replaceFirst('/lottery-reveal/', '');
      Navigator.of(this).pushNamed('/lottery-reveal', arguments: {'id': id});
    } else if (route == '/cart') {
      Navigator.of(this).pushNamed('/cart');
    } else if (route == '/store_cart') {
      Navigator.of(this).pushNamed('/store_cart');
    } else if (route == '/store_payment') {
      Navigator.of(this).pushNamed('/store_payment');
    } else if (route == '/store_checkout') {
      Navigator.of(this).pushNamed('/store_checkout');
    } else {
      Navigator.of(this).pushNamed(route);
    }
  }

  /// Pop the current route
  void pop([Object? result]) {
    Navigator.of(this).pop(result);
  }
}
