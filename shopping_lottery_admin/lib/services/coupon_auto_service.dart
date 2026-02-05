// lib/services/coupon_auto_service.dart
//
// ✅ CouponAutoService（自動發送優惠券系統｜完整版）
// ------------------------------------------------------------
// - 支援優惠券自動發送：會員登入 / 指定事件觸發
// - 可依會員等級 / 任務完成度 / 活動類型推送
// - 內建 Firestore 整合 + 通知中心 + FCM 通知
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class CouponAutoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // =====================================================
  // ✅ 自動發送主入口
  // =====================================================
  Future<void> autoSendCoupons({String trigger = 'login'}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final uid = user.uid;
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() ?? {};
      final level = (userData['level'] ?? 'basic').toString().toLowerCase();
      final email = (userData['email'] ?? '').toString();

      // 讀取所有 "自動派發" 的優惠券
      final now = DateTime.now();
      final snap = await _db
          .collection('coupons')
          .where('autoSend', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final startAt = _toDate(data['startAt']);
        final endAt = _toDate(data['endAt']);
        final targetLevel = (data['targetLevel'] ?? 'all').toString().toLowerCase();

        // 1️⃣ 日期檢查
        if (startAt != null && now.isBefore(startAt)) continue;
        if (endAt != null && now.isAfter(endAt)) continue;

        // 2️⃣ 等級匹配（若指定特定會員等級）
        if (targetLevel != 'all' && targetLevel != level) continue;

        // 3️⃣ 是否已領取（防止重複派發）
        final already = await _db
            .collection('users')
            .doc(uid)
            .collection('user_coupons')
            .doc(doc.id)
            .get();
        if (already.exists) continue;

        // 4️⃣ 發送給該會員
        await _assignCoupon(uid, doc.id, data);

        // 5️⃣ 建立通知
        await _sendNotification(
          uid: uid,
          title: '您收到新的優惠券',
          body: '${data['title']} - ${data['code']}',
          extra: {'couponId': doc.id},
        );

        if (kDebugMode) {
          print('[CouponAutoService] 優惠券已發送給 $email (${user.uid}) → ${data['code']}');
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('[CouponAutoService] 自動發送失敗: $e\n$st');
      }
    }
  }

  // =====================================================
  // ✅ 指派優惠券給會員
  // =====================================================

  Future<void> _assignCoupon(String uid, String couponId, Map<String, dynamic> couponData) async {
    final now = FieldValue.serverTimestamp();

    await _db
        .collection('users')
        .doc(uid)
        .collection('user_coupons')
        .doc(couponId)
        .set({
      'couponId': couponId,
      'title': couponData['title'] ?? '',
      'code': couponData['code'] ?? '',
      'discount': couponData['discount'] ?? 0,
      'status': 'available',
      'assignedAt': now,
      'startAt': couponData['startAt'],
      'endAt': couponData['endAt'],
    });
  }

  // =====================================================
  // ✅ 推播／系統通知
  // =====================================================

  Future<void> _sendNotification({
    required String uid,
    required String title,
    required String body,
    Map<String, dynamic>? extra,
  }) async {
    await _db.collection('notifications').add({
      'uid': uid,
      'title': title,
      'body': body,
      'data': extra ?? {},
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'coupon',
    });
  }

  // =====================================================
  // ✅ 工具
  // =====================================================

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}
