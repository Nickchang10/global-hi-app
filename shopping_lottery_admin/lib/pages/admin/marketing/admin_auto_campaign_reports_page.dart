// lib/pages/admin/marketing/admin_auto_campaign_reports_page.dart
//
// ✅ AdminAutoCampaignReportsPage（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// ✅ 修正：移除不必要 cast（避免 unnecessary_cast 警告）
// ✅ 修正：移除 spread 裡不必要的 toList（避免 unnecessary_to_list_in_spreads）
// ✅ 修正：withOpacity 已 deprecated → 改用 withValues(alpha: ...)（避免 deprecated_member_use）
// ✅ Firestore collection: auto_campaign_reports（可透過 constructor 調整）
//
// 期望文件欄位（有就用、沒有就忽略）：
// - campaignId      String
// - segment         String   (all/new/active/vip/churn_risk/sleeping...)
// - channel         String   (push/email/line)
// - date            Timestamp 或 ISO 字串
// - sent            int
// - delivered       int
// - opened          int
// - clicked         int
// - conversions     int
// - cost            double
// - revenue         double
// - errors          int
// - meta            Map      (可選)
// - note            String   (可選)
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAutoCampaignReportsPage extends StatefulWidget {
  const AdminAutoCampaignReportsPage({
    super.key,
    this.collectionName = 'auto_campaign_reports',
    this.campaignId,
  });

  final String collectionName;
  final String? campaignId;

  @override
  State<AdminAutoCampaignReportsPage> createState() =>
      _AdminAutoCampaignReportsPageState();
}

class _AdminAutoCampaignReportsPageState
    extends State<AdminAutoCampaignReportsPage> {
  final _searchCtrl = TextEditingController();
  String _keyword = '';

  // ✅ 分眾選項
  final List<_Segment> _segments = const [
    _Segment(id: 'all', label: '全部'),
    _Segment(id: 'new', label: '新客'),
    _Segment(id: 'active', label: '活躍'),
    _Segment(id: 'vip', label: 'VIP'),
    _Segment(id: 'churn_risk', label: '流失風險'),
    _Segment(id: 'sleeping', label: '沉睡'),
  ];

  String _selectedSegmentId = 'all';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final v = _searchCtrl.text.trim();
      if (v == _keyword) return;
      setState(() => _keyword = v);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(widget.collectionName);

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = _col;

    // 若外部指定 campaignId，就先過濾
    final fixedCampaignId = widget.campaignId?.trim();
    if (fixedCampaignId != null && fixedCampaignId.isNotEmpty) {
      q = q.where('campaignId', isEqualTo: fixedCampaignId);
    }

    // segment 過濾（all 不過濾）
    if (_selectedSegmentId != 'all') {
      q = q.where('segment', isEqualTo: _selectedSegmentId);
    }

    // date 排序（若你的欄位不是 date，改這行即可）
    q = q.orderBy('date', descending: true).limit(200);

    return q;
  }

  bool _matchKeyword(Map<String, dynamic> m) {
    final k = _keyword.trim().toLowerCase();
    if (k.isEmpty) return true;

    final campaignId = (m['campaignId'] ?? '').toString().toLowerCase();
    final segment = (m['segment'] ?? '').toString().toLowerCase();
    final channel = (m['channel'] ?? '').toString().toLowerCase();
    final note = (m['note'] ?? '').toString().toLowerCase();

    return campaignId.contains(k) ||
        segment.contains(k) ||
        channel.contains(k) ||
        note.contains(k);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.campaignId == null || widget.campaignId!.trim().isEmpty
              ? '自動行銷報表'
              : '自動行銷報表｜${widget.campaignId}',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _segments.map((s) {
                      final selected = _selectedSegmentId == s.id;
                      return ChoiceChip(
                        label: Text(s.label),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _selectedSegmentId = s.id),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: '搜尋 campaignId / segment / channel / note',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _keyword.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除',
                            onPressed: () => _searchCtrl.clear(),
                            icon: const Icon(Icons.clear),
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _buildQuery().snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorView(
              message:
                  '讀取失敗：${snap.error}\n\n'
                  '若出現索引需求（FAILED_PRECONDITION: requires an index），'
                  '請到 Firebase Console 建立索引（campaignId/segment/date）。',
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          final filtered = docs.where((d) => _matchKeyword(d.data())).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('目前沒有符合條件的報表資料'));
          }

          final summary = _aggregate(filtered);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _SummaryCard(summary: summary),
              const SizedBox(height: 12),
              Text(
                '明細',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              // ✅ spread 不需要 toList()
              ...filtered.map((d) => _ReportCard(doc: d)),
            ],
          );
        },
      ),
    );
  }

  _ReportSummary _aggregate(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int sent = 0;
    int delivered = 0;
    int opened = 0;
    int clicked = 0;
    int conversions = 0;
    int errors = 0;
    double cost = 0;
    double revenue = 0;

    for (final d in docs) {
      final m = d.data();
      sent += _asInt(m['sent']);
      delivered += _asInt(m['delivered']);
      opened += _asInt(m['opened']);
      clicked += _asInt(m['clicked']);
      conversions += _asInt(m['conversions']);
      errors += _asInt(m['errors']);
      cost += _asDouble(m['cost']);
      revenue += _asDouble(m['revenue']);
    }

    final ctr = delivered <= 0 ? 0.0 : (clicked / delivered);
    final openRate = delivered <= 0 ? 0.0 : (opened / delivered);
    final cvr = clicked <= 0 ? 0.0 : (conversions / clicked);
    final cpc = clicked <= 0 ? 0.0 : (cost / clicked);
    final cpa = conversions <= 0 ? 0.0 : (cost / conversions);
    final roi = cost <= 0 ? 0.0 : ((revenue - cost) / cost);

    return _ReportSummary(
      rows: docs.length,
      sent: sent,
      delivered: delivered,
      opened: opened,
      clicked: clicked,
      conversions: conversions,
      errors: errors,
      cost: cost,
      revenue: revenue,
      openRate: openRate,
      ctr: ctr,
      cvr: cvr,
      cpc: cpc,
      cpa: cpa,
      roi: roi,
    );
  }

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    if (v is List) return v.length;
    if (v is Map) return v.length;
    return 0;
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }
}

// -----------------------------
// Widgets
// -----------------------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final _ReportSummary summary;

  String _pct(double v) => '${(v * 100).toStringAsFixed(2)}%';
  String _money(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tiles = <_MetricTileData>[
      _MetricTileData('筆數', summary.rows.toString(), Icons.dataset),
      _MetricTileData('發送', summary.sent.toString(), Icons.send),
      _MetricTileData(
        '送達',
        summary.delivered.toString(),
        Icons.mark_email_read,
      ),
      _MetricTileData('開啟', summary.opened.toString(), Icons.drafts),
      _MetricTileData('點擊', summary.clicked.toString(), Icons.ads_click),
      _MetricTileData('轉換', summary.conversions.toString(), Icons.check_circle),
      _MetricTileData('錯誤', summary.errors.toString(), Icons.error_outline),
      _MetricTileData('OpenRate', _pct(summary.openRate), Icons.mail),
      _MetricTileData('CTR', _pct(summary.ctr), Icons.trending_up),
      _MetricTileData('CVR', _pct(summary.cvr), Icons.insights),
      _MetricTileData('花費', _money(summary.cost), Icons.payments),
      _MetricTileData('營收', _money(summary.revenue), Icons.monetization_on),
      _MetricTileData('CPC', _money(summary.cpc), Icons.calculate),
      _MetricTileData('CPA', _money(summary.cpa), Icons.price_check),
      _MetricTileData('ROI', _pct(summary.roi), Icons.auto_graph),
    ];

    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '總覽',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final crossAxisCount = w >= 900
                    ? 4
                    : w >= 600
                    ? 3
                    : 2;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tiles.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.8,
                  ),
                  itemBuilder: (_, i) => _MetricTile(data: tiles[i]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTileData {
  final String title;
  final String value;
  final IconData icon;
  const _MetricTileData(this.title, this.value, this.icon);
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.data});
  final _MetricTileData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Icon(data.icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  DateTime? _asDateTime(dynamic v) {
    try {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
    } catch (_) {}
    return null;
  }

  String _fmtDate(dynamic v) {
    final dt = _asDateTime(v);
    if (dt == null) return '';
    String two(int x) => x.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    if (v is List) return v.length;
    if (v is Map) return v.length;
    return 0;
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }

  // ✅ 不用 `as Map<String,dynamic>` 強轉，避免 unnecessary_cast
  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final m = doc.data();

    final campaignId = (m['campaignId'] ?? '').toString();
    final segment = (m['segment'] ?? '').toString();
    final channel = (m['channel'] ?? '').toString();
    final date = _fmtDate(m['date'] ?? m['createdAt']);

    final sent = _asInt(m['sent']);
    final delivered = _asInt(m['delivered']);
    final opened = _asInt(m['opened']);
    final clicked = _asInt(m['clicked']);
    final conversions = _asInt(m['conversions']);
    final errors = _asInt(m['errors']);

    final cost = _asDouble(m['cost']);
    final revenue = _asDouble(m['revenue']);

    final openRate = delivered <= 0 ? 0.0 : (opened / delivered);
    final ctr = delivered <= 0 ? 0.0 : (clicked / delivered);
    final cvr = clicked <= 0 ? 0.0 : (conversions / clicked);

    final note = (m['note'] ?? '').toString();

    final meta = _asMap(m['meta']);

    return Card(
      elevation: 0.6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      if (campaignId.isNotEmpty) campaignId,
                      if (date.isNotEmpty) date,
                    ].join(' · '),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (segment.isNotEmpty) _chip(segment),
                if (channel.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _chip(channel),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _kv('發送', '$sent'),
                _kv('送達', '$delivered'),
                _kv('開啟', '$opened'),
                _kv('點擊', '$clicked'),
                _kv('轉換', '$conversions'),
                _kv('錯誤', '$errors'),
                _kv('OpenRate', '${(openRate * 100).toStringAsFixed(2)}%'),
                _kv('CTR', '${(ctr * 100).toStringAsFixed(2)}%'),
                _kv('CVR', '${(cvr * 100).toStringAsFixed(2)}%'),
                _kv('花費', cost.toStringAsFixed(2)),
                _kv('營收', revenue.toStringAsFixed(2)),
              ],
            ),
            if (note.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(note, style: TextStyle(color: Colors.grey[800])),
            ],
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 10),
              _MetaBox(meta: meta),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        // ✅ withOpacity deprecated → withValues(alpha: ...)
        color: Colors.black.withValues(alpha: 0.06),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87),
          children: [
            TextSpan(
              text: '$k：',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: v),
          ],
        ),
      ),
    );
  }
}

class _MetaBox extends StatelessWidget {
  const _MetaBox({required this.meta});
  final Map<String, dynamic> meta;

  @override
  Widget build(BuildContext context) {
    final entries = meta.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        // ✅ withOpacity deprecated → withValues(alpha: ...)
        color: Colors.black.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Meta', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ...entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${e.key}: ${e.value}'),
            );
          }),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(message, style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}

// -----------------------------
// Data classes
// -----------------------------

class _Segment {
  final String id;
  final String label;
  const _Segment({required this.id, required this.label});
}

class _ReportSummary {
  final int rows;
  final int sent;
  final int delivered;
  final int opened;
  final int clicked;
  final int conversions;
  final int errors;
  final double cost;
  final double revenue;

  final double openRate;
  final double ctr;
  final double cvr;
  final double cpc;
  final double cpa;
  final double roi;

  const _ReportSummary({
    required this.rows,
    required this.sent,
    required this.delivered,
    required this.opened,
    required this.clicked,
    required this.conversions,
    required this.errors,
    required this.cost,
    required this.revenue,
    required this.openRate,
    required this.ctr,
    required this.cvr,
    required this.cpc,
    required this.cpa,
    required this.roi,
  });
}
