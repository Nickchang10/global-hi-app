// lib/services/lottery_service.dart
//
// ✅ LotteryService（最終完整版・含 NotificationService 通知整合）
// ------------------------------------------------------------
// 功能：
// - 抽獎（隨機選擇獎項）
// - 自動產生優惠券（amount / percent / shipping）
// - 自動寫入 orders/{orderId}.lottery
// - 自動發送通知到 notifications/{uid}/items/{notifId}
// - 支援 Cloud Functions fallback
// ------------------------------------------------------------

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'notification_service.dart';

class LotteryResult {
  final String orderId;
  final String uid;
  final String status; // won / none
  final String prizeId;
  final String prizeName;
  final String? couponId;
  final String? couponCode;
  final String? couponType;
  final num? amountOff;
  final num? percentOff;
  final num? minSpend;
  final DateTime? expiresAt;
  final DateTime? drawnAt;

  const LotteryResult({
    required this.orderId,
    required this.uid,
    required this.status,
    required this.prizeId,
    required this.prizeName,
    this.couponId,
    this.couponCode,
    this.couponType,
    this.amountOff,
    this.percentOff,
    this.minSpend,
    this.expiresAt,
    this.drawnAt,
  });

  Map<String, dynamic> toMapForOrder({
    required Map<String, dynamic> prizeMap,
    DateTime? expiresAtOverride,
  }) {
    final exp = expiresAtOverride ?? expiresAt;
    return <String, dynamic>{
      'drawn': true,
      'drawnAt': FieldValue.serverTimestamp(),
      'prize': prizeMap,
      'couponId': couponId,
      'couponCode': couponCode,
      'status': status,
      'prizeId': prizeId,
      'prizeName': prizeName,
      'couponType': couponType,
      'amountOff': amountOff,
      'percentOff': percentOff,
      'minSpend': minSpend,
      'expiresAt': exp == null ? null : Timestamp.fromDate(exp),
    };
  }

  static DateTime? _dt(dynamic v) =>
      v is Timestamp ? v.toDate() : (v is DateTime ? v : null);
  static num? _num(dynamic v) {
    if (v is num) return v;
    return num.tryParse('${v ?? ''}');
  }

  static LotteryResult fromOrderDoc({
    required String orderId,
    required String uid,
    required Map<String, dynamic> lottery,
  }) {
    final prize = (lottery['prize'] is Map)
        ? Map<String, dynamic>.from(lottery['prize'])
        : <String, dynamic>{};
    final prizeIdNew = (prize['id'] ?? '').toString().trim();
    final prizeNameNew = (prize['title'] ?? '').toString().trim();
    final prizeTypeNew = (prize['type'] ?? '').toString().trim();

    String status = (lottery['status'] ?? '').toString().trim();
    if (status.isEmpty) {
      status = (prizeTypeNew == 'none') ? 'none' : 'won';
    }

    return LotteryResult(
      orderId: orderId,
      uid: uid,
      status: status,
      prizeId: prizeIdNew,
      prizeName: prizeNameNew,
      couponId: (lottery['couponId'] ?? '').toString().trim(),
      couponCode: (lottery['couponCode'] ?? '').toString().trim(),
      couponType: (lottery['couponType'] ?? '').toString().trim(),
      amountOff: _num(lottery['amountOff']),
      percentOff: _num(lottery['percentOff']),
      minSpend: _num(lottery['minSpend']),
      expiresAt: _dt(lottery['expiresAt']),
      drawnAt: _dt(lottery['drawnAt']),
    );
  }
}

class _Prize {
  final String id;
  final String name;
  final int weight;
  final String? couponType;
  final num? amountOff;
  final num? percentOff;
  final num? minSpend;
  final int? validDays;

  const _Prize({
    required this.id,
    required this.name,
    required this.weight,
    this.couponType,
    this.amountOff,
    this.percentOff,
    this.minSpend,
    this.validDays,
  });

  bool get hasCoupon =>
      (couponType ?? '').trim().isNotEmpty && couponType != 'none';
}

class LotteryService {
  LotteryService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    NotificationService? notificationService,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _fn = functions ?? FirebaseFunctions.instance,
        _notif = notificationService ?? NotificationService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseFunctions _fn;
  final NotificationService _notif;

  DocumentReference<Map<String, dynamic>> _orderRef(String orderId) =>
      _db.collection('orders').doc(orderId);
  DocumentReference<Map<String, dynamic>> _couponRefByCode(String code) =>
      _db.collection('coupons').doc(code);

  final List<_Prize> _prizes = const [
    _Prize(
      id: 'p_amount_300',
      name: 'NT\$300 折價券（滿 NT\$2,000 可用）',
      weight: 10,
      couponType: 'amount',
      amountOff: 300,
      minSpend: 2000,
      validDays: 30,
    ),
    _Prize(
      id: 'p_amount_100',
      name: 'NT\$100 折價券（滿 NT\$1,000 可用）',
      weight: 35,
      couponType: 'amount',
      amountOff: 100,
      minSpend: 1000,
      validDays: 30,
    ),
    _Prize(
      id: 'p_percent_10',
      name: '9 折券（滿 NT\$1,500 可用）',
      weight: 20,
      couponType: 'percent',
      percentOff: 10,
      minSpend: 1500,
      validDays: 14,
    ),
    _Prize(
      id: 'p_shipping',
      name: '免運券',
      weight: 20,
      couponType: 'shipping',
      validDays: 14,
    ),
    _Prize(
      id: 'p_none',
      name: '銘謝惠顧（下次一定中）',
      weight: 15,
      couponType: 'none',
    ),
  ];

  String _randCode({int len = 10}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }

  _Prize _pickPrize() {
    final total = _prizes.fold<int>(0, (s, p) => s + p.weight);
    final r = Random.secure().nextInt(max(1, total));
    var acc = 0;
    for (final p in _prizes) {
      acc += p.weight;
      if (r < acc) return p;
    }
    return _prizes.last;
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  bool _isPaidOrCod(Map<String, dynamic> order) {
    final status = (order['status'] ?? '').toString().trim().toLowerCase();
    final payment = _asMap(order['payment']);
    final pStatus = (payment['status'] ?? '').toString().trim().toLowerCase();
    final provider = (payment['provider'] ?? '').toString().trim().toLowerCase();
    final method = (payment['method'] ?? '').toString().trim().toLowerCase();
    final isPaid = (pStatus == 'paid' || status == 'paid');
    final isCod = (pStatus == 'cod' ||
        provider == 'cod' ||
        method == 'cash' ||
        status == 'cod_pending');
    return isPaid || isCod;
  }

  bool _hasExistingLottery(Map<String, dynamic> order) {
    final lottery = _asMap(order['lottery']);
    if (lottery.isEmpty) return false;
    if (lottery['drawn'] == true) return true;
    final status = (lottery['status'] ?? '').toString().trim();
    final prizeId = (lottery['prizeId'] ?? '').toString().trim();
    final prizeName = (lottery['prizeName'] ?? '').toString().trim();
    return status.isNotEmpty || prizeId.isNotEmpty || prizeName.isNotEmpty;
  }

  Stream<LotteryResult?> streamLottery(String orderId) {
    return _orderRef(orderId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      final uid = (data['buyerUid'] ?? '').toString().trim();
      final lottery = _asMap(data['lottery']);
      if (lottery.isEmpty) return null;
      return LotteryResult.fromOrderDoc(
          orderId: orderId, uid: uid, lottery: lottery);
    });
  }

  /// ✅ 主抽獎邏輯 + 通知整合
  Future<LotteryResult> drawOnce(String orderId) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('尚未登入，無法抽獎');
    final uid = user.uid;

    final result = await _db.runTransaction<LotteryResult>((tx) async {
      final oRef = _orderRef(orderId);
      final oSnap = await tx.get(oRef);
      if (!oSnap.exists) throw StateError('訂單不存在：$orderId');

      final order = Map<String, dynamic>.from(oSnap.data() ?? {});
      final buyerUid = (order['buyerUid'] ?? '').toString().trim();
      final realUid = buyerUid.isEmpty ? uid : buyerUid;

      if (!_isPaidOrCod(order)) {
        throw StateError('此訂單尚未付款成功，不能抽獎');
      }

      if (_hasExistingLottery(order)) {
        final existing = _asMap(order['lottery']);
        return LotteryResult.fromOrderDoc(
            orderId: orderId, uid: realUid, lottery: existing);
      }

      final prize = _pickPrize();
      final prizeMap = {
        'id': prize.id,
        'title': prize.name,
        'type': prize.couponType ?? 'none',
        'value': prize.amountOff ?? prize.percentOff ?? 0,
        'minSpend': prize.minSpend ?? 0,
        'validDays': prize.validDays,
      };

      // 如果沒中獎
      if (!prize.hasCoupon || prize.id == 'p_none') {
        final result = LotteryResult(
          orderId: orderId,
          uid: realUid,
          status: 'none',
          prizeId: prize.id,
          prizeName: prize.name,
          couponId: null,
          couponCode: null,
          couponType: 'none',
          amountOff: null,
          percentOff: null,
          minSpend: null,
          expiresAt: null,
          drawnAt: null,
        );
        tx.set(
            oRef,
            {'lottery': result.toMapForOrder(prizeMap: prizeMap)},
            SetOptions(merge: true));
        return result;
      }

      // 有中獎：建立 coupon
      String? code;
      DocumentReference<Map<String, dynamic>>? cRef;
      for (int i = 0; i < 5; i++) {
        final candidate = _randCode();
        final ref = _couponRefByCode(candidate);
        final snap = await tx.get(ref);
        if (!snap.exists) {
          code = candidate;
          cRef = ref;
          break;
        }
      }
      if (code == null || cRef == null) {
        throw StateError('產生優惠碼失敗，請重試');
      }

      final expiresAt = prize.validDays == null
          ? null
          : DateTime.now().add(Duration(days: prize.validDays!));

      tx.set(
        cRef,
        {
          'code': code,
          'uid': realUid,
          'orderId': orderId,
          'type': prize.couponType,
          'amountOff': prize.amountOff,
          'percentOff': prize.percentOff,
          'minSpend': prize.minSpend ?? 0,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
          'meta': {'prizeId': prize.id, 'prizeName': prize.name},
        },
        SetOptions(merge: true),
      );

      final result = LotteryResult(
        orderId: orderId,
        uid: realUid,
        status: 'won',
        prizeId: prize.id,
        prizeName: prize.name,
        couponId: code,
        couponCode: code,
        couponType: prize.couponType,
        amountOff: prize.amountOff,
        percentOff: prize.percentOff,
        minSpend: prize.minSpend,
        expiresAt: expiresAt,
        drawnAt: null,
      );

      tx.set(
        oRef,
        {'lottery': result.toMapForOrder(prizeMap: prizeMap, expiresAtOverride: expiresAt)},
        SetOptions(merge: true),
      );

      return result;
    });

    // ✅ 抽獎結果發通知
    await _sendLotteryNotification(result);
    return result;
  }

  Future<void> _sendLotteryNotification(LotteryResult r) async {
    if (r.uid.isEmpty) return;

    if (r.status == 'won') {
      await _notif.sendToUser(
        uid: r.uid,
        title: '恭喜您中獎啦！🎉',
        body:
            '您在訂單（${r.orderId}）抽中了「${r.prizeName}」，優惠券代碼：${r.couponCode ?? '（請至優惠券查看）'}',
        type: 'lottery',
        route: '/lottery_detail',
        extra: {
          'orderId': r.orderId,
          'couponCode': r.couponCode,
          'prizeName': r.prizeName,
          'status': r.status,
        },
      );
    } else {
      await _notif.sendToUser(
        uid: r.uid,
        title: '銘謝惠顧！',
        body: '您在訂單（${r.orderId}）未中獎，下次加油！',
        type: 'lottery',
        route: '/lottery_history',
        extra: {'orderId': r.orderId, 'status': r.status},
      );
    }
  }

  // ✅ Cloud Function 呼叫封裝
  Future<Map<String, dynamic>> drawOnceOrder({required String orderId}) async {
    try {
      final callable = _fn.httpsCallable('drawLottery');
      final res = await callable.call({'orderId': orderId});
      final data = res.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'ok': false, 'message': 'Functions 回傳格式錯誤'};
    } on FirebaseFunctionsException catch (e) {
      return {'ok': false, 'message': '抽獎失敗（Functions）：${e.message ?? ''}'};
    } catch (e) {
      debugPrint('drawOnceOrder fallback -> $e');
      try {
        final lr = await drawOnce(orderId);
        return {
          'ok': true,
          'result': {
            'status': lr.status,
            'prizeId': lr.prizeId,
            'prizeName': lr.prizeName,
            'couponCode': lr.couponCode,
          }
        };
      } catch (e2) {
        return {'ok': false, 'message': '抽獎失敗：$e2'};
      }
    }
  }
}
