// lib/pages/vendor/vendor_reports_page.dart
//
// ✅ VendorReportsPage（最終完整版｜可編譯可用｜已修正 Unnecessary cast）
// ------------------------------------------------------------
// - Vendor 專用報表頁（只看自己的 vendorId）
// - 指標：訂單數、營收估算（最多取樣 1000 筆）、商品數、活動數
// - 區間：近 7/30/90 天、全部
//
// Firestore（依你專案可微調）：
// - orders（建議欄位：createdAt, vendorId, total/amount/totalAmount/grandTotal 任一）
// - products（vendorId）
// - campaigns（vendorId）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../layouts/scaffold_with_drawer.dart';
import '../../services/admin_gate.dart';

class VendorReportsPage extends StatefulWidget {
  const VendorReportsPage({super.key});

  @override
  State<VendorReportsPage> createState() => _VendorReportsPageState();
}

class _VendorReportsPageState extends State<VendorReportsPage> {
  final _db = FirebaseFirestore.instance;

  bool _loadingGate = true;
  bool _allowed = true;
  String _denyReason = '';

  String _vendorId = '';
  ReportRange _range = ReportRange.d30;

  int _refreshTick_ = 0;

  @override
  void initState() {
    super.initState();
    _bootstrapGate();
  }

  Future<void> _bootstrapGate() async {
    setState(() {
      _loadingGate = true;
      _allowed = true;
      _denyReason = '';
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _allowed = false;
        _denyReason = '尚未登入';
        _loadingGate = false;
      });
      return;
    }

    try {
      final gate = context.read<AdminGate>();
      final info = await gate.ensureAndGetRole(user, forceRefresh: false);

      var role = info.role.toString().toLowerCase().trim();
      if (role.contains('.')) role = role.split('.').last;

      // ✅ 修正：不需要 cast，直接用 toString() 避免 unnecessary_cast
      final vendorId = info.vendorId.toString().trim();

      if (role != 'vendor') {
        setState(() {
          _allowed = false;
          _denyReason = '此頁僅 Vendor 可查看';
        });
        return;
      }

      if (vendorId.isEmpty) {
        setState(() {
          _allowed = false;
          _denyReason = 'Vendor 帳號缺少 vendorId（請在 users/{uid} 補上 vendorId）';
        });
        return;
      }

      setState(() {
        _vendorId = vendorId;
        _allowed = true;
      });
    } catch (e) {
      setState(() {
        _allowed = false;
        _denyReason = '權限檢查失敗：$e';
      });
    } finally {
      if (mounted) setState(() => _loadingGate = false);
    }
  }

  DateTime? _rangeStart(ReportRange r) {
    final now = DateTime.now();
    return switch (r) {
      ReportRange.d7 => now.subtract(const Duration(days: 7)),
      ReportRange.d30 => now.subtract(const Duration(days: 30)),
      ReportRange.d90 => now.subtract(const Duration(days: 90)),
      ReportRange.all => null,
    };
  }

  String _rangeLabel(ReportRange r) {
    return switch (r) {
      ReportRange.d7 => '近 7 天',
      ReportRange.d30 => '近 30 天',
      ReportRange.d90 => '近 90 天',
      ReportRange.all => '全部',
    };
  }

  Query<Map<String, dynamic>> _ordersQuery({required DateTime? start}) {
    Query<Map<String, dynamic>> q = _db
        .collection('orders')
        .where('vendorId', isEqualTo: _vendorId);

    if (start != null) {
      q = q.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start),
      );
    }

    return q;
  }

  Query<Map<String, dynamic>> _productsQuery() {
    return _db.collection('products').where('vendorId', isEqualTo: _vendorId);
  }

  Query<Map<String, dynamic>> _campaignsQuery() {
    return _db.collection('campaigns').where('vendorId', isEqualTo: _vendorId);
  }

  Future<int> _count(Query<Map<String, dynamic>> q) async {
    try {
      final snap = await q.get();
      return snap.size;
    } catch (_) {
      return 0;
    }
  }

  num _readMoney(Map<String, dynamic> m) {
    final v = m['totalAmount'] ?? m['amount'] ?? m['total'] ?? m['grandTotal'];
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  Future<_VendorReportData> _loadReport() async {
    final start = _rangeStart(_range);

    final ordersQ = _ordersQuery(start: start);
    final productsQ = _productsQuery();
    final campaignsQ = _campaignsQuery();

    final results = await Future.wait<int>([
      _count(ordersQ),
      _count(productsQ),
      _count(campaignsQ),
    ]);

    final ordersCount = results[0];
    final productsCount = results[1];
    final campaignsCount = results[2];

    // 營收估算：最多取樣 1000 筆
    num revenue = 0;
    int sampled = 0;
    try {
      Query<Map<String, dynamic>> revenueQ = ordersQ.limit(1000);
      try {
        revenueQ = revenueQ.orderBy('createdAt', descending: true);
      } catch (_) {}
      final snap = await revenueQ.get();
      sampled = snap.size;
      for (final d in snap.docs) {
        revenue += _readMoney(d.data());
      }
    } catch (_) {}

    return _VendorReportData(
      range: _range,
      vendorId: _vendorId,
      generatedAt: DateTime.now(),
      ordersCount: ordersCount,
      productsCount: productsCount,
      campaignsCount: campaignsCount,
      revenueEstimate: revenue,
      revenueSampledOrders: sampled,
    );
  }

  void _refresh() => setState(() => _refreshTick_++);

  @override
  Widget build(BuildContext context) {
    if (_loadingGate) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_allowed) {
      return ScaffoldWithDrawer(
        title: '我的報表',
        currentRoute: '/reports',
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 44),
                    const SizedBox(height: 10),
                    Text(
                      _denyReason.isEmpty ? '無權限' : _denyReason,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _bootstrapGate,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新檢查權限'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ScaffoldWithDrawer(
      title: '我的報表',
      currentRoute: '/reports',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _TopBar(
            vendorId: _vendorId,
            range: _range,
            labelOf: _rangeLabel,
            onRangeChanged: (r) => setState(() => _range = r),
            onRefresh: _refresh,
          ),
          const SizedBox(height: 12),
          FutureBuilder<_VendorReportData>(
            key: ValueKey(
              'vendor_report_${_refreshTick_}_${_range.name}_$_vendorId',
            ),
            future: _loadReport(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return _ErrorCard(
                  title: '載入報表失敗',
                  message: snap.error.toString(),
                  onRetry: _refresh,
                );
              }
              final data = snap.data;
              if (data == null) {
                return _ErrorCard(
                  title: '載入報表失敗',
                  message: '沒有取得資料',
                  onRetry: _refresh,
                );
              }

              return Column(
                children: [
                  _SummaryHeader(data: data),
                  const SizedBox(height: 12),
                  _MetricGrid(data: data),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

enum ReportRange { d7, d30, d90, all }

class _VendorReportData {
  final ReportRange range;
  final String vendorId;
  final DateTime generatedAt;

  final int ordersCount;
  final int productsCount;
  final int campaignsCount;

  final num revenueEstimate;
  final int revenueSampledOrders;

  _VendorReportData({
    required this.range,
    required this.vendorId,
    required this.generatedAt,
    required this.ordersCount,
    required this.productsCount,
    required this.campaignsCount,
    required this.revenueEstimate,
    required this.revenueSampledOrders,
  });
}

class _TopBar extends StatelessWidget {
  final String vendorId;
  final ReportRange range;
  final String Function(ReportRange) labelOf;
  final ValueChanged<ReportRange> onRangeChanged;
  final VoidCallback onRefresh;

  const _TopBar({
    required this.vendorId,
    required this.range,
    required this.labelOf,
    required this.onRangeChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.primaryContainer,
              child: Icon(
                Icons.insights_outlined,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vendor 報表總覽',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'vendorId：$vendorId',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            DropdownButton<ReportRange>(
              value: range,
              onChanged: (v) {
                if (v != null) onRangeChanged(v);
              },
              items: ReportRange.values
                  .map(
                    (r) => DropdownMenuItem(value: r, child: Text(labelOf(r))),
                  )
                  .toList(),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '重新整理',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final _VendorReportData data;
  const _SummaryHeader({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dt = DateFormat('yyyy/MM/dd HH:mm:ss').format(data.generatedAt);

    final money = NumberFormat.decimalPattern().format(
      data.revenueEstimate.round(),
    );
    final sampled = data.revenueSampledOrders;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '更新時間：$dt',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '營收估算：NT\$ $money',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '取樣 $sampled 筆訂單',
                    style: TextStyle(
                      color: cs.onSecondaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '※ 營收為估算值（依 orders 內的 total/amount/totalAmount/grandTotal 欄位加總）',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final _VendorReportData data;
  const _MetricGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final crossAxisCount = w >= 980 ? 3 : (w >= 640 ? 2 : 1);

        final tiles = <_MetricTileData>[
          _MetricTileData('訂單數', data.ordersCount, Icons.receipt_long_outlined),
          _MetricTileData(
            '商品數',
            data.productsCount,
            Icons.inventory_2_outlined,
          ),
          _MetricTileData('活動數', data.campaignsCount, Icons.campaign_outlined),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: crossAxisCount == 1 ? 3.2 : 2.8,
          ),
          itemCount: tiles.length,
          itemBuilder: (_, i) => _MetricCard(data: tiles[i]),
        );
      },
    );
  }
}

class _MetricTileData {
  final String title;
  final int value;
  final IconData icon;
  _MetricTileData(this.title, this.value, this.icon);
}

class _MetricCard extends StatelessWidget {
  final _MetricTileData data;
  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = NumberFormat.decimalPattern().format(data.value);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.primaryContainer,
              child: Icon(data.icon, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    v,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 42),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }
}
