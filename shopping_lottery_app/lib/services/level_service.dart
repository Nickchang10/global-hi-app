// lib/services/level_service.dart
//
// ✅ LevelService（正式版｜完整版｜可直接編譯）
// ----------------------------------------------------
// ✅ 修正：補上 init() 以相容舊頁面呼叫（level_page.dart 的錯誤來源）
// ✅ 使用 FirebaseFirestore.instance / FirebaseAuth.instance
// ✅ 功能：watchMyLevel / ensureLevelDoc / addXp（自動升級+點數+通知）
//
// Firestore 結構：
// - users/{uid}
//     - points: int
// - users/{uid}/meta/level
//     - level: int
//     - xp: int
//     - updatedAt: timestamp
//
// 需要套件：cloud_firestore, firebase_auth
// ----------------------------------------------------

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LevelFields {
  static const String level = 'level';
  static const String xp = 'xp';
  static const String updatedAt = 'updatedAt';
  static const String createdAt = 'createdAt';
}

class LevelService {
  LevelService._({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static final LevelService instance = LevelService._();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  String? get currentUid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  /// 等級文件位置：users/{uid}/meta/level
  DocumentReference<Map<String, dynamic>> _levelRef(String uid) =>
      _userRef(uid).collection('meta').doc('level');

  CollectionReference<Map<String, dynamic>> _notiCol(String uid) =>
      _userRef(uid).collection('notifications');

  // ✅ 相容舊呼叫：LevelService.init()
  Future<void> init({String? uid}) async {
    await ensureLevelDoc(uid: uid);
  }

  // ------------------------
  // ✅ 等級曲線（可自行調整）
  // ------------------------
  int xpForNextLevel(int level) {
    // ✅ prefer_const_declarations：常數值用 const
    const base = 100;
    const step = 80;
    return base + (level - 1) * step;
  }

  /// 升級獎勵（points）
  int rewardPointsForLevelUp(int newLevel) {
    return 10 + newLevel * 2;
  }

  // ------------------------
  // Watch / Ensure
  // ------------------------

  Stream<LevelState> watchMyLevel() {
    final uid = currentUid;
    if (uid == null) {
      return const Stream.empty();
    }

    return _levelRef(uid).snapshots().map((snap) {
      final data = snap.data() ?? <String, dynamic>{};
      final lv = _asInt(data[LevelFields.level], fallback: 1);
      final xp = _asInt(data[LevelFields.xp], fallback: 0);
      return LevelState(level: lv, xp: xp);
    });
  }

  Future<void> ensureLevelDoc({String? uid}) async {
    final u = uid ?? currentUid;
    if (u == null) return;

    final ref = _levelRef(u);
    final snap = await ref.get();
    if (snap.exists) return;

    final now = FieldValue.serverTimestamp();
    await ref.set({
      LevelFields.level: 1,
      LevelFields.xp: 0,
      LevelFields.createdAt: now,
      LevelFields.updatedAt: now,
    }, SetOptions(merge: true));
  }

  // ------------------------
  // Core: add XP
  // ------------------------

  Future<LevelUpResult> addXp({
    required int deltaXp,
    String? uid,
    String reason = 'mission',
    Map<String, dynamic>? extra,
  }) async {
    final u = uid ?? currentUid;
    if (u == null) throw StateError('User not logged in');

    if (deltaXp == 0) {
      final st = await getMyLevelOnce(uid: u);
      return LevelUpResult(
        oldLevel: st.level,
        newLevel: st.level,
        oldXp: st.xp,
        newXp: st.xp,
        leveledUp: false,
        rewardPoints: 0,
      );
    }

    await ensureLevelDoc(uid: u);

    final levelRef = _levelRef(u);
    final userRef = _userRef(u);
    final notiRef = _notiCol(u).doc();

    late int oldLevel;
    late int oldXp;
    late int newLevel;
    late int newXp;
    int totalRewardPoints = 0;
    bool leveledUp = false;

    await _db.runTransaction((tx) async {
      final now = FieldValue.serverTimestamp();

      final snap = await tx.get(levelRef);
      final data = snap.data() ?? <String, dynamic>{};

      oldLevel = _asInt(data[LevelFields.level], fallback: 1);
      oldXp = _asInt(data[LevelFields.xp], fallback: 0);

      int xp = oldXp + deltaXp;
      int lv = oldLevel;

      while (xp >= xpForNextLevel(lv)) {
        xp -= xpForNextLevel(lv);
        lv += 1;
        leveledUp = true;
        totalRewardPoints += rewardPointsForLevelUp(lv);
      }

      newLevel = lv;
      newXp = xp;

      tx.set(levelRef, {
        LevelFields.level: newLevel,
        LevelFields.xp: newXp,
        LevelFields.updatedAt: now,
      }, SetOptions(merge: true));

      if (leveledUp && totalRewardPoints > 0) {
        tx.set(userRef, {
          'points': FieldValue.increment(totalRewardPoints),
          'updatedAt': now,
        }, SetOptions(merge: true));

        tx.set(notiRef, {
          'title': '等級提升！',
          'body': '恭喜升到 Lv.$newLevel，獲得 $totalRewardPoints 點獎勵',
          'type': 'level',
          'read': false,
          'createdAt': now,
          'data': {
            'reason': reason,
            'deltaXp': deltaXp,
            'oldLevel': oldLevel,
            'newLevel': newLevel,
            'rewardPoints': totalRewardPoints,
            ...?extra,
          },
        });
      }
    });

    return LevelUpResult(
      oldLevel: oldLevel,
      newLevel: newLevel,
      oldXp: oldXp,
      newXp: newXp,
      leveledUp: leveledUp,
      rewardPoints: totalRewardPoints,
    );
  }

  Future<LevelState> getMyLevelOnce({String? uid}) async {
    final u = uid ?? currentUid;
    if (u == null) throw StateError('User not logged in');
    await ensureLevelDoc(uid: u);

    final snap = await _levelRef(u).get();
    final data = snap.data() ?? <String, dynamic>{};
    final lv = _asInt(data[LevelFields.level], fallback: 1);
    final xp = _asInt(data[LevelFields.xp], fallback: 0);
    return LevelState(level: lv, xp: xp);
  }

  void startListeningMyLevel(void Function(LevelState state) onChanged) {
    final uid = currentUid;
    if (uid == null) return;

    _sub?.cancel();
    _sub = _levelRef(uid).snapshots().listen((snap) {
      final data = snap.data() ?? <String, dynamic>{};
      onChanged(
        LevelState(
          level: _asInt(data[LevelFields.level], fallback: 1),
          xp: _asInt(data[LevelFields.xp], fallback: 0),
        ),
      );
    });
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
  }

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}

class LevelState {
  final int level;
  final int xp;

  const LevelState({required this.level, required this.xp});
}

class LevelUpResult {
  final int oldLevel;
  final int newLevel;
  final int oldXp;
  final int newXp;
  final bool leveledUp;
  final int rewardPoints;

  const LevelUpResult({
    required this.oldLevel,
    required this.newLevel,
    required this.oldXp,
    required this.newXp,
    required this.leveledUp,
    required this.rewardPoints,
  });
}
