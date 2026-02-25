// lib/pages/admin_campaign_analytics_page.dart
//
// ✅ AdminCampaignAnalyticsPage（活動/投放 Analytics｜可編譯完整版）
// ------------------------------------------------------------
// 修正點：
// 1) import '../services/admin_gate.dart'（避免 pages/services 不存在）
// 2) ensureAndGetRole(user) 正確傳入 FirebaseAuth.currentUser
// 3) _role / _vendorId 改為 String?，避免 String? 指派給 String 的 invalid_assignment
// 4) ✅ 修正 deprecated：withOpacity → withValues(alpha: ...)
// 5) ✅ 修正 use_build_context_synchronously：async gap 不再使用 context.read
//
// 內容：
// - Admin Gate 檢查：只允許 role == 'admin'
// - 統計 campaigns / coupons / orders
// - 近 7/30 天訂單數與金額（欄位兼容：payment.total / totals.total / total / amount）
//
// 依賴：
// - cloud_firestore
// - firebase_auth
// - provider
// - intl
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';

class AdminCampaignAnalyticsPage extends StatefulWidget {
  const AdminCampaignAnalyticsPage({super.key});

  @override
  State<AdminCampaignAnalyticsPage> createState() =>
      _AdminCampaignAnalyticsPageState();
}

class _AdminCampaignAnalyticsPageState
    extends State<AdminCampaignAnalyticsPage> {
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;

  // ✅ 改成可空，避免 String? -> String 指派錯誤
  String? _role;
  String? _vendorId;

  late Future<_Metrics> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadMetrics(); // 先給預設，避免 late 未初始化
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _role = null;
          _vendorId = null;
          _error = '尚未登入（FirebaseAuth.currentUser 為 null）';
        });
        return;
      }

      // ✅ async gap 前先把 gate 取出，避免 await 後再用 context.read
      final gate = context.read<AdminGate>();

      final info = await gate.ensureAndGetRole(user, forceRefresh: false);

      if (!mounted) return;

      setState(() {
        _role = info.role;
        _vendorId = info.vendorId;
        _loading = false;
        _error = null;
      });

      // role OK 後再載入
      setState(() => _future = _loadMetrics());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // -----------------------------
  // Metrics
  // -----------------------------
  Future<_Metrics> _loadMetrics() async {
    final now = DateTime.now();
    final since7 = now.subtract(const Duration(days: 7));
    final since30 = now.subtract(const Duration(days: 30));

    // 你可依實際集合命名修改
    final campaignsCount = await _safeCount(_db.collection('campaigns'));
    final couponsCount = await _safeCount(_db.collection('coupons'));

    // 訂單近 7/30 天
    final orders7d = await _safeCount(
      _db
          .collection('orders')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(since7),
          ),
    );
    final orders30d = await _safeCount(
      _db
          .collection('orders')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(since30),
          ),
    );

    // 金額（取樣加總，避免 web 大集合卡死）
    final amount7d = await _safeSumOrdersSince(since7, limit: 2000);
    final amount30d = await _safeSumOrdersSince(since30, limit: 2000);

    return _Metrics(
      updatedAt: now,
      campaigns: campaignsCount,
      coupons: couponsCount,
      orders7d: orders7d,
      orders30d: orders30d,
      amount7d: amount7d,
      amount30d: amount30d,
    );
  }

  Future<int> _safeCount(Query<Map<String, dynamic>> q) async {
    try {
      final agg = await q.count().get();
      return agg.count ?? 0;
    } catch (_) {
      // fallback：最多抓 2000
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

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse((v ?? '0').toString()) ?? 0;
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final money = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
    final dt = DateFormat('yyyy/MM/dd HH:mm');

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('活動 Analytics')),
        body: Center(child: Text('載入失敗：$_error')),
      );
    }

    final role = (_role ?? '').trim();
    final vendorId = (_vendorId ?? '').trim();

    // 只允許 admin（你要 vendor 也能看就把條件放寬）
    if (role != 'admin') {
      return Scaffold(
        appBar: AppBar(title: const Text('活動 Analytics')),
        body: Center(
          child: Text(
            '無權限（role=${role.isEmpty ? '-' : role} vendorId=${vendorId.isEmpty ? '-' : vendorId}）\n\n'
            '此頁限制 admin 才能查看。',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '活動 / 投放 Analytics',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() => _future = _loadMetrics()),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<_Metrics>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('讀取失敗：${snap.error}'));
          }
          final m = snap.data!;
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
                    '更新時間：${dt.format(m.updatedAt)}',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _kpiGrid(
                children: [
                  _kpiCard('Campaigns 數量', '${m.campaigns}'),
                  _kpiCard('Coupons 數量', '${m.coupons}'),
                  _kpiCard('近 7 天訂單數', '${m.orders7d}'),
                  _kpiCard('近 30 天訂單數', '${m.orders30d}'),
                  _kpiCard('近 7 天金額（取樣加總）', money.format(m.amount7d)),
                  _kpiCard('近 30 天金額（取樣加總）', money.format(m.amount30d)),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    '說明：\n'
                    '• 訂單數：優先使用 Firestore count()；不支援時 fallback 取樣（最多 2000）。\n'
                    '• 金額：為避免 web 大集合卡死，僅加總前 2000 筆。\n'
                    '• 欄位兼容：payment.total / totals.total / total / amount / payAmount。',
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

class _Metrics {
  final DateTime updatedAt;
  final int campaigns;
  final int coupons;
  final int orders7d;
  final int orders30d;
  final num amount7d;
  final num amount30d;

  _Metrics({
    required this.updatedAt,
    required this.campaigns,
    required this.coupons,
    required this.orders7d,
    required this.orders30d,
    required this.amount7d,
    required this.amount30d,
  });
}
