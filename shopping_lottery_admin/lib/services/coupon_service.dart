// lib/services/coupon_service.dart
//
// ✅ CouponService（完整版・可編譯）
//
// 你目前的 CheckoutPage 會呼叫：
//   couponSvc.validateCoupon(code, amount: _subtotal)
//
// 因此本檔新增 validateCoupon(...)，並維持你原本的：
// - streamMyActiveCoupons
// - getCoupon
// - getAndValidateCoupon
// - quote
// - markUsed
//
// 並且兼容兩種 Firestore coupon schema：
// A) 你目前用的（以狀態為主）
//   - uid, status(active/used/expired/cancelled), type(amount/percent/shipping)
//   - amountOff, percentOff, minSpend, expiresAt, usedAt
//
// B) 常見/另一套（以啟用與 value 為主）
//   - isActive(bool), type(percent/fixed/amount/shipping), value(num)
//   - minSpend, startsAt, endsAt, title/name
//
// 注意：validateCoupon 是「前端預檢」；真正折扣仍建議在後端/交易內再驗證一次。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Coupon {
  final String code; // docId (建議=大寫券碼)
  final String uid; // 可為空：代表不綁定使用者（通用券）
  final String status; // active / used / expired / cancelled

  /// amount / percent / shipping
  final String type;

  /// amount: 固定折抵金額
  final num amountOff;

  /// percent: 折扣百分比（10 = 10% off）
  final num percentOff;

  /// 最低消費門檻（以小計 subtotal 比較）
  final num minSpend;

  /// 顯示用（可選）
  final String title;

  final DateTime? startsAt; // 可選（兼容 schema B）
  final DateTime? expiresAt; // 可選（schema A: expiresAt；schema B: endsAt）
  final DateTime? usedAt;

  const Coupon({
    required this.code,
    required this.uid,
    required this.status,
    required this.type,
    required this.amountOff,
    required this.percentOff,
    required this.minSpend,
    this.title = '',
    this.startsAt,
    this.expiresAt,
    this.usedAt,
  });

  static DateTime? _dt(dynamic v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  static num _num(dynamic v, {num fb = 0}) {
    if (v is num) return v;
    return num.tryParse('${v ?? ''}') ?? fb;
  }

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static Coupon fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};

    final code = ((_s(d['code']).isEmpty ? doc.id : d['code']).toString()).trim().toUpperCase();

    // 兼容兩套 status/isActive
    String status;
    if (_s(d['status']).isNotEmpty) {
      status = _s(d['status']);
    } else if (d.containsKey('isActive')) {
      status = (d['isActive'] == true) ? 'active' : 'cancelled';
    } else {
      status = 'active';
    }

    // type 兼容：fixed -> amount
    var type = _s(d['type']).toLowerCase();
    if (type == 'fixed') type = 'amount';
    if (type.isEmpty) type = 'amount';

    // minSpend
    final minSpend = _num(d['minSpend']);

    // title/name
    final title = _s(d['title']).isNotEmpty ? _s(d['title']) : _s(d['name']);

    // 時間窗（兼容）
    final startsAt = _dt(d['startsAt']);
    final endsAt = _dt(d['endsAt']);
    final expiresAt = _dt(d['expiresAt']) ?? endsAt;

    // amountOff / percentOff 兼容 value
    num amountOff = _num(d['amountOff']);
    num percentOff = _num(d['percentOff']);
    final value = _num(d['value']);

    if (type == 'amount' && amountOff <= 0 && value > 0) {
      amountOff = value;
    }
    if (type == 'percent' && percentOff <= 0 && value > 0) {
      percentOff = value;
    }

    return Coupon(
      code: code,
      uid: _s(d['uid']),
      status: status,
      type: type, // amount/percent/shipping
      amountOff: amountOff,
      percentOff: percentOff,
      minSpend: minSpend,
      title: title,
      startsAt: startsAt,
      expiresAt: expiresAt,
      usedAt: _dt(d['usedAt']),
    );
  }

  bool get isActive => status == 'active';

  bool isExpiredAt(DateTime now) {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore(now);
  }

  bool notStartedYet(DateTime now) {
    if (startsAt == null) return false;
    return now.isBefore(startsAt!);
  }
}

class CouponQuote {
  final Coupon coupon;

  /// 小計（不含運費）
  final num subtotal;

  /// 運費（可選，沒有就傳 0）
  final num shippingFee;

  /// 折扣金額
  final num discount;

  /// 結帳總額（subtotal + shippingFee - discount）
  final num total;

  const CouponQuote({
    required this.coupon,
    required this.subtotal,
    required this.shippingFee,
    required this.discount,
    required this.total,
  });
}

class CouponService {
  CouponService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _couponRef(String code) =>
      _db.collection('coupons').doc(code.trim().toUpperCase());

  // ---------------------------------------------------------------------------
  // ✅ 新增：給 CheckoutPage 用（回傳 Map?）
  // - 成功：回傳 {id/code/title/type/value/minSpend/discount/...}
  // - 不可用：回 null（符合你 checkout_page.dart 的判斷習慣）
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> validateCoupon(
    String code, {
    required num amount,
    num shippingFee = 0,
  }) async {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return null;

    // 若你希望「未登入也能使用通用券」，可以把這段限制拿掉，
    // 並在 getAndValidateCoupon 內改成「coupon.uid 空 => 不需要登入」。
    final u = _auth.currentUser;
    if (u == null) return null;

    try {
      final coupon = await getAndValidateCoupon(
        c,
        subtotal: amount,
        shippingFee: shippingFee,
      );

      final q = quote(
        coupon,
        subtotal: amount,
        shippingFee: shippingFee,
      );

      // 統一回傳給 UI：type + value
      // - amount: value = amountOff
      // - percent: value = percentOff
      // - shipping: value = 0（你若有運費可用 shippingFee 直接算折扣）
      num value = 0;
      if (coupon.type == 'amount') value = coupon.amountOff;
      if (coupon.type == 'percent') value = coupon.percentOff;

      return <String, dynamic>{
        'id': coupon.code,
        'code': coupon.code,
        'title': coupon.title,
        'type': coupon.type, // amount / percent / shipping
        'value': value,
        'amountOff': coupon.amountOff,
        'percentOff': coupon.percentOff,
        'minSpend': coupon.minSpend,
        if (coupon.startsAt != null) 'startsAt': coupon.startsAt,
        if (coupon.expiresAt != null) 'expiresAt': coupon.expiresAt,
        'discount': q.discount,
        'total': q.total,
      };
    } catch (_) {
      return null;
    }
  }

  /// 只看「我的有效券」（active 且未過期）
  Stream<List<Coupon>> streamMyActiveCoupons() {
    final u = _auth.currentUser;
    if (u == null) return const Stream<List<Coupon>>.empty();

    return _db
        .collection('coupons')
        .where('uid', isEqualTo: u.uid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((qs) {
      final now = DateTime.now();
      final list = qs.docs
          .map(Coupon.fromDoc)
          .where((c) => !c.notStartedYet(now))
          .where((c) => !c.isExpiredAt(now))
          .toList();

      // 快過期的在前；沒有 expiresAt 的放最後
      list.sort((a, b) {
        final ax = a.expiresAt?.millisecondsSinceEpoch ?? (1 << 62);
        final bx = b.expiresAt?.millisecondsSinceEpoch ?? (1 << 62);
        return ax.compareTo(bx);
      });

      return list;
    });
  }

  /// 讀取券碼（不驗證）
  Future<Coupon> getCoupon(String code) async {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) throw StateError('優惠碼不可為空');

    final snap = await _couponRef(c).get();
    if (!snap.exists) throw StateError('找不到此優惠碼：$c');
    return Coupon.fromDoc(snap);
  }

  /// 讀取/驗證券碼
  /// - 預設限制「只能本人 uid 使用」（若 coupon.uid 為空，則視為通用券）
  /// - 需 active、未過期、達到門檻
  /// - 兼容 schema B：startsAt/endsAt/isActive/value
  Future<Coupon> getAndValidateCoupon(
    String code, {
    required num subtotal,
    num shippingFee = 0,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('請先登入');

    final c = code.trim().toUpperCase();
    if (c.isEmpty) throw StateError('優惠碼不可為空');

    final snap = await _couponRef(c).get();
    if (!snap.exists) throw StateError('找不到此優惠碼：$c');

    final coupon = Coupon.fromDoc(snap);

    // 綁 uid 的券：只能本人用；uid 空：通用券
    if (coupon.uid.isNotEmpty && coupon.uid != u.uid) {
      throw StateError('此優惠碼不屬於你');
    }

    if (!coupon.isActive) throw StateError('此優惠碼不可用（status=${coupon.status}）');

    final now = DateTime.now();
    if (coupon.notStartedYet(now)) throw StateError('此優惠碼尚未開始使用');
    if (coupon.isExpiredAt(now)) throw StateError('此優惠碼已過期');

    final safeSubtotal = _safeNonNegative(subtotal);
    if (safeSubtotal < coupon.minSpend) {
      throw StateError('未達使用門檻：滿 NT\$${coupon.minSpend.toStringAsFixed(0)} 才可使用');
    }

    // 類型基本檢查
    switch (coupon.type) {
      case 'shipping':
        // 免運券：允許；折扣試算會用 shippingFee（若你還沒做運費，傳 0 也 ok）
        break;
      case 'amount':
        if (coupon.amountOff <= 0) throw StateError('折價券設定有誤（amountOff<=0）');
        break;
      case 'percent':
        if (coupon.percentOff <= 0) throw StateError('折扣券設定有誤（percentOff<=0）');
        break;
      default:
        throw StateError('不支援的優惠券類型：${coupon.type}');
    }

    return coupon;
  }

  /// 試算折扣（不寫入）
  /// subtotal：不含運費的小計
  /// shippingFee：運費（若你沒做運費可傳 0）
  CouponQuote quote(
    Coupon coupon, {
    required num subtotal,
    num shippingFee = 0,
  }) {
    final s = _safeNonNegative(subtotal);
    final ship = _safeNonNegative(shippingFee);

    num discount = 0;

    switch (coupon.type) {
      case 'amount':
        discount = coupon.amountOff;
        break;
      case 'percent':
        discount = s * (coupon.percentOff / 100.0);
        break;
      case 'shipping':
        // 免運券：折抵運費（若 shippingFee=0，就等於折扣=0）
        discount = ship;
        break;
      default:
        discount = 0;
    }

    // 折扣不可超過 subtotal+shippingFee
    final cap = s + ship;
    if (discount > cap) discount = cap;
    if (discount < 0) discount = 0;

    final total = (s + ship - discount);
    return CouponQuote(
      coupon: coupon,
      subtotal: s,
      shippingFee: ship,
      discount: discount,
      total: total < 0 ? 0 : total,
    );
  }

  /// 標記 used（建議在「付款成功 / 訂單確認」時呼叫）
  /// - 用 transaction 防止重複使用
  /// - 會寫 usedOrderId、usedAt
  Future<void> markUsed(
    String code, {
    required String orderId,
  }) async {
    final c = code.trim().toUpperCase();
    final oid = orderId.trim();
    if (c.isEmpty) return;
    if (oid.isEmpty) throw StateError('orderId 為空');

    final u = _auth.currentUser;
    if (u == null) throw StateError('請先登入');

    await _db.runTransaction((tx) async {
      final ref = _couponRef(c);
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('找不到此優惠碼：$c');

      final coupon = Coupon.fromDoc(snap);
      final now = DateTime.now();

      if (coupon.uid.isNotEmpty && coupon.uid != u.uid) {
        throw StateError('此優惠碼不屬於你');
      }
      if (coupon.status == 'used') {
        // 已用過：直接返回（可視需求改成丟錯）
        return;
      }
      if (coupon.status != 'active') throw StateError('此優惠碼不可用（status=${coupon.status}）');

      if (coupon.notStartedYet(now)) throw StateError('此優惠碼尚未開始使用');

      if (coupon.isExpiredAt(now)) {
        // 順便標記過期（可選）
        tx.set(ref, {'status': 'expired'}, SetOptions(merge: true));
        throw StateError('此優惠碼已過期');
      }

      tx.set(
        ref,
        <String, dynamic>{
          'status': 'used',
          'usedAt': FieldValue.serverTimestamp(),
          'usedOrderId': oid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  static num _safeNonNegative(num v) => v < 0 ? 0 : v;
}
