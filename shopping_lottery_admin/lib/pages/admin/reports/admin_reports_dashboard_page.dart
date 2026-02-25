// lib/pages/admin/reports/admin_reports_dashboard_page.dart
// =====================================================
// ✅ AdminReportsDashboardPage（修正版完整版｜可編譯）
// - ✅ 修正 control_flow_in_finally：finally 內不使用 return（改用 if (mounted) {...}）
// - 報表 Dashboard：區間統計（訂單數/營收/新會員/退款/出貨） + 最近訂單
// - Firestore（預設集合）：orders / users
//   - orders 欄位（常見）：createdAt(Timestamp), finalAmount/total/amount(num), status, userId
//   - users 欄位（常見）：createdAt(Timestamp), displayName/email/phone
// =====================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ✅ FIX: withOpacity deprecated → withValues(alpha: 0~1)
Color _withOpacity(Color c, double opacity01) {
  final o = opacity01.clamp(0.0, 1.0).toDouble();
  return c.withValues(alpha: o);
}

class AdminReportsDashboardPage extends StatefulWidget {
  const AdminReportsDashboardPage({super.key});

  @override
  State<AdminReportsDashboardPage> createState() =>
      _AdminReportsDashboardPageState();
}

class _AdminReportsDashboardPageState extends State<AdminReportsDashboardPage> {
  final _db = FirebaseFirestore.instance;

  bool _loading = false;
  String? _error;

  _DashRange _range = _DashRange.days30;
  _DashData? _data;

  Timer? _debounce;

  final _money = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
  final _df = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void initState() {
    super.initState();
    // 首次載入
    scheduleMicrotask(_reload);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  DateTime get _now => DateTime.now();
  DateTime get _start => _now.subtract(Duration(days: _range.days));

  // =====================================================
  // Data loader
  // =====================================================
  Future<void> _reload() async {
    // 避免短時間多次 refresh
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () async {
      if (!mounted) return;
      setState(() {
        _loading = true;
        _error = null;
      });

      try {
        final data = await _fetchDashData(start: _start);

        if (mounted) {
          setState(() => _data = data);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _error = e.toString());
        }
      } finally {
        // ✅ FIX: finally 不能 return
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    });
  }

  Future<_DashData> _fetchDashData({required DateTime start}) async {
    final startTs = Timestamp.fromDate(start);

    // orders：取區間內最近 500 筆，用來算 count / revenue / refund / shipping 等
    final ordersSnap = await _db
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: startTs)
        .orderBy('createdAt', descending: true)
        .limit(500)
        .get();

    // users：取區間內最近 1000 筆（一般會員新增量不會太誇張）
    final usersSnap = await _db
        .collection('users')
        .where('createdAt', isGreaterThanOrEqualTo: startTs)
        .orderBy('createdAt', descending: true)
        .limit(1000)
        .get();

    final orders = ordersSnap.docs;
    final users = usersSnap.docs;

    num revenue = 0;
    int refunded = 0;
    int shipping = 0;

    for (final doc in orders) {
      final m = doc.data();

      final amount = _asNum(m['finalAmount'] ?? m['total'] ?? m['amount'] ?? 0);
      revenue += amount;

      // 退款判斷（防呆：你欄位不同也不會炸）
      final refundStatus = (m['refundStatus'] ?? '').toString().toLowerCase();
      final refundRequested = m['refundRequested'] == true;
      final isRefunded =
          refundStatus.contains('refund') ||
          refundStatus.contains('refunded') ||
          refundRequested == true;
      if (isRefunded) refunded++;

      // 出貨判斷
      final shippingStatus = (m['shippingStatus'] ?? m['shipStatus'] ?? '')
          .toString()
          .toLowerCase();
      final shippedAt = m['shippedAt'];
      final isShipped =
          shippingStatus.contains('ship') ||
          shippingStatus.contains('delivered') ||
          shippedAt is Timestamp;
      if (isShipped) shipping++;
    }

    // 最近訂單（直接用同一批 orders）
    final recentOrders = orders
        .take(12)
        .map((d) {
          final m = d.data();
          return _OrderLite(
            id: d.id,
            createdAt: _toDateTime(m['createdAt']),
            status: (m['status'] ?? '').toString(),
            userId: (m['userId'] ?? m['uid'] ?? '').toString(),
            amount: _asNum(m['finalAmount'] ?? m['total'] ?? m['amount'] ?? 0),
          );
        })
        .toList(growable: false);

    return _DashData(
      rangeDays: _range.days,
      start: start,
      ordersCount: orders.length,
      revenue: revenue,
      newUsers: users.length,
      refundedCount: refunded,
      shippedCount: shipping,
      recentOrders: recentOrders,
      notes:
          '※ 此頁為「前端統計」：orders 取最多 500 筆、users 取最多 1000 筆。\n'
          '若你要「全量精準報表」，建議用 Cloud Functions/BigQuery 或 Firestore Aggregations。',
    );
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('報表總覽'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _filters(cs),
          const Divider(height: 1),
          Expanded(
            child: _loading && _data == null
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _ErrorView(title: '載入失敗', message: _error!, onRetry: _reload)
                : _body(cs),
          ),
        ],
      ),
    );
  }

  Widget _filters(ColorScheme cs) {
    // ✅ Flutter 3.33+：DropdownButtonFormField 用 initialValue
    final rangeDropdown = DropdownButtonFormField<_DashRange>(
      key: ValueKey('range_${_range.name}'),
      initialValue: _range,
      items: _DashRange.values
          .map(
            (r) => DropdownMenuItem<_DashRange>(value: r, child: Text(r.label)),
          )
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() => _range = v);
        _reload();
      },
      isExpanded: true,
      decoration: InputDecoration(
        labelText: '區間',
        isDense: true,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );

    final hint = Text(
      '統計區間：${DateFormat('yyyy/MM/dd').format(_start)} ～ ${DateFormat('yyyy/MM/dd').format(_now)}',
      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 640;

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                rangeDropdown,
                const SizedBox(height: 8),
                hint,
                if (_loading) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(minHeight: 2),
                ],
              ],
            );
          }

          return Row(
            children: [
              SizedBox(width: 260, child: rangeDropdown),
              const SizedBox(width: 12),
              Expanded(child: hint),
              if (_loading) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _body(ColorScheme cs) {
    final data = _data;

    if (data == null) {
      return const Center(child: Text('尚無資料'));
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _summaryGrid(cs, data),
        const SizedBox(height: 12),
        _recentOrdersCard(cs, data),
        const SizedBox(height: 12),
        _noteCard(cs, data.notes),
      ],
    );
  }

  Widget _summaryGrid(ColorScheme cs, _DashData d) {
    final items = <_KpiItem>[
      _KpiItem(
        title: '訂單數',
        value: d.ordersCount.toString(),
        icon: Icons.receipt_long,
        color: cs.primary,
      ),
      _KpiItem(
        title: '營收（估算）',
        value: _money.format(d.revenue),
        icon: Icons.payments,
        color: cs.tertiary,
      ),
      _KpiItem(
        title: '新會員',
        value: d.newUsers.toString(),
        icon: Icons.person_add_alt_1,
        color: cs.secondary,
      ),
      _KpiItem(
        title: '退款/申請退款',
        value: d.refundedCount.toString(),
        icon: Icons.undo,
        color: cs.error,
      ),
      _KpiItem(
        title: '出貨/已出貨',
        value: d.shippedCount.toString(),
        icon: Icons.local_shipping_outlined,
        color: cs.primary,
      ),
      _KpiItem(
        title: '區間天數',
        value: '${d.rangeDays} 天',
        icon: Icons.date_range,
        color: cs.secondary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final crossAxisCount = c.maxWidth >= 980
            ? 3
            : c.maxWidth >= 640
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: crossAxisCount == 1 ? 3.2 : 2.6,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _kpiCard(cs, items[i]),
        );
      },
    );
  }

  Widget _kpiCard(ColorScheme cs, _KpiItem it) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _withOpacity(it.color, 0.12),
              child: Icon(it.icon, color: it.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it.title,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    it.value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentOrdersCard(ColorScheme cs, _DashData d) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最近訂單（區間內）',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (d.recentOrders.isEmpty)
              Text('（無）', style: TextStyle(color: cs.onSurfaceVariant))
            else
              Column(
                children: [
                  for (final o in d.recentOrders) ...[
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '訂單 ${o.id}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          if (o.status.isNotEmpty) '狀態：${o.status}',
                          if (o.userId.isNotEmpty) 'userId：${o.userId}',
                          '金額：${_money.format(o.amount)}',
                          '時間：${o.createdAt == null ? '-' : _df.format(o.createdAt!)}',
                        ].join('  •  '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // 若你有 gate/page：/admin_order_detail
                        try {
                          Navigator.pushNamed(
                            context,
                            '/admin_order_detail',
                            arguments: {'orderId': o.id},
                          );
                        } catch (_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('尚未註冊路由：/admin_order_detail'),
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _noteCard(ColorScheme cs, String msg) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// Models / Utils
// =====================================================
class _DashData {
  final int rangeDays;
  final DateTime start;

  final int ordersCount;
  final num revenue;
  final int newUsers;

  final int refundedCount;
  final int shippedCount;

  final List<_OrderLite> recentOrders;

  final String notes;

  _DashData({
    required this.rangeDays,
    required this.start,
    required this.ordersCount,
    required this.revenue,
    required this.newUsers,
    required this.refundedCount,
    required this.shippedCount,
    required this.recentOrders,
    required this.notes,
  });
}

class _OrderLite {
  final String id;
  final DateTime? createdAt;
  final String status;
  final String userId;
  final num amount;

  _OrderLite({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.userId,
    required this.amount,
  });
}

class _KpiItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _KpiItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

enum _DashRange {
  days7(7, '近 7 天'),
  days30(30, '近 30 天'),
  days90(90, '近 90 天'),
  days365(365, '近 365 天');

  final int days;
  final String label;
  const _DashRange(this.days, this.label);
}

num _asNum(dynamic v) {
  if (v is num) return v;
  return num.tryParse((v ?? '').toString()) ?? 0;
}

DateTime? _toDateTime(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

// =====================================================
// Shared small views
// =====================================================
class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
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
