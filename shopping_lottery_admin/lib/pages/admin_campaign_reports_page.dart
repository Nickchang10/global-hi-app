// lib/pages/admin_campaign_reports_page.dart
//
// ✅ AdminCampaignReportsPage（活動報表｜可編譯完整版）
// ------------------------------------------------------------
// ✅ 不依賴 Provider / AdminGate（避免 Provider not found / 型別不合）
// ✅ 直接讀 users/{uid}.role 判斷是否 admin
// ✅ 訂單數：優先用 count()（用 dynamic 呼叫以相容舊版），不支援則 fallback 取樣
// ✅ 金額欄位兼容：payment.total / totals.total / total / amount / payAmount
// ✅ 修正 deprecated：
//    - cs.surfaceVariant → cs.surfaceContainerHighest
//    - withOpacity(...) → withValues(alpha: ...)
// ✅ 修正 lint：unnecessary_to_list_in_spreads（移除 spread 裡的 toList）
//
// 依賴：
// - cloud_firestore
// - firebase_auth
// - intl
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminCampaignReportsPage extends StatefulWidget {
  const AdminCampaignReportsPage({super.key});

  @override
  State<AdminCampaignReportsPage> createState() =>
      _AdminCampaignReportsPageState();
}

class _AdminCampaignReportsPageState extends State<AdminCampaignReportsPage> {
  final _db = FirebaseFirestore.instance;

  bool _booting = true;
  String? _bootError;

  String? _role;
  String? _vendorId;

  Future<_ReportData>? _future;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _booting = false;
          _bootError = '尚未登入（FirebaseAuth.currentUser 為 null）';
        });
        return;
      }

      // ✅ 直接查 users/{uid}
      final udoc = await _db.collection('users').doc(user.uid).get();
      final udata = udoc.data() ?? <String, dynamic>{};

      final role = (udata['role'] ?? '').toString().trim().toLowerCase();
      final vendorId = (udata['vendorId'] ?? udata['vendor_id'] ?? '')
          .toString()
          .trim();

      if (!mounted) return;
      setState(() {
        _role = role;
        _vendorId = vendorId.isEmpty ? null : vendorId;
        _booting = false;
        _bootError = null;
        // ✅ admin 才載入報表
        _future = (role == 'admin') ? _loadReport() : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _booting = false;
        _bootError = e.toString();
      });
    }
  }

  Future<_ReportData> _loadReport() async {
    final now = DateTime.now();
    final since7 = now.subtract(const Duration(days: 7));
    final since30 = now.subtract(const Duration(days: 30));

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

    final amount7d = await _safeSumOrdersSince(since7, limit: 2000);
    final amount30d = await _safeSumOrdersSince(since30, limit: 2000);

    final campaigns = await _loadCampaigns(limit: 80);

    return _ReportData(
      updatedAt: now,
      orders7d: orders7d,
      orders30d: orders30d,
      amount7d: amount7d,
      amount30d: amount30d,
      campaigns: campaigns,
    );
  }

  // count() 在某些舊版 cloud_firestore 不存在 → 用 dynamic 呼叫避免「編譯」失敗
  Future<int> _safeCount(Query<Map<String, dynamic>> q) async {
    try {
      final dynamic dq = q;
      final dynamic agg = await dq.count().get();
      final int? cnt = agg.count as int?;
      return cnt ?? 0;
    } catch (_) {
      // fallback：取樣
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

  Future<List<_CampaignRow>> _loadCampaigns({required int limit}) async {
    try {
      final snap = await _db
          .collection('campaigns')
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => _CampaignRow(id: d.id, data: d.data()))
          .toList();
    } catch (_) {
      try {
        final snap = await _db
            .collection('campaigns')
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
        return snap.docs
            .map((d) => _CampaignRow(id: d.id, data: d.data()))
            .toList();
      } catch (_) {
        final snap = await _db
            .collection('campaigns')
            .orderBy(FieldPath.documentId, descending: true)
            .limit(limit)
            .get();
        return snap.docs
            .map((d) => _CampaignRow(id: d.id, data: d.data()))
            .toList();
      }
    }
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse((v ?? '0').toString()) ?? 0;
  }

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_bootError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('活動報表')),
        body: Center(child: Text('初始化失敗：$_bootError')),
      );
    }

    final role = (_role ?? '').trim().toLowerCase();
    final vendorId = (_vendorId ?? '').trim();

    if (role != 'admin') {
      return Scaffold(
        appBar: AppBar(title: const Text('活動報表')),
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

    final money = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
    final dtFmt = DateFormat('yyyy/MM/dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '活動報表',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() => _future = _loadReport()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_ReportData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('載入失敗：${snap.error}'));
          }
          final d = snap.data;
          if (d == null) {
            return Center(
              child: Text('沒有資料', style: TextStyle(color: cs.onSurfaceVariant)),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '更新時間：${dtFmt.format(d.updatedAt)}',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _kpiGrid(
                children: [
                  _kpiCard('近 7 天訂單數', '${d.orders7d}'),
                  _kpiCard('近 30 天訂單數', '${d.orders30d}'),
                  _kpiCard('近 7 天金額（取樣）', money.format(d.amount7d)),
                  _kpiCard('近 30 天金額（取樣）', money.format(d.amount30d)),
                ],
              ),

              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Campaigns（最近 80 筆）',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (d.campaigns.isEmpty)
                        Text(
                          '目前 campaigns 沒資料或無法讀取。',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        )
                      else
                        // ✅ 修正：spread 裡不需要 .toList()
                        ...d.campaigns.map((c) {
                          final data = c.data;

                          final title = _s(data['title']).isNotEmpty
                              ? _s(data['title'])
                              : (_s(data['name']).isNotEmpty
                                    ? _s(data['name'])
                                    : c.id);

                          final status = _s(data['status']).isNotEmpty
                              ? _s(data['status'])
                              : '-';
                          final startAt = _toDateTime(
                            data['startAt'] ?? data['startDate'],
                          );
                          final endAt = _toDateTime(
                            data['endAt'] ?? data['endDate'],
                          );
                          final updatedAt = _toDateTime(
                            data['updatedAt'] ?? data['createdAt'],
                          );

                          final budget = _toNum(
                            data['budget'] ?? data['totalBudget'] ?? 0,
                          );
                          final spent = _toNum(
                            data['spent'] ?? data['spend'] ?? data['cost'] ?? 0,
                          );

                          final rangeText = (startAt == null && endAt == null)
                              ? ''
                              : '${startAt == null ? '?' : DateFormat('MM/dd').format(startAt)}'
                                    ' ~ ${endAt == null ? '?' : DateFormat('MM/dd').format(endAt)}';

                          final double pct = (budget <= 0)
                              ? 0.0
                              : (spent / budget * 100.0).toDouble();
                          final pctText =
                              '${pct.isNaN ? 0 : pct.clamp(0, 999).toStringAsFixed(1)}%';

                          final double progress = (budget <= 0)
                              ? 0.0
                              : ((spent / budget).isFinite
                                        ? (spent / budget)
                                        : 0.0)
                                    .clamp(0.0, 1.0)
                                    .toDouble();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          color: cs.primaryContainer,
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: cs.onPrimaryContainer,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: 6,
                                    children: [
                                      _kv('ID', c.id),
                                      if (rangeText.isNotEmpty)
                                        _kv('期間', rangeText),
                                      if (updatedAt != null)
                                        _kv('更新', dtFmt.format(updatedAt)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: 6,
                                    children: [
                                      _kv('Budget', money.format(budget)),
                                      _kv('Spent', money.format(spent)),
                                      _kv('使用率', pctText),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(99),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                      const SizedBox(height: 6),
                      Text(
                        '說明：\n'
                        '• 訂單數：優先 count()，不支援則 fallback 取樣。\n'
                        '• 金額：為避免 Web 大集合卡死，最多加總 2000 筆。\n'
                        '• campaigns 欄位不固定，本頁用安全讀取（不存在就顯示 -）。',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
            const Icon(Icons.assessment_outlined),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$k：',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        ),
        Text(v, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _ReportData {
  final DateTime updatedAt;
  final int orders7d;
  final int orders30d;
  final num amount7d;
  final num amount30d;
  final List<_CampaignRow> campaigns;

  _ReportData({
    required this.updatedAt,
    required this.orders7d,
    required this.orders30d,
    required this.amount7d,
    required this.amount30d,
    required this.campaigns,
  });
}

class _CampaignRow {
  final String id;
  final Map<String, dynamic> data;
  _CampaignRow({required this.id, required this.data});
}
