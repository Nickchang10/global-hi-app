import 'package:flutter/foundation.dart';

@immutable
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.store,
    required this.storeId,
    required this.rating,
    required this.sold,
    required this.description,
    required this.stock,
    this.officialWebsite,
  });

  final String id;
  final String name;
  final int price;
  final String imageUrl;
  final String store;
  final String storeId;
  final double rating;
  final int sold;
  final String description;
  final int stock;
  final String? officialWebsite;
}

enum LotteryRequirementType { share, purchase, free }

@immutable
class LotteryRequirement {
  const LotteryRequirement({
    required this.type,
    this.minAmount,
  });

  final LotteryRequirementType type;
  final int? minAmount;
}

@immutable
class Lottery {
  const Lottery({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.prize,
    required this.prizeValue,
    required this.endDate,
    required this.participants,
    required this.maxParticipants,
    required this.requirement,
    required this.store,
    required this.storeId,
    required this.description,
    this.officialWebsite,
    this.relatedProductIds,
  });

  final String id;
  final String name;
  final String imageUrl;
  final String prize;
  final int prizeValue;
  final DateTime endDate;
  final int participants;
  final int maxParticipants;
  final LotteryRequirement requirement;
  final String store;
  final String storeId;
  final String description;
  final String? officialWebsite;
  final List<String>? relatedProductIds;
}

@immutable
class Store {
  const Store({
    required this.id,
    required this.name,
    required this.logo,
    required this.rating,
    required this.products,
  });

  final String id;
  final String name;
  final String logo; // emoji
  final double rating;
  final int products;
}

@immutable
class Review {
  const Review({
    required this.id,
    required this.productId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.date,
    this.images,
  });

  final String id;
  final String productId;
  final String userName;
  final int rating; // 1..5
  final String comment;
  final DateTime date;
  final List<String>? images;
}

@immutable
class CartItem {
  const CartItem({
    required this.product,
    required this.quantity,
  });

  final Product product;
  final int quantity;

  CartItem copyWith({int? quantity}) => CartItem(
        product: product,
        quantity: quantity ?? this.quantity,
      );
}

enum LotteryStatus { pending, won, lost }

@immutable
class LotteryParticipation {
  const LotteryParticipation({
    required this.lottery,
    required this.participatedAt,
    required this.status,
    required this.announced,
    this.shareProofUrl,
  });

  final Lottery lottery;
  final DateTime participatedAt;
  final LotteryStatus status;
  final bool announced;
  final String? shareProofUrl;

  LotteryParticipation copyWith({
    LotteryStatus? status,
    bool? announced,
  }) =>
      LotteryParticipation(
        lottery: lottery,
        participatedAt: participatedAt,
        status: status ?? this.status,
        announced: announced ?? this.announced,
        shareProofUrl: shareProofUrl,
      );
}

enum OrderStatus { completed, shipping, cancelled }

@immutable
class Order {
  const Order({
    required this.id,
    required this.items,
    required this.total,
    required this.shippingFee,
    required this.date,
    required this.status,
  });

  final String id;
  final List<CartItem> items;
  final int total;
  final int shippingFee; // 新增：運費
  final DateTime date;
  final OrderStatus status;
}
