// lib/services/vendor_service.dart
//
// ✅ VendorService（廠商資料服務｜可編譯完整版）
// ------------------------------------------------------------
// ✅ 修正：移除未使用的 _asNum（unused_element）
// - 提供 vendors CRUD、查詢、狀態更新、簡易搜尋
//
// Firestore 建議：collection = vendors
// doc fields（可自行增減，本檔容錯）
// - name: String
// - email: String
// - phone: String
// - status: 'active'|'disabled'|'pending'
// - categoryIds: List<String>
// - address: String
// - logoUrl: String
// - createdAt: Timestamp
// - updatedAt: Timestamp
// - metrics: Map { rating, sales, ... } (optional)
//
// 依賴：cloud_firestore, firebase_auth(可選)

import 'package:cloud_firestore/cloud_firestore.dart';

class VendorService {
  VendorService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection('vendors');

  // =========================
  // Read
  // =========================

  Stream<List<VendorDoc>> streamVendors({
    String status = 'all', // all/active/disabled/pending
    int limit = 200,
  }) {
    Query<Map<String, dynamic>> q = _ref
        .orderBy('updatedAt', descending: true)
        .limit(limit);

    if (status != 'all') {
      q = q.where('status', isEqualTo: status);
    }

    return q.snapshots().map(
      (snap) => snap.docs.map(VendorDoc.fromDoc).toList(),
    );
  }

  Future<List<VendorDoc>> listVendors({
    String status = 'all',
    int limit = 200,
  }) async {
    Query<Map<String, dynamic>> q = _ref
        .orderBy('updatedAt', descending: true)
        .limit(limit);
    if (status != 'all') q = q.where('status', isEqualTo: status);

    final snap = await q.get();
    return snap.docs.map(VendorDoc.fromDoc).toList();
  }

  Future<VendorDoc?> getVendor(String vendorId) async {
    final id = vendorId.trim();
    if (id.isEmpty) return null;

    final doc = await _ref.doc(id).get();
    if (!doc.exists) return null;
    return VendorDoc.fromDoc(doc);
  }

  Stream<VendorDoc?> streamVendor(String vendorId) {
    final id = vendorId.trim();
    if (id.isEmpty) return const Stream.empty();
    return _ref
        .doc(id)
        .snapshots()
        .map((d) => d.exists ? VendorDoc.fromDoc(d) : null);
  }

  // =========================
  // Create / Update
  // =========================

  Future<String> createVendor({
    required String name,
    String email = '',
    String phone = '',
    String status = 'pending',
    List<String> categoryIds = const [],
    String address = '',
    String logoUrl = '',
    Map<String, dynamic> metrics = const {},
  }) async {
    final doc = _ref.doc();
    final now = FieldValue.serverTimestamp();

    await doc.set({
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'status': status.trim().isEmpty ? 'pending' : status.trim(),
      'categoryIds': categoryIds.map((e) => e.toString()).toList(),
      'address': address.trim(),
      'logoUrl': logoUrl.trim(),
      'metrics': metrics,
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    return doc.id;
  }

  Future<void> updateVendor(
    String vendorId, {
    String? name,
    String? email,
    String? phone,
    String? status,
    List<String>? categoryIds,
    String? address,
    String? logoUrl,
    Map<String, dynamic>? metrics,
  }) async {
    final id = vendorId.trim();
    if (id.isEmpty) throw ArgumentError('vendorId is empty');

    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};

    if (name != null) data['name'] = name.trim();
    if (email != null) data['email'] = email.trim();
    if (phone != null) data['phone'] = phone.trim();
    if (status != null) data['status'] = status.trim();
    if (categoryIds != null) {
      data['categoryIds'] = categoryIds.map((e) => e.toString()).toList();
    }
    if (address != null) data['address'] = address.trim();
    if (logoUrl != null) data['logoUrl'] = logoUrl.trim();
    if (metrics != null) data['metrics'] = metrics;

    await _ref.doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> setStatus(String vendorId, String status) async {
    final id = vendorId.trim();
    if (id.isEmpty) throw ArgumentError('vendorId is empty');
    await _ref.doc(id).set({
      'status': status.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteVendor(String vendorId) async {
    final id = vendorId.trim();
    if (id.isEmpty) return;
    await _ref.doc(id).delete();
  }

  // =========================
  // Utils
  // =========================

  /// client-side 搜尋（避免索引複雜度）
  List<VendorDoc> filterByKeyword(List<VendorDoc> items, String keyword) {
    final k = keyword.trim().toLowerCase();
    if (k.isEmpty) return items;

    return items.where((v) {
      return v.id.toLowerCase().contains(k) ||
          v.name.toLowerCase().contains(k) ||
          v.email.toLowerCase().contains(k) ||
          v.phone.toLowerCase().contains(k);
    }).toList();
  }
}

// ============================================================
// Model
// ============================================================

class VendorDoc {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String status;
  final List<String> categoryIds;
  final String address;
  final String logoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> metrics;

  const VendorDoc({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.status,
    required this.categoryIds,
    required this.address,
    required this.logoUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.metrics,
  });

  factory VendorDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return VendorDoc(
      id: doc.id,
      name: _s(d['name']),
      email: _s(d['email']),
      phone: _s(d['phone']),
      status: _s(d['status']).isEmpty ? 'pending' : _s(d['status']),
      categoryIds: _asStringList(d['categoryIds']),
      address: _s(d['address']),
      logoUrl: _s(d['logoUrl']),
      createdAt: _toDate(d['createdAt']),
      updatedAt: _toDate(d['updatedAt']),
      metrics: _asMap(d['metrics']),
    );
  }
}

// ============================================================
// Helpers（保留必要的，移除 _asNum）
// ============================================================

String _s(dynamic v) => (v ?? '').toString().trim();

List<String> _asStringList(dynamic v) {
  if (v is List) return v.map((e) => (e ?? '').toString()).toList();
  return const [];
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

DateTime? _toDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}
