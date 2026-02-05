// lib/services/vendor_service.dart
//
// ✅ VendorService（最終穩定完整版｜可編譯｜Vendor/廠商管理服務層）
// ------------------------------------------------------------
// 目的：
// - 讓 main.dart 的 Provider(create: (_) => VendorService()) 可正常編譯
// - 提供 VendorManagementPage / Admin 端常用的 vendors CRUD、搜尋、綁定 user->vendor 等方法
//
// Firestore 建議結構：
//
// vendors/{vendorId}
//   - name: String
//   - nameLower: String (for search)
//   - email: String
//   - phone: String
//   - contactName: String
//   - isActive: bool
//   - order: number
//   - createdAt: Timestamp
//   - updatedAt: Timestamp
//
// vendor_users/{docId}   (選用：記錄 vendor 與使用者的綁定/權限)
//   - vendorId: String
//   - uid: String
//   - role: String (owner/staff...)
//   - createdAt / updatedAt
//
// users/{uid}
//   - role: 'admin' | 'vendor' | ...
//   - vendorId: String
//
// ------------------------------------------------------------
// 依賴：cloud_firestore, firebase_auth, flutter/foundation
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

@immutable
class VendorDoc {
  final String id;
  final Map<String, dynamic> data;

  const VendorDoc({required this.id, required this.data});

  String get name => (data['name'] ?? '').toString();
  String get nameLower => (data['nameLower'] ?? '').toString();
  bool get isActive => data['isActive'] == true;
  String get email => (data['email'] ?? '').toString();
  String get phone => (data['phone'] ?? '').toString();
  String get contactName => (data['contactName'] ?? '').toString();

  num get order {
    final v = data['order'];
    if (v is num) return v;
    if (v is int) return v;
    return 999999999; // 缺欄位時排後面
  }

  DateTime? get createdAt => _toDate(data['createdAt']);
  DateTime? get updatedAt => _toDate(data['updatedAt']);

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}

class VendorService {
  VendorService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String vendorsCollection = 'vendors',
    String vendorUsersCollection = 'vendor_users',
    String usersCollection = 'users',
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _vendorsColName = vendorsCollection,
        _vendorUsersColName = vendorUsersCollection,
        _usersColName = usersCollection;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  final String _vendorsColName;
  final String _vendorUsersColName;
  final String _usersColName;

  CollectionReference<Map<String, dynamic>> get _vendors =>
      _db.collection(_vendorsColName);

  CollectionReference<Map<String, dynamic>> get _vendorUsers =>
      _db.collection(_vendorUsersColName);

  CollectionReference<Map<String, dynamic>> get _users => _db.collection(_usersColName);

  // -----------------------------
  // Utils
  // -----------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v is num) return v;
    if (v is int) return v;
    if (v is double) return v;
    return fallback;
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  Map<String, dynamic> _normalizeVendorData(Map<String, dynamic> input) {
    final name = _s(input['name']);
    final email = _s(input['email']);
    final phone = _s(input['phone']);
    final contactName = _s(input['contactName']);

    return <String, dynamic>{
      'name': name,
      'nameLower': name.toLowerCase(),
      'email': email,
      'phone': phone,
      'contactName': contactName,
      if (input.containsKey('isActive')) 'isActive': input['isActive'] == true,
      if (input.containsKey('order')) 'order': input['order'],
    };
  }

  // ------------------------------------------------------------
  // Vendors Query
  // ------------------------------------------------------------
  /// ✅ 以 updatedAt 做 server-side order（最穩：少索引問題）
  /// ✅ client-side：排序(order)、搜尋(keyword)、狀態(isActive)
  Stream<List<VendorDoc>> streamVendors({
    String keyword = '',
    bool? isActive,
    int limit = 500,
  }) {
    final kw = keyword.trim().toLowerCase();

    final q = _vendors
        .orderBy('updatedAt', descending: true)
        .limit(limit);

    return q.snapshots().map((snap) {
      final rows = snap.docs
          .map((d) => VendorDoc(id: d.id, data: d.data()))
          .toList();

      // client-side filter
      final filtered = rows.where((v) {
        final d = v.data;
        final name = _s(d['name']).toLowerCase();
        final email = _s(d['email']).toLowerCase();
        final phone = _s(d['phone']).toLowerCase();
        final contact = _s(d['contactName']).toLowerCase();
        final id = v.id.toLowerCase();

        final okKw = kw.isEmpty ||
            id.contains(kw) ||
            name.contains(kw) ||
            email.contains(kw) ||
            phone.contains(kw) ||
            contact.contains(kw);

        final okActive = isActive == null ? true : (d['isActive'] == true) == isActive;

        return okKw && okActive;
      }).toList();

      // client-side sort: order ASC, updatedAt DESC
      filtered.sort((a, b) {
        final ao = a.order;
        final bo = b.order;
        final c1 = ao.compareTo(bo);
        if (c1 != 0) return c1;

        final at = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });

      return filtered;
    });
  }

  /// ✅ 常用別名（避免你其他頁面用不同方法名造成編譯失敗）
  Stream<List<VendorDoc>> watchVendors({
    String keyword = '',
    bool? isActive,
    int limit = 500,
  }) =>
      streamVendors(keyword: keyword, isActive: isActive, limit: limit);

  Future<VendorDoc?> getVendorById(String vendorId) async {
    final id = vendorId.trim();
    if (id.isEmpty) return null;
    final doc = await _vendors.doc(id).get();
    if (!doc.exists) return null;
    return VendorDoc(id: doc.id, data: doc.data() ?? {});
  }

  // ------------------------------------------------------------
  // Vendors CRUD
  // ------------------------------------------------------------
  Future<String> createVendor({
    required String name,
    String email = '',
    String phone = '',
    String contactName = '',
    bool isActive = true,
    num? order,
    String? vendorId, // 允許外部指定（可選）
  }) async {
    final now = FieldValue.serverTimestamp();

    final data = _normalizeVendorData({
      'name': name,
      'email': email,
      'phone': phone,
      'contactName': contactName,
      'isActive': isActive,
      'order': order ?? DateTime.now().millisecondsSinceEpoch,
    });

    final payload = <String, dynamic>{
      ...data,
      'createdAt': now,
      'updatedAt': now,
    };

    final custom = vendorId?.trim() ?? '';
    if (custom.isNotEmpty) {
      await _vendors.doc(custom).set(payload, SetOptions(merge: true));
      return custom;
    }

    final ref = await _vendors.add(payload);
    return ref.id;
  }

  /// upsert（merge=true 預設）
  Future<void> upsertVendor(
    String vendorId,
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    final id = vendorId.trim();
    if (id.isEmpty) throw Exception('vendorId 不可為空');

    final normalized = _normalizeVendorData(data);

    await _vendors.doc(id).set(
      <String, dynamic>{
        ...normalized,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!merge) 'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: merge),
    );
  }

  /// ✅ 常用別名（有些頁面會叫 updateVendor）
  Future<void> updateVendor(
    String vendorId,
    Map<String, dynamic> data, {
    bool merge = true,
  }) =>
      upsertVendor(vendorId, data, merge: merge);

  Future<void> setVendorActive(String vendorId, bool isActive) async {
    final id = vendorId.trim();
    if (id.isEmpty) throw Exception('vendorId 不可為空');

    await _vendors.doc(id).set(
      <String, dynamic>{
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// ✅ 常用別名（有些頁面會叫 toggleActive）
  Future<void> toggleActive(String vendorId, bool toActive) =>
      setVendorActive(vendorId, toActive);

  Future<void> deleteVendor(
    String vendorId, {
    bool deleteVendorUsers = false,
  }) async {
    final id = vendorId.trim();
    if (id.isEmpty) throw Exception('vendorId 不可為空');

    if (deleteVendorUsers) {
      final qs = await _vendorUsers.where('vendorId', isEqualTo: id).limit(500).get();
      final batch = _db.batch();
      for (final d in qs.docs) {
        batch.delete(d.reference);
      }
      batch.delete(_vendors.doc(id));
      await batch.commit();
      return;
    }

    await _vendors.doc(id).delete();
  }

  Future<void> reorderVendors(List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;

    final batch = _db.batch();
    for (int i = 0; i < orderedIds.length; i++) {
      final id = orderedIds[i].trim();
      if (id.isEmpty) continue;
      batch.set(
        _vendors.doc(id),
        <String, dynamic>{
          'order': i + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  // ------------------------------------------------------------
  // User <-> Vendor 綁定（users/{uid}.vendorId）
  // ------------------------------------------------------------
  Future<void> bindUserToVendor({
    required String uid,
    required String vendorId,
    String? role, // optional: 同步更新 users.role
  }) async {
    final u = uid.trim();
    final v = vendorId.trim();
    if (u.isEmpty) throw Exception('uid 不可為空');
    if (v.isEmpty) throw Exception('vendorId 不可為空');

    await _users.doc(u).set(
      <String, dynamic>{
        'vendorId': v,
        if (role != null && role.trim().isNotEmpty) 'role': role.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> unbindUserVendor(String uid) async {
    final u = uid.trim();
    if (u.isEmpty) throw Exception('uid 不可為空');

    await _users.doc(u).set(
      <String, dynamic>{
        'vendorId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// 取得目前登入者 users/{uid}.vendorId（vendor 後台路由可用）
  Future<String?> getMyVendorId() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _users.doc(user.uid).get();
    if (!doc.exists) return null;

    final d = doc.data() ?? <String, dynamic>{};
    final vid = _s(d['vendorId']);
    return vid.isEmpty ? null : vid;
  }

  // ------------------------------------------------------------
  // vendor_users（選用）
  // ------------------------------------------------------------
  Stream<List<Map<String, dynamic>>> streamVendorUsers({
    required String vendorId,
    int limit = 500,
  }) {
    final v = vendorId.trim();
    if (v.isEmpty) {
      return const Stream<List<Map<String, dynamic>>>.empty();
    }

    final q = _vendorUsers
        .where('vendorId', isEqualTo: v)
        .orderBy('updatedAt', descending: true)
        .limit(limit);

    return q.snapshots().map(
          (snap) => snap.docs
              .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
              .toList(),
        );
  }

  Future<String> addVendorUser({
    required String vendorId,
    required String uid,
    String role = 'staff',
  }) async {
    final v = vendorId.trim();
    final u = uid.trim();
    if (v.isEmpty) throw Exception('vendorId 不可為空');
    if (u.isEmpty) throw Exception('uid 不可為空');

    final now = FieldValue.serverTimestamp();
    final ref = await _vendorUsers.add(<String, dynamic>{
      'vendorId': v,
      'uid': u,
      'role': role.trim().isEmpty ? 'staff' : role.trim(),
      'createdAt': now,
      'updatedAt': now,
    });
    return ref.id;
  }

  Future<void> updateVendorUser(String docId, Map<String, dynamic> data) async {
    final id = docId.trim();
    if (id.isEmpty) throw Exception('docId 不可為空');

    await _vendorUsers.doc(id).set(
      <String, dynamic>{
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deleteVendorUser(String docId) async {
    final id = docId.trim();
    if (id.isEmpty) throw Exception('docId 不可為空');
    await _vendorUsers.doc(id).delete();
  }

  // ------------------------------------------------------------
  // Debug / Helpers（可選）
  // ------------------------------------------------------------
  Future<void> ensureVendorDocExists(
    String vendorId, {
    String fallbackName = '未命名廠商',
  }) async {
    final id = vendorId.trim();
    if (id.isEmpty) return;

    final doc = await _vendors.doc(id).get();
    if (doc.exists) return;

    if (kDebugMode) {
      // ignore: avoid_print
      print('[VendorService] vendors/$id 不存在，建立預設資料');
    }

    await _vendors.doc(id).set(
      <String, dynamic>{
        'name': fallbackName,
        'nameLower': fallbackName.toLowerCase(),
        'email': '',
        'phone': '',
        'contactName': '',
        'isActive': true,
        'order': DateTime.now().millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  String formatTimestamp(dynamic v) {
    final d = _toDate(v);
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}
