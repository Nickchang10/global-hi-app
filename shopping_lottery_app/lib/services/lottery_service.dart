// lib/services/lottery_service.dart
//
// ✅ LotteryService（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// ✅ 修正重點：
// - ✅ 提供 LotteryService.instance（修正 payment_status_page.dart 的 undefined_getter）
// - ✅ 同 orderId 防重複抽獎（users/{uid}/lottery_spins/{orderId}）
// - ✅ points 類獎項：直接更新 users/{uid}.points
// - ✅ coupon/voucher：寫入 users/{uid}/coupons（方便 coupon_list_page 直接讀）
// - ✅ 抽獎回傳 Map，payment_status_page.dart 可用你現在的 _extractPrize 安全解析
//
// Firestore（建議/預設使用，不強制）：
// - lotteries/{lotteryId}
//   - prizes: List<Map> (optional)
//     每個 prize：{ name, type, value, weight, isActive }
//
// - users/{uid}/lottery_spins/{orderId}
//   - orderId, lotteryId, prizeName, prizeType, prizeValue, meta, createdAt
//
// - users/{uid}
//   - points: num
//
// - users/{uid}/coupons/{docId}
//   - title, type(coupon/voucher), value, status, sourceOrderId, lotteryId, createdAt
// ------------------------------------------------------------

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LotteryService {
  // ✅ 你 payment_status_page.dart 用到的單例
  static final LotteryService instance = LotteryService();

  LotteryService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    Random? random,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _fs = firestore ?? FirebaseFirestore.instance,
       _rand = random ?? Random.secure();

  final FirebaseAuth _auth;
  final FirebaseFirestore _fs;
  final Random _rand;

  User get _userOrThrow {
    final u = _auth.currentUser;
    if (u == null) {
      throw StateError('User not logged in');
    }
    return u;
  }

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  num _toNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _fs.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _lotteryRef(String lotteryId) =>
      _fs.collection('lotteries').doc(lotteryId);

  DocumentReference<Map<String, dynamic>> _spinRef(
    String uid,
    String orderId,
  ) =>
      _fs.collection('users').doc(uid).collection('lottery_spins').doc(orderId);

  CollectionReference<Map<String, dynamic>> _couponRef(String uid) =>
      _fs.collection('users').doc(uid).collection('coupons');

  /// ✅ 對應 PaymentStatusPage：spinForOrder(orderId, lotteryId, meta)
  /// - 同 orderId 只會抽一次（transaction 內檢查 users/{uid}/lottery_spins/{orderId}）
  /// - 回傳 Map：{ prizeName, prizeType, prizeValue, ... }
  Future<Map<String, dynamic>> spinForOrder({
    required String orderId,
    required String lotteryId,
    Map<String, dynamic>? meta,
  }) async {
    if (orderId.trim().isEmpty) {
      throw ArgumentError('orderId is empty');
    }
    if (lotteryId.trim().isEmpty) {
      throw ArgumentError('lotteryId is empty');
    }

    final user = _userOrThrow;
    final uid = user.uid;

    // 先抓一次獎池設定（沒有就用內建預設）
    final prizePool = await _loadPrizePool(lotteryId);

    Map<String, dynamic>? out;

    await _fs.runTransaction((tx) async {
      final spinRef = _spinRef(uid, orderId);
      final spinSnap = await tx.get(spinRef);

      // ✅ 防重複：已抽過就直接回傳舊結果
      if (spinSnap.exists) {
        out = spinSnap.data() ?? <String, dynamic>{};
        return;
      }

      // ✅ 抽獎
      final prize = _pickPrize(prizePool);

      final prizeName = _s(prize['name'], '獎品');
      final prizeType = _s(prize['type'], 'none');
      final prizeValue = prize['value'] ?? 0;

      final result = <String, dynamic>{
        'uid': uid,
        'orderId': orderId,
        'lotteryId': lotteryId,
        'prizeName': prizeName,
        'prizeType': prizeType,
        'prizeValue': prizeValue,
        'meta': meta ?? <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 寫入 spin 紀錄（orderId 當 docId）
      tx.set(spinRef, result, SetOptions(merge: true));

      // points：直接加到 users/{uid}.points
      if (prizeType == 'points') {
        final userRef = _userRef(uid);
        final userSnap = await tx.get(userRef);
        final u = userSnap.data() ?? <String, dynamic>{};
        final cur = _toNum(u['points'], fallback: 0);
        final add = _toNum(prizeValue, fallback: 0);
        tx.set(userRef, {
          'points': cur + add,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // coupon / voucher：寫入 users/{uid}/coupons
      if (prizeType == 'coupon' || prizeType == 'voucher') {
        final cRef = _couponRef(uid).doc();
        tx.set(cRef, {
          'title': prizeName,
          'type': prizeType,
          'value': prizeValue,
          'status': 'active',
          'sourceOrderId': orderId,
          'lotteryId': lotteryId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      out = result;
    });

    return out ?? <String, dynamic>{};
  }

  // -----------------------
  // 獎池：Firestore or 預設
  // -----------------------
  Future<List<Map<String, dynamic>>> _loadPrizePool(String lotteryId) async {
    try {
      final snap = await _lotteryRef(lotteryId).get();
      final data = snap.data();
      final prizes = data?['prizes'];
      if (prizes is List) {
        final list = <Map<String, dynamic>>[];
        for (final p in prizes) {
          if (p is Map) {
            final m = Map<String, dynamic>.from(p);
            final active = (m['isActive'] ?? true) == true;
            if (active) list.add(m);
          }
        }
        if (list.isNotEmpty) return list;
      }
    } catch (_) {
      // ignore -> fallback
    }

    // ✅ 預設獎池（你可依活動調整）
    return <Map<String, dynamic>>[
      {
        'name': '10 點',
        'type': 'points',
        'value': 10,
        'weight': 55,
        'isActive': true,
      },
      {
        'name': '50 點',
        'type': 'points',
        'value': 50,
        'weight': 20,
        'isActive': true,
      },
      {
        'name': '100 折價券',
        'type': 'coupon',
        'value': 100,
        'weight': 10,
        'isActive': true,
      },
      {
        'name': '100 代金券',
        'type': 'voucher',
        'value': 100,
        'weight': 5,
        'isActive': true,
      },
      {
        'name': '銘謝惠顧',
        'type': 'none',
        'value': 0,
        'weight': 10,
        'isActive': true,
      },
    ];
  }

  Map<String, dynamic> _pickPrize(List<Map<String, dynamic>> pool) {
    if (pool.isEmpty) {
      return {'name': '銘謝惠顧', 'type': 'none', 'value': 0, 'weight': 1};
    }

    final weights = pool.map((p) {
      final w = _toNum(p['weight'], fallback: 1);
      return w <= 0 ? 1 : w;
    }).toList();

    final sum = weights.fold<num>(0, (a, b) => a + b);
    final r = _rand.nextDouble() * sum;

    num acc = 0;
    for (int i = 0; i < pool.length; i++) {
      acc += weights[i];
      if (r <= acc) return pool[i];
    }
    return pool.last;
  }
}
