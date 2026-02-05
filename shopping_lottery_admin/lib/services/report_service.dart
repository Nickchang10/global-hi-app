// lib/services/report_service.dart
//
// ✅ ReportService（V9 修正版最終完整版）
// ------------------------------------------------------------
// 目標：徹底避免報表頁一直跳：
// [cloud_firestore/failed-precondition] The query requires an index
//
// ✅ 策略：
// - 不再用 whereIn(status) + createdAt range（這組最常逼你建 composite index）
// - 改為「只用 createdAt 區間」查詢，status 改成前端過濾
// - vendor 報表若需要 vendorId 篩選：先嘗試 vendorId + createdAt（若沒 index 會 fallback）
// - 所有查詢都加上 failed-precondition fallback，確保頁面先能載入
//
// 功能：
// 1) getSalesReport({DateTimeRange? range, String? vendorId})
// 2) getRecentDailyRevenue({int days = 14, String? vendorId})
// 3) exportOrders(DateTimeRange range, {String? vendorId})
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ✅ 你系統認定「有營收」的狀態（可自行增減）
  static const List<String> _revenueStatuses = [
    'paid',
    'shipping',
    'completed',
    'shipped', // 有些專案會用 shipped
  ];

  // ===========================================================
  // 1) 取得指定期間的營收報表統計資料
  // ===========================================================
  Future<ReportStats> getSalesReport({
    DateTimeRange? range,
    String? vendorId, // 若是廠商報表可傳入；管理員可不傳
  }) async {
    final now = DateTime.now();

    final start = range?.start ?? DateTime(now.year, now.month, 1);
    final end = range?.end ??
        DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);

    // ✅ 拉指定區間訂單（先只用 createdAt，避免 composite index 爆炸）
    final docs = await _fetchOrdersByCreatedAtRange(
      start: start,
      end: end,
      vendorId: vendorId,
    );

    double periodRevenue = 0;
    int orderCount = 0;

    final Map<String, double> dailyRevenue = {};
    final Map<String, double> vendorRevenue = {};
    final Map<String, double> productSales = {};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final data = doc.data();
      final createdAt = _toDateTime(data['createdAt']);
      if (createdAt == null) continue;

      // ✅ 前端過濾 status（避免 whereIn(status) + createdAt range）
      final status = (data['status'] ?? '').toString();
      if (!_isRevenueStatus(status)) continue;

      // ✅ 若有 vendorId（廠商報表），再做一次保險過濾（fallback 模式時需要）
      if (vendorId != null && vendorId.isNotEmpty) {
        if (!_orderBelongsToVendor(data, vendorId)) continue;
      }

      final amount = _numToDouble(data['finalAmount'] ?? data['amount'] ?? 0);

      periodRevenue += amount;
      orderCount++;

      // 日期字串 yyyy-MM-dd
      final dayKey =
          "${createdAt.year}-${_two(createdAt.month)}-${_two(createdAt.day)}";
      dailyRevenue[dayKey] = (dailyRevenue[dayKey] ?? 0) + amount;

      // 廠商營收（支援 vendorId string / vendorIds list）
      final vendorKeys = _extractVendorIds(data);
      for (final v in vendorKeys) {
        vendorRevenue[v] = (vendorRevenue[v] ?? 0) + amount;
      }

      // 商品銷售統計
      final items = (data['items'] as List?) ?? [];
      for (final item in items) {
        if (item is! Map) continue;
        final name = (item['name'] ?? item['productName'] ?? '').toString();
        if (name.trim().isEmpty) continue;

        final qty = _numToDouble(item['quantity'] ?? item['qty'] ?? 1);
        productSales[name] = (productSales[name] ?? 0) + qty;
      }
    }

    // ✅ 計算本月營收（用於總覽卡片）
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final thisMonthEnd =
        DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);

    final monthDocs = await _fetchOrdersByCreatedAtRange(
      start: thisMonthStart,
      end: thisMonthEnd,
      vendorId: vendorId,
    );

    double monthRevenue = 0;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in monthDocs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString();
      if (!_isRevenueStatus(status)) continue;

      if (vendorId != null && vendorId.isNotEmpty) {
        if (!_orderBelongsToVendor(data, vendorId)) continue;
      }

      monthRevenue += _numToDouble(data['finalAmount'] ?? data['amount'] ?? 0);
    }

    return ReportStats(
      totalRevenue: periodRevenue, // 若你未做全歷史統計，這裡就維持與 periodRevenue 相同
      periodRevenue: periodRevenue,
      monthRevenue: monthRevenue,
      orderCount: orderCount,
      dailyRevenue: _sortMapByKey(dailyRevenue),
      vendorRevenue: vendorRevenue,
      productSales: productSales,
    );
  }

  // ===========================================================
  // 2) 取得最近 N 天每日營收（折線圖）
  // ===========================================================
  Future<Map<String, num>> getRecentDailyRevenue({
    int days = 14,
    String? vendorId,
  }) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final docs = await _fetchOrdersByCreatedAtRange(
      start: start,
      end: end,
      vendorId: vendorId,
    );

    final Map<String, num> result = {};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final data = doc.data();
      final createdAt = _toDateTime(data['createdAt']);
      if (createdAt == null) continue;

      final status = (data['status'] ?? '').toString();
      if (!_isRevenueStatus(status)) continue;

      if (vendorId != null && vendorId.isNotEmpty) {
        if (!_orderBelongsToVendor(data, vendorId)) continue;
      }

      final amount = _numToDouble(data['finalAmount'] ?? data['amount'] ?? 0);
      final dayKey =
          "${createdAt.year}-${_two(createdAt.month)}-${_two(createdAt.day)}";
      result[dayKey] = (result[dayKey] ?? 0) + amount;
    }

    // 補零天數（確保折線圖連續）
    for (int i = 0; i < days; i++) {
      final d = start.add(Duration(days: i));
      final dayKey = "${d.year}-${_two(d.month)}-${_two(d.day)}";
      result.putIfAbsent(dayKey, () => 0);
    }

    return Map.fromEntries(result.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key)));
  }

  // ===========================================================
  // 3) 匯出指定期間內所有訂單資料（for CSV / PDF）
  // ===========================================================
  Future<List<Map<String, dynamic>>> exportOrders(
    DateTimeRange range, {
    String? vendorId,
  }) async {
    final start = range.start;
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
      999,
    );

    final docs = await _fetchOrdersByCreatedAtRange(
      start: start,
      end: end,
      vendorId: vendorId,
    );

    final List<Map<String, dynamic>> orders = [];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final data = doc.data();
      final createdAt = _toDateTime(data['createdAt']);

      final status = (data['status'] ?? '').toString();
      if (!_isRevenueStatus(status)) continue;

      if (vendorId != null && vendorId.isNotEmpty) {
        if (!_orderBelongsToVendor(data, vendorId)) continue;
      }

      orders.add({
        'id': doc.id,
        'orderId': data['orderId'] ?? doc.id,
        'createdAt': createdAt?.toIso8601String(),
        'customerName': data['customerName'] ?? data['userName'] ?? '',
        'finalAmount': _numToDouble(data['finalAmount'] ?? data['amount'] ?? 0),
        'status': status,
        'paymentMethod': data['paymentMethod'] ?? data['payment'] ?? '',
        'couponCode': data['couponCode'] ?? data['coupon'] ?? '',
        'discount': _numToDouble(data['discount'] ?? data['discountAmount'] ?? 0),
        'vendorIds': _extractVendorIds(data),
        'items': (data['items'] as List?) ?? [],
        'shippingFee': _numToDouble(data['shippingFee'] ?? 0),
        'note': data['note'] ?? data['remark'] ?? '',
      });
    }

    // 依 createdAt 排序（避免 query 不 orderBy）
    orders.sort((a, b) {
      final da = a['createdAt']?.toString() ?? '';
      final db = b['createdAt']?.toString() ?? '';
      return db.compareTo(da);
    });

    return orders;
  }

  // ===========================================================
  // Firestore Fetch (with fallback)
  // ===========================================================
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _fetchOrdersByCreatedAtRange({
    required DateTime start,
    required DateTime end,
    String? vendorId,
  }) async {
    final startTs = Timestamp.fromDate(start);
    final endTs = Timestamp.fromDate(end);

    // A) 優先嘗試：vendorId + createdAt range（讀取量最省）
    //    但如果你沒建 index，會丟 failed-precondition
    if (vendorId != null && vendorId.isNotEmpty) {
      try {
        // 優先嘗試單一 vendorId 欄位
        final snap = await _db
            .collection('orders')
            .where('vendorId', isEqualTo: vendorId)
            .where('createdAt', isGreaterThanOrEqualTo: startTs)
            .where('createdAt', isLessThanOrEqualTo: endTs)
            .get();
        return snap.docs;
      } on FirebaseException catch (e) {
        if (e.code != 'failed-precondition') rethrow;
        // fallthrough to try arrayContains or createdAt-only
      } catch (_) {
        // fallthrough
      }

      // 再嘗試 vendorIds arrayContains + createdAt
      try {
        final snap = await _db
            .collection('orders')
            .where('vendorIds', arrayContains: vendorId)
            .where('createdAt', isGreaterThanOrEqualTo: startTs)
            .where('createdAt', isLessThanOrEqualTo: endTs)
            .get();
        return snap.docs;
      } on FirebaseException catch (e) {
        if (e.code != 'failed-precondition') rethrow;
        // fallback below
      } catch (_) {
        // fallback below
      }
    }

    // B) 最保險：只用 createdAt range（幾乎不需要 composite index）
    final snap = await _db
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: startTs)
        .where('createdAt', isLessThanOrEqualTo: endTs)
        .get();

    return snap.docs;
  }

  // ===========================================================
  // Utils
  // ===========================================================
  bool _isRevenueStatus(String status) {
    final s = status.trim().toLowerCase();
    return _revenueStatuses.contains(s);
  }

  bool _orderBelongsToVendor(Map<String, dynamic> data, String vendorId) {
    // 1) 單一 vendorId
    final v1 = data['vendorId'];
    if (v1 is String && v1 == vendorId) return true;

    // 2) vendorIds list
    final v2 = data['vendorIds'];
    if (v2 is List &&
        v2.map((e) => e.toString()).contains(vendorId)) return true;

    // 3) items 裡若有 vendorId（少數資料結構會這樣）
    final items = data['items'];
    if (items is List) {
      for (final it in items) {
        if (it is Map && (it['vendorId']?.toString() == vendorId)) return true;
      }
    }

    return false;
  }

  List<String> _extractVendorIds(Map<String, dynamic> data) {
    final List<String> ids = [];

    final v1 = data['vendorId'];
    if (v1 is String && v1.isNotEmpty) ids.add(v1);

    final v2 = data['vendorIds'];
    if (v2 is List) {
      ids.addAll(v2.map((e) => e.toString()).where((e) => e.isNotEmpty));
    }

    // 去重
    return ids.toSet().toList();
  }

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;

    // 兼容：毫秒 / 秒（某些資料會用 int）
    if (v is int) {
      // 粗略判斷秒/毫秒
      if (v > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(v);
      } else {
        return DateTime.fromMillisecondsSinceEpoch(v * 1000);
      }
    }

    // 兼容：ISO String
    if (v is String) {
      return DateTime.tryParse(v);
    }

    // 兼容：Firebase 常見 toDate() 物件
    try {
      final t = (v as dynamic).toDate();
      if (t is DateTime) return t;
    } catch (_) {}

    return null;
  }

  double _numToDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    try {
      return double.parse(v.toString());
    } catch (_) {
      return 0;
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  Map<String, double> _sortMapByKey(Map<String, double> input) {
    final entries = input.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Map<String, double>.fromEntries(entries);
  }
}

// ===========================================================
// Model
// ===========================================================
class ReportStats {
  final double totalRevenue;
  final double periodRevenue;
  final double monthRevenue;
  final int orderCount;
  final Map<String, double> dailyRevenue;
  final Map<String, double> vendorRevenue;
  final Map<String, double> productSales;

  ReportStats({
    required this.totalRevenue,
    required this.periodRevenue,
    required this.monthRevenue,
    required this.orderCount,
    required this.dailyRevenue,
    required this.vendorRevenue,
    required this.productSales,
  });
}
