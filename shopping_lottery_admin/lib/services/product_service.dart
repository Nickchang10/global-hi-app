// lib/services/product_service.dart
//
// ✅ ProductService v2.2（最終完整版・可編譯強化版｜Web/Chrome OK｜含 Storage 圖片刪除）
//
// 支援頁面：
// - AdminProductsPage
// - ProductsPage
// - VendorProductsPage
//
// Firestore 結構: products/{productId}
// - title: String
// - price: num
// - isActive: bool
// - createdAt: Timestamp
// - updatedAt: Timestamp
// - vendorId: String?
// - categoryId: String?
// - images: List<String>（建議放「downloadURL」或「gs://」）
// - imageUrl: String（舊版相容）
//
// Storage：
// - 建議上傳到：products/{productId}/{timestamp}_{filename}
// - 刪除商品時可一併刪除 images/imageUrl 指向的 Storage 檔案（僅限 Firebase Storage URL / gs://）
//
// 依賴：cloud_firestore, firebase_storage

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class ProductException implements Exception {
  final String code;
  final String message;
  ProductException(this.code, this.message);
  @override
  String toString() => 'ProductException($code): $message';
}

class ProductService {
  ProductService({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('products');

  String _s(dynamic v) => (v ?? '').toString().trim();

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(_s(v)) ?? 0;
  }

  Map<String, dynamic> _withId(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    return <String, dynamic>{...m, 'id': d.id};
  }

  // ------------------------------------------------------------
  // Streams / Queries
  // ------------------------------------------------------------

  /// ✅ 全部商品串流（含 vendor / active 篩選）
  Stream<List<Map<String, dynamic>>> streamProducts({
    String? vendorId,
    bool includeInactive = true,
    int limit = 500,
    String orderByField = 'updatedAt',
    bool descending = true,
  }) async* {
    Query<Map<String, dynamic>> q = _col;

    final v = _s(vendorId);
    if (v.isNotEmpty) q = q.where('vendorId', isEqualTo: v);

    if (!includeInactive) q = q.where('isActive', isEqualTo: true);

    q = q.orderBy(orderByField, descending: descending);
    if (limit > 0) q = q.limit(limit);

    try {
      yield* q.snapshots().map((s) => s.docs.map(_withId).toList());
    } on FirebaseException catch (e) {
      // 索引缺失提示
      if (e.code == 'failed-precondition' && (e.message ?? '').contains('requires an index')) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('[ProductService] Firestore 索引缺失：${e.message}');
        }
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[ProductService] streamProducts error: $e');
      }
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> streamVendorProducts(
    String vendorId, {
    bool includeInactive = true,
    int limit = 500,
  }) {
    final v = _s(vendorId);
    if (v.isEmpty) return const Stream<List<Map<String, dynamic>>>.empty();
    return streamProducts(vendorId: v, includeInactive: includeInactive, limit: limit);
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    final pid = _s(id);
    if (pid.isEmpty) return null;

    try {
      final d = await _col.doc(pid).get();
      if (!d.exists) return null;
      return _withId(d);
    } catch (e) {
      throw ProductException('get_failed', '讀取商品失敗：$e');
    }
  }

  // ------------------------------------------------------------
  // Upsert / Update
  // ------------------------------------------------------------

  Future<void> upsert({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final pid = _s(id);
    if (pid.isEmpty) throw ProductException('invalid_id', '商品 id 不可為空');

    final normalized = _normalizeData(data);

    try {
      final ref = _col.doc(pid);
      final snap = await ref.get();

      final payload = <String, dynamic>{
        ...normalized,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
        'id': pid,
      };

      await ref.set(payload, SetOptions(merge: true));
    } catch (e) {
      throw ProductException('upsert_failed', '儲存商品失敗：$e');
    }
  }

  Future<void> createOrUpdate(String id, Map<String, dynamic> data) => upsert(id: id, data: data);

  Future<void> updateFields(String id, Map<String, dynamic> fields) async {
    final pid = _s(id);
    if (pid.isEmpty) return;

    try {
      await _col.doc(pid).set(
        <String, dynamic>{
          ..._normalizeData(fields),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      throw ProductException('update_failed', '更新商品失敗：$e');
    }
  }

  Map<String, dynamic> _normalizeData(Map<String, dynamic> inData) {
    final data = Map<String, dynamic>.from(inData);

    if (data.containsKey('title')) data['title'] = _s(data['title']);
    if (data.containsKey('price')) {
      final p = _toNum(data['price']);
      data['price'] = p < 0 ? 0 : p;
    }
    if (data.containsKey('isActive')) data['isActive'] = data['isActive'] == true;
    if (data.containsKey('categoryId')) data['categoryId'] = _s(data['categoryId']);
    if (data.containsKey('vendorId')) data['vendorId'] = _s(data['vendorId']);

    final imageUrl = _s(data['imageUrl']);
    if (data['images'] is List) {
      final imgs = List.from(data['images'] as List)
          .map((e) => _s(e))
          .where((e) => e.isNotEmpty)
          .toList();
      data['images'] = imgs;
      if (imgs.isNotEmpty) {
        data['imageUrl'] = imgs.first;
      } else if (imageUrl.isNotEmpty) {
        data['images'] = [imageUrl];
      }
    } else {
      if (imageUrl.isNotEmpty) data['images'] = [imageUrl];
    }

    if (data.containsKey('rating')) {
      final r = data['rating'];
      data['rating'] = r is num ? r : (num.tryParse(_s(r)) ?? 0);
    }

    return data;
  }

  // ------------------------------------------------------------
  // Active toggle
  // ------------------------------------------------------------

  Future<void> toggleActive(String id, bool active) async {
    final pid = _s(id);
    if (pid.isEmpty) return;
    try {
      await _col.doc(pid).set(
        <String, dynamic>{
          'isActive': active,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      throw ProductException('toggle_failed', '切換上架狀態失敗：$e');
    }
  }

  Future<void> setActive(String id, bool active) => toggleActive(id, active);

  Future<void> batchToggleActive(List<String> ids, bool toActive) async {
    final list = ids.map(_s).where((e) => e.isNotEmpty).toList();
    if (list.isEmpty) return;

    const chunk = 450;
    try {
      for (var i = 0; i < list.length; i += chunk) {
        final part = list.sublist(i, (i + chunk).clamp(0, list.length));
        final batch = _db.batch();
        for (final id in part) {
          batch.set(
            _col.doc(id),
            <String, dynamic>{
              'isActive': toActive,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      }
    } catch (e) {
      throw ProductException('batch_toggle_failed', '批次切換上架失敗：$e');
    }
  }

  // ------------------------------------------------------------
  // Delete
  // ------------------------------------------------------------

  Future<void> delete(String id) async {
    final pid = _s(id);
    if (pid.isEmpty) return;
    try {
      await _col.doc(pid).delete();
    } catch (e) {
      throw ProductException('delete_failed', '刪除商品失敗：$e');
    }
  }

  Future<void> deleteProduct(String id) => delete(id);

  /// ✅ 刪除商品（含 Storage 圖片）
  ///
  /// - 會從 Firestore 商品文件讀取：
  ///   - images（List<String>）
  ///   - imageUrl（String）
  /// - 嘗試刪除「可辨識為 Firebase Storage」的 URL / gs://
  /// - 預設就算刪 Storage 失敗，也會刪掉 Firestore 商品（避免卡住）
  Future<void> deleteProductWithImages(
    String id, {
    bool deleteStorageFiles = true,
    bool failOnStorageError = false,
  }) async {
    final pid = _s(id);
    if (pid.isEmpty) return;

    final ref = _col.doc(pid);

    try {
      final snap = await ref.get();
      if (!snap.exists) return;

      final data = snap.data() ?? <String, dynamic>{};

      // 收集 URLs
      final urls = <String>{};
      final images = data['images'];
      if (images is List) {
        for (final x in images) {
          final u = _s(x);
          if (u.isNotEmpty) urls.add(u);
        }
      }
      final imageUrl = _s(data['imageUrl']);
      if (imageUrl.isNotEmpty) urls.add(imageUrl);

      // 先刪 Storage（可選）
      if (deleteStorageFiles && urls.isNotEmpty) {
        final errs = <String>[];

        for (final u in urls) {
          final ok = await _tryDeleteStorageByUrl(u);
          if (!ok) {
            errs.add(u);
          }
        }

        if (errs.isNotEmpty && failOnStorageError) {
          throw ProductException('storage_delete_failed', '部分圖片刪除失敗：${errs.take(3).join(', ')}');
        }
      }

      // 最後刪 Firestore doc
      await ref.delete();
    } catch (e) {
      throw ProductException('delete_with_images_failed', '刪除商品（含圖片）失敗：$e');
    }
  }

  /// 嘗試用 URL/gs:// 推回 Storage ref 並刪除；非 Storage URL 會略過（回傳 false 代表未刪）
  Future<bool> _tryDeleteStorageByUrl(String urlOrGs) async {
    final u = _s(urlOrGs);
    if (u.isEmpty) return false;

    // 只處理 Firebase Storage 來源（refFromURL 支援 gs:// 與 https downloadURL）
    try {
      final Reference r = _storage.refFromURL(u);
      await r.delete();
      return true;
    } catch (e) {
      // 不是 Storage URL 或權限不足或檔案不存在
      if (kDebugMode) {
        // ignore: avoid_print
        print('[ProductService] skip/delete storage failed: $u -> $e');
      }
      return false;
    }
  }

  Future<void> deleteProductWithImagesCompat(String id) => deleteProductWithImages(id);

  Future<void> batchDelete(List<String> ids) async {
    final list = ids.map(_s).where((e) => e.isNotEmpty).toList();
    if (list.isEmpty) return;

    const chunk = 450;
    try {
      for (var i = 0; i < list.length; i += chunk) {
        final part = list.sublist(i, (i + chunk).clamp(0, list.length));
        final batch = _db.batch();
        for (final id in part) {
          batch.delete(_col.doc(id));
        }
        await batch.commit();
      }
    } catch (e) {
      throw ProductException('batch_delete_failed', '批次刪除商品失敗：$e');
    }
  }
}
