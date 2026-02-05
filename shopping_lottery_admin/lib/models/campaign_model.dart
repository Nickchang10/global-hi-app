import 'package:cloud_firestore/cloud_firestore.dart';

class Campaign {
  final String id;
  final String title;
  final String vendorId;
  final String vendorName;
  final String description;
  final DateTime startAt;
  final DateTime endAt;
  final String status;
  final bool isPublic;
  final String ruleType;
  final num discountValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  Campaign({
    required this.id,
    required this.title,
    required this.vendorId,
    required this.vendorName,
    required this.description,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.isPublic,
    required this.ruleType,
    required this.discountValue,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Campaign.fromMap(String id, Map<String, dynamic> data) {
    return Campaign(
      id: id,
      title: data['title'] ?? '',
      vendorId: data['vendorId'] ?? '',
      vendorName: data['vendorName'] ?? '',
      description: data['description'] ?? '',
      startAt: (data['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endAt: (data['endAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'draft',
      isPublic: data['isPublic'] ?? false,
      ruleType: data['ruleType'] ?? 'none',
      discountValue: (data['discountValue'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'description': description,
      'startAt': startAt,
      'endAt': endAt,
      'status': status,
      'isPublic': isPublic,
      'ruleType': ruleType,
      'discountValue': discountValue,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
