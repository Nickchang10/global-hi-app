// lib/services/dashboard_service.dart
//
// ✅ DashboardService（最終可編譯完整版｜修正 dead_code）
// ------------------------------------------------------------
// - 提供 Admin / Vendor 儀表板 KPI、趨勢、最近訂單
// - 僅依賴 cloud_firestore
// - 提供 Future 讀取 + 輪詢 Stream（不用 rxdart）
//
// Firestore 預設集合（可在 constructor 覆蓋）：
// - orders, users, products, campaigns, coupons, notifications, support_tasks, warranties
//
// 訂單欄位（容錯）：
// - createdAt / updatedAt / paidAt (Timestamp/DateTime)
// - total / amount / grandTotal / priceTotal (num)
// - vendorId (for vendor filter)
// - status / payment.status (paid/success/cod...)
// ------------------------------------------------------------

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardService {
  final FirebaseFirestore _db;

  final String ordersCol;
  final String usersCol;
  final String productsCol;
  final String campaignsCol;
  final String couponsCol;
  final String notificationsCol;
  final String supportTasksCol;
  final String warrantiesCol;

  DashboardService({
    FirebaseFirestore? db,
    this.ordersCol = 'orders',
    this.usersCol = 'users',
    this.productsCol = 'products',
    this.campaignsCol = 'campaigns',
    this.couponsCol = 'coupons',
    this.notificationsCol = 'notifications',
    this.supportTasksCol = 'support_tasks',
    this.warrantiesCol = 'warranties',
  }) : _db = db ?? FirebaseFirestore.instance;

  // ===========================================================
  // Public APIs (Future)
  // ===========================================================

  /// Admin 總覽
  Future<DashboardSummary> loadAdminSummary({
    DateTime? from,
    DateTime? to,
    int recentOrdersLimit = 10,
    int maxOrdersForScan = 2000,
  }) async {
    final range = _normalizeRange(from: from, to: to);
    return _buildSummary(
      vendorId: null,
      from: range.from,
      to: range.to,
      recentOrdersLimit: recentOrdersLimit,
      maxOrdersForScan: maxOrdersForScan,
    );
  }

  /// Vendor 總覽
  Future<DashboardSummary> loadVendorSummary({
    required String vendorId,
    DateTime? from,
    DateTime? to,
    int recentOrdersLimit = 10,
    int maxOrdersForScan = 2000,
  }) async {
    final vid = vendorId.trim();
    final range = _normalizeRange(from: from, to: to);
    return _buildSummary(
      vendorId: vid.isEmpty ? null : vid,
      from: range.from,
      to: range.to,
      recentOrdersLimit: recentOrdersLimit,
      maxOrdersForScan: maxOrdersForScan,
    );
  }

  /// 兼容用：回 Map（很多舊 UI 喜歡直接吃 Map）
  Future<Map<String, dynamic>> loadAdminDashboard({
    DateTime? from,
    DateTime? to,
  }) async {
    final s = await loadAdminSummary(from: from, to: to);
    return s.toMap();
  }

  Future<Map<String, dynamic>> loadVendorDashboard({
    required String vendorId,
    DateTime? from,
    DateTime? to,
  }) async {
    final s = await loadVendorSummary(vendorId: vendorId, from: from, to: to);
    return s.toMap();
  }

  // ===========================================================
  // Public APIs (Polling Stream)
  // ===========================================================

  /// 不用 rxdart，直接輪詢（預設 15 秒）更新一次
  Stream<DashboardSummary> streamAdminSummary({
    DateTime? from,
    DateTime? to,
    Duration interval = const Duration(seconds: 15),
  }) {
    final range = _normalizeRange(from: from, to: to);
    return Stream.periodic(interval)
        .asyncMap((_) {
          return loadAdminSummary(from: range.from, to: range.to);
        })
        .startWith(loadAdminSummary(from: range.from, to: range.to));
  }

  Stream<DashboardSummary> streamVendorSummary({
    required String vendorId,
    DateTime? from,
    DateTime? to,
    Duration interval = const Duration(seconds: 15),
  }) {
    final range = _normalizeRange(from: from, to: to);
    return Stream.periodic(interval)
        .asyncMap((_) {
          return loadVendorSummary(
            vendorId: vendorId,
            from: range.from,
            to: range.to,
          );
        })
        .startWith(
          loadVendorSummary(vendorId: vendorId, from: range.from, to: range.to),
        );
  }

  // ===========================================================
  // Core Builder (NO dead code)
  // ===========================================================

  Future<DashboardSummary> _buildSummary({
    required String? vendorId,
    required DateTime from,
    required DateTime to,
    required int recentOrdersLimit,
    required int maxOrdersForScan,
  }) async {
    // 1) 並行抓「計數型」資料（不需要掃大量訂單）
    final futures = await Future.wait<_PartResult>([
      _countUsers(),
      _countProducts(vendorId: vendorId),
      _countCampaigns(vendorId: vendorId),
      _countCoupons(vendorId: vendorId),
      _countSupportTasks(vendorId: vendorId),
      _countWarranties(vendorId: vendorId),
      _countUnreadNotifications(vendorId: vendorId),
    ]);

    final counts = <String, int>{};
    for (final p in futures) {
      counts[p.key] = p.value;
    }

    // 2) 訂單（需要掃描一段時間內的訂單做營收/趨勢）
    final orderScan = await _scanOrdersForKpis(
      vendorId: vendorId,
      from: from,
      to: to,
      limit: maxOrdersForScan,
    );

    // 3) 最近訂單（列表顯示）
    final recentOrders = await _fetchRecentOrders(
      vendorId: vendorId,
      limit: recentOrdersLimit,
    );

    return DashboardSummary(
      vendorId: vendorId ?? '',
      from: from,
      to: to,
      usersCount: counts['users'] ?? 0,
      productsCount: counts['products'] ?? 0,
      campaignsCount: counts['campaigns'] ?? 0,
      couponsCount: counts['coupons'] ?? 0,
      openSupportTasks: counts['support'] ?? 0,
      pendingWarranties: counts['warranties'] ?? 0,
      unreadNotifications: counts['unreadNotifications'] ?? 0,
      ordersCount: orderScan.ordersCount,
      revenue: orderScan.revenue,
      ordersSeries: orderScan.ordersSeries,
      revenueSeries: orderScan.revenueSeries,
      recentOrders: recentOrders,
    );
  }

  // ===========================================================
  // Counts
  // ===========================================================

  Future<_PartResult> _countUsers() async {
    try {
      final snap = await _db.collection(usersCol).count().get();
      return _PartResult('users', snap.count ?? 0);
    } catch (_) {
      // fallback：舊版 Firebase SDK 沒 count() 時
      final snap = await _db.collection(usersCol).limit(1000).get();
      return _PartResult('users', snap.size);
    }
  }

  Future<_PartResult> _countProducts({required String? vendorId}) async {
    Query<Map<String, dynamic>> q = _db.collection(productsCol);
    if ((vendorId ?? '').isNotEmpty) {
      q = q.where('vendorId', isEqualTo: vendorId);
    }
    return _safeCount(q, 'products');
  }

  Future<_PartResult> _countCampaigns({required String? vendorId}) async {
    Query<Map<String, dynamic>> q = _db.collection(campaignsCol);
    if ((vendorId ?? '').isNotEmpty) {
      q = q.where('vendorId', isEqualTo: vendorId);
    }
    // 常見做法：active/paused 才算在跑
    // 但這裡不強制（避免你 schema 不一致），先統計全部
    return _safeCount(q, 'campaigns');
  }

  Future<_PartResult> _countCoupons({required String? vendorId}) async {
    Query<Map<String, dynamic>> q = _db.collection(couponsCol);
    if ((vendorId ?? '').isNotEmpty) {
      q = q.where('vendorId', isEqualTo: vendorId);
    }
    return _safeCount(q, 'coupons');
  }

  Future<_PartResult> _countSupportTasks({required String? vendorId}) async {
    Query<Map<String, dynamic>> q = _db.collection(supportTasksCol);

    // 常見：status=open / pending
    // 如果你有 status 欄位，會更準；沒有也不會壞
    q = q.where('status', whereIn: const ['open', 'pending']);

    if ((vendorId ?? '').isNotEmpty) {
      q = q.where('vendorId', isEqualTo: vendorId);
    }
    return _safeCount(q, 'support');
  }

  Future<_PartResult> _countWarranties({required String? vendorId}) async {
    Query<Map<String, dynamic>> q = _db.collection(warrantiesCol);

    // 常見：status=pending / reviewing
    q = q.where('status', whereIn: const ['pending', 'reviewing']);

    if ((vendorId ?? '').isNotEmpty) {
      q = q.where('vendorId', isEqualTo: vendorId);
    }
    return _safeCount(q, 'warranties');
  }

  Future<_PartResult> _countUnreadNotifications({
    required String? vendorId,
  }) async {
    Query<Map<String, dynamic>> q = _db.collection(notificationsCol);

    // 常見：read=false 或 isRead=false
    // 用 OR 很難（Firestore 限制），所以採用容錯：先抓 read=false
    q = q.where('read', isEqualTo: false);

    if ((vendorId ?? '').isNotEmpty) {
      // 若你通知是 vendor scope
      q = q.where('vendorId', isEqualTo: vendorId);
    }

    // 若你 schema 用 isRead，可自行改成 isRead=false
    return _safeCount(q, 'unreadNotifications');
  }

  Future<_PartResult> _safeCount(
    Query<Map<String, dynamic>> q,
    String key,
  ) async {
    try {
      final snap = await q.count().get();
      return _PartResult(key, snap.count ?? 0);
    } catch (_) {
      final snap = await q.limit(1000).get();
      return _PartResult(key, snap.size);
    }
  }

  // ===========================================================
  // Orders scan for KPI & trend
  // ===========================================================

  Future<_OrderScanResult> _scanOrdersForKpis({
    required String? vendorId,
    required DateTime from,
    required DateTime to,
    required int limit,
  }) async {
    Query<Map<String, dynamic>> q = _db.collection(ordersCol);

    if ((vendorId ?? '').isNotEmpty) {
      q = q.where('vendorId', isEqualTo: vendorId);
    }

    // 以 createdAt 篩選區間（若你用 paidAt 可改）
    q = q
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('createdAt', descending: true)
        .limit(limit);

    final snap = await q.get();

    double revenue = 0.0;
    int ordersCount = 0;

    // 以 day bucket 做趨勢（粗粒度）
    final ordersByDay = <String, int>{};
    final revenueByDay = <String, double>{};

    for (final doc in snap.docs) {
      final data = doc.data();

      // 只計入「看起來已付款/成功/cod」的單（容錯）
      if (!_isOrderCountable(data)) continue;

      ordersCount += 1;

      final amount = _pickAmount(data);
      revenue += amount;

      final createdAt = _pickOrderTime(data) ?? from;
      final key = _ymd(createdAt);

      ordersByDay[key] = (ordersByDay[key] ?? 0) + 1;
      revenueByDay[key] = (revenueByDay[key] ?? 0) + amount;
    }

    // 補齊 range 每一天（UI 會比較漂亮）
    final days = _allDays(from, to);
    final ordersSeries = <TimeSeriesPoint>[];
    final revenueSeries = <TimeSeriesPoint>[];

    for (final d in days) {
      final k = _ymd(d);
      ordersSeries.add(
        TimeSeriesPoint(date: d, value: (ordersByDay[k] ?? 0).toDouble()),
      );
      revenueSeries.add(
        TimeSeriesPoint(date: d, value: (revenueByDay[k] ?? 0.0)),
      );
    }

    return _OrderScanResult(
      ordersCount: ordersCount,
      revenue: revenue,
      ordersSeries: ordersSeries,
      revenueSeries: revenueSeries,
    );
  }

  bool _isOrderCountable(Map<String, dynamic> order) {
    final status = _s(order['status']).toLowerCase();

    final payment = _asMap(order['payment']);
    final pStatus = _s(payment['status']).toLowerCase();
    final provider = _s(payment['provider']).toLowerCase();
    final method = _s(payment['method']).toLowerCase();

    final isPaid =
        status == 'paid' ||
        const ['paid', 'success', 'succeeded', 'completed'].contains(pStatus);

    final isCod =
        status.contains('cod') ||
        pStatus == 'cod' ||
        provider == 'cod' ||
        method == 'cash';

    // 若你希望「所有訂單都算」可直接 return true
    return isPaid || isCod;
  }

  double _pickAmount(Map<String, dynamic> order) {
    final candidates = [
      order['total'],
      order['amount'],
      order['grandTotal'],
      order['priceTotal'],
      _asMap(order['pricing'])['total'],
      _asMap(order['pricing'])['grandTotal'],
    ];

    for (final v in candidates) {
      final n = _toNum(v);
      if (n != null) return n.toDouble();
    }
    return 0.0;
  }

  DateTime? _pickOrderTime(Map<String, dynamic> order) {
    final candidates = [
      order['createdAt'],
      order['paidAt'],
      order['updatedAt'],
    ];
    for (final v in candidates) {
      final d = _toDate(v);
      if (d != null) return d;
    }
    return null;
  }

  // ===========================================================
  // Recent orders
  // ===========================================================

  Future<List<RecentOrder>> _fetchRecentOrders({
    required String? vendorId,
    required int limit,
  }) async {
    Query<Map<String, dynamic>> q = _db.collection(ordersCol);

    if ((vendorId ?? '').isNotEmpty) {
      q = q.where('vendorId', isEqualTo: vendorId);
    }

    // 以 createdAt 排序（若你用 created_at 可改）
    q = q.orderBy('createdAt', descending: true).limit(limit);

    final snap = await q.get();
    return snap.docs.map((d) {
      final data = d.data();
      return RecentOrder(
        id: d.id,
        status: _s(data['status']),
        amount: _pickAmount(data),
        createdAt: _pickOrderTime(data),
        buyerName: _s(_asMap(data['buyer'])['name']),
        buyerPhone: _s(_asMap(data['buyer'])['phone']),
      );
    }).toList();
  }

  // ===========================================================
  // Helpers
  // ===========================================================

  _Range _normalizeRange({DateTime? from, DateTime? to}) {
    final now = DateTime.now();
    final end = (to ?? now);
    final start = (from ?? end.subtract(const Duration(days: 30)));

    // normalize to day boundaries
    final s = DateTime(start.year, start.month, start.day, 0, 0, 0);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59);

    return _Range(from: s, to: e);
  }

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  static num? _toNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim());
    return null;
  }

  static DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static String _ymd(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  static List<DateTime> _allDays(DateTime from, DateTime to) {
    final list = <DateTime>[];
    var cur = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    while (!cur.isAfter(end)) {
      list.add(cur);
      cur = cur.add(const Duration(days: 1));
    }
    return list;
  }
}

// =============================================================
// Data Models for dashboard
// =============================================================

class DashboardSummary {
  final String vendorId;
  final DateTime from;
  final DateTime to;

  final int usersCount;
  final int productsCount;
  final int campaignsCount;
  final int couponsCount;
  final int openSupportTasks;
  final int pendingWarranties;
  final int unreadNotifications;

  final int ordersCount;
  final double revenue;

  final List<TimeSeriesPoint> ordersSeries;
  final List<TimeSeriesPoint> revenueSeries;

  final List<RecentOrder> recentOrders;

  const DashboardSummary({
    required this.vendorId,
    required this.from,
    required this.to,
    required this.usersCount,
    required this.productsCount,
    required this.campaignsCount,
    required this.couponsCount,
    required this.openSupportTasks,
    required this.pendingWarranties,
    required this.unreadNotifications,
    required this.ordersCount,
    required this.revenue,
    required this.ordersSeries,
    required this.revenueSeries,
    required this.recentOrders,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'vendorId': vendorId,
    'from': from.toIso8601String(),
    'to': to.toIso8601String(),
    'usersCount': usersCount,
    'productsCount': productsCount,
    'campaignsCount': campaignsCount,
    'couponsCount': couponsCount,
    'openSupportTasks': openSupportTasks,
    'pendingWarranties': pendingWarranties,
    'unreadNotifications': unreadNotifications,
    'ordersCount': ordersCount,
    'revenue': revenue,
    'ordersSeries': ordersSeries.map((e) => e.toMap()).toList(),
    'revenueSeries': revenueSeries.map((e) => e.toMap()).toList(),
    'recentOrders': recentOrders.map((e) => e.toMap()).toList(),
  };
}

class TimeSeriesPoint {
  final DateTime date;
  final double value;

  const TimeSeriesPoint({required this.date, required this.value});

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'value': value,
  };
}

class RecentOrder {
  final String id;
  final String status;
  final double amount;
  final DateTime? createdAt;

  final String buyerName;
  final String buyerPhone;

  const RecentOrder({
    required this.id,
    required this.status,
    required this.amount,
    required this.createdAt,
    required this.buyerName,
    required this.buyerPhone,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'status': status,
    'amount': amount,
    'createdAt': createdAt?.toIso8601String(),
    'buyerName': buyerName,
    'buyerPhone': buyerPhone,
  };
}

// =============================================================
// Internal structs
// =============================================================

class _PartResult {
  final String key;
  final int value;
  const _PartResult(this.key, this.value);
}

class _OrderScanResult {
  final int ordersCount;
  final double revenue;
  final List<TimeSeriesPoint> ordersSeries;
  final List<TimeSeriesPoint> revenueSeries;

  const _OrderScanResult({
    required this.ordersCount,
    required this.revenue,
    required this.ordersSeries,
    required this.revenueSeries,
  });
}

class _Range {
  final DateTime from;
  final DateTime to;
  const _Range({required this.from, required this.to});
}

// =============================================================
// Stream extension: startWith (避免引入 rxdart)
// =============================================================
extension _StartWithExt<T> on Stream<T> {
  Stream<T> startWith(Future<T> first) async* {
    yield await first;
    yield* this;
  }
}
