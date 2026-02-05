// lib/pages/admin_campaign_dashboard_page.dart
//
// ✅ AdminCampaignDashboardPage（最終完整版｜活動報表總覽）
// ------------------------------------------------------------
// Firestore:
// - campaigns/{id}
// - campaigns/{id}/participants
// - orders (campaignId)
// - coupons (campaignId)
// ------------------------------------------------------------

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:recharts/recharts.dart';
import '../services/admin_gate.dart';

class AdminCampaignDashboardPage extends StatefulWidget {
  const AdminCampaignDashboardPage({super.key});

  @override
  State<AdminCampaignDashboardPage> createState() => _AdminCampaignDashboardPageState();
}

class _AdminCampaignDashboardPageState extends State<AdminCampaignDashboardPage> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;
  List<_CampaignSummary> _campaigns = [];
  List<_DailyPoint> _trend = [];
  Map<String, int> _sourceMap = {};
  Map<String, int> _statusMap = {'啟用': 0, '停用': 0};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final gate = context.read<AdminGate>();
      final info = await gate.getRoleInfo(forceRefresh: false);
      final role = (info?.role ?? '').toLowerCase().trim();
      final isAdmin = role == 'admin';
      final vendorId = (info?.vendorId ?? '').trim();

      Query<Map<String, dynamic>> q = _db.collection('campaigns');
      if (!isAdmin && vendorId.isNotEmpty) {
        q = q.where('vendorId', isEqualTo: vendorId);
      }

      final snap = await q.get();
      final campaigns = <_CampaignSummary>[];

      for (final c in snap.docs) {
        final d = c.data();
        final id = c.id;
        final title = (d['title'] ?? id).toString();
        final isActive = d['isActive'] == true;
        final startAt = (d['startAt'] as Timestamp?)?.toDate();
        final endAt = (d['endAt'] as Timestamp?)?.toDate();
        final vendorId = d['vendorId'];

        // participants
        final pSnap = await _db.collection('campaigns').doc(id).collection('participants').get();
        final pCount = pSnap.size;

        // orders
        final oSnap = await _db.collection('orders').where('campaignId', isEqualTo: id).get();
        final oCount = oSnap.size;

        // coupons
        final cSnap = await _db.collection('coupons').where('campaignId', isEqualTo: id).get();
        final cCount = cSnap.size;

        final conversion = pCount > 0 ? oCount / pCount : 0.0;
        final sum = _CampaignSummary(
          id: id,
          title: title,
          vendorId: vendorId ?? '',
          isActive: isActive,
          participants: pCount,
          orders: oCount,
          coupons: cCount,
          conversionRate: conversion,
          startAt: startAt,
          endAt: endAt,
        );
        campaigns.add(sum);

        // 狀態統計
        _statusMap[isActive ? '啟用' : '停用'] = (_statusMap[isActive ? '啟用' : '停用'] ?? 0) + 1;

        // 來源統計
        for (final p in pSnap.docs) {
          final src = (p['source'] ?? 'unknown').toString();
          _sourceMap[src] = (_sourceMap[src] ?? 0) + 1;
        }

        // 趨勢統計
        final df = DateFormat('MM-dd');
        for (final p in pSnap.docs) {
          final date = (p['joinedAt'] as Timestamp?)?.toDate();
          if (date == null) continue;
          final key = df.format(date);
          final existing = _trend.firstWhere(
            (t) => t.date == key,
            orElse: () => _DailyPoint(date: key, participants: 0, orders: 0),
          );
          existing.participants++;
          if (!_trend.contains(existing)) _trend.add(existing);
        }
        for (final o in oSnap.docs) {
          final date = (o['createdAt'] as Timestamp?)?.toDate();
          if (date == null) continue;
          final key = DateFormat('MM-dd').format(date);
          final existing = _trend.firstWhere(
            (t) => t.date == key,
            orElse: () => _DailyPoint(date: key, participants: 0, orders: 0),
          );
          existing.orders++;
          if (!_trend.contains(existing)) _trend.add(existing);
        }
      }

      campaigns.sort((a, b) => b.orders.compareTo(a.orders));
      _trend.sort((a, b) => a.date.compareTo(b.date));

      if (mounted) {
        setState(() {
          _campaigns = campaigns;
          _loading = false;
        });
      }
    } catch (e) {
      _snack('載入失敗：$e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('活動報表總覽'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 20),
                  _buildTopChart(),
                  const SizedBox(height: 20),
                  _buildTrendChart(),
                  const SizedBox(height: 20),
                  _buildPieCharts(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    final total = _campaigns.length;
    final totalOrders = _campaigns.fold<int>(0, (s, e) => s + e.orders);
    final totalParticipants = _campaigns.fold<int>(0, (s, e) => s + e.participants);
    final avgConversion = totalParticipants > 0 ? totalOrders / totalParticipants : 0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 30,
          runSpacing: 8,
          children: [
            _summaryTile('活動總數', '$total'),
            _summaryTile('總參加人數', '$totalParticipants'),
            _summaryTile('總訂單數', '$totalOrders'),
            _summaryTile('平均轉換率', '${(avgConversion * 100).toStringAsFixed(1)}%'),
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

  Widget _buildTopChart() {
    final top10 = _campaigns.take(10).toList();

    if (top10.isEmpty) {
      return const Center(child: Text('尚無活動資料'));
    }

    return SizedBox(
      height: 300,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: BarChart(
            data: top10,
            variables: {
              'title': Variable<String>(accessor: (d) => d.title),
              '訂單數': Variable<num>(accessor: (d) => d.orders),
            },
            marks: [IntervalMark(color: Colors.blue)],
            axes: [Defaults.horizontalAxis, Defaults.verticalAxis],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendChart() {
    if (_trend.isEmpty) {
      return const Center(child: Text('尚無趨勢資料'));
    }

    return SizedBox(
      height: 280,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LineChart(
            data: _trend,
            variables: {
              'date': Variable<String>(accessor: (d) => d.date),
              'participants': Variable<num>(accessor: (d) => d.participants),
              'orders': Variable<num>(accessor: (d) => d.orders),
            },
            marks: [
              LineMark(
                x: (d) => d['date'] as String,
                y: (d) => d['participants'] as num,
                color: Colors.orange,
              ),
              LineMark(
                x: (d) => d['date'] as String,
                y: (d) => d['orders'] as num,
                color: Colors.blue,
              ),
            ],
            axes: [Defaults.horizontalAxis, Defaults.verticalAxis],
          ),
        ),
      ),
    );
  }

  Widget _buildPieCharts() {
    final totalStatus = _statusMap.values.fold<int>(0, (s, e) => s + e);
    final totalSource = _sourceMap.values.fold<int>(0, (s, e) => s + e);

    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        SizedBox(
          width: 350,
          height: 300,
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PieChart(
                data: _statusMap.entries
                    .map((e) => {'label': e.key, 'value': e.value})
                    .toList(),
                variables: {
                  'label': Variable<String>(accessor: (d) => d['label'] as String),
                  'value': Variable<num>(accessor: (d) => d['value'] as num),
                },
                marks: [
                  ArcLabelMark(
                    label: (d) =>
                        '${d['label']} ${(d['value'] / (totalStatus == 0 ? 1 : totalStatus) * 100).toStringAsFixed(1)}%',
                    labelStyle: Defaults.arcLabelStyle,
                  ),
                ],
                coord: PolarCoord(transposed: true),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 350,
          height: 300,
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PieChart(
                data: _sourceMap.entries
                    .map((e) => {'label': e.key, 'value': e.value})
                    .toList(),
                variables: {
                  'label': Variable<String>(accessor: (d) => d['label'] as String),
                  'value': Variable<num>(accessor: (d) => d['value'] as num),
                },
                marks: [
                  ArcLabelMark(
                    label: (d) =>
                        '${d['label']} ${(d['value'] / (totalSource == 0 ? 1 : totalSource) * 100).toStringAsFixed(1)}%',
                    labelStyle: Defaults.arcLabelStyle,
                  ),
                ],
                coord: PolarCoord(transposed: true),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CampaignSummary {
  final String id;
  final String title;
  final String vendorId;
  final bool isActive;
  final int participants;
  final int orders;
  final int coupons;
  final double conversionRate;
  final DateTime? startAt;
  final DateTime? endAt;

  _CampaignSummary({
    required this.id,
    required this.title,
    required this.vendorId,
    required this.isActive,
    required this.participants,
    required this.orders,
    required this.coupons,
    required this.conversionRate,
    this.startAt,
    this.endAt,
  });
}

class _DailyPoint {
  final String date;
  int participants;
  int orders;

  _DailyPoint({required this.date, this.participants = 0, this.orders = 0});
}
