// lib/models/user_address.dart
import 'package:flutter/material.dart';

class UserAddress {
  final String id;
  String receiverName;
  String phone;
  String city;
  String district;
  String detail;
  String tag; // 'home' | 'office' | 'other'
  bool isDefaultShipping;
  bool isDefaultBilling;

  UserAddress({
    required this.id,
    required this.receiverName,
    required this.phone,
    required this.city,
    required this.district,
    required this.detail,
    this.tag = 'home',
    this.isDefaultShipping = false,
    this.isDefaultBilling = false,
  });

  String get fullAddress => '$city$district$detail';

  String get tagLabel {
    switch (tag) {
      case 'office':
        return '公司';
      case 'other':
        return '其它';
      case 'home':
      default:
        return '住家';
    }
  }

  Color get tagColor {
    switch (tag) {
      case 'office':
        return Colors.blueAccent;
      case 'other':
        return Colors.grey;
      case 'home':
      default:
        return Colors.orangeAccent;
    }
  }

  UserAddress copyWith({
    String? id,
    String? receiverName,
    String? phone,
    String? city,
    String? district,
    String? detail,
    String? tag,
    bool? isDefaultShipping,
    bool? isDefaultBilling,
  }) {
    return UserAddress(
      id: id ?? this.id,
      receiverName: receiverName ?? this.receiverName,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      district: district ?? this.district,
      detail: detail ?? this.detail,
      tag: tag ?? this.tag,
      isDefaultShipping: isDefaultShipping ?? this.isDefaultShipping,
      isDefaultBilling: isDefaultBilling ?? this.isDefaultBilling,
    );
  }
}
