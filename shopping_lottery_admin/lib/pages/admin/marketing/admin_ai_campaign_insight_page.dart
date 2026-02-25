// lib/pages/admin/marketing/admin_ai_campaign_insight_page.dart
//
// ✅ AdminAiCampaignInsightPage（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// ✅ 修正：_segments 有使用（ChoiceChips 分眾篩選），不再 unused_field
// ✅ Firestore：讀取 ai_campaign_insights
// ✅ 功能：
//   - 分眾篩選（All / New / Active / VIP / ChurnRisk ...）
//   - 依 campaignId（可選）過濾
//   - 指標彙總（曝光、點擊、轉換、花費、營收、CTR、CVR、CPC、CPA、ROI）
//   - 明細列表
//
// ✅ 修正（lint）
//   - 移除 spread 裡不必要的 toList()
//   - withOpacity deprecated → 改用 withValues(alpha: x)
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAiCampaignInsightPage extends StatefulWidget {
  const AdminAiCampaignInsightPage({
    super.key,
    this.campaignId,
    this.collectionName = 'ai_campaign_insights',
  });

  /// 可選：只看某個活動
  final String? campaignId;

  /// 可改成你實際的 insights collection 名稱
  final String collectionName;

  @override
  State<AdminAiCampaignInsightPage> createState() =>
      _AdminAiCampaignInsightPageState();
}

class _AdminAiCampaignInsightPageState
    extends State<AdminAiCampaignInsightPage> {
  // ✅ 這個欄位原本 unused，現在會用在 UI（ChoiceChips）與查詢過濾
  final List<_Segment> _segments = const [
    _Segment(id: 'all', label: '全部'),
    _Segment(id: 'new', label: '新客'),
    _Segment(id: 'active', label: '活躍'),
    _Segment(id: 'vip', label: 'VIP'),
    _Segment(id: 'churn_risk', label: '流失風險'),
    _Segment(id: 'sleeping', label: '沉睡'),
  ];

  String _selectedSegmentId = 'all';

  final _searchCtrl = TextEditingController();
  String _keyword = '';

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

    if (widget.campaignId != null && widget.campaignId!.trim().isNotEmpty) {
      q = q.where('campaignId', isEqualTo: widget.campaignId!.trim());
    }

    if (_selectedSegmentId != 'all') {
      // segment 欄位值建議與 _segments.id 對齊
      q = q.where('segment', isEqualTo: _selectedSegmentId);
    }

    // date 若是 Timestamp / DateTime / yyyy-MM-dd 字串都可；這裡先以 date/createdAt 排序
    // 若沒有索引或欄位不一致，會在 onError 提示
    q = q.orderBy('date', descending: true);

    // 控制數量（避免一次拉太多）
    q = q.limit(200);

    return q;
  }

  bool _matchKeyword(Map<String, dynamic> data) {
    final k = _keyword.trim().toLowerCase();
    if (k.isEmpty) return true;

    final campaignId = (data['campaignId'] ?? '').toString().toLowerCase();
    final segment = (data['segment'] ?? '').toString().toLowerCase();
    final note = (data['note'] ?? data['summary'] ?? data['title'] ?? '')
        .toString()
        .toLowerCase();

    return campaignId.contains(k) || segment.contains(k) || note.contains(k);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.campaignId == null || widget.campaignId!.isEmpty
              ? 'AI 活動洞察'
              : 'AI 活動洞察｜${widget.campaignId}',
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
                    hintText: '搜尋 campaignId / segment / note',
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
                  '如果你看到 "FAILED_PRECONDITION: The query requires an index"，'
                  '請到 Firebase Console 建索引（campaignId/segment/date）。',
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          final filtered = docs.where((d) => _matchKeyword(d.data())).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('目前沒有符合條件的洞察資料'));
          }

          final summary = _aggregate(filtered);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _SummaryGrid(summary: summary),
              const SizedBox(height: 12),
              Text(
                '明細',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),

              // ✅ 修正：spread 裡不要 .toList()
              ...filtered.map((d) => _InsightCard(doc: d)),
            ],
          );
        },
      ),
    );
  }

  _InsightSummary _aggregate(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int impressions = 0;
    int clicks = 0;
    int conversions = 0;
    double cost = 0;
    double revenue = 0;

    for (final d in docs) {
      final m = d.data();
      impressions += _asInt(m['impressions']);
      clicks += _asInt(m['clicks']);
      conversions += _asInt(m['conversions']);
      cost += _asDouble(m['cost']);
      revenue += _asDouble(m['revenue']);
    }

    final ctr = impressions <= 0 ? 0.0 : (clicks / impressions);
    final cvr = clicks <= 0 ? 0.0 : (conversions / clicks);
    final cpc = clicks <= 0 ? 0.0 : (cost / clicks);
    final cpa = conversions <= 0 ? 0.0 : (cost / conversions);
    final roi = cost <= 0 ? 0.0 : ((revenue - cost) / cost);

    return _InsightSummary(
      impressions: impressions,
      clicks: clicks,
      conversions: conversions,
      cost: cost,
      revenue: revenue,
      ctr: ctr,
      cvr: cvr,
      cpc: cpc,
      cpa: cpa,
      roi: roi,
      rows: docs.length,
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
// UI Widgets
// -----------------------------

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final _InsightSummary summary;

  String _pct(double v) => '${(v * 100).toStringAsFixed(2)}%';
  String _money(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tiles = <_MetricTileData>[
      _MetricTileData('資料筆數', summary.rows.toString(), Icons.dataset),
      _MetricTileData(
        '曝光',
        summary.impressions.toString(),
        Icons.remove_red_eye,
      ),
      _MetricTileData('點擊', summary.clicks.toString(), Icons.ads_click),
      _MetricTileData('轉換', summary.conversions.toString(), Icons.check_circle),
      _MetricTileData('花費', _money(summary.cost), Icons.payments),
      _MetricTileData('營收', _money(summary.revenue), Icons.monetization_on),
      _MetricTileData('CTR', _pct(summary.ctr), Icons.trending_up),
      _MetricTileData('CVR', _pct(summary.cvr), Icons.insights),
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
                final width = c.maxWidth;
                final crossAxisCount = width >= 900
                    ? 4
                    : width >= 600
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

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  String _fmtDate(dynamic v) {
    try {
      DateTime? dt;
      if (v is Timestamp) dt = v.toDate();
      if (v is DateTime) dt = v;
      if (v is String) dt = DateTime.tryParse(v);
      if (dt == null) return '';
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    } catch (_) {
      return '';
    }
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

  @override
  Widget build(BuildContext context) {
    final m = doc.data();

    final campaignId = (m['campaignId'] ?? '').toString();
    final segment = (m['segment'] ?? '').toString();
    final date = _fmtDate(m['date'] ?? m['createdAt']);

    final impressions = _asInt(m['impressions']);
    final clicks = _asInt(m['clicks']);
    final conversions = _asInt(m['conversions']);
    final cost = _asDouble(m['cost']);
    final revenue = _asDouble(m['revenue']);

    final ctr = impressions <= 0 ? 0.0 : (clicks / impressions);
    final cvr = clicks <= 0 ? 0.0 : (conversions / clicks);

    final note = (m['note'] ?? m['summary'] ?? '').toString();

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
                if (segment.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),

                      // ✅ 修正：withOpacity deprecated → withValues(alpha: ...)
                      color: Colors.black.withValues(alpha: 0.06),

                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      segment,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _kv('曝光', impressions.toString()),
                _kv('點擊', clicks.toString()),
                _kv('轉換', conversions.toString()),
                _kv('花費', cost.toStringAsFixed(2)),
                _kv('營收', revenue.toStringAsFixed(2)),
                _kv('CTR', '${(ctr * 100).toStringAsFixed(2)}%'),
                _kv('CVR', '${(cvr * 100).toStringAsFixed(2)}%'),
              ],
            ),
            if (note.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(note, style: TextStyle(color: Colors.grey[800])),
            ],
          ],
        ),
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

class _InsightSummary {
  final int impressions;
  final int clicks;
  final int conversions;
  final double cost;
  final double revenue;
  final double ctr;
  final double cvr;
  final double cpc;
  final double cpa;
  final double roi;
  final int rows;

  const _InsightSummary({
    required this.impressions,
    required this.clicks,
    required this.conversions,
    required this.cost,
    required this.revenue,
    required this.ctr,
    required this.cvr,
    required this.cpc,
    required this.cpa,
    required this.roi,
    required this.rows,
  });
}
