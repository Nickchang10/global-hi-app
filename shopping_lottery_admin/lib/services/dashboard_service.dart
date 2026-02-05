import 'package:cloud_firestore/cloud_firestore.dart';

/// Dashboard 統計資料（可直接轉 Map 給 UI 使用）
class DashboardStats {
  final int products;
  final int orders;
  final int coupons;
  final int campaigns;
  final int lotteries;
  final int customers;
  final int unreadNotifications;

  /// 只有主後台通常需要
  final int vendors;

  const DashboardStats({
    required this.products,
    required this.orders,
    required this.coupons,
    required this.campaigns,
    required this.lotteries,
    required this.customers,
    required this.unreadNotifications,
    this.vendors = 0,
  });

  Map<String, int> toMap() => {
        'products': products,
        'orders': orders,
        'coupons': coupons,
        'campaigns': campaigns,
        'lotteries': lotteries,
        'customers': customers,
        'unread': unreadNotifications,
        'vendors': vendors,
      };
}

/// 可選：統一管理集合名稱（避免你之後改 collection name 很痛）
class DashboardCollections {
  final String products;
  final String orders;
  final String coupons;
  final String campaigns;
  final String lotteries;
  final String vendors;
  final String users;
  final String notifications;

  const DashboardCollections({
    this.products = 'products',
    this.orders = 'orders',
    this.coupons = 'coupons',
    this.campaigns = 'campaigns',
    this.lotteries = 'lotteries',
    this.vendors = 'vendors',
    this.users = 'users',
    this.notifications = 'notifications',
  });
}

/// DashboardService（主後台/廠商後台共用）
///
/// - vendorId == null：全站（主後台）
/// - vendorId != null：該廠商（廠商後台）
///
/// 注意：
/// 1) 要讓 vendor 篩選正確運作，products/orders/coupons/campaigns/lotteries/notifications 這些集合內
///    建議都有 vendorId 欄位。
/// 2) customers 的計算提供兩種模式：
///    A) users 集合本身有 vendorId 欄位（最省成本）
///    B) 若 users 沒 vendorId，會 fallback 用 orders 的 buyerId 做「去重估算」（會讀取一定量的訂單，適合量不大的情況）
///       量大建議改成：vendors/{vendorId}/customers 或 vendor_stats 聚合表 + Cloud Functions。
class DashboardService {
  DashboardService({
    FirebaseFirestore? db,
    DashboardCollections? collections,
  })  : _db = db ?? FirebaseFirestore.instance,
        col = collections ?? const DashboardCollections();

  final FirebaseFirestore _db;
  final DashboardCollections col;

  // -------------------------
  // Public APIs
  // -------------------------

  /// 主後台（全站）統計
  Future<DashboardStats> getAdminStats({
    DateTime? createdAfter,
    DateTime? createdBefore,
  }) async {
    final products = await countDocs(col.products);
    final orders = await countDocs(
      col.orders,
      createdAfter: createdAfter,
      createdBefore: createdBefore,
    );
    final coupons = await countDocs(col.coupons);
    final campaigns = await countDocs(col.campaigns);
    final lotteries = await countDocs(col.lotteries);
    final vendors = await countDocs(col.vendors);

    // customers（全站）：通常就是 users 數量
    final customers = await countDocs(col.users);

    // unread notifications（全站）：若你 notifications 有 read 欄位
    final unread = await countDocs(
      col.notifications,
      equals: const {'read': false},
    );

    return DashboardStats(
      products: products,
      orders: orders,
      coupons: coupons,
      campaigns: campaigns,
      lotteries: lotteries,
      customers: customers,
      unreadNotifications: unread,
      vendors: vendors,
    );
  }

  /// 廠商後台（指定 vendor）統計
  Future<DashboardStats> getVendorStats({
    required String vendorId,
    DateTime? createdAfter,
    DateTime? createdBefore,
    bool customersPreferUsersVendorIdField = true,
    int customersFallbackMaxOrdersToScan = 2000,
  }) async {
    final products = await countDocs(col.products, vendorId: vendorId);
    final orders = await countDocs(
      col.orders,
      vendorId: vendorId,
      createdAfter: createdAfter,
      createdBefore: createdBefore,
    );
    final coupons = await countDocs(col.coupons, vendorId: vendorId);
    final campaigns = await countDocs(col.campaigns, vendorId: vendorId);
    final lotteries = await countDocs(col.lotteries, vendorId: vendorId);

    final unread = await countDocs(
      col.notifications,
      vendorId: vendorId,
      equals: const {'read': false},
    );

    final customers = await _countCustomersForVendor(
      vendorId: vendorId,
      preferUsersVendorIdField: customersPreferUsersVendorIdField,
      maxOrdersToScan: customersFallbackMaxOrdersToScan,
      createdAfter: createdAfter,
      createdBefore: createdBefore,
    );

    return DashboardStats(
      products: products,
      orders: orders,
      coupons: coupons,
      campaigns: campaigns,
      lotteries: lotteries,
      customers: customers,
      unreadNotifications: unread,
      vendors: 0,
    );
  }

  /// 通用文件數量統計（支援 vendorId + equals + createdAt 篩選）
  Future<int> countDocs(
    String collection, {
    String? vendorId,
    Map<String, Object?> equals = const {},
    DateTime? createdAfter,
    DateTime? createdBefore,
    String createdAtField = 'createdAt',
    bool applyVendorFilter = true,
  }) async {
    Query<Map<String, dynamic>> q = _db.collection(collection);

    if (applyVendorFilter && vendorId != null) {
      q = q.where('vendorId', isEqualTo: vendorId);
    }

    // equals filters
    equals.forEach((k, v) {
      q = q.where(k, isEqualTo: v);
    });

    // createdAt range filters (optional)
    if (createdAfter != null) {
      q = q.where(
        createdAtField,
        isGreaterThanOrEqualTo: Timestamp.fromDate(createdAfter),
      );
    }
    if (createdBefore != null) {
      q = q.where(
        createdAtField,
        isLessThanOrEqualTo: Timestamp.fromDate(createdBefore),
      );
    }

    return _countQuery(q);
  }

  // -------------------------
  // Internal helpers
  // -------------------------

  /// Firestore Aggregate count()（若環境/版本不支援則 fallback 用 get() 取 size）
  Future<int> _countQuery(Query<Map<String, dynamic>> q) async {
    try {
      final agg = await q.count().get();
      return agg.count;
    } catch (_) {
      // fallback：避免 count() 在某些版本/平台不支援造成崩潰
      final snap = await q.get();
      return snap.size;
    }
  }

  /// 廠商顧客數計算
  ///
  /// 優先策略：
  /// A) users 集合有 vendorId：users.where(vendorId == xxx).count()
  /// B) fallback：orders.where(vendorId==xxx) 讀取 buyerId 去重（只掃描 maxOrdersToScan 筆）
  Future<int> _countCustomersForVendor({
    required String vendorId,
    required bool preferUsersVendorIdField,
    required int maxOrdersToScan,
    DateTime? createdAfter,
    DateTime? createdBefore,
  }) async {
    if (preferUsersVendorIdField) {
      // 若你們 users 本身就有 vendorId：最省成本、最準
      try {
        return await countDocs(
          col.users,
          vendorId: vendorId,
          applyVendorFilter: true,
        );
      } catch (_) {
        // 若 users 沒 vendorId 索引/欄位，會丟錯；就走 fallback
      }
    }

    // fallback：用 orders 的 buyerId 去重估算（需要 orders 有 buyerId 欄位）
    // 注意：這會讀取訂單文件；量大時請改做 vendor_customers 或聚合表。
    Query<Map<String, dynamic>> q = _db.collection(col.orders).where('vendorId', isEqualTo: vendorId);

    if (createdAfter != null) {
      q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(createdAfter));
    }
    if (createdBefore != null) {
      q = q.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(createdBefore));
    }

    // 若你 orders 有 createdAt，建議排序讓分頁一致
    q = q.orderBy('createdAt', descending: true).limit(maxOrdersToScan);

    final snap = await q.get();
    final set = <String>{};

    for (final doc in snap.docs) {
      final data = doc.data();
      final buyerId = data['buyerId'];
      if (buyerId is String && buyerId.isNotEmpty) {
        set.add(buyerId);
      }
    }

    return set.length;
  }
}
