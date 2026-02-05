// lib/pages/admin/vendors/admin_vendors_dashboard_page.dart
//
// ✅ AdminVendorsDashboardPage（最終完整版｜含圖表）
// ------------------------------------------------------------
// - Firestore 即時同步統計
// - 圓餅圖：啟用 vs 停用比例
// - 長條圖：地區廠商分布
// - 自適應佈局、完整錯誤防護
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class AdminVendorsDashboardPage extends StatefulWidget {
  const AdminVendorsDashboardPage({super.key});

  @override
  State<AdminVendorsDashboardPage> createState() =>
      _AdminVendorsDashboardPageState();
}

class _AdminVendorsDashboardPageState
    extends State<AdminVendorsDashboardPage> {
  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('廠商營運儀表板'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db.collection('vendors').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text('載入失敗：${snap.error}',
                  style: TextStyle(color: cs.error)),
            );
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('目前尚無廠商資料'));
          }

          final vendors = snap.data!.docs.map((d) {
            final data = d.data();
            return {
              ...data,
              'id': d.id,
            };
          }).toList();

          final active =
              vendors.where((v) => v['status'] == 'active').length;
          final inactive =
              vendors.where((v) => v['status'] == 'inactive').length;
          final total = active + inactive;

          final regionMap = <String, int>{};
          for (final v in vendors) {
            final region = (v['region'] ?? '未指定').toString();
            regionMap[region] = (regionMap[region] ?? 0) + 1;
          }

          final newest = List<Map<String, dynamic>>.from(vendors)
            ..sort((a, b) {
              final ta = (a['createdAt'] as Timestamp?)
                      ?.toDate() ??
                  DateTime(2000);
              final tb = (b['createdAt'] as Timestamp?)
                      ?.toDate() ??
                  DateTime(2000);
              return tb.compareTo(ta);
            });

          final fmt = DateFormat('yyyy-MM-dd HH:mm');

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _summaryCards(active, inactive, total, cs),
                const SizedBox(height: 16),
                _pieChartSection(active, inactive),
                const SizedBox(height: 16),
                _barChartSection(regionMap),
                const SizedBox(height: 16),
                _newestVendorList(newest, fmt),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // 概覽統計卡片
  // ============================================================
  Widget _summaryCards(int active, int inactive, int total, ColorScheme cs) {
    final cards = [
      _summaryCard('啟用中', active, Colors.green.shade100, cs.primary),
      _summaryCard('停用中', inactive, Colors.red.shade100, cs.error),
      _summaryCard('總廠商數', total, Colors.blue.shade100, cs.primary),
    ];

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 500) {
        return Column(
          children: [
            for (final w in cards) ...[w, const SizedBox(height: 8)],
          ],
        );
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final w in cards)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: w,
              ),
            ),
        ],
      );
    });
  }

  Widget _summaryCard(
      String label, int count, Color bg, Color color) {
    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$count',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 圓餅圖：啟用／停用比例
  // ============================================================
  Widget _pieChartSection(int active, int inactive) {
    final total = (active + inactive).clamp(1, 999999);
    final activePercent = (active / total * 100).toStringAsFixed(1);
    final inactivePercent = (inactive / total * 100).toStringAsFixed(1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('啟用／停用比例',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 50,
                  sections: [
                    PieChartSectionData(
                      value: active.toDouble(),
                      color: Colors.green,
                      radius: 50,
                      title: '啟用\n$activePercent%',
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                    PieChartSectionData(
                      value: inactive.toDouble(),
                      color: Colors.red,
                      radius: 50,
                      title: '停用\n$inactivePercent%',
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 長條圖：地區廠商分布
  // ============================================================
  Widget _barChartSection(Map<String, int> regionMap) {
    if (regionMap.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('尚無地區分布資料'),
        ),
      );
    }

    final entries = regionMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxY = math.max(1.0, entries.map((e) => e.value).reduce(math.max) * 1.2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 240,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                      return Text(
                        entries[i].key,
                        style: const TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (v, _) {
                          if (v == 0) return const Text('0');
                          return Text(v.toInt().toString(),
                              style: const TextStyle(fontSize: 10));
                        })),
              ),
              barGroups: [
                for (int i = 0; i < entries.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: entries[i].value.toDouble(),
                        color: Colors.blueAccent,
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 最新廠商清單
  // ============================================================
  Widget _newestVendorList(
      List<Map<String, dynamic>> vendors, DateFormat fmt) {
    final latest = vendors.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('最近新增廠商',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            if (latest.isEmpty)
              const Text('尚無資料')
            else
              Column(
                children: [
                  for (final v in latest)
                    ListTile(
                      leading: const Icon(Icons.store, color: Colors.blue),
                      title: Text(
                        v['name'] ?? '未命名',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        (v['createdAt'] is Timestamp)
                            ? fmt.format(
                                (v['createdAt'] as Timestamp).toDate())
                            : '未設定時間',
                      ),
                      trailing: Text(
                        v['status'] == 'active' ? '啟用' : '停用',
                        style: TextStyle(
                            color: v['status'] == 'active'
                                ? Colors.green
                                : Colors.red),
                      ),
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/admin_vendors/detail',
                        arguments: {'id': v['id']},
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
