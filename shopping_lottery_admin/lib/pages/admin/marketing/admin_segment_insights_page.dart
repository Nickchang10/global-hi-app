// lib/pages/admin/marketing/admin_segment_insights_page.dart
//
// ✅ AdminSegmentInsightsPage（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// ✅ 修正：curly_braces_in_flow_control_structures（if/else 統一用 {}）
// ✅ 修正：unnecessary_to_list_in_spreads（spread 裡移除 .toList()）
// ✅ 修正：withOpacity deprecated → withValues(alpha: 0~1) 統一用 _withOpacity()
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSegmentInsightsPage extends StatefulWidget {
  const AdminSegmentInsightsPage({
    super.key,
    this.collectionName = 'segment_insights',
  });

  final String collectionName;

  @override
  State<AdminSegmentInsightsPage> createState() =>
      _AdminSegmentInsightsPageState();
}

class _AdminSegmentInsightsPageState extends State<AdminSegmentInsightsPage> {
  static const _segments = <_Option>[
    _Option('all', '全部'),
    _Option('new', '新客'),
    _Option('active', '活躍'),
    _Option('vip', 'VIP'),
    _Option('churn_risk', '流失風險'),
    _Option('sleeping', '沉睡'),
  ];

  String _segment = 'all';

  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    // 預設最近 30 天
    final now = DateTime.now();
    _toDate = DateTime(now.year, now.month, now.day);
    _fromDate = _toDate!.subtract(const Duration(days: 30));
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
      widget.collectionName,
    );

    if (_segment != 'all') {
      q = q.where('segment', isEqualTo: _segment);
    }

    // ✅ fromDate/toDate 用在 query（date 區間）
    if (_fromDate != null) {
      q = q.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(_fromDate!),
      );
    }
    if (_toDate != null) {
      final toExclusive = DateTime(
        _toDate!.year,
        _toDate!.month,
        _toDate!.day,
      ).add(const Duration(days: 1));
      q = q.where('date', isLessThan: Timestamp.fromDate(toExclusive));
    }

    // Firestore：有 range filter 的欄位要 orderBy 同欄位
    q = q.orderBy('date', descending: true).limit(300);
    return q;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final base = isFrom ? (_fromDate ?? now) : (_toDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      final d = DateTime(picked.year, picked.month, picked.day);
      if (isFrom) {
        _fromDate = d;
      } else {
        _toDate = d;
      }
    });
  }

  void _setRangeDays(int days) {
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day);
    setState(() {
      _toDate = to;
      _fromDate = to.subtract(Duration(days: days));
    });
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) {
      return '未設定';
    }
    String two(int x) => x.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final rangeText = '期間：${_fmtDate(_fromDate)} ～ ${_fmtDate(_toDate)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('分眾洞察報表'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(150),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _DateBox(
                        label: 'From',
                        value: _fmtDate(_fromDate),
                        onPick: () => _pickDate(isFrom: true),
                        onClear: () => setState(() => _fromDate = null),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateBox(
                        label: 'To',
                        value: _fmtDate(_toDate),
                        onPick: () => _pickDate(isFrom: false),
                        onClear: () => setState(() => _toDate = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _RangeChip(label: '7 天', onTap: () => _setRangeDays(7)),
                    const SizedBox(width: 8),
                    _RangeChip(label: '30 天', onTap: () => _setRangeDays(30)),
                    const SizedBox(width: 8),
                    _RangeChip(label: '90 天', onTap: () => _setRangeDays(90)),
                    const Spacer(),
                    Text(rangeText, style: TextStyle(color: Colors.grey[700])),
                  ],
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
                  '若提示需要索引：請建立索引（segment/date）或（date）。\n'
                  '且 date 欄位需存在（Timestamp）。',
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('目前沒有符合條件的洞察資料'));
          }

          final summary = _SegmentSummary.fromDocs(docs);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _SummaryCard(summary: summary),
              const SizedBox(height: 12),
              const Text('明細', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),

              // ✅ FIX: spread 裡不要 .toList()
              ...docs.map((d) => _InsightCard(doc: d)),
            ],
          );
        },
      ),
    );
  }
}

// ----------------------- Summary -----------------------

class _SegmentSummary {
  final int rows;
  final int audienceSize;
  final int impressions;
  final int clicks;
  final int conversions;
  final double cost;
  final double revenue;

  _SegmentSummary({
    required this.rows,
    required this.audienceSize,
    required this.impressions,
    required this.clicks,
    required this.conversions,
    required this.cost,
    required this.revenue,
  });

  static _SegmentSummary fromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int audienceSize = 0, impressions = 0, clicks = 0, conversions = 0;
    double cost = 0, revenue = 0;

    for (final d in docs) {
      final m = d.data();
      audienceSize += _Num.asInt(m['audienceSize']);
      impressions += _Num.asInt(m['impressions']);
      clicks += _Num.asInt(m['clicks']);
      conversions += _Num.asInt(m['conversions']);
      cost += _Num.asDouble(m['cost']);
      revenue += _Num.asDouble(m['revenue']);
    }

    return _SegmentSummary(
      rows: docs.length,
      audienceSize: audienceSize,
      impressions: impressions,
      clicks: clicks,
      conversions: conversions,
      cost: cost,
      revenue: revenue,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final _SegmentSummary summary;

  @override
  Widget build(BuildContext context) {
    final ctr = summary.impressions <= 0
        ? 0.0
        : summary.clicks / summary.impressions;
    final cvr = summary.clicks <= 0
        ? 0.0
        : summary.conversions / summary.clicks;
    final cpc = summary.clicks <= 0 ? 0.0 : summary.cost / summary.clicks;
    final cpa = summary.conversions <= 0
        ? 0.0
        : summary.cost / summary.conversions;
    final roi = summary.cost <= 0
        ? 0.0
        : (summary.revenue - summary.cost) / summary.cost;

    final tiles = <_Metric>[
      _Metric('筆數', '${summary.rows}', Icons.dataset),
      _Metric('受眾', '${summary.audienceSize}', Icons.groups),
      _Metric('曝光', '${summary.impressions}', Icons.remove_red_eye),
      _Metric('點擊', '${summary.clicks}', Icons.ads_click),
      _Metric('轉換', '${summary.conversions}', Icons.check_circle),
      _Metric('CTR', _Fmt.pct(ctr), Icons.trending_up),
      _Metric('CVR', _Fmt.pct(cvr), Icons.insights),
      _Metric('花費', _Fmt.money(summary.cost), Icons.payments),
      _Metric('營收', _Fmt.money(summary.revenue), Icons.monetization_on),
      _Metric('CPC', _Fmt.money(cpc), Icons.calculate),
      _Metric('CPA', _Fmt.money(cpa), Icons.price_check),
      _Metric('ROI', _Fmt.pct(roi), Icons.auto_graph),
    ];

    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('KPI 彙總', style: TextStyle(fontWeight: FontWeight.w900)),
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

// ----------------------- Detail Card -----------------------

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.doc});
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final m = doc.data();

    final segment = (m['segment'] ?? '').toString();
    final date = _Fmt.date(m['date']);
    final audience = _Num.asInt(m['audienceSize']);
    final impressions = _Num.asInt(m['impressions']);
    final clicks = _Num.asInt(m['clicks']);
    final conversions = _Num.asInt(m['conversions']);
    final cost = _Num.asDouble(m['cost']);
    final revenue = _Num.asDouble(m['revenue']);
    final summary = (m['summary'] ?? m['note'] ?? '').toString();

    final ctr = impressions <= 0 ? 0.0 : clicks / impressions;
    final cvr = clicks <= 0 ? 0.0 : conversions / clicks;

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
                    [
                      if (segment.isNotEmpty) segment,
                      if (date.isNotEmpty) date,
                    ].join(' · '),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _Tag(text: segment.isEmpty ? 'segment' : segment),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _kv('aud', '$audience'),
                _kv('impr', '$impressions'),
                _kv('click', '$clicks'),
                _kv('conv', '$conversions'),
                _kv('CTR', _Fmt.pct(ctr)),
                _kv('CVR', _Fmt.pct(cvr)),
                _kv('cost', _Fmt.money(cost)),
                _kv('rev', _Fmt.money(revenue)),
              ],
            ),
            if (summary.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(summary, style: TextStyle(color: Colors.grey[800])),
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

// ----------------------- Small UI -----------------------

class _DateBox extends StatelessWidget {
  const _DateBox({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: Colors.grey[800])),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.calendar_month),
                label: const Text('選擇'),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: onClear, child: const Text('清除')),
            ],
          ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.black12),
          color: _withOpacity(Colors.black, 0.03),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Colors.black54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _withOpacity(c, 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _withOpacity(c, 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w800),
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
        color: _withOpacity(Colors.black, 0.03),
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
  static Map<String, dynamic> asMap(dynamic v) {
    if (v is Map) {
      return Map<String, dynamic>.from(v);
    }
    return <String, dynamic>{};
  }
}

class _Num {
  static int asInt(dynamic v) {
    if (v == null) {
      return 0;
    }
    if (v is int) {
      return v;
    }
    if (v is double) {
      return v.round();
    }
    if (v is num) {
      return v.toInt();
    }
    if (v is String) {
      return int.tryParse(v.trim()) ?? 0;
    }
    if (v is List) {
      return v.length;
    }
    if (v is Map) {
      return v.length;
    }
    return 0;
  }

  static double asDouble(dynamic v) {
    if (v == null) {
      return 0.0;
    }
    if (v is double) {
      return v;
    }
    if (v is int) {
      return v.toDouble();
    }
    if (v is num) {
      return v.toDouble();
    }
    if (v is String) {
      return double.tryParse(v.trim()) ?? 0.0;
    }
    return 0.0;
  }
}

class _Fmt {
  static String pct(double v) => '${(v * 100).toStringAsFixed(2)}%';
  static String money(double v) => v.toStringAsFixed(2);

  static DateTime? _asDateTime(dynamic v) {
    try {
      if (v == null) {
        return null;
      }
      if (v is Timestamp) {
        return v.toDate();
      }
      if (v is DateTime) {
        return v;
      }
      if (v is int) {
        return DateTime.fromMillisecondsSinceEpoch(v);
      }
      if (v is String) {
        return DateTime.tryParse(v);
      }
    } catch (_) {}
    return null;
  }

  static String date(dynamic v) {
    final dt = _asDateTime(v);
    if (dt == null) {
      return '';
    }
    String two(int x) => x.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }
}

/// ✅ FIX: withOpacity deprecated → withValues(alpha: 0~1)
Color _withOpacity(Color c, double opacity01) {
  final o = opacity01.clamp(0.0, 1.0).toDouble();
  return c.withValues(alpha: o);
}
