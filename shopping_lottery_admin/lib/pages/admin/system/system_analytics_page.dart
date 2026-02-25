// lib/pages/admin/system/system_analytics_page.dart
//
// ✅ SystemAnalyticsPage（系統分析｜單檔完整版｜可直接編譯｜無 deprecated）
// -----------------------------------------------------------------------------
// 修正重點：
// - ✅ 移除/避免 withOpacity（deprecated）→ 改用 withValues(alpha: ...)
// - ✅ _toDt 不再 unused（會用於解析 createdAt）
// - ✅ 修正 control_flow_in_finally：finally 裡不使用 return
//
// 會讀取的集合（若不存在也不會崩，會顯示 0 或提示）：
// - users
// - orders
// - sos_events
//
// 注意：此頁為避免掃全庫過重，採「最多掃描 _maxScan 筆」的方式，超過會顯示 ≥N
// -----------------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SystemAnalyticsPage extends StatefulWidget {
  const SystemAnalyticsPage({super.key});

  @override
  State<SystemAnalyticsPage> createState() => _SystemAnalyticsPageState();
}

class _SystemAnalyticsPageState extends State<SystemAnalyticsPage> {
  final _db = FirebaseFirestore.instance;

  static const int _maxScan = 5000; // 最多掃描筆數（避免超大集合造成 UI 卡死）
  bool _loading = true;
  String? _error;
  _AnalyticsData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------------------------------------------------------------------
  // Utils
  // ---------------------------------------------------------------------------

  DateTime? _toDt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    try {
      final dynamic d = v;
      final dt = d.toDate();
      return dt is DateTime ? dt : null;
    } catch (_) {
      return null;
    }
  }

  String _fmtDt(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('yyyy/MM/dd HH:mm').format(dt);
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '0') ?? 0;
  }

  Future<_CountResult> _countApprox(String collectionPath) async {
    // 以 documentId 分頁掃描到 _maxScan，避免一次抓全庫
    final col = _db.collection(collectionPath);

    int total = 0;
    DocumentSnapshot<Map<String, dynamic>>? last;
    const pageSize = 500;

    while (total < _maxScan) {
      Query<Map<String, dynamic>> q = col
          .orderBy(FieldPath.documentId)
          .limit(pageSize);

      if (last != null) {
        q = q.startAfterDocument(last);
      }

      final snap = await q.get();
      if (snap.docs.isEmpty) break;

      total += snap.docs.length;
      last = snap.docs.last;

      if (snap.docs.length < pageSize) break;
    }

    final capped = total >= _maxScan;
    return _CountResult(count: total, capped: capped);
  }

  Future<_OrdersAggResult> _aggregateOrdersLastDays(int days) async {
    final now = DateTime.now();
    final from = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days));

    // where(createdAt>=from) + orderBy(createdAt) 通常不需要複合索引（同欄位）
    final q = _db
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .orderBy('createdAt', descending: true)
        .limit(_maxScan);

    final snap = await q.get();
    num sum = 0;
    int count = 0;

    for (final d in snap.docs) {
      final m = d.data();
      final amount = _toNum(m['finalAmount'] ?? m['total'] ?? 0);
      sum += amount;
      count += 1;
    }

    final capped = snap.docs.length >= _maxScan;
    return _OrdersAggResult(from: from, count: count, sum: sum, capped: capped);
  }

  Future<_SosAggResult> _aggregateSosLastDays(int days) async {
    final now = DateTime.now();
    final from = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days));

    final q = _db
        .collection('sos_events')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .orderBy('createdAt', descending: true)
        .limit(_maxScan);

    final snap = await q.get();

    int triggered = 0;
    int processing = 0;
    int resolved = 0;
    int cancelled = 0;
    DateTime? lastAt;

    for (final doc in snap.docs) {
      final m = doc.data();
      final status = (m['status'] ?? '').toString();

      // ✅ 使用 _toDt（避免 unused_element）
      final createdAt = _toDt(m['createdAt']);
      if (lastAt == null && createdAt != null) lastAt = createdAt;

      switch (status) {
        case 'triggered':
          triggered++;
          break;
        case 'processing':
          processing++;
          break;
        case 'resolved':
          resolved++;
          break;
        case 'cancelled':
          cancelled++;
          break;
        default:
          break;
      }
    }

    final capped = snap.docs.length >= _maxScan;
    return _SosAggResult(
      from: from,
      triggered: triggered,
      processing: processing,
      resolved: resolved,
      cancelled: cancelled,
      lastEventAt: lastAt,
      capped: capped,
    );
  }

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final usersCount = await _countApprox('users');
      final ordersCount = await _countApprox('orders');
      final orders30d = await _aggregateOrdersLastDays(30);
      final sos7d = await _aggregateSosLastDays(7);

      if (!mounted) return;

      setState(() {
        _data = _AnalyticsData(
          users: usersCount,
          orders: ordersCount,
          orders30d: orders30d,
          sos7d: sos7d,
          refreshedAt: DateTime.now(),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      // ✅ 修正：finally 內不可 return
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '系統分析',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(title: '載入失敗', message: _error!, onRetry: _load)
          : _data == null
          ? const _EmptyView(title: '無資料', message: '尚未取得任何統計資料。')
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _headerCard(cs, _data!),
                  const SizedBox(height: 12),
                  _grid(cs, _data!),
                  const SizedBox(height: 12),
                  _ordersCard(cs, _data!),
                  const SizedBox(height: 12),
                  _sosCard(cs, _data!),
                  const SizedBox(height: 28),
                ],
              ),
            ),
    );
  }

  Widget _headerCard(ColorScheme cs, _AnalyticsData d) {
    final bg = cs.primary.withValues(alpha: 0.10);
    final border = cs.primary.withValues(alpha: 0.22);

    return Card(
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.insights, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '更新時間：${_fmtDt(d.refreshedAt)}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '最大掃描：$_maxScan',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(ColorScheme cs, _AnalyticsData d) {
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
    final usersText = d.users.capped
        ? '≥${d.users.count}'
        : d.users.count.toString();
    final ordersText = d.orders.capped
        ? '≥${d.orders.count}'
        : d.orders.count.toString();
    final rev30dText = d.orders30d.capped
        ? '≥${fmtMoney.format(d.orders30d.sum)}'
        : fmtMoney.format(d.orders30d.sum);
    final orders30dText = d.orders30d.capped
        ? '≥${d.orders30d.count}'
        : d.orders30d.count.toString();

    return LayoutBuilder(
      builder: (context, c) {
        final twoCols = c.maxWidth >= 760;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metricCard(
              cs,
              width: twoCols ? (c.maxWidth - 12) / 2 : c.maxWidth,
              title: '會員數（users）',
              value: usersText,
              icon: Icons.people_alt_outlined,
              hint: d.users.capped ? '超過 $_maxScan 筆，顯示下限' : null,
            ),
            _metricCard(
              cs,
              width: twoCols ? (c.maxWidth - 12) / 2 : c.maxWidth,
              title: '訂單數（orders）',
              value: ordersText,
              icon: Icons.receipt_long,
              hint: d.orders.capped ? '超過 $_maxScan 筆，顯示下限' : null,
            ),
            _metricCard(
              cs,
              width: twoCols ? (c.maxWidth - 12) / 2 : c.maxWidth,
              title: '近 30 天訂單筆數',
              value: orders30dText,
              icon: Icons.calendar_month,
              hint: '起算：${DateFormat('MM/dd').format(d.orders30d.from)}',
            ),
            _metricCard(
              cs,
              width: twoCols ? (c.maxWidth - 12) / 2 : c.maxWidth,
              title: '近 30 天營收合計',
              value: rev30dText,
              icon: Icons.payments_outlined,
              hint: d.orders30d.capped ? '只加總前 $_maxScan 筆（顯示下限）' : null,
            ),
          ],
        );
      },
    );
  }

  Widget _metricCard(
    ColorScheme cs, {
    required double width,
    required String title,
    required String value,
    required IconData icon,
    String? hint,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon),
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
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        hint,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
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

  Widget _ordersCard(ColorScheme cs, _AnalyticsData d) {
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
    final capHint = d.orders30d.capped ? '（已達掃描上限，顯示下限）' : '';
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '訂單概況',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              '近 30 天：${d.orders30d.count} 筆$capHint，營收 ${fmtMoney.format(d.orders30d.sum)}',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '提示：此頁為避免掃全庫，採「最多掃描 $_maxScan 筆」策略。若要做精準全庫統計，建議改用 Firestore Aggregation / BigQuery / Cloud Functions 定期落地 metrics。',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sosCard(ColorScheme cs, _AnalyticsData d) {
    final s = d.sos7d;
    final capHint = s.capped ? '（已達掃描上限，顯示下限）' : '';
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SOS 概況',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _pill(cs, '近 7 天', '起算 ${DateFormat('MM/dd').format(s.from)}'),
                _pill(cs, 'triggered', s.triggered.toString()),
                _pill(cs, 'processing', s.processing.toString()),
                _pill(cs, 'resolved', s.resolved.toString()),
                _pill(cs, 'cancelled', s.cancelled.toString()),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '最近一筆事件時間：${_fmtDt(s.lastEventAt)}  $capHint',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(ColorScheme cs, String k, String v) {
    final bg = cs.secondary.withValues(alpha: 0.10);
    final border = cs.secondary.withValues(alpha: 0.22);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        '$k：$v',
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Data models
// -----------------------------------------------------------------------------
class _AnalyticsData {
  final _CountResult users;
  final _CountResult orders;
  final _OrdersAggResult orders30d;
  final _SosAggResult sos7d;
  final DateTime refreshedAt;

  _AnalyticsData({
    required this.users,
    required this.orders,
    required this.orders30d,
    required this.sos7d,
    required this.refreshedAt,
  });
}

class _CountResult {
  final int count;
  final bool capped;
  _CountResult({required this.count, required this.capped});
}

class _OrdersAggResult {
  final DateTime from;
  final int count;
  final num sum;
  final bool capped;
  _OrdersAggResult({
    required this.from,
    required this.count,
    required this.sum,
    required this.capped,
  });
}

class _SosAggResult {
  final DateTime from;
  final int triggered;
  final int processing;
  final int resolved;
  final int cancelled;
  final DateTime? lastEventAt;
  final bool capped;

  _SosAggResult({
    required this.from,
    required this.triggered,
    required this.processing,
    required this.resolved,
    required this.cancelled,
    required this.lastEventAt,
    required this.capped,
  });
}

// -----------------------------------------------------------------------------
// Common Views
// -----------------------------------------------------------------------------
class _EmptyView extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyView({required this.title, required this.message});

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
                  Icon(Icons.info_outline, size: 44, color: cs.primary),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
        constraints: const BoxConstraints(maxWidth: 760),
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
