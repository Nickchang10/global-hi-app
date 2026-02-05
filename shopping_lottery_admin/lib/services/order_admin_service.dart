// lib/services/order_admin_service.dart
import 'dart:convert';

/// OrderAdminService
/// - 提供後台匯出 CSV
/// - 給 OrdersPage 用於 downloadCsv('orders_export.csv', csv)
class OrderAdminService {
  /// 將 Firestore 訂單列表轉換為 CSV 字串
  String buildOrdersCsv(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) {
      return 'orderId,status,buyerEmail,total,createdAt\n';
    }

    final headers = [
      'orderId',
      'status',
      'buyerEmail',
      'buyerUid',
      'vendorIds',
      'total',
      'createdAt',
      'paymentMethod',
      'paymentStatus',
      'shippingStatus',
    ];

    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));

    for (final o in orders) {
      final id = o['id'] ?? '';
      final status = o['status'] ?? '';
      final email = o['buyerEmail'] ?? '';
      final uid = o['buyerUid'] ?? '';
      final vendorIds = (o['vendorIds'] is List)
          ? (o['vendorIds'] as List).join('|')
          : (o['vendorId'] ?? '');
      final total = _pickAmount(o);
      final createdAt = _fmtTs(o['createdAt']);
      final p = (o['payment'] ?? {}) as Map?;
      final payMethod = p?['method'] ?? o['paymentMethod'] ?? '';
      final payStatus = p?['status'] ?? '';
      final ship = (o['shipping'] ?? {}) as Map?;
      final shipStatus = ship?['status'] ?? '';

      final row = [
        id,
        status,
        email,
        uid,
        vendorIds,
        total,
        createdAt,
        payMethod,
        payStatus,
        shipStatus,
      ].map((e) => _csvEscape(e.toString())).join(',');

      buffer.writeln(row);
    }

    return buffer.toString();
  }

  String _csvEscape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      v = v.replaceAll('"', '""');
      return '"$v"';
    }
    return v;
  }

  String _fmtTs(dynamic v) {
    if (v == null) return '';
    try {
      if (v.toString().contains('Timestamp')) {
        final millis = int.tryParse(v.toString().replaceAll(RegExp(r'[^0-9]'), ''));
        if (millis != null) {
          final dt = DateTime.fromMillisecondsSinceEpoch(millis);
          return dt.toIso8601String();
        }
      }
      if (v is DateTime) return v.toIso8601String();
      return v.toString();
    } catch (_) {
      return v.toString();
    }
  }

  double _pickAmount(Map<String, dynamic> o) {
    final direct = o['total'] ?? o['amount'];
    if (direct != null) return (num.tryParse('$direct') ?? 0).toDouble();
    if (o['payment'] is Map) {
      final p = Map<String, dynamic>.from(o['payment'] as Map);
      final a = p['amount'];
      return (num.tryParse('$a') ?? 0).toDouble();
    }
    return 0;
  }
}
