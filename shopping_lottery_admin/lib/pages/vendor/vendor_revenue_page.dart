// lib/pages/vendor/vendor_revenue_page.dart
//
// ✅ VendorRevenuePage（可編譯完整版｜已修正：value deprecated + curly_braces lint + withOpacity deprecated）
// ------------------------------------------------------------
// - 顯示指定區間營收、訂單數、平均客單
// - 支援狀態篩選
// - 顯示每日營收折線圖 + 最近訂單列表
// - vendorId 由 users/{uid}.vendorId 取得（你也可改成接 AdminGate）
//
// 依賴：firebase_auth, cloud_firestore, intl, fl_chart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VendorRevenuePage extends StatefulWidget {
  const VendorRevenuePage({super.key});

  static const String routeName = '/vendor/revenue';

  @override
  State<VendorRevenuePage> createState() => _VendorRevenuePageState();
}

class _VendorRevenuePageState extends State<VendorRevenuePage> {
  final _db = FirebaseFirestore.instance;
  final _moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

  String? _vendorId;
  bool _loading = true;

  static const List<_RangeOption> _ranges = <_RangeOption>[
    _RangeOption('近 7 天', 7),
    _RangeOption('近 30 天', 30),
    _RangeOption('近 90 天', 90),
  ];
  _RangeOption _range = _ranges[1];

  // 依你專案狀態命名自行調整
  static const List<_StatusOption> _statuses = <_StatusOption>[
    _StatusOption('全部', 'all'),
    _StatusOption('待付款', 'pending_payment'),
    _StatusOption('已付款', 'paid'),
    _StatusOption('已出貨', 'shipping'),
    _StatusOption('已完成', 'completed'),
    _StatusOption('已取消', 'canceled'),
  ];
  _StatusOption _status = _statuses[0];

  @override
  void initState() {
    super.initState();
    _loadVendorId();
  }

  Future<void> _loadVendorId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    final snap = await _db.collection('users').doc(uid).get();
    _vendorId = (snap.data()?['vendorId'] ?? '').toString().trim();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse((v ?? '').toString()) ?? 0;
  }

  DateTime? _toDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return null;
  }

  String _fmtYmd(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  String _fmtDateTime(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Query<Map<String, dynamic>> _buildOrdersQuery(String vendorId) {
    final from = DateTime.now().subtract(Duration(days: _range.days));
    final fromTs = Timestamp.fromDate(
      DateTime(from.year, from.month, from.day),
    );

    Query<Map<String, dynamic>> q = _db
        .collection('orders')
        .where('vendorIds', arrayContains: vendorId)
        .where('createdAt', isGreaterThanOrEqualTo: fromTs)
        .orderBy('createdAt', descending: true)
        .limit(500);

    if (_status.value != 'all') {
      q = q.where('status', isEqualTo: _status.value);
    }
    return q;
  }

  Color _statusColor(BuildContext context, String status) {
    final s = status.toLowerCase();
    if (s.contains('pending')) return Colors.orange;
    if (s.contains('paid')) return Colors.blue;
    if (s.contains('ship')) return Colors.purple;
    if (s.contains('complete')) return Colors.green;
    if (s.contains('cancel')) return Colors.grey;
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (FirebaseAuth.instance.currentUser == null) {
      return const Scaffold(body: Center(child: Text('請先登入')));
    }
    if ((_vendorId ?? '').isEmpty) {
      return const Scaffold(body: Center(child: Text('此帳號尚未綁定 vendorId')));
    }

    final vendorId = _vendorId!;
    final ordersQuery = _buildOrdersQuery(vendorId);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '營收總覽',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _decoratedDropdown<_RangeOption>(
                  label: '區間',
                  value: _range,
                  items: _ranges,
                  itemLabel: (x) => x.label,
                  onChanged: (v) => setState(() => _range = v),
                ),
                _decoratedDropdown<_StatusOption>(
                  label: '狀態',
                  value: _status,
                  items: _statuses,
                  itemLabel: (x) => x.label,
                  onChanged: (v) => setState(() => _status = v),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Text(
                    'Vendor：$vendorId',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ordersQuery.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        '讀取失敗：${snap.error}',
                        style: TextStyle(color: cs.error),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '請確認 orders 索引：vendorIds(arrayContains) + createdAt(where/orderBy)。',
                      ),
                    ],
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;

                // ===== 統計 =====
                var revenue = 0.0;
                final orderCount = docs.length;

                // 每日營收
                final Map<String, double> daily = {};

                for (final d in docs) {
                  final m = d.data();
                  final created = _toDate(m['createdAt']);
                  if (created == null) {
                    continue;
                  }

                  // 你的金額欄位可能是 finalAmount / total / amount / grandTotal
                  final amount = _toNum(
                    m['finalAmount'] ??
                        m['total'] ??
                        m['amount'] ??
                        m['grandTotal'] ??
                        0,
                  );
                  revenue += amount.toDouble();

                  final key = _fmtYmd(
                    DateTime(created.year, created.month, created.day),
                  );
                  daily[key] = (daily[key] ?? 0) + amount.toDouble();
                }

                final avg = orderCount == 0 ? 0.0 : (revenue / orderCount);

                // ===== 轉成圖表點 =====
                final keys = daily.keys.toList()..sort();
                final spots = <FlSpot>[];
                for (var i = 0; i < keys.length; i++) {
                  spots.add(
                    FlSpot(i.toDouble(), (daily[keys[i]] ?? 0).toDouble()),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _metricCard('訂單數', orderCount.toString()),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _metricCard('總營收', _moneyFmt.format(revenue)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _metricCard('平均客單', _moneyFmt.format(avg)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _metricCard('區間', _range.label)),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ===== 圖表 =====
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '每日營收趨勢',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (spots.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 18),
                                child: Text('（此區間沒有資料）'),
                              )
                            else
                              SizedBox(
                                height: 180,
                                child: LineChart(
                                  LineChartData(
                                    gridData: const FlGridData(show: false),
                                    borderData: FlBorderData(show: true),
                                    titlesData: FlTitlesData(
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          interval: 1,
                                          getTitlesWidget: (v, meta) {
                                            final idx = v.toInt();
                                            if (idx < 0 || idx >= keys.length) {
                                              return const SizedBox.shrink();
                                            }
                                            final parts = keys[idx].split('-');
                                            final label = parts.length >= 3
                                                ? '${parts[1]}/${parts[2]}'
                                                : keys[idx];
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 6,
                                              ),
                                              child: Text(
                                                label,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 44,
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                    ),
                                    lineBarsData: [
                                      LineChartBarData(
                                        isCurved: true,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        barWidth: 3,
                                        dotData: const FlDotData(show: false),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          // ✅ withOpacity deprecated → withValues
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.12),
                                        ),
                                        spots: spots,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    const Text(
                      '最近訂單',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (docs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('（沒有訂單）'),
                      )
                    else
                      ...docs.take(60).map((d) {
                        final m = d.data();
                        final statusRaw = (m['status'] ?? '').toString().trim();
                        final status = statusRaw.isEmpty ? '-' : statusRaw;
                        final createdAt = _toDate(m['createdAt']);
                        final customer =
                            (m['customerName'] ?? m['userName'] ?? '-')
                                .toString();
                        final amount = _toNum(
                          m['finalAmount'] ??
                              m['total'] ??
                              m['amount'] ??
                              m['grandTotal'] ??
                              0,
                        );

                        final chipColor = _statusColor(context, status);
                        final bg = chipColor.withValues(alpha: 0.12);
                        final bd = chipColor.withValues(alpha: 0.25);

                        return Card(
                          child: ListTile(
                            title: Text(
                              '訂單 ${d.id}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              '$customer ・ $status ・ ${_moneyFmt.format(amount)} ・ ${_fmtDateTime(createdAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: bd),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: chipColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String value) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decoratedDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T> onChanged,
  }) {
    return SizedBox(
      width: 170,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isDense: true,
            isExpanded: true,
            onChanged: (v) {
              if (v == null) {
                return;
              }
              onChanged(v);
            },
            items: items
                .map(
                  (e) => DropdownMenuItem<T>(
                    value: e,
                    child: Text(itemLabel(e), overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
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

class _StatusOption {
  final String label;
  final String value;
  const _StatusOption(this.label, this.value);

  @override
  bool operator ==(Object other) =>
      other is _StatusOption && other.value == value && other.label == label;

  @override
  int get hashCode => Object.hash(label, value);
}
