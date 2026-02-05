// lib/pages/admin_campaign_analytics_page.dart
//
// ✅ AdminCampaignAnalyticsPage（最終完整版｜活動成效分析｜折線圖 + 圓餅圖 + 日期篩選）
// ------------------------------------------------------------
// Firestore：
// campaigns/{campaignId}/participants
// orders (campaignId == this)
// coupons (campaignId == this)
// ------------------------------------------------------------

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:recharts/recharts.dart';
import '../services/admin_gate.dart';

class AdminCampaignAnalyticsPage extends StatefulWidget {
  final String campaignId;
  const AdminCampaignAnalyticsPage({super.key, required this.campaignId});

  @override
  State<AdminCampaignAnalyticsPage> createState() => _AdminCampaignAnalyticsPageState();
}

class _AdminCampaignAnalyticsPageState extends State<AdminCampaignAnalyticsPage> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;

  DateTimeRange? _range;
  List<_DailyStat> _daily = [];
  Map<String, int> _sourceMap = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
    _loadData();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (result != null) {
      setState(() => _range = result);
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_range == null) return;
    setState(() => _loading = true);

    try {
      final cid = widget.campaignId;
      final start = Timestamp.fromDate(_range!.start);
      final end = Timestamp.fromDate(_range!.end.add(const Duration(days: 1)));

      // participants
      final pSnap = await _db
          .collection('campaigns')
          .doc(cid)
          .collection('participants')
          .where('joinedAt', isGreaterThanOrEqualTo: start)
          .where('joinedAt', isLessThan: end)
          .get();

      // orders
      final oSnap = await _db
          .collection('orders')
          .where('campaignId', isEqualTo: cid)
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .where('createdAt', isLessThan: end)
          .get();

      // coupons
      final cSnap = await _db
          .collection('coupons')
          .where('campaignId', isEqualTo: cid)
          .where('usedAt', isGreaterThanOrEqualTo: start)
          .where('usedAt', isLessThan: end)
          .get();

      final map = <String, _DailyStat>{};
      final df = DateFormat('yyyy-MM-dd');

      for (final p in pSnap.docs) {
        final d = (p['joinedAt'] as Timestamp?)?.toDate();
        if (d == null) continue;
        final key = df.format(d);
        map.putIfAbsent(key, () => _DailyStat(date: key)).participants++;
        final src = (p['source'] ?? 'unknown').toString();
        _sourceMap[src] = (_sourceMap[src] ?? 0) + 1;
      }

      for (final o in oSnap.docs) {
        final d = (o['createdAt'] as Timestamp?)?.toDate();
        if (d == null) continue;
        final key = df.format(d);
        map.putIfAbsent(key, () => _DailyStat(date: key)).orders++;
      }

      for (final c in cSnap.docs) {
        final d = (c['usedAt'] as Timestamp?)?.toDate();
        if (d == null) continue;
        final key = df.format(d);
        map.putIfAbsent(key, () => _DailyStat(date: key)).coupons++;
      }

      final sorted = map.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      if (mounted) {
        setState(() {
          _daily = sorted;
          _loading = false;
        });
      }
    } catch (e) {
      _snack('載入統計失敗：$e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();
    return FutureBuilder<RoleInfo>(
      future: gate.ensureAndGetRole(),
      builder: (context, snap) {
        final info = snap.data;
        final role = (info?.role ?? '').toLowerCase().trim();

        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('活動成效分析'),
            actions: [
              IconButton(icon: const Icon(Icons.date_range_outlined), onPressed: _pickDateRange),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummary(context),
                    const SizedBox(height: 20),
                    _buildLineChart(),
                    const SizedBox(height: 20),
                    _buildPieChart(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSummary(BuildContext context) {
    final totalP = _daily.fold<int>(0, (s, e) => s + e.participants);
    final totalO = _daily.fold<int>(0, (s, e) => s + e.orders);
    final totalC = _daily.fold<int>(0, (s, e) => s + e.coupons);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 40,
          runSpacing: 10,
          children: [
            _summaryTile('期間', '${DateFormat('MM/dd').format(_range!.start)} - ${DateFormat('MM/dd').format(_range!.end)}'),
            _summaryTile('參加人數', totalP.toString()),
            _summaryTile('訂單數', totalO.toString()),
            _summaryTile('用券數', totalC.toString()),
            _summaryTile('轉換率', totalP > 0 ? '${(totalO / totalP * 100).toStringAsFixed(1)}%' : '-'),
          ],
        ),
      ),
    );
  }

  Widget _summaryTile(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label),
      ],
    );
  }

  Widget _buildLineChart() {
    if (_daily.isEmpty) {
      return const Center(child: Text('無資料可繪製折線圖'));
    }

    return SizedBox(
      height: 300,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LineChart(
            data: _daily,
            variables: {
              'date': Variable<String>(
                accessor: (d) => d.date,
              ),
              '參加': Variable<num>(
                accessor: (d) => d.participants,
              ),
              '訂單': Variable<num>(
                accessor: (d) => d.orders,
              ),
              '用券': Variable<num>(
                accessor: (d) => d.coupons,
              ),
            },
            marks: [
              LineMark(
                x: (d) => d['date'] as String,
                y: (d) => d['參加'] as num,
                color: Colors.blue,
              ),
              LineMark(
                x: (d) => d['date'] as String,
                y: (d) => d['訂單'] as num,
                color: Colors.green,
              ),
              LineMark(
                x: (d) => d['date'] as String,
                y: (d) => d['用券'] as num,
                color: Colors.orange,
              ),
            ],
            axes: [
              Defaults.horizontalAxis,
              Defaults.verticalAxis,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    if (_sourceMap.isEmpty) {
      return const Center(child: Text('無來源資料可繪製圓餅圖'));
    }

    final total = _sourceMap.values.fold<int>(0, (s, e) => s + e);
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red];
    final entries = _sourceMap.entries.toList();

    return SizedBox(
      height: 320,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: PieChart(
            data: [
              for (int i = 0; i < entries.length; i++)
                {'source': entries[i].key, 'count': entries[i].value}
            ],
            variables: {
              'source': Variable<String>(accessor: (d) => d['source'] as String),
              'count': Variable<num>(accessor: (d) => d['count'] as num),
            },
            marks: [
              ArcLabelMark(
                label: (d) =>
                    '${d['source']} (${((d['count'] as num) / total * 100).toStringAsFixed(1)}%)',
                labelStyle: Defaults.arcLabelStyle,
              ),
            ],
            coord: PolarCoord(transposed: true, startRadius: 0.1, endRadius: 0.9),
          ),
        ),
      ),
    );
  }
}

class _DailyStat {
  final String date;
  int participants = 0;
  int orders = 0;
  int coupons = 0;

  _DailyStat({required this.date});
}
