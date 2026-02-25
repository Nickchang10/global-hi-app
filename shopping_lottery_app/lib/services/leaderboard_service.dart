// lib/services/leaderboard_service.dart
//
// ✅ LeaderboardService（正式版｜完整版｜可直接編譯）
// ----------------------------------------------------
// ✅ 移除 FirestoreMockService.instance（你目前錯誤來源）
// ✅ 使用 FirebaseFirestore.instance / FirebaseAuth.instance
// ✅ 排行榜資料來源：預設用 users.points（最穩、最少資料結構依賴）
//
// 需要套件：cloud_firestore, firebase_auth
// ----------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeaderboardService {
  LeaderboardService._({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static final LeaderboardService instance = LeaderboardService._();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const String usersCol = 'users';
  static const String leaderboardsCol = 'leaderboards';

  String? get currentUid => _auth.currentUser?.uid;

  /// ✅ 監聽即時排行榜（依 points 由大到小）
  Stream<List<LeaderboardRow>> watchLeaderboard({int limit = 20}) {
    return _db
        .collection(usersCol)
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(_rowFromDoc).toList(growable: false));
  }

  /// ✅ 一次性讀取排行榜
  Future<List<LeaderboardRow>> getLeaderboardOnce({int limit = 20}) async {
    final snap = await _db
        .collection(usersCol)
        .orderBy('points', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map(_rowFromDoc).toList(growable: false);
  }

  /// ✅ 取得我的排行資訊（如果不在前 N 名，仍可查到自己）
  Future<LeaderboardRow?> getMyRow() async {
    final uid = currentUid;
    if (uid == null) return null;

    final doc = await _db.collection(usersCol).doc(uid).get();
    if (!doc.exists) return null;
    return _rowFromDoc(doc);
  }

  /// ✅ 更新自己的 points（增量）
  Future<void> updateMyPoints(int delta) async {
    final uid = currentUid;
    if (uid == null) throw StateError('User not logged in');

    await _db.collection(usersCol).doc(uid).set({
      'points': FieldValue.increment(delta),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ✅ 把某期（週/月）排行榜快照保存下來（可給後台報表/結算用）
  ///
  /// 結構：
  /// leaderboards/{boardId}/periods/{periodKey}/entries/{uid}
  Future<void> snapshotLeaderboard({
    required String boardId,
    required String periodKey,
    int limit = 50,
  }) async {
    final top = await getLeaderboardOnce(limit: limit);

    final root = _db
        .collection(leaderboardsCol)
        .doc(boardId)
        .collection('periods')
        .doc(periodKey);

    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();

    // period metadata
    batch.set(root, {
      'boardId': boardId,
      'periodKey': periodKey,
      'limit': limit,
      'createdAt': now,
    }, SetOptions(merge: true));

    for (var i = 0; i < top.length; i++) {
      final rank = i + 1;
      final r = top[i];

      final ref = root.collection('entries').doc(r.uid);
      batch.set(ref, {
        'uid': r.uid,
        'displayName': r.displayName,
        'points': r.points,
        'rank': rank,
        'photoUrl': r.photoUrl,
        'updatedAt': now,
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  // ---------- internal ----------

  LeaderboardRow _rowFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return LeaderboardRow(
      uid: doc.id,
      displayName: (d['displayName'] ?? d['name'] ?? '會員').toString(),
      photoUrl: d['photoUrl']?.toString(),
      points: _asInt(d['points']),
      role: (d['role'] ?? 'user').toString(),
    );
  }

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}

class LeaderboardRow {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final int points;
  final String role;

  const LeaderboardRow({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    required this.points,
    required this.role,
  });
}
