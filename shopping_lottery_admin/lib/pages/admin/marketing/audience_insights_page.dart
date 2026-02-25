// lib/pages/admin/marketing/audience_insights_page.dart
//
// ✅ AudienceInsightsPage（受眾洞察分析｜完整版 v1.1｜可直接編譯）
// ------------------------------------------------------------
// - Firestore 集合：/segments
// - 分析欄位：filters.gender, filters.region, filters.membership, filters.ageRange
// - 視覺化：PieChart（fl_chart）
// - 支援即時重新整理與 KPI 摘要
//
// ✅ FIX:
// - use_build_context_synchronously：await 後使用 context 前先 mounted 檢查
// - 避免不安全 cast：filters / memberCount 以安全解析處理
// - fold 參數命名避免 lint（sum -> acc）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AudienceInsightsPage extends StatefulWidget {
  const AudienceInsightsPage({super.key});

  @override
  State<AudienceInsightsPage> createState() => _AudienceInsightsPageState();
}

class _AudienceInsightsPageState extends State<AudienceInsightsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _segments = [];

  Map<String, int> _genderCount = {};
  Map<String, int> _regionCount = {};
  Map<String, int> _membershipCount = {};
  Map<String, int> _ageCount = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // -----------------------
  // Safe parsers
  // -----------------------
  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? fallback;
    return fallback;
  }

  String _asString(dynamic v, {String fallback = '未設定'}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  // -----------------------
  // Load
  // -----------------------
  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('segments')
          .get();

      final segments = snap.docs.map((e) => e.data()).toList(growable: false);

      final gender = <String, int>{};
      final region = <String, int>{};
      final membership = <String, int>{};
      final age = <String, int>{};

      for (final s in segments) {
        final f = _asMap(s['filters']);
        final members = _asInt(s['memberCount']);

        final g = _asString(f['gender']);
        final r = _asString(f['region']);
        final m = _asString(f['membership']);
        final a = _asString(f['ageRange']);

        gender[g] = (gender[g] ?? 0) + members;
        region[r] = (region[r] ?? 0) + members;
        membership[m] = (membership[m] ?? 0) + members;
        age[a] = (age[a] ?? 0) + members;
      }

      if (!mounted) return; // ✅ FIX: await 後避免使用已失效 context / setState
      setState(() {
        _segments = segments;
        _genderCount = gender;
        _regionCount = region;
        _membershipCount = membership;
        _ageCount = age;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return; // ✅ FIX: await 後使用 context 前先 mounted
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('資料讀取失敗：$e')));
    }
  }

  int _totalMembers(Map<String, int> map) =>
      map.values.fold(0, (acc, v) => acc + v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('受眾洞察分析'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新整理',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _segments.isEmpty
          ? const Center(child: Text('尚無受眾分群資料'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _kpiSummary(),
                const SizedBox(height: 20),
                _chartSection('性別比例', _genderCount, Colors.pinkAccent),
                const SizedBox(height: 30),
                _chartSection('地區分佈', _regionCount, Colors.blueAccent),
                const SizedBox(height: 30),
                _chartSection('會員等級', _membershipCount, Colors.green),
                const SizedBox(height: 30),
                _chartSection('年齡層比例', _ageCount, Colors.orange),
              ],
            ),
    );
  }

  // =====================================================
  // KPI 摘要
  // =====================================================
  Widget _kpiSummary() {
    final totalSegments = _segments.length;
    final totalMembers = _segments.fold<int>(
      0,
      (acc, e) => acc + _asInt(e['memberCount']),
    );

    final avg = totalSegments > 0 ? (totalMembers / totalSegments) : 0.0;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _kpiCard('分群總數', '$totalSegments', Icons.people_outline),
        _kpiCard('總會員數', '$totalMembers', Icons.groups),
        _kpiCard(
          '平均分群人數',
          totalSegments > 0 ? avg.toStringAsFixed(1) : '0',
          Icons.analytics,
        ),
      ],
    );
  }

  Widget _kpiCard(String label, String value, IconData icon) {
    return Container(
      width: 180,
      height: 90,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // =====================================================
  // 統計圖表區塊
  // =====================================================
  Widget _chartSection(String title, Map<String, int> data, Color baseColor) {
    final total = _totalMembers(data);
    if (data.isEmpty || total == 0) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('$title：無資料'),
        ),
      );
    }

    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: entries.map((e) {
                    final percent = (e.value / total * 100);
                    return PieChartSectionData(
                      color: _colorByKey(baseColor, e.key),
                      value: e.value.toDouble(),
                      title: '${e.key}\n${percent.toStringAsFixed(1)}%',
                      radius: 90,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 顏色動態分配
  Color _colorByKey(Color base, String key) {
    final hash = key.hashCode;
    final h = (hash % 360).toDouble();
    return HSVColor.fromAHSV(1.0, h, 0.45, 0.95).toColor();
  }
}
