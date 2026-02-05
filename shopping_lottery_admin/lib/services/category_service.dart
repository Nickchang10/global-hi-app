// lib/services/category_service.dart
//
// ✅ CategoryService（完整版・可編譯強化版）
//
// 目標：提供 ProductsPage / AdminCategoriesPage 需要的完整能力，並相容常見命名。
// - streamCategories(): 即時監聽分類（可包含停用）
// - upsert(id,data): 新增/更新分類
// - toggleActive(id,bool): 啟用/停用
// - delete(id): 刪除分類
// - ensureDefaults(): 建立/補齊預設分類（可選）
// - getById(id): 讀取單一分類（可選）
//
// Firestore: categories/{categoryId}
// fields（建議）:
// - id: String（可選，通常與 docId 相同）
// - name: String
// - sort: num（數字越小越前）
// - isActive: bool
// - createdAt: Timestamp
// - updatedAt: Timestamp
//
// 注意：
// - orderBy('sort') 對舊資料 sort 為 null 也能跑（null 會排在前/後依 Firestore 行為）
// - 若你想嚴格避免 null sort，可在 ensureDefaults / upsert 時補上 sort

import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryException implements Exception {
  final String code;
  final String message;
  CategoryException(this.code, this.message);

  @override
  String toString() => 'CategoryException($code): $message';
}

class CategoryService {
  CategoryService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('categories');

  String _s(dynamic v) => (v ?? '').toString().trim();

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(_s(v)) ?? 0;
  }

  bool _toBool(dynamic v, {bool fallback = true}) {
    if (v is bool) return v;
    final s = _s(v).toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return fallback;
  }

  Map<String, dynamic> _withId(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    return <String, dynamic>{...m, 'id': d.id};
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> inData) {
    final data = Map<String, dynamic>.from(inData);

    if (data.containsKey('name')) data['name'] = _s(data['name']);
    if (data.containsKey('sort')) data['sort'] = _toNum(data['sort']);
    if (data.containsKey('isActive')) data['isActive'] = _toBool(data['isActive'], fallback: true);

    // 讓 doc 內也可帶 id（非必要，但方便 debug / query）
    if (data.containsKey('id')) {
      data['id'] = _s(data['id']);
    }

    return data;
  }

  // ------------------------------------------------------------
  // Streams / Read
  // ------------------------------------------------------------

  /// ✅ 即時監聽分類
  /// - includeInactive=true：包含停用
  /// - includeInactive=false：只回傳 isActive==true
  Stream<List<Map<String, dynamic>>> streamCategories({
    bool includeInactive = true,
    int limit = 500,
  }) {
    Query<Map<String, dynamic>> q = _col;

    if (!includeInactive) {
      q = q.where('isActive', isEqualTo: true);
    }

    // 建議排序：sort 小到大，再用 updatedAt/createdAt 作次排序
    // updatedAt 若為 null 也不會報錯
    q = q.orderBy('sort', descending: false).orderBy('updatedAt', descending: true);

    if (limit > 0) q = q.limit(limit);

    return q.snapshots().map((s) => s.docs.map(_withId).toList());
  }

  /// ✅ 讀取單一分類（可選）
  Future<Map<String, dynamic>?> getById(String id) async {
    final cid = _s(id);
    if (cid.isEmpty) return null;
    try {
      final d = await _col.doc(cid).get();
      if (!d.exists) return null;
      return _withId(d);
    } catch (e) {
      throw CategoryException('get_failed', '讀取分類失敗：$e');
    }
  }

  // ------------------------------------------------------------
  // Upsert / Update
  // ------------------------------------------------------------

  /// ✅ 新增/更新分類
  /// - docId = id
  /// - 自動補 createdAt/updatedAt
  Future<void> upsert({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final cid = _s(id);
    if (cid.isEmpty) throw CategoryException('invalid_id', '分類 id 不可為空');

    final normalized = _normalize(data);

    try {
      final ref = _col.doc(cid);
      final snap = await ref.get();

      final payload = <String, dynamic>{
        ...normalized,
        'id': cid,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
        // 若外部未傳 isActive，預設 true（避免新增後看不到）
        if (!normalized.containsKey('isActive')) 'isActive': true,
        if (!normalized.containsKey('sort')) 'sort': 0,
      };

      await ref.set(payload, SetOptions(merge: true));
    } catch (e) {
      throw CategoryException('upsert_failed', '儲存分類失敗：$e');
    }
  }

  /// ✅ 相容命名：createOrUpdate
  Future<void> createOrUpdate(String id, Map<String, dynamic> data) =>
      upsert(id: id, data: data);

  /// ✅ 更新部分欄位
  Future<void> updateFields(String id, Map<String, dynamic> fields) async {
    final cid = _s(id);
    if (cid.isEmpty) return;

    try {
      await _col.doc(cid).set(
        <String, dynamic>{
          ..._normalize(fields),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      throw CategoryException('update_failed', '更新分類失敗：$e');
    }
  }

  // ------------------------------------------------------------
  // Active toggle
  // ------------------------------------------------------------

  /// ✅ 啟用/停用
  Future<void> toggleActive(String id, bool active) async {
    final cid = _s(id);
    if (cid.isEmpty) return;

    try {
      await _col.doc(cid).set(
        <String, dynamic>{
          'isActive': active,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      throw CategoryException('toggle_failed', '切換啟用狀態失敗：$e');
    }
  }

  /// ✅ 相容命名：setActive
  Future<void> setActive(String id, bool active) => toggleActive(id, active);

  // ------------------------------------------------------------
  // Delete
  // ------------------------------------------------------------

  Future<void> delete(String id) async {
    final cid = _s(id);
    if (cid.isEmpty) return;

    try {
      await _col.doc(cid).delete();
    } catch (e) {
      throw CategoryException('delete_failed', '刪除分類失敗：$e');
    }
  }

  /// ✅ 相容命名：deleteCategory
  Future<void> deleteCategory(String id) => delete(id);

  // ------------------------------------------------------------
  // Defaults
  // ------------------------------------------------------------

  /// ✅ 建立/補齊預設分類（可自行調整）
  /// - 不會覆蓋既有分類（merge + exists check）
  Future<void> ensureDefaults() async {
    const defaults = <Map<String, dynamic>>[
      {'id': 'all', 'name': '全部', 'sort': -999, 'isActive': true}, // 可選：若你不想寫入可刪
      {'id': 'watch', 'name': '手錶', 'sort': 10, 'isActive': true},
      {'id': 'accessory', 'name': '配件', 'sort': 20, 'isActive': true},
      {'id': 'service', 'name': '服務', 'sort': 30, 'isActive': true},
      {'id': 'voucher', 'name': '代金券', 'sort': 40, 'isActive': true},
    ];

    try {
      final batch = _db.batch();

      for (final c in defaults) {
        final id = _s(c['id']);
        if (id.isEmpty) continue;

        final ref = _col.doc(id);
        final snap = await ref.get();

        // 已存在就不動（避免覆蓋你後台改的 name/sort）
        if (snap.exists) continue;

        batch.set(
          ref,
          <String, dynamic>{
            'id': id,
            'name': _s(c['name']),
            'sort': _toNum(c['sort']),
            'isActive': _toBool(c['isActive'], fallback: true),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    } catch (e) {
      throw CategoryException('ensure_defaults_failed', '建立預設分類失敗：$e');
    }
  }
}
