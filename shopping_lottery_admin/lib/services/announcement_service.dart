// lib/services/announcement_service.dart
//
// ✅ AnnouncementService（公告服務｜可編譯完整版｜修正 ...?... 警告）
// ------------------------------------------------------------
// Firestore collection: announcements
//
// 建議欄位（可擴充）：
// - title: String
// - body: String
// - category: String (optional)
// - pinned: bool
// - priority: int (0~100)
// - targetRoles: List<String> 例如 ['admin','vendor','user']
// - targetVendorIds: List<String>（可選）
// - startAt: Timestamp?（可選）
// - endAt: Timestamp?（可選）
// - status: String ('draft'|'published'|'archived')
// - createdAt / updatedAt: Timestamp
// - createdBy: String
//
// ✅ 本檔不依賴你的其他 model 檔案，直接可用。

import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String id;
  final String title;
  final String body;

  final String category;
  final bool pinned;
  final int priority;

  /// ✅ 非 nullable，避免 ...?... 的警告源頭
  final List<String> targetRoles;
  final List<String> targetVendorIds;

  final DateTime? startAt;
  final DateTime? endAt;

  /// 'draft' | 'published' | 'archived'
  final String status;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.category = '',
    this.pinned = false,
    this.priority = 0,
    this.targetRoles = const [],
    this.targetVendorIds = const [],
    this.startAt,
    this.endAt,
    this.status = 'published',
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
  });

  bool get isPublished => status.toLowerCase() == 'published';

  bool get isActiveNow {
    final now = DateTime.now();
    if (!isPublished) return false;
    if (startAt != null && now.isBefore(startAt!)) return false;
    if (endAt != null && now.isAfter(endAt!)) return false;
    return true;
  }

  static String _s(dynamic v) => (v ?? '').toString().trim();
  static bool _b(dynamic v) => v is bool ? v : _s(v).toLowerCase() == 'true';

  static int _i(dynamic v, {int def = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(_s(v)) ?? def;
  }

  static DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static List<String> _stringList(dynamic v) {
    if (v is List) {
      return v
          .map((e) => (e ?? '').toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  factory Announcement.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return Announcement(
      id: doc.id,
      title: _s(data['title']),
      body: _s(data['body']).isNotEmpty
          ? _s(data['body'])
          : _s(data['content']),
      category: _s(data['category']),
      pinned: _b(data['pinned']),
      priority: _i(data['priority']),
      targetRoles: _stringList(data['targetRoles']),
      targetVendorIds: _stringList(data['targetVendorIds']),
      startAt: _toDate(data['startAt']),
      endAt: _toDate(data['endAt']),
      status: _s(data['status']).isEmpty ? 'published' : _s(data['status']),
      createdAt: _toDate(data['createdAt']),
      updatedAt: _toDate(data['updatedAt']),
      createdBy: _s(data['createdBy']),
    );
  }

  Map<String, dynamic> toJsonForWrite() {
    // ✅ 修正點：targetRoles/targetVendorIds 都是非 nullable list
    // 所以只用 ...list，不要用 ...?list
    return <String, dynamic>{
      'title': title,
      'body': body,
      if (category.isNotEmpty) 'category': category,
      'pinned': pinned,
      'priority': priority,
      'targetRoles': <String>[...targetRoles],
      'targetVendorIds': <String>[...targetVendorIds],
      if (startAt != null) 'startAt': Timestamp.fromDate(startAt!),
      if (endAt != null) 'endAt': Timestamp.fromDate(endAt!),
      'status': status,
      if (createdBy.isNotEmpty) 'createdBy': createdBy,
    };
  }

  Announcement copyWith({
    String? title,
    String? body,
    String? category,
    bool? pinned,
    int? priority,
    List<String>? targetRoles,
    List<String>? targetVendorIds,
    DateTime? startAt,
    DateTime? endAt,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Announcement(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      pinned: pinned ?? this.pinned,
      priority: priority ?? this.priority,
      targetRoles: targetRoles ?? this.targetRoles,
      targetVendorIds: targetVendorIds ?? this.targetVendorIds,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

class AnnouncementService {
  final FirebaseFirestore _db;
  AnnouncementService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('announcements');

  /// 列表：預設只回傳 published（可用 includeDraft/includeArchived 開）
  Stream<List<Announcement>> streamAnnouncements({
    int limit = 50,
    bool includeDraft = false,
    bool includeArchived = false,
  }) {
    // ⚠️ Firestore 無法用 whereIn 太多狀態組合；用最簡單策略：
    // - 若 includeDraft/includeArchived 都 false：只抓 published
    // - 否則抓全部，回 client 端 filter（避免複雜索引）
    Query<Map<String, dynamic>> q = _col
        .orderBy('updatedAt', descending: true)
        .limit(limit);

    if (!includeDraft && !includeArchived) {
      q = q.where('status', isEqualTo: 'published');
    }

    return q.snapshots().map((snap) {
      final all = snap.docs.map(Announcement.fromDoc).toList();

      if (!includeDraft && !includeArchived) return all;

      return all.where((a) {
        final s = a.status.toLowerCase();
        if (s == 'draft' && !includeDraft) return false;
        if (s == 'archived' && !includeArchived) return false;
        return true;
      }).toList();
    });
  }

  /// 依角色/廠商過濾（前台顯示常用）
  Stream<List<Announcement>> streamForAudience({
    required String role, // 'admin'|'vendor'|'user'
    String vendorId = '',
    int limit = 50,
    bool onlyActiveNow = true,
  }) {
    final r = role.trim().toLowerCase();
    final vid = vendorId.trim();

    // 這裡先以 published 為主，避免額外索引
    final q = _col
        .where('status', isEqualTo: 'published')
        .orderBy('updatedAt', descending: true)
        .limit(limit);

    return q.snapshots().map((snap) {
      final items = snap.docs.map(Announcement.fromDoc).toList();

      return items.where((a) {
        if (onlyActiveNow && !a.isActiveNow) return false;

        // role 目標
        if (a.targetRoles.isNotEmpty &&
            !a.targetRoles.map((e) => e.toLowerCase()).contains(r)) {
          return false;
        }

        // vendor 目標
        if (vid.isNotEmpty &&
            a.targetVendorIds.isNotEmpty &&
            !a.targetVendorIds.contains(vid)) {
          return false;
        }

        return true;
      }).toList()..sort((x, y) {
        // pinned > priority > updatedAt
        if (x.pinned != y.pinned) return x.pinned ? -1 : 1;
        if (x.priority != y.priority) return y.priority.compareTo(x.priority);
        final xt = x.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final yt = y.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return yt.compareTo(xt);
      });
    });
  }

  Future<Announcement?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return Announcement.fromDoc(doc);
  }

  Future<String> create({
    required String title,
    required String body,
    String category = '',
    bool pinned = false,
    int priority = 0,
    List<String> targetRoles = const [],
    List<String> targetVendorIds = const [],
    DateTime? startAt,
    DateTime? endAt,
    String status = 'published',
    String createdBy = '',
  }) async {
    final now = FieldValue.serverTimestamp();

    final ann = Announcement(
      id: '',
      title: title.trim(),
      body: body.trim(),
      category: category.trim(),
      pinned: pinned,
      priority: priority,
      targetRoles: targetRoles,
      targetVendorIds: targetVendorIds,
      startAt: startAt,
      endAt: endAt,
      status: status.trim().isEmpty ? 'published' : status.trim(),
      createdBy: createdBy.trim(),
    );

    final ref = await _col.add({
      ...ann.toJsonForWrite(),
      'createdAt': now,
      'updatedAt': now,
    });

    return ref.id;
  }

  Future<void> update(String id, Announcement data) async {
    await _col.doc(id).set({
      ...data.toJsonForWrite(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setStatus(String id, String status) async {
    await _col.doc(id).set({
      'status': status.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
