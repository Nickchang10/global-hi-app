// lib/pages/admin/system/admin_system_analytics_page.dart
//
// ✅ AdminSystemAnalyticsPage（最終完整版｜報表分析 Dashboard｜可直接使用）
// ------------------------------------------------------------
// 目的：取代 AdminShellPage 內的 system.analytics Placeholder
//
// Firestore（預設）
// - orders（建議欄位：createdAt, status, total/totalAmount/payment/summary...）
// - users（建議欄位：createdAt）
// - products（可選）
//
// 功能：
// - 時間區間：7 / 30 / 90 / 365 天 + 自訂 DateRange
// - 指標：訂單數、營收估算、狀態分佈、會員新增（若 users.createdAt 存在）、商品總數（可選）
// - 容錯：
//   - createdAt 缺失 → 該筆略過（不影響頁面）
//   - total 欄位位置不固定 → 多 key / 多層 fallback 解析
//   - users/products 查詢失敗 → 顯示為「—」但不讓整頁壞掉
//
// 依賴：cloud_firestore, intl
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminSystemAnalyticsPage extends StatefulWidget {
  const AdminSystemAnalyticsPage({super.key});

  @override
  State<AdminSystemAnalyticsPage> createState() =>
      _AdminSystemAnalyticsPageState();
}

class _AdminSystemAnalyticsPageState extends State<AdminSystemAnalyticsPage> {
  final _db = FirebaseFirestore.instance;

  // 快速區間
  static const _range7 = '7';
  static const _range30 = '30';
  static const _range90 = '90';
  static const _range365 = '365';
  static const _rangeCustom = 'custom';

  String _rangeKey = _range30;
  DateTimeRange? _customRange;

  late Future<_AnalyticsData> _future;

  final _dtFmt = DateFormat('yyyy/MM/dd');
  final _moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: r'$');

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  DateTimeRange get _activeRange {
    if (_rangeKey == _rangeCustom && _customRange != null) return _customRange!;
    final now = DateTime.now();
    final days = int.tryParse(_rangeKey) ?? 30;
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return DateTimeRange(start: start, end: end);
  }

  Future<_AnalyticsData> _load() async {
    final r = _activeRange;

    // 1) Orders：以 createdAt 做範圍
    final orders = await _fetchOrdersInRange(r);

    // 2) Users / Products：容錯，不要讓整頁因為缺 index / 欄位而壞
    final usersNew = await _tryCountUsersInRange(r);
    final productsCount = await _tryCountProducts();

    return _AnalyticsData(
      range: r,
      orders: orders,
      usersNew: usersNew,
      productsCount: productsCount,
    );
  }

  Future<List<_OrderLite>> _fetchOrdersInRange(DateTimeRange r) async {
    // Firestore range on createdAt：建議存在 Timestamp createdAt
    // 注意：若你 orders 用別的欄位（例如 placedAt / created_time），請自行替換此欄位名
    final q = _db
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(r.start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(r.end))
        .orderBy('createdAt', descending: true)
        .limit(2000);

    final snap = await q.get();
    final out = <_OrderLite>[];

    for (final doc in snap.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final createdAt = _toDateTime(d['createdAt']);
      if (createdAt == null) continue;

      final status = _normalizeStatus(d);
      final total = _extractMoney(d);

      out.add(
        _OrderLite(
          id: doc.id,
          createdAt: createdAt,
          status: status,
          total: total,
          raw: d,
        ),
      );
    }
    return out;
  }

  Future<int?> _tryCountUsersInRange(DateTimeRange r) async {
    // 如果 users 沒有 createdAt 或缺 index，就回傳 null（顯示「—」）
    try {
      final q = _db
          .collection('users')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(r.start))
          .where('createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(r.end))
          .limit(2000);

      final snap = await q.get();
      return snap.size;
    } catch (_) {
      return null;
    }
  }

  Future<int?> _tryCountProducts() async {
    try {
      final snap = await _db.collection('products').limit(2000).get();
      return snap.size;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '報表分析',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _future = _load()),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          _rangeBar(cs),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<_AnalyticsData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorView(
                    title: '載入失敗',
                    message: snap.error.toString(),
                    hint:
                        '若看到 permission-denied：請確認 rules 允許 isAdmin() 讀取 orders/users/products。\n'
                        '若看到 FAILED_PRECONDITION：可能需要索引或 users 無 createdAt。',
                    onRetry: () => setState(() => _future = _load()),
                  );
                }

                final data = snap.data ?? _AnalyticsData.empty(_activeRange);
                return _content(data, cs);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _rangeBar(ColorScheme cs) {
    final r = _activeRange;
    final label = '${_dtFmt.format(r.start)} ~ ${_dtFmt.format(r.end)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '區間：$label',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _rangeKey,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: _range7, child: Text('近 7 天')),
              DropdownMenuItem(value: _range30, child: Text('近 30 天')),
              DropdownMenuItem(value: _range90, child: Text('近 90 天')),
              DropdownMenuItem(value: _range365, child: Text('近 365 天')),
              DropdownMenuItem(value: _rangeCustom, child: Text('自訂')),
            ],
            onChanged: (v) async {
              final next = v ?? _range30;
              if (next == _rangeCustom) {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  initialDateRange: _customRange ?? _activeRange,
                );
                if (picked == null) return;
                setState(() {
                  _rangeKey = _rangeCustom;
                  _customRange = picked;
                  _future = _load();
                });
                return;
              }

              setState(() {
                _rangeKey = next;
                _future = _load();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _content(_AnalyticsData data, ColorScheme cs) {
    final orders = data.orders;

    final orderCount = orders.length;
    final revenue = orders.fold<double>(0.0, (sum, o) => sum + (o.total ?? 0.0));

    final statusCounts = <String, int>{};
    for (final o in orders) {
      final k = o.status.isEmpty ? 'unknown' : o.status;
      statusCounts[k] = (statusCounts[k] ?? 0) + 1;
    }

    // 近 7 天日別營收（簡單表格，避免額外 chart 依賴）
    final daily = _dailyRevenue(orders);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metricCard(
              title: '訂單數',
              value: orderCount.toString(),
              icon: Icons.receipt_long_outlined,
              cs: cs,
            ),
            _metricCard(
              title: '營收估算',
              value: _moneyFmt.format(revenue),
              icon: Icons.payments_outlined,
              cs: cs,
            ),
            _metricCard(
              title: '會員新增',
              value: data.usersNew == null ? '—' : data.usersNew.toString(),
              icon: Icons.person_add_alt_1_outlined,
              cs: cs,
              sub: data.usersNew == null ? 'users.createdAt 不存在或索引/查詢限制' : null,
            ),
            _metricCard(
              title: '商品數',
              value: data.productsCount == null ? '—' : data.productsCount.toString(),
              icon: Icons.inventory_2_outlined,
              cs: cs,
            ),
          ],
        ),

        const SizedBox(height: 16),

        _sectionTitle('訂單狀態分佈', cs),
        const SizedBox(height: 8),
        _statusTable(statusCounts, cs),

        const SizedBox(height: 16),

        _sectionTitle('近 7 天日別營收（估算）', cs),
        const SizedBox(height: 8),
        _dailyTable(daily, cs),

        const SizedBox(height: 16),

        _sectionTitle('資料來源與注意事項', cs),
        const SizedBox(height: 8),
        _hintCard(cs),
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required ColorScheme cs,
    String? sub,
  }) {
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: cs.primaryContainer,
                child: Icon(icon, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (sub != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        sub,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, ColorScheme cs) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 16,
        color: cs.onSurface,
      ),
    );
  }

  Widget _statusTable(Map<String, int> counts, ColorScheme cs) {
    if (counts.isEmpty) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('此區間沒有訂單資料'),
        ),
      );
    }

    final rows = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: rows.map((e) {
            final label = _statusDisplay(e.key);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '${e.value}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _dailyTable(List<_DayRevenue> daily, ColorScheme cs) {
    if (daily.isEmpty) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('此區間沒有可用的 createdAt/金額資料'),
        ),
      );
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: daily.map((d) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      d.day,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    _moneyFmt.format(d.revenue),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _hintCard(ColorScheme cs) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          '- 本頁以 orders.createdAt 為時間範圍；若你的欄位名稱不同，請在程式中替換。\n'
          '- 營收估算會從多個欄位嘗試抓取（total/totalAmount/payment/summary...），若你的結構不同可再加 key。\n'
          '- users 新增數依賴 users.createdAt；若沒有該欄位會顯示「—」。\n'
          '- 為避免一次拉太多資料，orders 目前上限 2000 筆；若需要可改用 Aggregate 或後端統計。',
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Helpers: status + money + date
  // ============================================================

  static String _normalizeStatus(Map<String, dynamic> d) {
    final raw = (d['status'] ??
            d['orderStatus'] ??
            d['paymentStatus'] ??
            d['shippingStatus'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    if (raw.isEmpty) return '';
    return raw;
  }

  static String _statusDisplay(String s) {
    switch (s) {
      case 'pending':
        return 'pending（待處理）';
      case 'paid':
        return 'paid（已付款）';
      case 'processing':
        return 'processing（處理中）';
      case 'shipped':
        return 'shipped（已出貨）';
      case 'delivered':
        return 'delivered（已送達）';
      case 'completed':
        return 'completed（已完成）';
      case 'cancelled':
      case 'canceled':
        return 'cancelled（已取消）';
      case 'refunded':
        return 'refunded（已退款）';
      case 'closed':
        return 'closed（已結案）';
      case 'unknown':
        return 'unknown（未知）';
      default:
        return s;
    }
  }

  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  static double? _extractMoney(Map<String, dynamic> d) {
    // 常見 top-level keys
    final directKeys = [
      'total',
      'totalAmount',
      'grandTotal',
      'amount',
      'payable',
      'priceTotal',
    ];

    for (final k in directKeys) {
      final v = d[k];
      final x = _numToDouble(v);
      if (x != null) return x;
    }

    // 常見 nested：payment / summary / pricing
    final nestedPaths = [
      ['payment', 'total'],
      ['payment', 'amount'],
      ['summary', 'total'],
      ['summary', 'amount'],
      ['pricing', 'total'],
      ['pricing', 'amount'],
    ];

    for (final path in nestedPaths) {
      dynamic cur = d;
      for (final key in path) {
        if (cur is Map && cur[key] != null) {
          cur = cur[key];
        } else {
          cur = null;
          break;
        }
      }
      final x = _numToDouble(cur);
      if (x != null) return x;
    }

    return null;
  }

  static double? _numToDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final cleaned = v.replaceAll(',', '').trim();
      return double.tryParse(cleaned);
    }
    return null;
  }

  List<_DayRevenue> _dailyRevenue(List<_OrderLite> orders) {
    // 取最近 7 天（依照「今天往回」）
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));

    final map = <String, double>{};
    for (final o in orders) {
      if (o.total == null) continue;
      final dt = o.createdAt;
      if (dt.isBefore(start)) continue;

      final day = DateTime(dt.year, dt.month, dt.day);
      final key = _dtFmt.format(day);
      map[key] = (map[key] ?? 0) + o.total!;
    }

    final days = map.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return days.map((e) => _DayRevenue(day: e.key, revenue: e.value)).toList();
  }
}

// ============================================================
// Data models
// ============================================================

class _AnalyticsData {
  final DateTimeRange range;
  final List<_OrderLite> orders;
  final int? usersNew;
  final int? productsCount;

  _AnalyticsData({
    required this.range,
    required this.orders,
    required this.usersNew,
    required this.productsCount,
  });

  factory _AnalyticsData.empty(DateTimeRange r) => _AnalyticsData(
        range: r,
        orders: const [],
        usersNew: null,
        productsCount: null,
      );
}

class _OrderLite {
  final String id;
  final DateTime createdAt;
  final String status;
  final double? total;
  final Map<String, dynamic> raw;

  _OrderLite({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.total,
    required this.raw,
  });
}

class _DayRevenue {
  final String day;
  final double revenue;

  _DayRevenue({required this.day, required this.revenue});
}

// ============================================================
// Error View
// ============================================================

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final String? hint;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 44, color: cs.error),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                  if (hint != null) ...[
                    const SizedBox(height: 10),
                    Text(hint!, style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重試'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
