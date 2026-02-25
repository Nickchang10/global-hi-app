// lib/services/achievement_service.dart
//
// ✅ AchievementService（正式版｜完整版｜可直接編譯）
// ----------------------------------------------------
// ✅ 不依賴 FirestoreMockService（避免 instance getter 不存在）
// ✅ 使用 FirebaseFirestore / FirebaseAuth
// ✅ 成就資料：users/{uid}/achievements/{achievementId}
// ✅ 通知資料：users/{uid}/notifications/{autoId}
// ✅ 點數欄位：users/{uid}.points（用 FieldValue.increment）
//
// 需要套件：cloud_firestore, firebase_auth
// ----------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AchievementIds {
  static const String firstLogin = 'first_login';
  static const String firstPurchase = 'first_purchase';
  static const String purchase3 = 'purchase_3';
  static const String purchase10 = 'purchase_10';
  static const String shareApp = 'share_app';
}

class AchievementDocFields {
  static const String id = 'id';
  static const String title = 'title';
  static const String description = 'description';

  static const String unlocked = 'unlocked';
  static const String unlockedAt = 'unlockedAt';

  static const String progress = 'progress';
  static const String goal = 'goal';
  static const String rewardPoints = 'rewardPoints';

  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
}

class NotificationFields {
  static const String title = 'title';
  static const String body = 'body';
  static const String type = 'type';
  static const String read = 'read';
  static const String createdAt = 'createdAt';
  static const String data = 'data';
}

class AchievementDefinition {
  final String id;
  final String title;
  final String description;
  final int goal;
  final int rewardPoints;

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.goal,
    required this.rewardPoints,
  });
}

class AchievementService {
  AchievementService._({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static final AchievementService instance = AchievementService._();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// ✅ 你可以在這裡集中定義所有成就（前後台一致最好）
  static const Map<String, AchievementDefinition> definitions = {
    AchievementIds.firstLogin: AchievementDefinition(
      id: AchievementIds.firstLogin,
      title: '首次登入',
      description: '第一次登入 Osmile',
      goal: 1,
      rewardPoints: 10,
    ),
    AchievementIds.firstPurchase: AchievementDefinition(
      id: AchievementIds.firstPurchase,
      title: '首次購買',
      description: '完成第一次訂單付款',
      goal: 1,
      rewardPoints: 30,
    ),
    AchievementIds.purchase3: AchievementDefinition(
      id: AchievementIds.purchase3,
      title: '購買 3 次',
      description: '累積完成 3 筆付款訂單',
      goal: 3,
      rewardPoints: 50,
    ),
    AchievementIds.purchase10: AchievementDefinition(
      id: AchievementIds.purchase10,
      title: '購買 10 次',
      description: '累積完成 10 筆付款訂單',
      goal: 10,
      rewardPoints: 120,
    ),
    AchievementIds.shareApp: AchievementDefinition(
      id: AchievementIds.shareApp,
      title: '分享 App',
      description: '完成一次分享',
      goal: 1,
      rewardPoints: 20,
    ),
  };

  // ---------- Public Helpers ----------

  String? get currentUid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _achievementRef(
    String uid,
    String achievementId,
  ) => _userRef(uid).collection('achievements').doc(achievementId);

  CollectionReference<Map<String, dynamic>> _notiCol(String uid) =>
      _userRef(uid).collection('notifications');

  /// ✅ 監聽使用者成就列表（給 UI 用）
  Stream<List<Map<String, dynamic>>> watchMyAchievements() {
    final uid = currentUid;
    if (uid == null) {
      return const Stream.empty();
    }

    return _userRef(uid)
        .collection('achievements')
        .orderBy(AchievementDocFields.updatedAt, descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  /// ✅ 確保成就文件存在（通常第一次進成就頁可呼叫一次）
  Future<void> ensureAchievementDocsExist({String? uid}) async {
    final u = uid ?? currentUid;
    if (u == null) return;

    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();

    for (final def in definitions.values) {
      final ref = _achievementRef(u, def.id);
      batch.set(ref, {
        AchievementDocFields.id: def.id,
        AchievementDocFields.title: def.title,
        AchievementDocFields.description: def.description,
        AchievementDocFields.goal: def.goal,
        AchievementDocFields.rewardPoints: def.rewardPoints,
        AchievementDocFields.progress: 0,
        AchievementDocFields.unlocked: false,
        AchievementDocFields.createdAt: now,
        AchievementDocFields.updatedAt: now,
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  // ---------- Event Handlers (你可在各流程呼叫) ----------

  /// ✅ 登入成功後呼叫
  Future<void> onLoginSuccess({String? uid}) async {
    final u = uid ?? currentUid;
    if (u == null) return;
    await ensureAchievementDocsExist(uid: u);
    await addProgress(
      achievementId: AchievementIds.firstLogin,
      delta: 1,
      uid: u,
      // first_login 是 goal=1，會自動解鎖
    );
  }

  /// ✅ 付款成功後呼叫（可在 PaymentStatusPage success 時呼叫）
  Future<void> onOrderPaid({String? uid}) async {
    final u = uid ?? currentUid;
    if (u == null) return;
    await ensureAchievementDocsExist(uid: u);

    // 首購
    await addProgress(
      achievementId: AchievementIds.firstPurchase,
      delta: 1,
      uid: u,
    );

    // 累積付款次數
    await addProgress(
      achievementId: AchievementIds.purchase3,
      delta: 1,
      uid: u,
    );

    await addProgress(
      achievementId: AchievementIds.purchase10,
      delta: 1,
      uid: u,
    );
  }

  /// ✅ 分享行為完成時呼叫
  Future<void> onShareApp({String? uid}) async {
    final u = uid ?? currentUid;
    if (u == null) return;
    await ensureAchievementDocsExist(uid: u);

    await addProgress(achievementId: AchievementIds.shareApp, delta: 1, uid: u);
  }

  // ---------- Core Logic ----------

  /// ✅ 增加成就進度：達標自動解鎖、加點數、寫通知
  Future<void> addProgress({
    required String achievementId,
    required int delta,
    String? uid,
  }) async {
    final u = uid ?? currentUid;
    if (u == null) return;

    final def = definitions[achievementId];
    if (def == null) {
      // 沒定義就不做事（避免跑出錯）
      return;
    }

    final achRef = _achievementRef(u, achievementId);
    final userRef = _userRef(u);
    final notiRef = _notiCol(u).doc(); // autoId

    await _db.runTransaction((tx) async {
      final now = FieldValue.serverTimestamp();

      final achSnap = await tx.get(achRef);
      final data = achSnap.data() ?? <String, dynamic>{};

      final bool unlocked = (data[AchievementDocFields.unlocked] == true);
      final int currentProgress = _asInt(data[AchievementDocFields.progress]);
      final int goal = _asInt(
        data[AchievementDocFields.goal],
        fallback: def.goal,
      );

      if (unlocked) {
        // 已解鎖就只更新 updatedAt（可選：也可不更新）
        tx.set(achRef, {
          AchievementDocFields.updatedAt: now,
        }, SetOptions(merge: true));
        return;
      }

      final int nextProgress = (currentProgress + delta).clamp(0, goal);
      final bool shouldUnlock = nextProgress >= goal;

      final update = <String, dynamic>{
        AchievementDocFields.id: def.id,
        AchievementDocFields.title: def.title,
        AchievementDocFields.description: def.description,
        AchievementDocFields.goal: goal,
        AchievementDocFields.rewardPoints: def.rewardPoints,
        AchievementDocFields.progress: nextProgress,
        AchievementDocFields.updatedAt: now,
        if (!achSnap.exists) AchievementDocFields.createdAt: now,
      };

      if (shouldUnlock) {
        update[AchievementDocFields.unlocked] = true;
        update[AchievementDocFields.unlockedAt] = now;

        // ✅ 加點數（users/{uid}.points）
        tx.set(userRef, {
          'points': FieldValue.increment(def.rewardPoints),
          'updatedAt': now,
          if (!await _existsInTx(tx, userRef)) 'createdAt': now,
        }, SetOptions(merge: true));

        // ✅ 寫通知（可讓通知中心直接顯示）
        tx.set(notiRef, {
          NotificationFields.title: '成就解鎖：${def.title}',
          NotificationFields.body: '恭喜獲得 ${def.rewardPoints} 點',
          NotificationFields.type: 'achievement',
          NotificationFields.read: false,
          NotificationFields.createdAt: now,
          NotificationFields.data: {
            'achievementId': def.id,
            'rewardPoints': def.rewardPoints,
          },
        });
      }

      tx.set(achRef, update, SetOptions(merge: true));
    });
  }

  /// ✅ 直接強制解鎖（必要時用，例如後台補發）
  Future<void> forceUnlock({required String achievementId, String? uid}) async {
    final u = uid ?? currentUid;
    if (u == null) return;

    final def = definitions[achievementId];
    if (def == null) return;

    final achRef = _achievementRef(u, achievementId);
    final userRef = _userRef(u);
    final notiRef = _notiCol(u).doc();

    final now = FieldValue.serverTimestamp();

    await _db.runTransaction((tx) async {
      final achSnap = await tx.get(achRef);
      final data = achSnap.data() ?? <String, dynamic>{};
      final bool unlocked = (data[AchievementDocFields.unlocked] == true);
      if (unlocked) return;

      tx.set(achRef, {
        AchievementDocFields.id: def.id,
        AchievementDocFields.title: def.title,
        AchievementDocFields.description: def.description,
        AchievementDocFields.goal: def.goal,
        AchievementDocFields.rewardPoints: def.rewardPoints,
        AchievementDocFields.progress: def.goal,
        AchievementDocFields.unlocked: true,
        AchievementDocFields.unlockedAt: now,
        AchievementDocFields.updatedAt: now,
        if (!achSnap.exists) AchievementDocFields.createdAt: now,
      }, SetOptions(merge: true));

      tx.set(userRef, {
        'points': FieldValue.increment(def.rewardPoints),
        'updatedAt': now,
      }, SetOptions(merge: true));

      tx.set(notiRef, {
        NotificationFields.title: '成就解鎖：${def.title}',
        NotificationFields.body: '已補發 ${def.rewardPoints} 點',
        NotificationFields.type: 'achievement',
        NotificationFields.read: false,
        NotificationFields.createdAt: now,
        NotificationFields.data: {
          'achievementId': def.id,
          'rewardPoints': def.rewardPoints,
          'forced': true,
        },
      });
    });
  }

  // ---------- Utils ----------

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static Future<bool> _existsInTx(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final snap = await tx.get(ref);
    return snap.exists;
  }
}
