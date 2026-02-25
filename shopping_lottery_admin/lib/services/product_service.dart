// lib/services/product_service.dart
//
// ✅ ProductService（可編譯完整版｜補齊缺的方法：deleteProductWithImages 等）
// ------------------------------------------------------------
// ✅ 修正：firebase_storage 某些版本沒有 ref.putStream()
//      => uploadProductStream 改成：先把 Stream<List<int>> 收集成 bytes，再 ref.putData()
// ------------------------------------------------------------
//
// 目標：讓以下頁面不再報 undefined_method：
// - product_admin_page.dart: deleteProductWithImages
// - admin_products_page_full.dart: streamProducts / toggleActive / deleteProductWithImages
// - new_product_dialog.dart: uploadProductBytes / uploadProductStream / upsert / appendProductImages
//                           updateImageOrder / setPrimaryImage / removeProductImage
//
// Firestore schema（建議）:
// products/{productId}
// - id: String
// - title: String
// - price: num
// - vendorId: String
// - categoryId: String
// - isActive: bool
// - imageUrl: String (主圖 url)
// - primaryImage: {url, path}
// - images: [ String(url) | {url, path} ]
// - updatedAt, createdAt: Timestamp
//
// Storage schema（建議）:
// /products/{productId}/{timestamp}_{filename}

import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProductService {
  ProductService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _db = firestore ?? FirebaseFirestore.instance,
      _st = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _st;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('products');

  String _s(dynamic v) => (v ?? '').toString().trim();

  // ------------------------------------------------------------
  // Stream: all products -> List<Map>
  // ------------------------------------------------------------
  Stream<List<Map<String, dynamic>>> streamProducts({int limit = 500}) {
    return _col
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
          return snap.docs.map((d) {
            // ⚠️ d.data() 回來的 Map 可能被重用；這裡複製一份避免副作用
            final m = Map<String, dynamic>.from(d.data());

            // 確保 map 內有 id（優先用欄位 id，沒有就用 docId）
            final id = _s(m['id']).isNotEmpty ? _s(m['id']) : d.id;

            // 確保 imageUrl（若缺就從 primary/images 推導）
            final mainUrl = _pickMainImageUrl(m);
            if (_s(m['imageUrl']).isEmpty && mainUrl.isNotEmpty) {
              m['imageUrl'] = mainUrl;
            }

            return {...m, 'id': id, '_docId': d.id};
          }).toList();
        });
  }

  String _pickMainImageUrl(Map<String, dynamic> m) {
    final primary = m['primaryImage'];
    if (primary is Map) {
      final u = _s(primary['url']);
      if (u.isNotEmpty) return u;
    }

    final u0 = _s(m['imageUrl']);
    if (u0.isNotEmpty) return u0;

    final imgs = m['images'];
    if (imgs is List && imgs.isNotEmpty) {
      final first = imgs.first;
      if (first is String) return _s(first);
      if (first is Map) return _s(first['url']);
    }
    return '';
  }

  // ------------------------------------------------------------
  // Upsert product
  // ------------------------------------------------------------
  Future<void> upsert({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final pid = id.trim();
    if (pid.isEmpty) throw Exception('productId is empty');

    final payload = <String, dynamic>{
      ...data,
      'id': pid,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // createdAt：只在「呼叫者有提供」才寫入；避免每次 upsert 都誤蓋
    if (!payload.containsKey('createdAt')) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await _col.doc(pid).set(payload, SetOptions(merge: true));
  }

  // ------------------------------------------------------------
  // Toggle active
  // ------------------------------------------------------------
  Future<void> toggleActive(String productId, bool isActive) async {
    final pid = productId.trim();
    if (pid.isEmpty) throw Exception('productId is empty');

    await _col.doc(pid).set({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ------------------------------------------------------------
  // Upload helpers
  // ------------------------------------------------------------
  String _safeFileName(String name) {
    final n = name.trim();
    if (n.isEmpty) return 'file';
    // 避免奇怪字元
    return n.replaceAll(RegExp(r'[^\w\.\-\(\)\[\]\s]'), '_');
  }

  String _buildStoragePath(String productId, String filename) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'products/$productId/${ts}_${_safeFileName(filename)}';
  }

  Future<Map<String, String>> uploadProductBytes({
    required String productId,
    required Uint8List bytes,
    required String filename,
    void Function(double progress)? onProgress,
    String? contentType,
  }) async {
    final pid = productId.trim();
    if (pid.isEmpty) throw Exception('productId is empty');

    final path = _buildStoragePath(pid, filename);
    final ref = _st.ref(path);

    final meta = SettableMetadata(
      contentType: contentType, // 可為 null
      customMetadata: {'productId': pid},
    );

    final task = ref.putData(bytes, meta);

    StreamSubscription<TaskSnapshot>? sub;
    if (onProgress != null) {
      sub = task.snapshotEvents.listen((snap) {
        final total = snap.totalBytes;
        final sent = snap.bytesTransferred;
        if (total > 0) onProgress(sent / total);
      });
    }

    final snap = await task.whenComplete(() {});
    await sub?.cancel();

    final url = await snap.ref.getDownloadURL();
    return {'url': url, 'path': path};
  }

  /// ✅ 兼容版本：不使用 ref.putStream（有些 firebase_storage 版本沒有）
  /// 改用：先把 openStream 收集成 bytes → ref.putData
  Future<Map<String, String>> uploadProductStream({
    required String productId,
    required Stream<List<int>> Function() openStream,
    required String filename,
    void Function(double progress)? onProgress,
    String? contentType,
  }) async {
    final pid = productId.trim();
    if (pid.isEmpty) throw Exception('productId is empty');

    final path = _buildStoragePath(pid, filename);
    final ref = _st.ref(path);

    // 先把 stream 收集成 bytes（避免 putStream）
    final bb = BytesBuilder(copy: false);
    await for (final chunk in openStream()) {
      bb.add(chunk);
    }
    final bytes = bb.takeBytes(); // Uint8List

    final meta = SettableMetadata(
      contentType: contentType,
      customMetadata: {'productId': pid},
    );

    final task = ref.putData(bytes, meta);

    StreamSubscription<TaskSnapshot>? sub;
    if (onProgress != null) {
      sub = task.snapshotEvents.listen((snap) {
        final total = snap.totalBytes;
        final sent = snap.bytesTransferred;
        if (total > 0) onProgress(sent / total);
      });
    }

    final snap = await task.whenComplete(() {});
    await sub?.cancel();

    final url = await snap.ref.getDownloadURL();
    return {'url': url, 'path': path};
  }

  // ------------------------------------------------------------
  // Images ops
  // ------------------------------------------------------------
  Future<void> appendProductImages(
    String productId,
    List<Map<String, String>> images, {
    bool setPrimaryIfEmpty = true,
  }) async {
    final pid = productId.trim();
    if (pid.isEmpty) throw Exception('productId is empty');
    if (images.isEmpty) return;

    final ref = _col.doc(pid);
    final doc = await ref.get();
    final m = doc.data() ?? <String, dynamic>{};

    final oldList = (m['images'] is List)
        ? List.from(m['images'] as List)
        : <dynamic>[];

    final addList = images
        .map(
          (e) => <String, dynamic>{
            'url': e['url'] ?? '',
            'path': e['path'] ?? '',
          },
        )
        .where((e) => _s(e['url']).isNotEmpty)
        .toList();

    // 合併（避免 url 重複）
    final seen = <String>{};
    final merged = <dynamic>[];

    void push(dynamic item) {
      if (item is String) {
        final u = _s(item);
        if (u.isEmpty || seen.contains(u)) return;
        seen.add(u);
        merged.add(u);
      } else if (item is Map) {
        final u = _s(item['url']);
        if (u.isEmpty || seen.contains(u)) return;
        seen.add(u);
        merged.add({'url': u, 'path': _s(item['path'])});
      }
    }

    for (final it in oldList) {
      push(it);
    }
    for (final it in addList) {
      push(it);
    }

    final payload = <String, dynamic>{
      'images': merged,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 若沒有主圖，補主圖
    final existingPrimary = (m['primaryImage'] is Map)
        ? Map<String, dynamic>.from(m['primaryImage'] as Map)
        : null;
    final existingImageUrl = _s(m['imageUrl']);

    if (setPrimaryIfEmpty) {
      if ((existingPrimary == null || _s(existingPrimary['url']).isEmpty) &&
          existingImageUrl.isEmpty) {
        final first = merged.isEmpty ? null : merged.first;
        if (first is String) {
          payload['imageUrl'] = first;
          payload['primaryImage'] = {'url': first, 'path': ''};
        } else if (first is Map) {
          final u = _s(first['url']);
          final p = _s(first['path']);
          if (u.isNotEmpty) {
            payload['imageUrl'] = u;
            payload['primaryImage'] = {'url': u, 'path': p};
          }
        }
      }
    }

    await ref.set(payload, SetOptions(merge: true));
  }

  Future<void> setPrimaryImage(
    String productId, {
    required String url,
    String? path,
  }) async {
    final pid = productId.trim();
    final u = url.trim();
    if (pid.isEmpty) throw Exception('productId is empty');
    if (u.isEmpty) throw Exception('url is empty');

    await _col.doc(pid).set({
      'primaryImage': {'url': u, 'path': _s(path)},
      'imageUrl': u,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateImageOrder(
    String productId,
    List<String> urlsOrder,
  ) async {
    final pid = productId.trim();
    if (pid.isEmpty) throw Exception('productId is empty');

    final ref = _col.doc(pid);
    final doc = await ref.get();
    final m = doc.data() ?? <String, dynamic>{};

    final imgs = (m['images'] is List)
        ? List.from(m['images'] as List)
        : <dynamic>[];
    if (imgs.isEmpty || urlsOrder.isEmpty) return;

    // 建 index: url -> item
    final map = <String, dynamic>{};
    for (final it in imgs) {
      if (it is String) {
        final u = _s(it);
        if (u.isNotEmpty) map[u] = it;
      } else if (it is Map) {
        final u = _s(it['url']);
        if (u.isNotEmpty) {
          map[u] = {'url': u, 'path': _s(it['path'])};
        }
      }
    }

    final newList = <dynamic>[];
    final used = <String>{};

    // 先依指定順序
    for (final u0 in urlsOrder) {
      final u = _s(u0);
      if (u.isEmpty) continue;
      final it = map[u];
      if (it == null) continue;
      if (used.contains(u)) continue;
      used.add(u);
      newList.add(it);
    }

    // 再補上剩餘
    for (final entry in map.entries) {
      if (used.contains(entry.key)) continue;
      newList.add(entry.value);
    }

    final payload = <String, dynamic>{
      'images': newList,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 主圖跟著第一張
    final first = newList.isEmpty ? null : newList.first;
    if (first is String) {
      payload['imageUrl'] = first;
      payload['primaryImage'] = {'url': first, 'path': ''};
    } else if (first is Map) {
      final u = _s(first['url']);
      final p = _s(first['path']);
      if (u.isNotEmpty) {
        payload['imageUrl'] = u;
        payload['primaryImage'] = {'url': u, 'path': p};
      }
    }

    await ref.set(payload, SetOptions(merge: true));
  }

  Future<void> removeProductImage({
    required String productId,
    required String imageUrl,
    String? storagePath,
  }) async {
    final pid = productId.trim();
    final u = imageUrl.trim();
    if (pid.isEmpty) throw Exception('productId is empty');
    if (u.isEmpty) return;

    final ref = _col.doc(pid);
    final doc = await ref.get();
    final m = doc.data() ?? <String, dynamic>{};

    final imgs = (m['images'] is List)
        ? List.from(m['images'] as List)
        : <dynamic>[];
    if (imgs.isEmpty) return;

    final newList = <dynamic>[];
    for (final it in imgs) {
      if (it is String) {
        if (_s(it) == u) continue;
        newList.add(it);
      } else if (it is Map) {
        if (_s(it['url']) == u) continue;
        newList.add({'url': _s(it['url']), 'path': _s(it['path'])});
      }
    }

    // 如果主圖就是被刪的那張，改成第一張
    final primary = (m['primaryImage'] is Map)
        ? Map<String, dynamic>.from(m['primaryImage'] as Map)
        : null;
    final primaryUrl = _s(primary?['url']);
    final imageUrlField = _s(m['imageUrl']);

    final payload = <String, dynamic>{
      'images': newList,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final needResetPrimary = (primaryUrl == u) || (imageUrlField == u);
    if (needResetPrimary) {
      final first = newList.isEmpty ? null : newList.first;
      if (first is String) {
        payload['imageUrl'] = first;
        payload['primaryImage'] = {'url': first, 'path': ''};
      } else if (first is Map) {
        final fu = _s(first['url']);
        final fp = _s(first['path']);
        if (fu.isNotEmpty) {
          payload['imageUrl'] = fu;
          payload['primaryImage'] = {'url': fu, 'path': fp};
        } else {
          payload['imageUrl'] = '';
          payload['primaryImage'] = {'url': '', 'path': ''};
        }
      } else {
        payload['imageUrl'] = '';
        payload['primaryImage'] = {'url': '', 'path': ''};
      }
    }

    await ref.set(payload, SetOptions(merge: true));

    // 刪 Storage（如果有 path）
    final p = _s(storagePath);
    if (p.isNotEmpty) {
      try {
        await _st.ref(p).delete();
      } catch (_) {
        // 忽略：可能檔案已不存在或權限不足
      }
    }
  }

  // ------------------------------------------------------------
  // Delete product + images in storage
  // ------------------------------------------------------------
  Future<void> deleteProductWithImages(String productId) async {
    final pid = productId.trim();
    if (pid.isEmpty) throw Exception('productId is empty');

    final ref = _col.doc(pid);
    final doc = await ref.get();

    if (!doc.exists) {
      await ref.delete().catchError((_) {});
      return;
    }

    final m = doc.data() ?? <String, dynamic>{};
    final imgs = (m['images'] is List)
        ? List.from(m['images'] as List)
        : <dynamic>[];

    // 收集 storage paths（若有）
    final paths = <String>{};

    // primaryImage
    final primary = m['primaryImage'];
    if (primary is Map) {
      final p = _s(primary['path']);
      if (p.isNotEmpty) paths.add(p);
    }

    // images list
    for (final it in imgs) {
      if (it is Map) {
        final p = _s(it['path']);
        if (p.isNotEmpty) paths.add(p);
      }
    }

    // 刪 storage 檔案
    for (final p in paths) {
      try {
        await _st.ref(p).delete();
      } catch (_) {
        // ignore
      }
    }

    // 刪 firestore doc
    await ref.delete();
  }

  // （可選）只刪 doc 不刪圖
  Future<void> deleteProductDocOnly(String productId) async {
    final pid = productId.trim();
    if (pid.isEmpty) return;
    await _col.doc(pid).delete();
  }
}
