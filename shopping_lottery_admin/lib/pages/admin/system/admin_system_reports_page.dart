// lib/pages/admin/system/admin_system_reports_page.dart
//
// ✅ AdminSystemReportsPage（系統報表｜可編譯完整版）
// ------------------------------------------------------------
// - 顯示系統關鍵集合的筆數統計（users / orders / products / carts / coupons）
// - 匯出 CSV（摘要 / 近 30 天訂單）
// - ✅ 修正 agg.count (int?) → int：使用 agg.count ?? 0
// - ✅ 修正 deprecated_member_use：withOpacity → withValues(alpha: ...)
//
// 依賴：
// - cloud_firestore
// - intl
// - csv
// - utils/report_file_saver.dart（提供 saveReportBytes）
// ------------------------------------------------------------

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ✅ 依你專案實際路徑調整
import 'package:osmile_admin/utils/report_file_saver.dart';

class AdminSystemReportsPage extends StatefulWidget {
  const AdminSystemReportsPage({super.key});

  @override
  State<AdminSystemReportsPage> createState() => _AdminSystemReportsPageState();
}

class _AdminSystemReportsPageState extends State<AdminSystemReportsPage> {
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;

  _CountResult? _users;
  _CountResult? _orders;
  _CountResult? _products;
  _CountResult? _carts;
  _CountResult? _coupons;

  String? _exportResult;

  final _dt = DateFormat('yyyy/MM/dd HH:mm');
  final _stamp = DateFormat('yyyyMMdd_HHmm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ------------------------------------------------------------
  // Load counts (with count() fallback)
  // ------------------------------------------------------------
  Future<_CountResult> _countCollection(String collectionPath) async {
    // ✅ 優先用聚合 count（新版本 cloud_firestore 支援）
    try {
      final agg = await _db.collection(collectionPath).count().get();

      // ✅ 修正：agg.count 在部分版本為 int?（nullable）
      return _CountResult(count: agg.count ?? 0, approx: false, note: null);
    } catch (e) {
      // ✅ fallback：用 limit 取樣（避免大集合把 Web 跑死）
      const limit = 2000;
      final snap = await _db.collection(collectionPath).limit(limit).get();
      final approx = snap.size >= limit;
      return _CountResult(
        count: snap.size,
        approx: approx,
        note: approx ? '（僅取前 $limit 筆，可能更多）' : null,
      );
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _exportResult = null;
    });

    try {
      final results = await Future.wait<_CountResult>([
        _countCollection('users'),
        _countCollection('orders'),
        _countCollection('products'),
        _countCollection('carts'),
        _countCollection('coupons'),
      ]);

      if (!mounted) return;
      setState(() {
        _users = results[0];
        _orders = results[1];
        _products = results[2];
        _carts = results[3];
        _coupons = results[4];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ------------------------------------------------------------
  // Export: Summary CSV
  // ------------------------------------------------------------
  Future<void> _exportSummaryCsv() async {
    try {
      final now = DateTime.now();
      final csv = <List<dynamic>>[
        ['generatedAt', _dt.format(now)],
        [],
        ['collection', 'count', 'approx', 'note'],
        [
          'users',
          _users?.count ?? 0,
          _users?.approx ?? false,
          _users?.note ?? '',
        ],
        [
          'orders',
          _orders?.count ?? 0,
          _orders?.approx ?? false,
          _orders?.note ?? '',
        ],
        [
          'products',
          _products?.count ?? 0,
          _products?.approx ?? false,
          _products?.note ?? '',
        ],
        [
          'carts',
          _carts?.count ?? 0,
          _carts?.approx ?? false,
          _carts?.note ?? '',
        ],
        [
          'coupons',
          _coupons?.count ?? 0,
          _coupons?.approx ?? false,
          _coupons?.note ?? '',
        ],
      ];

      final csvString = const ListToCsvConverter().convert(csv);
      final bytes = utf8.encode('\uFEFF$csvString'); // BOM for Excel

      final name = 'system_summary_${_stamp.format(now)}.csv';

      final saved = await saveReportBytes(
        name: name,
        bytes: bytes,
        mimeType: 'text/csv',
      );

      if (!mounted) return;
      setState(() => _exportResult = saved);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('摘要 CSV 匯出完成')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('匯出失敗：$e')));
    }
  }

  // ------------------------------------------------------------
  // Export: Orders (last 30 days) CSV
  // ------------------------------------------------------------
  Future<void> _exportOrders30dCsv() async {
    try {
      final now = DateTime.now();
      final since = now.subtract(const Duration(days: 30));

      Query<Map<String, dynamic>> q = _db
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .orderBy('createdAt', descending: true)
          .limit(2000);

      final snap = await q.get();

      String s(dynamic v) => (v ?? '').toString().trim();
      num n(dynamic v) =>
          v is num ? v : (num.tryParse((v ?? '0').toString()) ?? 0);
      DateTime? dt(dynamic v) {
        if (v is Timestamp) return v.toDate();
        if (v is DateTime) return v;
        return null;
      }

      final csv = <List<dynamic>>[
        ['generatedAt', _dt.format(now)],
        ['rangeFrom', _dt.format(since)],
        ['rangeTo', _dt.format(now)],
        ['rows', snap.size],
        [],
        [
          'orderId',
          'userId',
          'vendorId',
          'status',
          'payment.status',
          'payment.method',
          'total',
          'createdAt',
        ],
      ];

      for (final doc in snap.docs) {
        final d = doc.data();
        final payment = (d['payment'] is Map)
            ? Map<String, dynamic>.from(d['payment'])
            : <String, dynamic>{};

        final createdAt = dt(d['createdAt']);
        csv.add([
          doc.id,
          s(d['userId']),
          s(d['vendorId']),
          s(d['status']),
          s(payment['status']),
          s(payment['method']),
          n(payment['total'] ?? d['total']).toString(),
          createdAt == null ? '' : _dt.format(createdAt),
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csv);
      final bytes = utf8.encode('\uFEFF$csvString');

      final name = 'orders_30d_${_stamp.format(now)}.csv';

      final saved = await saveReportBytes(
        name: name,
        bytes: bytes,
        mimeType: 'text/csv',
      );

      if (!mounted) return;
      setState(() => _exportResult = saved);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('近 30 天訂單 CSV 匯出完成')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('匯出失敗：$e')));
    }
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            '系統報表',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Center(child: Text('載入失敗：$_error')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '系統報表',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '匯出摘要 CSV',
            onPressed: _exportSummaryCsv,
            icon: const Icon(Icons.download),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _gridCounts(cs),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '匯出',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _exportSummaryCsv,
                        icon: const Icon(Icons.summarize_outlined),
                        label: const Text('匯出摘要 CSV'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _exportOrders30dCsv,
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('匯出近 30 天訂單 CSV'),
                      ),
                    ],
                  ),
                  if (_exportResult != null) ...[
                    const SizedBox(height: 10),
                    Text('匯出結果：', style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text(
                      _exportResult!,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          Card(
            elevation: 0,
            // ✅ 修正 deprecated: withOpacity -> withValues(alpha: ...)
            color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                '提示：若集合很大，建議使用 Firestore aggregate count()（本頁已優先使用）。\n'
                '若你的 cloud_firestore 版本太舊不支援 count()，本頁會自動 fallback 取樣筆數（上限 2000）。',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridCounts(ColorScheme cs) {
    Widget card(String title, _CountResult? r) {
      final countText = r == null
          ? '-'
          : (r.approx ? '≥${r.count}' : '${r.count}');
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                countText,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (r?.note != null) ...[
                const SizedBox(height: 6),
                Text(
                  r!.note!,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 820;
        final children = <Widget>[
          card('Users', _users),
          card('Orders', _orders),
          card('Products', _products),
          card('Carts', _carts),
          card('Coupons', _coupons),
        ];

        if (narrow) {
          return Column(
            children: children
                .map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: w,
                  ),
                )
                .toList(),
          );
        }

        return GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: children,
        );
      },
    );
  }
}

class _CountResult {
  final int count;
  final bool approx;
  final String? note;

  _CountResult({required this.count, required this.approx, required this.note});
}
