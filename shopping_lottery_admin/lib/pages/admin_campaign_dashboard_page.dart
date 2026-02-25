// lib/pages/admin_campaign_dashboard_page.dart
//
// ✅ AdminCampaignDashboardPage（活動/投放 Dashboard｜可編譯完整版）
// ------------------------------------------------------------
// 修正點：
// - 移除錯誤的 `package:recharts/recharts.dart`（那是 React 套件，Flutter 不存在）
// - 改用 Flutter 可用的 `fl_chart` 畫 BarChart
// - ✅ 修正：withOpacity deprecated → withValues(alpha: ...)
// - ✅ 修正：curly_braces_in_flow_control_structures（加上大括號）
//
// 功能：
// - 顯示 campaigns/coupons/orders 基本 KPI
// - 近 14 天訂單每日數量柱狀圖
// - 近 7/30 天訂單數 + 金額（取樣加總）
// - 欄位兼容：createdAt(Timestamp)；金額 payment.total / totals.total / total / amount / payAmount
//
// 依賴：
// - cloud_firestore
// - intl
// - fl_chart
// ------------------------------------------------------------

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminCampaignDashboardPage extends StatefulWidget {
  const AdminCampaignDashboardPage({super.key});

  @override
  State<AdminCampaignDashboardPage> createState() =>
      _AdminCampaignDashboardPageState();
}

class _AdminCampaignDashboardPageState
    extends State<AdminCampaignDashboardPage> {
  final _db = FirebaseFirestore.instance;

  late Future<_DashData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashData> _load() async {
    final now = DateTime.now();
    final since7 = now.subtract(const Duration(days: 7));
    final since30 = now.subtract(const Duration(days: 30));

    final campaigns = await _safeCount(_db.collection('campaigns'));
    final coupons = await _safeCount(_db.collection('coupons'));

    final orders7 = await _safeCount(
      _db
          .collection('orders')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(since7),
          ),
    );
    final orders30 = await _safeCount(
      _db
          .collection('orders')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(since30),
          ),
    );

    final amount7 = await _safeSumOrdersSince(since7, limit: 2000);
    final amount30 = await _safeSumOrdersSince(since30, limit: 2000);

    final series14 = await _loadDailyOrderCount(days: 14, limit: 2500);

    return _DashData(
      updatedAt: now,
      campaigns: campaigns,
      coupons: coupons,
      orders7d: orders7,
      orders30d: orders30,
      amount7d: amount7,
      amount30d: amount30,
      daily14: series14,
    );
  }

  Future<int> _safeCount(Query<Map<String, dynamic>> q) async {
    try {
      final agg = await q.count().get();
      return agg.count ?? 0;
    } catch (_) {
      final snap = await q.limit(2000).get();
      return snap.size;
    }
  }

  Future<num> _safeSumOrdersSince(DateTime since, {required int limit}) async {
    try {
      final snap = await _db
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      num total = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        final payment = (d['payment'] is Map)
            ? Map<String, dynamic>.from(d['payment'])
            : <String, dynamic>{};
        final totals = (d['totals'] is Map)
            ? Map<String, dynamic>.from(d['totals'])
            : <String, dynamic>{};

        total += _toNum(
          payment['total'] ??
              totals['total'] ??
              d['total'] ??
              d['amount'] ??
              d['payAmount'] ??
              0,
        );
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<List<_DailyPoint>> _loadDailyOrderCount({
    required int days,
    required int limit,
  }) async {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));

    // 初始化 days 筆（確保沒訂單也會顯示 0）
    final map = <DateTime, int>{};
    for (int i = 0; i < days; i++) {
      final d = DateTime(
        start.year,
        start.month,
        start.day,
      ).add(Duration(days: i));
      map[d] = 0;
    }

    try {
      final snap = await _db
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .orderBy('createdAt', descending: false)
          .limit(limit)
          .get();

      for (final doc in snap.docs) {
        final d = doc.data();
        final ts = d['createdAt'];
        if (ts is! Timestamp) continue;
        final dt = ts.toDate();
        final day = DateTime(dt.year, dt.month, dt.day);
        if (map.containsKey(day)) {
          map[day] = (map[day] ?? 0) + 1;
        }
      }
    } catch (_) {
      // ignore, keep zeros
    }

    final keys = map.keys.toList()..sort((a, b) => a.compareTo(b));
    return keys.map((k) => _DailyPoint(day: k, count: map[k] ?? 0)).toList();
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse((v ?? '0').toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final money = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
    final dtFmt = DateFormat('yyyy/MM/dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '活動 Dashboard',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() => _future = _load()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_DashData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('載入失敗：${snap.error}'));
          }
          final d = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                // ✅ 修正：withOpacity deprecated → withValues(alpha: ...)
                color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '更新時間：${dtFmt.format(d.updatedAt)}',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _kpiGrid(
                children: [
                  _kpiCard('Campaigns', '${d.campaigns}'),
                  _kpiCard('Coupons', '${d.coupons}'),
                  _kpiCard('近 7 天訂單數', '${d.orders7d}'),
                  _kpiCard('近 30 天訂單數', '${d.orders30d}'),
                  _kpiCard('近 7 天金額（取樣）', money.format(d.amount7d)),
                  _kpiCard('近 30 天金額（取樣）', money.format(d.amount30d)),
                ],
              ),

              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '近 14 天訂單數（每日）',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 260,
                        child: _OrdersBarChart(points: d.daily14),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '註：為避免 Web 大集合過慢，圖表資料最多讀取 2500 筆近 14 天訂單。',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    '欄位假設：orders.createdAt 必須是 Timestamp。\n'
                    '金額來源：payment.total / totals.total / total / amount / payAmount。',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _kpiGrid({required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        if (!wide) {
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
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 3.2,
          children: children,
        );
      },
    );
  }

  Widget _kpiCard(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.insights_outlined),
          ],
        ),
      ),
    );
  }
}

class _OrdersBarChart extends StatelessWidget {
  final List<_DailyPoint> points;
  const _OrdersBarChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Text('沒有資料'));
    }

    final peak = points
        .map((e) => e.count)
        .fold<int>(0, (a, b) => math.max(a, b));
    final maxY = math.max(3, peak).toDouble();

    return BarChart(
      BarChartData(
        maxY: maxY + 1,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 34),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 2,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                // ✅ 修正：curly braces lint
                if (idx < 0 || idx >= points.length) {
                  return const SizedBox.shrink();
                }
                final d = points[idx].day;
                final label = '${d.month}/${d.day}';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(points.length, (i) {
          final y = points[i].count.toDouble();
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: y,
                width: 10,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _DashData {
  final DateTime updatedAt;
  final int campaigns;
  final int coupons;
  final int orders7d;
  final int orders30d;
  final num amount7d;
  final num amount30d;
  final List<_DailyPoint> daily14;

  _DashData({
    required this.updatedAt,
    required this.campaigns,
    required this.coupons,
    required this.orders7d,
    required this.orders30d,
    required this.amount7d,
    required this.amount30d,
    required this.daily14,
  });
}

class _DailyPoint {
  final DateTime day;
  final int count;
  _DailyPoint({required this.day, required this.count});
}
