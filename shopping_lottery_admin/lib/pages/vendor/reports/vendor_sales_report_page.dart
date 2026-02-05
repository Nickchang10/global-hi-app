// lib/pages/vendor/reports/vendor_sales_report_page.dart
//
// ✅ VendorSalesReportPage（最終完整版｜Vendor 銷售報表｜僅自己的營收）
// ------------------------------------------------------------
// - 優先讀 reports_sales_vendor（建議由 Cloud Function 建立）
//   欄位建議：vendorId, date(yyyy-MM-dd), revenue, orderCount, updatedAt
// - 若 reports_sales_vendor 為空：fallback 從 orders 近 N 天計算（arrayContains vendorId）
//
// 注意：若用 fallback（從 orders 計算），資料量大會變慢；上線建議用 reports_sales_vendor。
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VendorSalesReportPage extends StatefulWidget {
  final String vendorId;

  const VendorSalesReportPage({
    super.key,
    required this.vendorId,
  });

  @override
  State<VendorSalesReportPage> createState() => _VendorSalesReportPageState();
}

class _VendorSalesReportPageState extends State<VendorSalesReportPage> {
  final _moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

  int _rangeDays = 30;

  num _num(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  int _int(dynamic v, {int fallback = 1}) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  DateTime get _since => DateTime.now().subtract(Duration(days: _rangeDays));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('銷售報表（Vendor）', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildRangeBar(),
          const Divider(height: 1),
          Expanded(child: _buildReportBody()),
        ],
      ),
    );
  }

  Widget _buildRangeBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('區間', style: TextStyle(fontWeight: FontWeight.w900)),
          ChoiceChip(
            label: const Text('7 天'),
            selected: _rangeDays == 7,
            onSelected: (_) => setState(() => _rangeDays = 7),
          ),
          ChoiceChip(
            label: const Text('30 天'),
            selected: _rangeDays == 30,
            onSelected: (_) => setState(() => _rangeDays = 30),
          ),
          ChoiceChip(
            label: const Text('90 天'),
            selected: _rangeDays == 90,
            onSelected: (_) => setState(() => _rangeDays = 90),
          ),
          Text(
            '（從 ${DateFormat('yyyy/MM/dd').format(_since)} 起）',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildReportBody() {
    // 先試 reports_sales_vendor
    final q = FirebaseFirestore.instance
        .collection('reports_sales_vendor')
        .where('vendorId', isEqualTo: widget.vendorId)
        .orderBy('date', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          // 若你還沒建立 index 或集合，改走 fallback
          return _buildFallbackFromOrders();
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        // 如果集合存在但沒資料，走 fallback（先可用）
        if (docs.isEmpty) {
          return _buildFallbackFromOrders();
        }

        // 依區間過濾 date
        final sinceStr = DateFormat('yyyy-MM-dd').format(_since);
        final filtered = docs.where((d) {
          final m = (d.data() as Map?)?.cast<String, dynamic>() ?? {};
          final date = (m['date'] ?? '').toString(); // yyyy-MM-dd
          return date.compareTo(sinceStr) >= 0;
        }).toList();

        if (filtered.isEmpty) {
          return const Center(child: Text('此區間沒有報表資料'));
        }

        num totalRevenue = 0;
        int totalOrders = 0;

        final rows = filtered.map((d) {
          final m = (d.data() as Map?)?.cast<String, dynamic>() ?? {};
          final date = (m['date'] ?? '').toString();
          final revenue = _num(m['revenue']);
          final orderCount = _int(m['orderCount'], fallback: 0);
          totalRevenue += revenue;
          totalOrders += orderCount;
          return _ReportRow(date: date, revenue: revenue, orderCount: orderCount);
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _summaryCard(totalRevenue: totalRevenue, totalOrders: totalOrders, source: 'reports_sales_vendor'),
            const SizedBox(height: 12),
            ...rows.map(_rowTile),
          ],
        );
      },
    );
  }

  // fallback：從 orders 計算近 N 天（只算自己的 items 小計）
  Widget _buildFallbackFromOrders() {
    final q = FirebaseFirestore.instance
        .collection('orders')
        .where('vendorIds', arrayContains: widget.vendorId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_since))
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('讀取訂單失敗（可能缺少 Index）'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('此區間沒有訂單資料'));
        }

        // 聚合：date => (revenue, orders)
        final map = <String, _Agg>{};

        for (final d in docs) {
          final m = (d.data() as Map?)?.cast<String, dynamic>() ?? {};
          final createdAt = m['createdAt'] is Timestamp ? (m['createdAt'] as Timestamp).toDate() : null;
          if (createdAt == null) continue;

          final dateKey = DateFormat('yyyy-MM-dd').format(createdAt);

          final items = (m['items'] is List) ? (m['items'] as List) : const [];
          final mySubtotal = _calcMySubtotal(items, widget.vendorId);

          // 只統計「可認列營收」狀態（你可依需求調整）
          final status = (m['status'] ?? '').toString();
          final countable = ['paid', 'shipping', 'completed'].contains(status);
          if (!countable) continue;

          map.putIfAbsent(dateKey, () => _Agg());
          map[dateKey]!.revenue += mySubtotal;
          map[dateKey]!.orders += 1;
        }

        final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
        if (keys.isEmpty) {
          return const Center(child: Text('此區間沒有可統計的營收（paid/shipping/completed）'));
        }

        num totalRevenue = 0;
        int totalOrders = 0;

        final rows = keys.map((k) {
          final a = map[k]!;
          totalRevenue += a.revenue;
          totalOrders += a.orders;
          return _ReportRow(date: k, revenue: a.revenue, orderCount: a.orders);
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _summaryCard(totalRevenue: totalRevenue, totalOrders: totalOrders, source: 'orders(fallback)'),
            const SizedBox(height: 12),
            ...rows.map(_rowTile),
            const SizedBox(height: 10),
            Text(
              '提示：建議由 Cloud Function 在 paymentSuccess 建立 reports_sales_vendor，可大幅提升效能。',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
        );
      },
    );
  }

  num _calcMySubtotal(List items, String myVendorId) {
    num sum = 0;
    for (final it in items) {
      if (it is! Map) continue;
      final m = Map<String, dynamic>.from(it as Map);
      final vid = (m['vendorId'] ?? '').toString();
      if (vid != myVendorId) continue;
      final price = _num(m['price']);
      final qty = _int(m['qty'] ?? m['quantity'] ?? 1, fallback: 1);
      sum += price * qty;
    }
    return sum;
  }

  Widget _summaryCard({
    required num totalRevenue,
    required int totalOrders,
    required String source,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('總覽', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            _kv('總營收（我的）', _moneyFmt.format(totalRevenue), highlight: true),
            _kv('訂單數', totalOrders.toString()),
            const SizedBox(height: 6),
            Text('資料來源：$source', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _rowTile(_ReportRow r) {
    return Card(
      child: ListTile(
        title: Text(r.date, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('訂單數：${r.orderCount}'),
        trailing: Text(
          _moneyFmt.format(r.revenue),
          style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k)),
          Text(
            v,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.w900 : FontWeight.normal,
              color: highlight ? Colors.redAccent : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Agg {
  num revenue = 0;
  int orders = 0;
}

class _ReportRow {
  final String date; // yyyy-MM-dd
  final num revenue;
  final int orderCount;

  _ReportRow({
    required this.date,
    required this.revenue,
    required this.orderCount,
  });
}
