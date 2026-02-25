// lib/services/order_ai_push_service.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// ✅ OrderAIPushService（訂單 AI 推播/通知服務｜修改後完整版）
/// ------------------------------------------------------------
/// 修正重點：
/// - ✅ 移除不存在的 FirestoreService
/// - ✅ 直接使用 FirebaseFirestore.instance
/// - ✅ 將「AI 推播」落地成 Firestore 通知：users/{uid}/notifications/{nid}
///
/// 通知資料結構（建議）：
/// users/{uid}/notifications/{nid}
///  - title: String
///  - body: String
///  - type: String            // "order_ai"
///  - route: String?          // 例如 "/orders"
///  - data: Map<String,dynamic>? // { orderId: "...", ... }
///  - isRead: bool
///  - createdAt: Timestamp
///
/// 你可在「通知中心」用 route/data 做跳轉。
/// ------------------------------------------------------------
class OrderAIPushService {
  final FirebaseFirestore _fs;

  OrderAIPushService({FirebaseFirestore? firestore})
    : _fs = firestore ?? FirebaseFirestore.instance;

  /// ✅ 常用：下單成功後推一則「感謝 + 建議」
  Future<void> pushAfterOrderPlaced({
    required String uid,
    required String orderId,
    Map<String, dynamic>? orderData,
  }) async {
    final insights = _buildInsights(orderData);

    await _addUserNotification(
      uid: uid,
      title: '✅ 訂單已成立',
      body: [
        '訂單編號：$orderId',
        if (insights.isNotEmpty) '',
        ...insights,
      ].join('\n'),
      type: 'order_ai',
      route: '/orders',
      data: {'orderId': orderId, if (orderData != null) 'order': orderData},
    );
  }

  /// ✅ 付款成功（或補款成功）後推一則
  Future<void> pushAfterPaymentSuccess({
    required String uid,
    required String orderId,
    num? paidAmount,
  }) async {
    await _addUserNotification(
      uid: uid,
      title: '💳 付款成功',
      body: [
        '訂單編號：$orderId',
        if (paidAmount != null) '付款金額：${paidAmount.toStringAsFixed(0)}',
        '',
        '我們已開始處理你的訂單，稍後會更新出貨狀態。',
      ].join('\n'),
      type: 'order_ai',
      route: '/orders',
      data: {
        'orderId': orderId,
        if (paidAmount != null) 'paidAmount': paidAmount,
      },
    );
  }

  /// ✅ 出貨狀態更新（例如已出貨/到店）
  Future<void> pushShippingUpdate({
    required String uid,
    required String orderId,
    required String status,
    String? trackingNo,
  }) async {
    await _addUserNotification(
      uid: uid,
      title: '📦 物流更新：$status',
      body: [
        '訂單編號：$orderId',
        if ((trackingNo ?? '').trim().isNotEmpty) '追蹤號碼：$trackingNo',
        '',
        '你可以到「我的訂單」查看詳細物流資訊。',
      ].join('\n'),
      type: 'order_ai',
      route: '/orders',
      data: {
        'orderId': orderId,
        'status': status,
        if ((trackingNo ?? '').trim().isNotEmpty) 'trackingNo': trackingNo,
      },
    );
  }

  /// ✅ 若你想在後台/流程中「指定內容推播」也可用這個
  Future<void> pushCustom({
    required String uid,
    required String title,
    required String body,
    String route = '/orders',
    Map<String, dynamic>? data,
  }) async {
    await _addUserNotification(
      uid: uid,
      title: title,
      body: body,
      type: 'order_ai',
      route: route,
      data: data,
    );
  }

  // -------------------------
  // Internal helpers
  // -------------------------

  CollectionReference<Map<String, dynamic>> _userNotiRef(String uid) =>
      _fs.collection('users').doc(uid).collection('notifications');

  Future<void> _addUserNotification({
    required String uid,
    required String title,
    required String body,
    required String type,
    String? route,
    Map<String, dynamic>? data,
  }) async {
    final id = _userNotiRef(uid).doc().id;

    final payload = <String, dynamic>{
      'title': title,
      'body': body,
      'type': type,
      'route': (route ?? '').trim().isEmpty ? null : route,
      'data': data,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _userNotiRef(uid).doc(id).set(payload, SetOptions(merge: true));
  }

  List<String> _buildInsights(Map<String, dynamic>? order) {
    if (order == null) {
      return const ['🔎 小提醒：你可以在「我的訂單」查看付款/出貨進度。'];
    }

    final total = _asNum(
      order['totalAmount'] ?? order['total'] ?? order['amount'],
    );
    final items = _asList(order['items']);

    final itemCount = items.length;
    final hasWatch = items.any((e) {
      final name = _s(e['name']).toLowerCase();
      final category = _s(e['category']).toLowerCase();
      return name.contains('watch') ||
          name.contains('手錶') ||
          category.contains('watch') ||
          category.contains('wearable') ||
          category.contains('穿戴');
    });

    final hasWarranty = _truthy(order['hasWarranty'] ?? order['warranty']);
    final payMethod = _s(order['paymentMethod'] ?? order['payMethod']);
    final shipMethod = _s(order['shippingMethod'] ?? order['shipMethod']);

    final tips = <String>[];

    // 1) 金額/件數建議
    if (total >= 3000) {
      tips.add('🎁 你的訂單金額較高，記得查看是否有可用優惠券/回饋點數。');
    } else if (itemCount >= 3) {
      tips.add('🧾 你本次購買品項較多，建議到「訂單」確認收件資料是否正確。');
    } else {
      tips.add('🧭 小提醒：如需修改收件資訊，請趁出貨前到「我的訂單」處理。');
    }

    // 2) 商品類型建議
    if (hasWatch) {
      if (!hasWarranty) {
        tips.add('⌚ 若是手錶/穿戴產品，建議加購延伸保固或確認保固條款。');
      } else {
        tips.add('✅ 已含保固資訊，出貨後記得保留序號/保固卡以便售後服務。');
      }
    }

    // 3) 付款/物流提示
    if (payMethod.isNotEmpty) {
      tips.add('💳 付款方式：$payMethod');
    }
    if (shipMethod.isNotEmpty) {
      tips.add('🚚 配送方式：$shipMethod');
    }

    // 4) 用一點「AI 口吻」但保持可控
    final rng = Random();
    const closings = [
      '需要我幫你追蹤訂單進度也可以～',
      '如果你想要更快收到，可以留意物流更新通知。',
      '有任何問題歡迎到客服中心詢問。',
    ];
    tips.add(closings[rng.nextInt(closings.length)]);

    return tips;
  }

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  // ✅ 修正 prefer_iterable_wheretype：用 whereType<Map>() 取代 where((e) => e is Map)
  List<Map<String, dynamic>> _asList(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  bool _truthy(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes' || s == 'y';
  }
}
