// lib/pages/vendor/vendor_revenue_page.dart
//
// ✅ VendorRevenuePage（最終完整版 / 免 vendorIds+status 複合查詢 index 地獄）
// ------------------------------------------------------------
// - 支援 admin / vendor 兩種模式：
//   - vendor：自動讀取自己的 vendorId
//   - admin：可下拉選擇任一 vendor 觀看營收
// - 查詢策略：
//   - 只呼叫 ReportService.exportOrders(range)（status + createdAt）
//   - 回來後在 App 端依 vendorId/vendorIds 過濾彙總
//   - ✅ 避免 Firestore 「arrayContains + whereIn」導致一直要 composite index
// - 顯示：總營收、訂單數、平均客單、每日營收折線圖、熱銷商品 Top10
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/report_service.dart';

class VendorRevenuePage extends StatefulWidget {
  /// admin 模式可指定預設 vendorId
  final String? initialVendorId;

  /// 可指定預設日期區間（不指定則預設近 30 天）
  final DateTimeRange? initialRange;

  const VendorRevenuePage({
    super.key,
    this.initialVendorId,
    this.initialRange,
  });

  @override
  State<VendorRevenuePage> createState() => _VendorRevenuePageState();
}

class _VendorRevenuePageState extends State<VendorRevenuePage> {
  final _moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
  final _dateFmt = DateFormat('yyyy-MM-dd');

  final _db = FirebaseFirestore.instance;
  final _reportService = ReportService();

  bool _loadingProfile = true;
  bool _isAdmin = false;

  String? _myVendorId; // vendor 登入者自己的 vendorId
  String? _selectedVendorId; // admin 下拉選到的 vendorId

  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 29)),
    end: DateTime.now(),
  );

  Future<_VendorRevenueData>? _futureData;

  @override
  void initState() {
    super.initState();

    if (widget.initialRange != null) {
      _range = widget.initialRange!;
    }

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _loadingProfile = false;
        _isAdmin = false;
      });
      return;
    }

    try {
      final userSnap = await _db.collection('users').doc(uid).get();
      final user = userSnap.data() ?? {};

      final role = (user['role'] ?? '').toString();
      _isAdmin = role == 'admin';

      final vendorId = (user['vendorId'] ?? '').toString();
      _myVendorId = vendorId.isNotEmpty ? vendorId : null;

      // admin：優先使用 initialVendorId，其次不選（等 UI 選擇）
      // vendor：固定使用自己的 vendorId
      if (_isAdmin) {
        _selectedVendorId = widget.initialVendorId;
      } else {
        _selectedVendorId = _myVendorId;
      }

      _reload();
    } catch (_) {
      // 若讀不到 users（規則或資料問題），至少不要卡死
      _isAdmin = false;
      _selectedVendorId = null;
    } finally {
      setState(() => _loadingProfile = false);
    }
  }

  void _reload() {
    final vid = _selectedVendorId;
    if (vid == null || vid.isEmpty) {
      setState(() => _futureData = null);
      return;
    }

    setState(() {
      _futureData = _buildRevenueData(vendorId: vid, range: _range);
    });
  }

  Future<_VendorRevenueData> _buildRevenueData({
    required String vendorId,
    required DateTimeRange range,
  }) async {
    // ✅ 只做 status + createdAt 的查詢（由 ReportService 負責）
    // ✅ 避免 vendorIds arrayContains + status whereIn 的複合索引需求
    final orders = await _reportService.exportOrders(range);

    // 依 vendorId/vendorIds 過濾
    final filtered = orders.where((o) {
      final v1 = (o['vendorId'] ?? '').toString();
      final vIds = (o['vendorIds'] as List?) ?? const [];

      if (v1.isNotEmpty) return v1 == vendorId;
      return vIds.map((e) => e.toString()).contains(vendorId);
    }).toList();

    double totalRevenue = 0;
    int orderCount = 0;
    final dailyRevenue = <String, double>{};
    final productSales = <String, double>{};

    for (final o in filtered) {
      final createdAt = o['createdAt'];
      if (createdAt is! DateTime) continue;

      final amount = (o['finalAmount'] ?? 0).toDouble();
      totalRevenue += amount;
      orderCount++;

      final day = _dateFmt.format(createdAt);
      dailyRevenue[day] = (dailyRevenue[day] ?? 0) + amount;

      final items = (o['items'] as List?) ?? const [];
      for (final it in items) {
        if (it is! Map) continue;
        final name = (it['name'] ?? it['productName'] ?? '').toString();
        if (name.isEmpty) continue;

        // 若你的 items 內有 vendorId，可在這裡更精準只算該 vendor 的商品
        // final itemVendorId = (it['vendorId'] ?? '').toString();
        // if (itemVendorId.isNotEmpty && itemVendorId != vendorId) continue;

        final qty = (it['quantity'] ?? it['qty'] ?? 1).toDouble();
        productSales[name] = (productSales[name] ?? 0) + qty;
      }
    }

    // 補齊區間內每日（確保折線圖連續）
    final normalizedDaily = <String, double>{};
    final startDate = DateTime(range.start.year, range.start.month, range.start.day);
    final endDate = DateTime(range.end.year, range.end.month, range.end.day);

    final days = endDate.difference(startDate).inDays;
    for (int i = 0; i <= days; i++) {
      final d = startDate.add(Duration(days: i));
      final key = _dateFmt.format(d);
      normalizedDaily[key] = dailyRevenue[key] ?? 0;
    }

    return _VendorRevenueData(
      vendorId: vendorId,
      totalRevenue: totalRevenue,
      orderCount: orderCount,
      dailyRevenue: normalizedDaily,
      productSales: productSales,
    );
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      locale: const Locale('zh', 'TW'),
    );

    if (picked == null) return;

    setState(() => _range = picked);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // vendor 若沒有 vendorId，就直接提示
    if (!_isAdmin && (_myVendorId == null || _myVendorId!.isEmpty)) {
      return const Scaffold(
        body: Center(child: Text('尚未綁定廠商帳號（users.vendorId 缺失）')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('營收報表', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: '選擇日期區間',
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range),
          ),
          IconButton(
            tooltip: '重新整理',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderControls(),
          const SizedBox(height: 12),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildHeaderControls() {
    final rangeText =
        '${_dateFmt.format(_range.start)} ~ ${_dateFmt.format(_range.end)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '區間：$rangeText',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (_isAdmin) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 260,
                child: _buildVendorDropdown(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVendorDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('vendors').orderBy('name').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Text('讀取廠商列表失敗');
        }
        if (!snap.hasData) {
          return const LinearProgressIndicator();
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Text('尚無廠商資料');
        }

        final items = docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          final name = (data['name'] ?? data['title'] ?? d.id).toString();
          return DropdownMenuItem<String>(
            value: d.id,
            child: Text(name, overflow: TextOverflow.ellipsis),
          );
        }).toList();

        // 若目前沒有選到 vendor，就預設第一個
        if ((_selectedVendorId == null || _selectedVendorId!.isEmpty) &&
            items.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() => _selectedVendorId = items.first.value);
            _reload();
          });
        }

        return DropdownButtonFormField<String>(
          value: _selectedVendorId,
          items: items,
          decoration: const InputDecoration(
            labelText: '選擇廠商',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) {
            setState(() => _selectedVendorId = v);
            _reload();
          },
        );
      },
    );
  }

  Widget _buildBody() {
    final vid = _selectedVendorId;
    if (vid == null || vid.isEmpty) {
      return const Center(child: Text('請先選擇廠商'));
    }

    final future = _futureData;
    if (future == null) {
      return const Center(child: Text('尚未載入資料'));
    }

    return FutureBuilder<_VendorRevenueData>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) {
          return _errorCard('讀取營收資料失敗（請確認 orders/status/createdAt 欄位與 index）');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snap.data!;
        if (data.orderCount == 0) {
          return const Center(child: Text('此區間尚無營收資料'));
        }

        return Column(
          children: [
            _buildSummaryCards(data),
            const SizedBox(height: 16),
            _buildRevenueChart(data),
            const SizedBox(height: 16),
            _buildTopProducts(data),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCards(_VendorRevenueData d) {
    final avg = d.orderCount == 0 ? 0 : (d.totalRevenue / d.orderCount);

    return Row(
      children: [
        Expanded(
          child: _metricCard(
            title: '總營收',
            value: _moneyFmt.format(d.totalRevenue),
            icon: Icons.payments,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(
            title: '訂單數',
            value: d.orderCount.toString(),
            icon: Icons.receipt_long,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(
            title: '平均客單',
            value: _moneyFmt.format(avg),
            icon: Icons.trending_up,
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 6),
                  Text(value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart(_VendorRevenueData d) {
    final keys = d.dailyRevenue.keys.toList()..sort();
    final spots = <FlSpot>[];

    for (int i = 0; i < keys.length; i++) {
      spots.add(FlSpot(i.toDouble(), d.dailyRevenue[keys[i]]!));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('每日營收', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (keys.length / 6).clamp(1, 999).toDouble(),
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= keys.length) {
                            return const SizedBox.shrink();
                          }
                          // 顯示 MM-dd
                          return Text(
                            keys[i].substring(5),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (v, meta) {
                          // 左側顯示簡化金額
                          if (v == 0) return const Text('0');
                          if (v >= 1000000) return Text('${(v / 1000000).toStringAsFixed(1)}M');
                          if (v >= 1000) return Text('${(v / 1000).toStringAsFixed(0)}K');
                          return Text(v.toStringAsFixed(0));
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.green,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.18),
                      ),
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

  Widget _buildTopProducts(_VendorRevenueData d) {
    final entries = d.productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('尚無商品銷售資料'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('熱銷商品 Top 10', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            ...entries.take(10).map((e) {
              return ListTile(
                dense: true,
                title: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text('銷售量 ${e.value.toInt()}'),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String msg) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// Data model
// --------------------------------------------------

class _VendorRevenueData {
  final String vendorId;
  final double totalRevenue;
  final int orderCount;
  final Map<String, double> dailyRevenue;
  final Map<String, double> productSales;

  _VendorRevenueData({
    required this.vendorId,
    required this.totalRevenue,
    required this.orderCount,
    required this.dailyRevenue,
    required this.productSales,
  });
}
