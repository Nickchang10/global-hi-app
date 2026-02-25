// lib/pages/admin/marketing/admin_marketing_reports_page.dart
//
// ✅ AdminMarketingReportsPage（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// ✅ 修正：移除不必要 cast（避免 unnecessary_cast）
//    - 不使用：xxx as Map<String, dynamic>
//    - 改用：if (v is Map) Map<String, dynamic>.from(v)
//
// ✅ 修正：unnecessary_to_list_in_spreads
//    - ...iterable.toList() → ...iterable
//
// ✅ 修正：curly_braces_in_flow_control_structures
//    - if (...) return ...; → if (...) { return ...; }
//
// ✅ 預防：withOpacity deprecated → withValues(alpha: double 0~1)
//
// ✅ 功能：
//   - Tab 1：自動活動報表（auto_campaign_reports）
//   - Tab 2：AI 洞察（ai_campaign_insights）
//   - Tab 3：抽獎中獎（lottery_winners）
//   - 搜尋（campaignId / segment / channel / user / prize 等）
//   - KPI 彙總（CTR/CVR/ROI...）
//
// 依賴：cloud_firestore, flutter/material
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminMarketingReportsPage extends StatefulWidget {
  const AdminMarketingReportsPage({
    super.key,
    this.autoReportsCollection = 'auto_campaign_reports',
    this.aiInsightsCollection = 'ai_campaign_insights',
    this.lotteryWinnersCollection = 'lottery_winners',
  });

  final String autoReportsCollection;
  final String aiInsightsCollection;
  final String lotteryWinnersCollection;

  @override
  State<AdminMarketingReportsPage> createState() =>
      _AdminMarketingReportsPageState();
}

class _AdminMarketingReportsPageState extends State<AdminMarketingReportsPage> {
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('行銷報表'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(106),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText:
                          '搜尋（campaignId / segment / channel / user / prize / note）',
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
                  const SizedBox(height: 10),
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.bar_chart), text: '自動活動'),
                      Tab(icon: Icon(Icons.insights), text: 'AI 洞察'),
                      Tab(icon: Icon(Icons.emoji_events), text: '抽獎中獎'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _AutoReportsTab(
              keyword: _keyword,
              collectionName: widget.autoReportsCollection,
            ),
            _AiInsightsTab(
              keyword: _keyword,
              collectionName: widget.aiInsightsCollection,
            ),
            _LotteryWinnersTab(
              keyword: _keyword,
              collectionName: widget.lotteryWinnersCollection,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Tab 1: Auto Campaign Reports
// ============================================================

class _AutoReportsTab extends StatefulWidget {
  const _AutoReportsTab({required this.keyword, required this.collectionName});

  final String keyword;
  final String collectionName;

  @override
  State<_AutoReportsTab> createState() => _AutoReportsTabState();
}

class _AutoReportsTabState extends State<_AutoReportsTab> {
  String _segment = 'all';

  static const _segments = <_Option>[
    _Option('all', '全部'),
    _Option('new', '新客'),
    _Option('active', '活躍'),
    _Option('vip', 'VIP'),
    _Option('churn_risk', '流失風險'),
    _Option('sleeping', '沉睡'),
  ];

  Query<Map<String, dynamic>> _query() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
      widget.collectionName,
    );

    if (_segment != 'all') {
      q = q.where('segment', isEqualTo: _segment);
    }

    // 若你不是 date 欄位，可改成 createdAt
    q = q.orderBy('date', descending: true).limit(250);
    return q;
  }

  bool _match(Map<String, dynamic> m) {
    final k = widget.keyword.trim().toLowerCase();
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
    return Column(
      children: [
        _FilterBar(
          left: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _segments.map((s) {
              final selected = _segment == s.value;
              return ChoiceChip(
                label: Text(s.label),
                selected: selected,
                onSelected: (_) => setState(() => _segment = s.value),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _query().snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _ErrorView(
                  message:
                      '讀取自動活動報表失敗：${snap.error}\n\n'
                      '若提示需要索引，請建立索引（segment/date 或 campaignId/segment/date）。\n'
                      '若你沒有 date 欄位，請把 orderBy(\'date\') 改成 orderBy(\'createdAt\')。',
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;
              final filtered = docs.where((d) => _match(d.data())).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('沒有符合條件的自動活動報表資料'));
              }

              final summary = _AutoSummary.fromDocs(filtered);

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _SummaryCard(title: '自動活動 KPI', tiles: summary.tiles()),
                  const SizedBox(height: 12),
                  const Text(
                    '明細',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  // ✅ FIX: unnecessary_to_list_in_spreads
                  ...filtered.map((d) => _AutoReportCard(doc: d)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AutoSummary {
  final int rows;
  final int sent;
  final int delivered;
  final int opened;
  final int clicked;
  final int conversions;
  final int errors;
  final double cost;
  final double revenue;

  _AutoSummary({
    required this.rows,
    required this.sent,
    required this.delivered,
    required this.opened,
    required this.clicked,
    required this.conversions,
    required this.errors,
    required this.cost,
    required this.revenue,
  });

  static _AutoSummary fromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int sent = 0,
        delivered = 0,
        opened = 0,
        clicked = 0,
        conversions = 0,
        errors = 0;
    double cost = 0, revenue = 0;

    for (final d in docs) {
      final m = d.data();
      sent += _Num.asInt(m['sent']);
      delivered += _Num.asInt(m['delivered']);
      opened += _Num.asInt(m['opened']);
      clicked += _Num.asInt(m['clicked']);
      conversions += _Num.asInt(m['conversions']);
      errors += _Num.asInt(m['errors']);
      cost += _Num.asDouble(m['cost']);
      revenue += _Num.asDouble(m['revenue']);
    }

    return _AutoSummary(
      rows: docs.length,
      sent: sent,
      delivered: delivered,
      opened: opened,
      clicked: clicked,
      conversions: conversions,
      errors: errors,
      cost: cost,
      revenue: revenue,
    );
  }

  List<_Metric> tiles() {
    final openRate = delivered <= 0 ? 0.0 : opened / delivered;
    final ctr = delivered <= 0 ? 0.0 : clicked / delivered;
    final cvr = clicked <= 0 ? 0.0 : conversions / clicked;
    final cpc = clicked <= 0 ? 0.0 : cost / clicked;
    final cpa = conversions <= 0 ? 0.0 : cost / conversions;
    final roi = cost <= 0 ? 0.0 : (revenue - cost) / cost;

    return [
      _Metric('筆數', '$rows', Icons.dataset),
      _Metric('發送', '$sent', Icons.send),
      _Metric('送達', '$delivered', Icons.mark_email_read),
      _Metric('開啟', '$opened', Icons.drafts),
      _Metric('點擊', '$clicked', Icons.ads_click),
      _Metric('轉換', '$conversions', Icons.check_circle),
      _Metric('錯誤', '$errors', Icons.error_outline),
      _Metric('OpenRate', _Fmt.pct(openRate), Icons.mail),
      _Metric('CTR', _Fmt.pct(ctr), Icons.trending_up),
      _Metric('CVR', _Fmt.pct(cvr), Icons.insights),
      _Metric('花費', _Fmt.money(cost), Icons.payments),
      _Metric('營收', _Fmt.money(revenue), Icons.monetization_on),
      _Metric('CPC', _Fmt.money(cpc), Icons.calculate),
      _Metric('CPA', _Fmt.money(cpa), Icons.price_check),
      _Metric('ROI', _Fmt.pct(roi), Icons.auto_graph),
    ];
  }
}

class _AutoReportCard extends StatelessWidget {
  const _AutoReportCard({required this.doc});
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final m = doc.data();

    final campaignId = (m['campaignId'] ?? '').toString();
    final segment = (m['segment'] ?? '').toString();
    final channel = (m['channel'] ?? '').toString();
    final date = _Fmt.date(m['date'] ?? m['createdAt']);

    final sent = _Num.asInt(m['sent']);
    final delivered = _Num.asInt(m['delivered']);
    final opened = _Num.asInt(m['opened']);
    final clicked = _Num.asInt(m['clicked']);
    final conversions = _Num.asInt(m['conversions']);
    final errors = _Num.asInt(m['errors']);

    final cost = _Num.asDouble(m['cost']);
    final revenue = _Num.asDouble(m['revenue']);

    final openRate = delivered <= 0 ? 0.0 : opened / delivered;
    final ctr = delivered <= 0 ? 0.0 : clicked / delivered;
    final cvr = clicked <= 0 ? 0.0 : conversions / clicked;

    // ✅ 不用 cast：meta 用安全解析（避免 unnecessary_cast）
    final meta = _Safe.asMap(m['meta']);
    final note = (m['note'] ?? '').toString();

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
                    style: const TextStyle(fontWeight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (segment.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _Tag(text: segment),
                ],
                if (channel.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _Tag(text: channel),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _kv('sent', '$sent'),
                _kv('delivered', '$delivered'),
                _kv('opened', '$opened'),
                _kv('clicked', '$clicked'),
                _kv('conversions', '$conversions'),
                _kv('errors', '$errors'),
                _kv('OpenRate', _Fmt.pct(openRate)),
                _kv('CTR', _Fmt.pct(ctr)),
                _kv('CVR', _Fmt.pct(cvr)),
                _kv('cost', _Fmt.money(cost)),
                _kv('revenue', _Fmt.money(revenue)),
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

  Widget _kv(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Text('$k：$v', style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// ============================================================
// Tab 2: AI Insights
// ============================================================

class _AiInsightsTab extends StatelessWidget {
  const _AiInsightsTab({required this.keyword, required this.collectionName});

  final String keyword;
  final String collectionName;

  Query<Map<String, dynamic>> _query() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
      collectionName,
    );

    // 若你不是 date 欄位，可改 createdAt
    q = q.orderBy('date', descending: true).limit(250);
    return q;
  }

  bool _match(Map<String, dynamic> m) {
    final k = keyword.trim().toLowerCase();
    if (k.isEmpty) return true;
    final campaignId = (m['campaignId'] ?? '').toString().toLowerCase();
    final segment = (m['segment'] ?? '').toString().toLowerCase();
    final note = (m['note'] ?? m['summary'] ?? '').toString().toLowerCase();
    return campaignId.contains(k) || segment.contains(k) || note.contains(k);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _query().snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorView(
            message:
                '讀取 AI 洞察失敗：${snap.error}\n\n'
                '若你沒有 date 欄位，請把 orderBy(\'date\') 改成 orderBy(\'createdAt\')。',
          );
        }
        // ✅ FIX: curly braces
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        final filtered = docs.where((d) => _match(d.data())).toList();

        if (filtered.isEmpty) {
          return const Center(child: Text('沒有符合條件的 AI 洞察資料'));
        }

        final summary = _AiSummary.fromDocs(filtered);

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _SummaryCard(title: 'AI 洞察 KPI', tiles: summary.tiles()),
            const SizedBox(height: 12),
            const Text('明細', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            // ✅ FIX: unnecessary_to_list_in_spreads
            ...filtered.map((d) => _AiInsightCard(doc: d)),
          ],
        );
      },
    );
  }
}

class _AiSummary {
  final int rows;
  final int impressions;
  final int clicks;
  final int conversions;
  final double cost;
  final double revenue;

  _AiSummary({
    required this.rows,
    required this.impressions,
    required this.clicks,
    required this.conversions,
    required this.cost,
    required this.revenue,
  });

  static _AiSummary fromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int impressions = 0, clicks = 0, conversions = 0;
    double cost = 0, revenue = 0;

    for (final d in docs) {
      final m = d.data();
      impressions += _Num.asInt(m['impressions']);
      clicks += _Num.asInt(m['clicks']);
      conversions += _Num.asInt(m['conversions']);
      cost += _Num.asDouble(m['cost']);
      revenue += _Num.asDouble(m['revenue']);
    }

    return _AiSummary(
      rows: docs.length,
      impressions: impressions,
      clicks: clicks,
      conversions: conversions,
      cost: cost,
      revenue: revenue,
    );
  }

  List<_Metric> tiles() {
    final ctr = impressions <= 0 ? 0.0 : clicks / impressions;
    final cvr = clicks <= 0 ? 0.0 : conversions / clicks;
    final cpc = clicks <= 0 ? 0.0 : cost / clicks;
    final cpa = conversions <= 0 ? 0.0 : cost / conversions;
    final roi = cost <= 0 ? 0.0 : (revenue - cost) / cost;

    return [
      _Metric('筆數', '$rows', Icons.dataset),
      _Metric('曝光', '$impressions', Icons.remove_red_eye),
      _Metric('點擊', '$clicks', Icons.ads_click),
      _Metric('轉換', '$conversions', Icons.check_circle),
      _Metric('CTR', _Fmt.pct(ctr), Icons.trending_up),
      _Metric('CVR', _Fmt.pct(cvr), Icons.insights),
      _Metric('花費', _Fmt.money(cost), Icons.payments),
      _Metric('營收', _Fmt.money(revenue), Icons.monetization_on),
      _Metric('CPC', _Fmt.money(cpc), Icons.calculate),
      _Metric('CPA', _Fmt.money(cpa), Icons.price_check),
      _Metric('ROI', _Fmt.pct(roi), Icons.auto_graph),
    ];
  }
}

class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({required this.doc});
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final m = doc.data();

    final campaignId = (m['campaignId'] ?? '').toString();
    final segment = (m['segment'] ?? '').toString();
    final date = _Fmt.date(m['date'] ?? m['createdAt']);

    final impressions = _Num.asInt(m['impressions']);
    final clicks = _Num.asInt(m['clicks']);
    final conversions = _Num.asInt(m['conversions']);
    final cost = _Num.asDouble(m['cost']);
    final revenue = _Num.asDouble(m['revenue']);

    final ctr = impressions <= 0 ? 0.0 : clicks / impressions;
    final cvr = clicks <= 0 ? 0.0 : conversions / clicks;

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
                    style: const TextStyle(fontWeight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (segment.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _Tag(text: segment),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _kv('impr', '$impressions'),
                _kv('click', '$clicks'),
                _kv('conv', '$conversions'),
                _kv('CTR', _Fmt.pct(ctr)),
                _kv('CVR', _Fmt.pct(cvr)),
                _kv('cost', _Fmt.money(cost)),
                _kv('rev', _Fmt.money(revenue)),
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
      child: Text('$k：$v', style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// ============================================================
// Tab 3: Lottery Winners
// ============================================================

class _LotteryWinnersTab extends StatefulWidget {
  const _LotteryWinnersTab({
    required this.keyword,
    required this.collectionName,
  });

  final String keyword;
  final String collectionName;

  @override
  State<_LotteryWinnersTab> createState() => _LotteryWinnersTabState();
}

class _LotteryWinnersTabState extends State<_LotteryWinnersTab> {
  bool _onlyUnfulfilled = false;

  Query<Map<String, dynamic>> _query() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
      widget.collectionName,
    );

    if (_onlyUnfulfilled) {
      q = q.where('fulfilled', isEqualTo: false);
    }

    // 若你不是 createdAt 欄位，可改 date
    q = q.orderBy('createdAt', descending: true).limit(300);
    return q;
  }

  bool _match(Map<String, dynamic> m) {
    final k = widget.keyword.trim().toLowerCase();
    if (k.isEmpty) return true;

    final lotteryId = (m['lotteryId'] ?? '').toString().toLowerCase();
    final userId = (m['userId'] ?? '').toString().toLowerCase();
    final userName = (m['userName'] ?? '').toString().toLowerCase();
    final prizeName = (m['prizeName'] ?? '').toString().toLowerCase();
    return lotteryId.contains(k) ||
        userId.contains(k) ||
        userName.contains(k) ||
        prizeName.contains(k);
  }

  Future<void> _toggleFulfilled(
    DocumentSnapshot<Map<String, dynamic>> doc,
    bool next,
  ) async {
    try {
      await doc.reference.update({
        'fulfilled': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FilterBar(
          left: Row(
            children: [
              Switch(
                value: _onlyUnfulfilled,
                onChanged: (v) => setState(() => _onlyUnfulfilled = v),
              ),
              const SizedBox(width: 6),
              const Text('只看未發放'),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _query().snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _ErrorView(
                  message:
                      '讀取抽獎中獎失敗：${snap.error}\n\n'
                      '若你沒有 createdAt 欄位，請把 orderBy(\'createdAt\') 改成 orderBy(\'date\')。',
                );
              }
              // ✅ FIX: curly braces
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;
              final filtered = docs.where((d) => _match(d.data())).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('沒有符合條件的中獎紀錄'));
              }

              final summary = _LotterySummary.fromDocs(filtered);

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _SummaryCard(title: '抽獎 KPI', tiles: summary.tiles()),
                  const SizedBox(height: 12),
                  const Text(
                    '明細',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  // ✅ FIX: unnecessary_to_list_in_spreads
                  ...filtered.map(
                    (d) => _WinnerCard(doc: d, onToggle: _toggleFulfilled),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LotterySummary {
  final int rows;
  final int fulfilled;
  final int unfulfilled;

  _LotterySummary({
    required this.rows,
    required this.fulfilled,
    required this.unfulfilled,
  });

  static _LotterySummary fromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int f = 0, uf = 0;
    for (final d in docs) {
      final m = d.data();
      final ok = m['fulfilled'] == true;
      if (ok) {
        f += 1;
      } else {
        uf += 1;
      }
    }
    return _LotterySummary(rows: docs.length, fulfilled: f, unfulfilled: uf);
  }

  List<_Metric> tiles() {
    final rate = rows <= 0 ? 0.0 : fulfilled / rows;
    return [
      _Metric('筆數', '$rows', Icons.dataset),
      _Metric('已發放', '$fulfilled', Icons.check_circle),
      _Metric('未發放', '$unfulfilled', Icons.pending_actions),
      _Metric('發放率', _Fmt.pct(rate), Icons.trending_up),
    ];
  }
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({required this.doc, required this.onToggle});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Future<void> Function(
    DocumentSnapshot<Map<String, dynamic>> doc,
    bool next,
  )
  onToggle;

  @override
  Widget build(BuildContext context) {
    final m = doc.data();

    final lotteryId = (m['lotteryId'] ?? '').toString();
    final userId = (m['userId'] ?? '').toString();
    final userName = (m['userName'] ?? '').toString();
    final prizeName = (m['prizeName'] ?? '').toString();
    final fulfilled = m['fulfilled'] == true;
    final time = _Fmt.dateTime(m['createdAt'] ?? m['date']);

    // ✅ 不用 cast：meta 用安全解析（避免 unnecessary_cast）
    final meta = _Safe.asMap(m['meta']);

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
                    prizeName.isEmpty ? '(未命名獎品)' : prizeName,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _Tag(
                  text: fulfilled ? '已發放' : '未發放',
                  color: fulfilled ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _kv('lotteryId', lotteryId),
                _kv('userId', userId),
                _kv('userName', userName),
                if (time.isNotEmpty) _kv('time', time),
              ],
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 10),
              _MetaBox(meta: meta),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => onToggle(doc, !fulfilled),
              icon: Icon(fulfilled ? Icons.undo : Icons.check),
              label: Text(fulfilled ? '改為未發放' : '標記已發放'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    final text = v.trim().isEmpty ? '-' : v.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        '$k：$text',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ============================================================
// Shared Widgets / Utils
// ============================================================

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.left});
  final Widget left;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            // ✅ FIX: withOpacity deprecated
            color: _ColorX.withOpacity(Colors.black, 0.08),
          ),
        ),
      ),
      child: left,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.tiles});
  final String title;
  final List<_Metric> tiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
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
                  itemBuilder: (_, i) => _MetricTile(metric: tiles[i]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric {
  final String title;
  final String value;
  final IconData icon;
  const _Metric(this.title, this.value, this.icon);
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});
  final _Metric metric;

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
          Icon(metric.icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metric.value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        // ✅ FIX: withOpacity deprecated
        color: _ColorX.withOpacity(Colors.black, 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Meta', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          ...entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${e.key}: ${e.value}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.black54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // ✅ FIX: withOpacity deprecated
        color: _ColorX.withOpacity(c, 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _ColorX.withOpacity(c, 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w800),
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

class _Option {
  final String value;
  final String label;
  const _Option(this.value, this.label);
}

class _Safe {
  // ✅ 不用 cast：避免 unnecessary_cast
  static Map<String, dynamic> asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }
}

class _Num {
  static int asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    if (v is List) return v.length;
    if (v is Map) return v.length;
    return 0;
  }

  static double asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }
}

class _Fmt {
  static String pct(double v) => '${(v * 100).toStringAsFixed(2)}%';
  static String money(double v) => v.toStringAsFixed(2);

  static DateTime? _asDateTime(dynamic v) {
    try {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
    } catch (_) {}
    return null;
  }

  static String date(dynamic v) {
    final dt = _asDateTime(v);
    if (dt == null) return '';
    String two(int x) => x.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  static String dateTime(dynamic v) {
    final dt = _asDateTime(v);
    if (dt == null) return '';
    String two(int x) => x.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}

/// ✅ 統一處理透明度（withOpacity deprecated → withValues(alpha: 0~1)）
class _ColorX {
  static Color withOpacity(Color c, double opacity01) {
    final o = opacity01.clamp(0.0, 1.0).toDouble();
    return c.withValues(alpha: o);
  }
}
