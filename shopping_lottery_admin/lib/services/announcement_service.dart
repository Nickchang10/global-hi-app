// lib/services/announcement_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementService {
  final FirebaseFirestore _db;
  AnnouncementService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('announcements');

  /// 讀取全部公告（後台用）：
  /// - 為了避免需要複合 index，這裡只 orderBy createdAt
  /// - priority / 其他排序交給前端處理
  Stream<List<Map<String, dynamic>>> streamAll() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map((d) => {'id': d.id, ...?d.data()}).toList());
  }

  Future<List<Map<String, dynamic>>> getAllOnce() async {
    final snap = await _col.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => {'id': d.id, ...?d.data()}).toList();
  }

  DocumentReference<Map<String, dynamic>> doc(String id) => _col.doc(id);

  Future<String> create({
    required String title,
    required String content,
    required bool isActive,
    required int priority,
    required String targetRole, // all / admin / vendor
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    final now = FieldValue.serverTimestamp();
    final ref = await _col.add({
      'title': title.trim(),
      'content': content.trim(),
      'isActive': isActive,
      'priority': priority,
      'targetRole': targetRole.trim().isEmpty ? 'all' : targetRole.trim(),
      'startAt': startAt == null ? null : Timestamp.fromDate(startAt),
      'endAt': endAt == null ? null : Timestamp.fromDate(endAt),
      'createdAt': now,
      'updatedAt': now,
    });
    return ref.id;
  }

  Future<void> update({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    await _col.doc(id).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> toggleActive(String id, bool v) async {
    await update(id: id, data: {'isActive': v});
  }

  /// 可選：初始化範例公告（第一次專案可用）
  Future<void> ensureDefaultAnnouncements() async {
    final snap = await _col.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    await create(
      title: '系統公告：歡迎使用後台',
      content: '這是一則範例公告。你可以在後台新增/編輯/停用公告。',
      isActive: true,
      priority: 10,
      targetRole: 'all',
      startAt: DateTime.now().subtract(const Duration(days: 1)),
      endAt: DateTime.now().add(const Duration(days: 30)),
    );
  }
}
