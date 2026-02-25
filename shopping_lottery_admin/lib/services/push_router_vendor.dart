// lib/services/push_router_vendor.dart
import 'package:flutter/material.dart';

import '../pages/vendor/orders/vendor_order_detail_gate.dart';
import '../pages/vendor/reports/vendor_sales_report_gate.dart';

/// ✅ Vendor 端路由集中管理（避免 .routeName 缺失造成編譯錯）
///
/// 用法：
/// 1) MaterialApp routes 合併：
///    routes: {
///      ...PushRouterVendor.routes,
///      // 你的其他 routes...
///    }
///
/// 2) 導頁：
///    PushRouterVendor.toOrderDetail(context, orderId: 'xxx');
///    PushRouterVendor.toSalesReport(context, vendorId: 'yyy');
class PushRouterVendor {
  /// 建議固定路由字串，不依賴 page static routeName
  static const String orderDetailRoute = '/vendor/orderDetail';
  static const String salesReportRoute = '/vendor/salesReport';

  /// 給 MaterialApp routes 用
  static Map<String, WidgetBuilder> get routes => {
    orderDetailRoute: (_) => const VendorOrderDetailGate(),
    salesReportRoute: (_) => const VendorSalesReportGate(),
  };

  /// ✅ 前往訂單明細
  static Future<T?> toOrderDetail<T>(
    BuildContext context, {
    required String orderId,
  }) {
    return Navigator.of(
      context,
    ).pushNamed<T>(orderDetailRoute, arguments: {'orderId': orderId});
  }

  /// ✅ 前往銷售報表（vendorId 可選；Gate 內也會 fallback 取 currentUser.uid）
  static Future<T?> toSalesReport<T>(BuildContext context, {String? vendorId}) {
    return Navigator.of(context).pushNamed<T>(
      salesReportRoute,
      arguments: vendorId == null ? null : {'vendorId': vendorId},
    );
  }

  /// ✅（可選）用於推播 payload 導頁
  /// 支援 payload 範例：
  /// { "type": "order_detail", "orderId": "xxx" }
  /// { "type": "sales_report", "vendorId": "yyy" }
  static bool handlePushPayload(
    BuildContext context,
    Map<String, dynamic> payload,
  ) {
    final type = (payload['type'] ?? payload['action'] ?? '').toString();

    if (type == 'order_detail' || type == 'vendor_order_detail') {
      final orderId = _pickString(payload, const ['orderId', 'order_id', 'id']);
      if (orderId == null || orderId.isEmpty) return false;
      toOrderDetail(context, orderId: orderId);
      return true;
    }

    if (type == 'sales_report' || type == 'vendor_sales_report') {
      final vendorId = _pickString(payload, const [
        'vendorId',
        'vendor_id',
        'id',
      ]);
      toSalesReport(context, vendorId: vendorId);
      return true;
    }

    return false;
  }

  static String? _pickString(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }
}
