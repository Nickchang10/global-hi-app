// lib/pages/kpi_page.dart
//
// ✅ KPIPage（可編譯完整版｜不依賴 charts_flutter）
// ------------------------------------------------------------
// ✅ 修正：
// - curly_braces_in_flow_control_structures：所有 if/else 單行改成區塊 { ... }
// - deprecated_member_use：withOpacity -> withValues(alpha: ...)
//
// Firestore 結構（建議）
// collection: kpi_records
// doc fields:
//   - date: Timestamp (建議用當天 00:00)
//   - lineAdds: int
//   - ed1000Sales: int
//   - revenue: num (可選)
//   - notes: String (可選)
//   - createdAt: Timestamp
//   - updatedAt: Timestamp

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class KpiPage extends StatefulWidget {
  const KpiPage({super.key});

  @override
  State<KpiPage> createState() => _KpiPageState();
}

class _KpiPageState extends State<KpiPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  late final TabController _tab;

  // 可自行調整：載入最近多少筆
  static const int _limit = 120;

  // 手動刷新用（重建 StreamBuilder）
  int _rev = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _q() {
    // 若你的 date 欄位不是 Timestamp 或沒有 index，可改用 createdAt
    return _db
        .collection('kpi_records')
        .orderBy('date', descending: true)
        .limit(_limit);
  }

  void _snack(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KPI / 業績'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '今日'),
            Tab(text: '近 7 天'),
            Tab(text: '近 30 天'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() => _rev++),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('新增 KPI'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        key: ValueKey(_rev),
        stream: _q().snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorView(
              title: '讀取失敗',
              message: '${snap.error}',
              hint: "請確認：Firestore rules、kpi_records 集合存在、以及 date 欄位可排序。",
              onRetry: () => setState(() => _rev++),
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snap.data!.docs.map(KpiEntry.fromDoc).toList();

          if (entries.isEmpty) {
            return _emptyState(
              context,
              title: '尚無 KPI 紀錄',
              subtitle: '點右下角「新增 KPI」開始記錄每日數據。',
            );
          }

          return TabBarView(
            controller: _tab,
            children: [
              _buildPeriod(context, cs, entries, days: 1),
              _buildPeriod(context, cs, entries, days: 7),
              _buildPeriod(context, cs, entries, days: 30),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPeriod(
    BuildContext context,
    ColorScheme cs,
    List<KpiEntry> all, {
    required int days,
  }) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));

    final list = all.where((e) => !e.date.isBefore(start)).toList()
      ..sort((a, b) => a.date.compareTo(b.date)); // old -> new for chart

    final sumLine = list.fold<int>(0, (p, e) => p + e.lineAdds);
    final sumSales = list.fold<int>(0, (p, e) => p + e.ed1000Sales);
    final sumRev = list.fold<double>(0.0, (p, e) => p + (e.revenue ?? 0));

    // 趨勢圖顯示最後最多 14 個點（避免太擠）
    final chartList = (list.length <= 14)
        ? list
        : list.sublist(list.length - 14);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      children: [
        _sectionTitle(days == 1 ? '今日總覽' : '期間總覽（近 $days 天）'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _statCard(
              cs,
              title: '新增 LINE 客',
              value: _fmtInt(sumLine),
              icon: Icons.group_add,
            ),
            _statCard(
              cs,
              title: 'ED1000 銷量',
              value: _fmtInt(sumSales),
              icon: Icons.watch,
            ),
            _statCard(
              cs,
              title: '營收',
              value: sumRev > 0 ? _fmtMoney(sumRev) : '-',
              icon: Icons.payments,
            ),
            _statCard(
              cs,
              title: '紀錄筆數',
              value: _fmtInt(list.length),
              icon: Icons.list_alt,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _sectionTitle('趨勢（最後 ${chartList.length} 筆）'),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '新增 LINE 客',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _MiniBarChart(
                  values: chartList.map((e) => e.lineAdds.toDouble()).toList(),
                  labels: chartList.map((e) => _fmtMd(e.date)).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'ED1000 銷量',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _MiniBarChart(
                  values: chartList
                      .map((e) => e.ed1000Sales.toDouble())
                      .toList(),
                  labels: chartList.map((e) => _fmtMd(e.date)).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _sectionTitle('明細（最新在下方）'),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = list[i];
              return ListTile(
                title: Text(
                  _fmtYmd(e.date),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  'LINE +${e.lineAdds} ｜ ED1000 ${e.ed1000Sales} ｜ 營收 ${e.revenue == null ? '-' : _fmtMoney(e.revenue!)}'
                  '${(e.notes ?? '').trim().isEmpty ? '' : '\n備註：${e.notes}'}',
                ),
                trailing: IconButton(
                  tooltip: '刪除此筆',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(e),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // Add / Delete
  // ------------------------------------------------------------

  Future<void> _openAddDialog() async {
    final now = DateTime.now();
    DateTime pickedDate = DateTime(now.year, now.month, now.day);

    final lineCtrl = TextEditingController(text: '0');
    final salesCtrl = TextEditingController(text: '0');
    final revCtrl = TextEditingController(text: '');
    final notesCtrl = TextEditingController(text: '');

    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('新增 KPI'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '日期：${_fmtYmd(pickedDate)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: pickedDate,
                            firstDate: DateTime(now.year - 2, 1, 1),
                            lastDate: DateTime(now.year + 2, 12, 31),
                          );
                          if (d == null) {
                            return;
                          }
                          pickedDate = DateTime(d.year, d.month, d.day);
                          // 讓 dialog 內容更新
                          (context as Element).markNeedsBuild();
                        },
                        icon: const Icon(Icons.event),
                        label: const Text('選日期'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: lineCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '新增 LINE 客（lineAdds）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: salesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ED1000 銷量（ed1000Sales）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: revCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '營收（revenue，可留空）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '備註（notes，可留空）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('儲存'),
              ),
            ],
          );
        },
      );

      if (ok != true) {
        return;
      }

      final lineAdds = _toInt(lineCtrl.text, 0);
      final sales = _toInt(salesCtrl.text, 0);
      final revenue = _toDoubleOrNull(revCtrl.text);

      await _db.collection('kpi_records').add({
        'date': Timestamp.fromDate(
          DateTime(pickedDate.year, pickedDate.month, pickedDate.day),
        ),
        'lineAdds': lineAdds,
        'ed1000Sales': sales,
        if (revenue != null) 'revenue': revenue,
        if (notesCtrl.text.trim().isNotEmpty) 'notes': notesCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _snack('已新增 KPI');
    } catch (e) {
      _snack('新增失敗：$e');
    } finally {
      lineCtrl.dispose();
      salesCtrl.dispose();
      revCtrl.dispose();
      notesCtrl.dispose();
    }
  }

  Future<void> _confirmDelete(KpiEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          '刪除此筆 KPI？',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          '日期：${_fmtYmd(e.date)}\nLINE +${e.lineAdds} / ED1000 ${e.ed1000Sales}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) {
      return;
    }

    try {
      await _db.collection('kpi_records').doc(e.id).delete();
      _snack('已刪除');
    } catch (err) {
      _snack('刪除失敗：$err');
    }
  }

  // ------------------------------------------------------------
  // UI helpers
  // ------------------------------------------------------------

  Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
  );

  Widget _statCard(
    ColorScheme cs, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  // ✅ withOpacity -> withValues(alpha:)
                  color: cs.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.primary),
              ),
              const SizedBox(width: 10),
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
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insights_outlined, size: 44, color: cs.primary),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Format helpers (不依賴 intl)
  // ------------------------------------------------------------

  static String _fmtYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y/$m/$day';
  }

  static String _fmtMd(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$m/$day';
  }

  static String _fmtInt(int v) => v.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );

  static String _fmtMoney(num v) => 'NT\$ ${_fmtInt(v.round())}';

  static int _toInt(String s, int fallback) =>
      int.tryParse(s.trim()) ?? fallback;

  static double? _toDoubleOrNull(String s) {
    final t = s.trim();
    if (t.isEmpty) {
      return null;
    }
    return double.tryParse(t);
  }
}

// ------------------------------------------------------------
// Data model
// ------------------------------------------------------------

class KpiEntry {
  final String id;
  final DateTime date;
  final int lineAdds;
  final int ed1000Sales;
  final double? revenue;
  final String? notes;

  const KpiEntry({
    required this.id,
    required this.date,
    required this.lineAdds,
    required this.ed1000Sales,
    this.revenue,
    this.notes,
  });

  static KpiEntry fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();

    DateTime date = DateTime.now();
    final rawDate = d['date'];
    if (rawDate is Timestamp) {
      date = rawDate.toDate();
    } else if (rawDate is DateTime) {
      date = rawDate;
    } else if (rawDate is String) {
      // 支援 "YYYY-MM-DD" / "YYYY/MM/DD"
      final s = rawDate.trim().replaceAll('-', '/');
      final parts = s.split('/');
      if (parts.length >= 3) {
        final y = int.tryParse(parts[0]) ?? date.year;
        final m = int.tryParse(parts[1]) ?? date.month;
        final day = int.tryParse(parts[2]) ?? date.day;
        date = DateTime(y, m, day);
      }
    }

    int toInt(dynamic v, {int fallback = 0}) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('${v ?? ''}') ?? fallback;
    }

    double? toDoubleOrNull(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      return double.tryParse('$v');
    }

    String? toStrOrNull(dynamic v) {
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? null : s;
    }

    return KpiEntry(
      id: doc.id,
      date: DateTime(date.year, date.month, date.day),
      lineAdds: toInt(d['lineAdds']),
      ed1000Sales: toInt(d['ed1000Sales']),
      revenue: toDoubleOrNull(d['revenue']),
      notes: toStrOrNull(d['notes']),
    );
  }
}

// ------------------------------------------------------------
// Mini bar chart (純 Flutter)
// ------------------------------------------------------------

class _MiniBarChart extends StatelessWidget {
  final List<double> values; // >=0
  final List<String> labels; // same length
  const _MiniBarChart({required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (values.isEmpty) {
      return Text('無資料', style: TextStyle(color: cs.onSurfaceVariant));
    }

    final maxV = values.fold<double>(0, (p, v) => v > p ? v : p);
    final safeMax = maxV <= 0 ? 1 : maxV;

    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final v = values[i];
          final frac = (v / safeMax).clamp(0.0, 1.0);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: frac,
                        child: Container(
                          decoration: BoxDecoration(
                            // ✅ withOpacity -> withValues(alpha:)
                            color: cs.primary.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels.length == values.length ? labels[i] : '',
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ------------------------------------------------------------
// Error view
// ------------------------------------------------------------

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
        constraints: const BoxConstraints(maxWidth: 640),
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
