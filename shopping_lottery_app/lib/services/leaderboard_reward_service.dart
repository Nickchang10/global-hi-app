// lib/services/leaderboard_reward_service.dart
//
// ✅ LeaderboardRewardService（排行榜獎勵服務｜可編譯完整版）
// ------------------------------------------------------------
// ✅ 修正重點：
// - _auth 會被使用（不再 unused_field）
// - 不依賴 MockService
// - 以 users/{uid}/leaderboard_reward_history 管理獎勵紀錄
// - 領取流程 runTransaction：claimed=true + claimedAt
//
// Firestore 建議結構：
// users/{uid}/leaderboard_reward_history/{historyId}
//   - seasonId: String (optional)
//   - seasonName: String (optional)
//   - rank: num (optional)
//   - rewardTitle: String (optional)
//   - rewardType: String (optional)  // coupon / points / gift / ...
//   - rewardValue: num (optional)
//   - claimed: bool (optional)
//   - claimedAt: Timestamp (optional)
//   - createdAt: Timestamp (optional)
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeaderboardRewardService {
  LeaderboardRewardService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _fs = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth; // ✅ 會被使用（currentUser / uid）
  final FirebaseFirestore _fs;

  // ----------------------------
  // Auth helpers（確保 _auth 有用到）
  // ----------------------------

  User? get currentUser => _auth.currentUser;

  String? get currentUid => _auth.currentUser?.uid;

  String requireUid([String? uid]) {
    final v = uid ?? currentUid;
    if (v == null || v.isEmpty) {
      throw StateError('User not logged in (uid is null)');
    }
    return v;
  }

  // ----------------------------
  // Firestore refs
  // ----------------------------

  CollectionReference<Map<String, dynamic>> _histCol(String uid) =>
      _fs.collection('users').doc(uid).collection('leaderboard_reward_history');

  DocumentReference<Map<String, dynamic>> _histDoc(
    String uid,
    String historyId,
  ) => _histCol(uid).doc(historyId);

  // ----------------------------
  // Public APIs
  // ----------------------------

  /// 監聽我的排行榜獎勵紀錄（預設用 docId desc，避免欄位不存在導致 orderBy 失敗）
  Stream<List<LeaderboardRewardHistory>> watchMyHistory({
    String? uid,
    int limit = 200,
  }) {
    final u = requireUid(uid);
    return _histCol(u)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit)
        .snapshots()
        .map((qs) => qs.docs.map(LeaderboardRewardHistory.fromDoc).toList());
  }

  /// 讀取一次（不監聽）
  Future<List<LeaderboardRewardHistory>> fetchMyHistory({
    String? uid,
    int limit = 200,
  }) async {
    final u = requireUid(uid);
    final qs = await _histCol(
      u,
    ).orderBy(FieldPath.documentId, descending: true).limit(limit).get();
    return qs.docs.map(LeaderboardRewardHistory.fromDoc).toList();
  }

  /// 寫入一筆「獎勵紀錄」到 users/{uid}/leaderboard_reward_history
  /// - 若你要固定 historyId，可傳入 historyId；否則自動產生
  Future<String> addHistory({
    String? uid,
    String? historyId,
    String seasonId = '',
    String seasonName = '',
    int rank = 0,
    String rewardTitle = '',
    String rewardType = '',
    num rewardValue = 0,
    bool claimed = false,
    DateTime? createdAt,
    DateTime? claimedAt,
  }) async {
    final u = requireUid(uid);

    final doc = (historyId == null || historyId.trim().isEmpty)
        ? _histCol(u).doc()
        : _histCol(u).doc(historyId.trim());

    await doc.set({
      'seasonId': seasonId,
      'seasonName': seasonName,
      'rank': rank,
      'rewardTitle': rewardTitle,
      'rewardType': rewardType,
      'rewardValue': rewardValue,
      'claimed': claimed,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt),
      if (claimedAt != null) 'claimedAt': Timestamp.fromDate(claimedAt),
    }, SetOptions(merge: true));

    return doc.id;
  }

  /// 領取獎勵：把 claimed=true + claimedAt=serverTimestamp
  /// - 用 transaction 避免重複領取
  Future<void> claim({required String historyId, String? uid}) async {
    final u = requireUid(uid);
    final ref = _histDoc(u, historyId);

    await _fs.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('獎勵紀錄不存在：$historyId');
      }
      final data = snap.data() ?? <String, dynamic>{};
      final already = (data['claimed'] ?? false) == true;
      if (already) {
        // 已領取就直接視為成功（或你要 throw 也可以改）
        return;
      }

      tx.set(ref, {
        'claimed': true,
        'claimedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// 取消領取（如果你後台需要回滾狀態）
  Future<void> unclaim({required String historyId, String? uid}) async {
    final u = requireUid(uid);
    await _histDoc(u, historyId).set({
      'claimed': false,
      'claimedAt': FieldValue.delete(),
    }, SetOptions(merge: true));
  }
}

// ------------------------------------------------------------
// Model
// ------------------------------------------------------------

class LeaderboardRewardHistory {
  final String id;

  final String seasonId;
  final String seasonName;
  final int rank;

  final String rewardTitle;
  final String rewardType;
  final num rewardValue;

  final bool claimed;
  final DateTime? createdAt;
  final DateTime? claimedAt;

  const LeaderboardRewardHistory({
    required this.id,
    required this.seasonId,
    required this.seasonName,
    required this.rank,
    required this.rewardTitle,
    required this.rewardType,
    required this.rewardValue,
    required this.claimed,
    required this.createdAt,
    required this.claimedAt,
  });

  static String _s(dynamic v, [String fallback = '']) =>
      (v ?? fallback).toString();

  static num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  static DateTime? _asDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static LeaderboardRewardHistory fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();

    return LeaderboardRewardHistory(
      id: doc.id,
      seasonId: _s(d['seasonId']).trim(),
      seasonName: _s(d['seasonName']).trim(),
      rank: _asNum(d['rank'], fallback: 0).toInt(),
      rewardTitle: _s(d['rewardTitle']).trim(),
      rewardType: _s(d['rewardType']).trim(),
      rewardValue: _asNum(d['rewardValue'], fallback: 0),
      claimed: (d['claimed'] ?? false) == true,
      createdAt: _asDate(d['createdAt']),
      claimedAt: _asDate(d['claimedAt']),
    );
  }
}
