// lib/pages/vendor/reports/vendor_sales_report_gate.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ VendorSalesReportGate（最終可編譯｜移除 Unnecessary cast）
/// - 從 route args 取 vendorId；若沒有就 fallback 用 FirebaseAuth.currentUser.uid
/// - 直接顯示銷售報表（避免 vendorId 參數不存在問題）
///
/// ✅ 支援 arguments：
/// 1) String vendorId
/// 2) {'vendorId': 'xxx'}
/// 3) {'id': 'xxx'}（容錯）
class VendorSalesReportGate extends StatelessWidget {
  const VendorSalesReportGate({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    String? vendorId;

    if (args is String) {
      vendorId = args;
    } else if (args is Map<String, dynamic>) {
      // ✅ 不需要 cast
      vendorId = (args['vendorId'] ?? args['id'])?.toString();
    } else if (args is Map) {
      // ✅ 容錯：如果外部傳的是 Map 但不是強型別
      final map = Map<String, dynamic>.from(args);
      vendorId = (map['vendorId'] ?? map['id'])?.toString();
    }

    vendorId ??= FirebaseAuth.instance.currentUser?.uid;

    if (vendorId == null || vendorId.trim().isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('銷售報表')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('缺少 vendorId（且未登入），無法開啟銷售報表。'),
          ),
        ),
      );
    }

    return _VendorSalesReportScreen(vendorId: vendorId);
  }
}

class _VendorSalesReportScreen extends StatefulWidget {
  final String vendorId;
  const _VendorSalesReportScreen({required this.vendorId});

  @override
  State<_VendorSalesReportScreen> createState() =>
      _VendorSalesReportScreenState();
}

class _VendorSalesReportScreenState extends State<_VendorSalesReportScreen> {
  static const _ranges = <_RangeOption>[
    _RangeOption('近 7 天', 7),
    _RangeOption('近 30 天', 30),
    _RangeOption('近 90 天', 90),
  ];

  _RangeOption _selected = _ranges[1]; // default 30 天

  @override
  Widget build(BuildContext context) {
    final from = DateTime.now().subtract(Duration(days: _selected.days));
    final fromTs = Timestamp.fromDate(
      DateTime(from.year, from.month, from.day),
    );

    // ⚠️ 假設 orders 結構：
    // - collection: orders
    // - 欄位: vendorId / createdAt / total / status
    //
    // 若你的實際欄位不同，只要改這裡：
    final q = FirebaseFirestore.instance
        .collection('orders')
        .where('vendorId', isEqualTo: widget.vendorId)
        .where('createdAt', isGreaterThanOrEqualTo: fromTs);

    return Scaffold(
      appBar: AppBar(
        title: const Text('銷售報表'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_RangeOption>(
                value: _selected,
                items: _ranges
                    .map(
                      (r) => DropdownMenuItem<_RangeOption>(
                        value: r,
                        child: Text(r.label),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selected = v);
                },
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('讀取失敗：${snap.error}'),
                const SizedBox(height: 8),
                const Text(
                  '請確認 Firestore collection/欄位名稱與索引（vendorId, createdAt）。',
                ),
              ],
            );
          }

          final docs = snap.data?.docs ?? const [];
          final computed = _compute(docs);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _infoCard(widget.vendorId, _selected.label, from),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _metricCard('訂單數', computed.totalOrders.toString()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metricCard(
                      '總營收',
                      computed.totalRevenue.toStringAsFixed(0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _metricCard('已付款', computed.paidOrders.toString()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metricCard(
                      '已取消',
                      computed.cancelledOrders.toString(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                '最近訂單',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (docs.isEmpty)
                const Text('（此區間內沒有訂單）')
              else
                ...docs
                    .take(30)
                    .map((d) => _orderTile(orderId: d.id, data: d.data())),
            ],
          );
        },
      ),
    );
  }

  Widget _infoCard(String vendorId, String rangeLabel, DateTime from) {
    final f =
        '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('報表範圍', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('區間：$rangeLabel（自 $f 起）'),
            const SizedBox(height: 6),
            Text(
              'Vendor：$vendorId',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderTile({
    required String orderId,
    required Map<String, dynamic> data,
  }) {
    final status = (data['status'] ?? '').toString();
    final total = data['total'];
    final createdAt = _fmtTs(data['createdAt']);

    return Card(
      child: ListTile(
        title: Text('訂單：$orderId'),
        subtitle: Text('時間：$createdAt\n狀態：${status.isEmpty ? '-' : status}'),
        trailing: Text(total == null ? '-' : total.toString()),
      ),
    );
  }

  _Computed _compute(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final totalOrders = docs.length;
    var paidOrders = 0;
    var cancelledOrders = 0;
    var revenue = 0.0;

    for (final d in docs) {
      final data = d.data();
      final status = (data['status'] ?? '').toString().toLowerCase();
      final totalVal = data['total'];

      final isCancelled = status.contains('cancel');
      final isPaid =
          status.contains('paid') ||
          status.contains('success') ||
          status.contains('completed');

      if (isCancelled) cancelledOrders++;
      if (isPaid) paidOrders++;

      // 營收：預設算所有非取消單；若你要只算已付款 => 改成 if (isPaid) 才加
      if (!isCancelled) {
        final num? n = (totalVal is num)
            ? totalVal
            : num.tryParse(totalVal?.toString() ?? '');
        if (n != null) revenue += n.toDouble();
      }
    }

    return _Computed(
      totalOrders: totalOrders,
      paidOrders: paidOrders,
      cancelledOrders: cancelledOrders,
      totalRevenue: revenue,
    );
  }

  String _fmtTs(dynamic v) {
    if (v == null) return '-';
    if (v is Timestamp) {
      final dt = v.toDate();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return v.toString();
  }
}

class _RangeOption {
  final String label;
  final int days;
  const _RangeOption(this.label, this.days);

  @override
  bool operator ==(Object other) =>
      other is _RangeOption && other.days == days && other.label == label;

  @override
  int get hashCode => Object.hash(label, days);
}

class _Computed {
  final int totalOrders;
  final int paidOrders;
  final int cancelledOrders;
  final double totalRevenue;

  const _Computed({
    required this.totalOrders,
    required this.paidOrders,
    required this.cancelledOrders,
    required this.totalRevenue,
  });
}
