import 'package:flutter/material.dart';
import '../models/coupon_model.dart';

class CouponProvider with ChangeNotifier {
  final List<CouponModel> _coupons = [];

  List<CouponModel> get coupons => _coupons;

  void addCoupon(CouponModel coupon) {
    _coupons.add(coupon);
    notifyListeners();
  }

  void markAsUsed(String code) {
    final index = _coupons.indexWhere((c) => c.code == code);
    if (index != -1) {
      _coupons[index].used = true;
      notifyListeners();
    }
  }
}
