// lib/pages/admin/members/admin_member_points_tasks_page.dart
//
// ✅ AdminMemberPointsTasksPage（積分 / 任務｜專業單檔完整版｜可編譯｜欄位容錯｜可搜尋/篩選｜可查看詳情）
// ------------------------------------------------------------
// - 讀取 Firestore points_logs 集合（orderBy createdAt desc）
// - 搜尋：userId / uid / email / phone / reason / refId / taskId（有就搜）
// - 篩選：類型 type（points / task / reward / admin / system...）、正負分、日期區間（client filter 避免複合索引）
// - 列表：顯示分數變動、原因、使用者、時間
// - 詳情 Dialog：顯示完整原始欄位（Debug）+ 可複製 docId / userId
//
// 建議 points_logs 結構（可彈性）：
// points_logs/{logId}
// {
//   userId: string,        // 或 uid
//   email: string?,
//   phone: string?,
//   points: number,        // 分數變動（可正可負）
//   type: string?,         // "task" | "admin" | "system" | ...
//   reason: string?,       // 文字原因
//   taskId: string?,       // 任務 id（若是任務）
//   refId: string?,        // 關聯 id（訂單/活動/兌換）
//   meta: map?,            // 任何附加資訊
//   createdAt: Timestamp,
//   operatorUid: string?,  // 後台操作人（若有）
// }
//
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminMemberPointsTasksPage extends StatefulWidget {
  const AdminMemberPointsTasksPage({super.key});

  @override
  State<AdminMemberPointsTasksPage> createState() =>
      _AdminMemberPointsTasksPageState();
}

class _AdminMemberPointsTasksPageState extends State<AdminMemberPointsTasksPage> {
  final _db = FirebaseFirestore.instance;

  final _search = TextEditingController();

  DateTimeRange? _range;

  static const String _all = 'all';
  String _type = _all; // task/admin/system/...
  String _sign = _all; // all/pos/neg/zero

  bool _busy = false;

  int _limit = 800;

  final _dtFmt = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // Query
  // ------------------------------------------------------------
  Query<Map<String, dynamic>> _baseQuery() {
    // points_logs 必須有 createdAt 才能 orderBy；若沒有請改成 updatedAt 或移除 orderBy
    return _db
        .collection('points_logs')
        .orderBy('createdAt', descending: true)
        .limit(_limit);
  }

  // ------------------------------------------------------------
  // Safe casting
  // ------------------------------------------------------------
  String _s(dynamic v) => v == null ? '' : v.toString();

  int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(_s(v)) ?? 0;
  }

  num _n(dynamic v) {
    if (v is num) return v;
    return num.tryParse(_s(v)) ?? 0;
  }

  DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  Map<String, dynamic> _m(dynamic v) =>
      (v is Map<String, dynamic>) ? v : <String, dynamic>{};

  String _lower(dynamic v) => _s(v).trim().toLowerCase();

  bool _inRange(DateTime? t, DateTimeRange? r) {
    if (r == null) return true;
    if (t == null) return false;
    return !t.isBefore(r.start) && !t.isAfter(r.end);
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final q = _baseQuery();

    return Scaffold(
      appBar: AppBar(
        title: const Text('積分 / 任務', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '清除篩選',
            icon: const Icon(Icons.filter_alt_off),
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _search.clear();
                      _type = _all;
                      _sign = _all;
                      _range = null;
                      _limit = 800;
                    });
                  },
          ),
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : () => setState(() {}),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _topBar(),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: q.snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return _ErrorView(
                        title: '載入失敗',
                        message: '${snap.error}',
                        hint: '請確認 points_logs 集合存在、createdAt 欄位為 Timestamp，並檢查 Firestore rules（admin 需可讀 points_logs）。',
                        onRetry: () => setState(() {}),
                      );
                    }

                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const _EmptyView(title: '目前沒有積分紀錄');
                    }

                    final filtered = _applyFilters(docs);
                    if (filtered.isEmpty) {
                      return const _EmptyView(title: '沒有符合條件的紀錄');
                    }

                    final stats = _calcStats(filtered);

                    return Column(
                      children: [
                        _statsBar(stats),
                        const Divider(height: 1),
                        Expanded(child: _buildList(filtered)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.06),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Top bar (search + filters)
  // ------------------------------------------------------------
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 980;

          final search = TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜尋（userId/uid/email/phone/reason/refId/taskId）',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          final typeDD = _dropdown(
            label: '類型',
            value: _type,
            items: const [
              (_all, '全部'),
              ('task', 'task'),
              ('admin', 'admin'),
              ('system', 'system'),
              ('reward', 'reward'),
              ('order', 'order'),
              ('unknown', 'unknown'),
            ],
            onChanged: (v) => setState(() => _type = v),
          );

          final signDD = _dropdown(
            label: '分數',
            value: _sign,
            items: const [
              (_all, '全部'),
              ('pos', '加分'),
              ('neg', '扣分'),
              ('zero', '0 分'),
            ],
            onChanged: (v) => setState(() => _sign = v),
          );

          final rangeBtn = OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range),
            label: Text(_range == null ? '日期區間' : _fmtRange(_range!)),
          );

          final clearRange = TextButton(
            onPressed: _range == null ? null : () => setState(() => _range = null),
            child: const Text('清除'),
          );

          final limitDD = _dropdown(
            label: '載入上限',
            value: '$_limit',
            items: const [
              ('200', '200'),
              ('400', '400'),
              ('800', '800'),
              ('1200', '1200'),
            ],
            onChanged: (v) => setState(() => _limit = int.tryParse(v) ?? 800),
          );

          if (narrow) {
            return Column(
              children: [
                Row(children: [Expanded(child: search)]),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: typeDD),
                    const SizedBox(width: 10),
                    Expanded(child: signDD),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: rangeBtn),
                    const SizedBox(width: 6),
                    clearRange,
                    const SizedBox(width: 10),
                    SizedBox(width: 160, child: limitDD),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 5, child: search),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: typeDD),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: signDD),
              const SizedBox(width: 10),
              rangeBtn,
              const SizedBox(width: 6),
              clearRange,
              const SizedBox(width: 10),
              SizedBox(width: 160, child: limitDD),
            ],
          );
        },
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<(String, String)> items,
    required ValueChanged<String> onChanged,
  }) {
    final allowed = items.map((e) => e.$1).toList();
    final v = allowed.contains(value) ? value : items.first.$1;

    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: v,
      onChanged: (nv) => onChanged(nv ?? v),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items.map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2))).toList(),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initial = _range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29)),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      helpText: '選擇日期區間（createdAt）',
      confirmText: '套用',
      cancelText: '取消',
    );
    if (picked == null) return;

    setState(() {
      _range = DateTimeRange(
        start: DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
      );
    });
  }

  String _fmtRange(DateTimeRange r) {
    final a = DateFormat('yyyy/MM/dd').format(r.start);
    final b = DateFormat('yyyy/MM/dd').format(r.end);
    return '$a～$b';
  }

  // ------------------------------------------------------------
  // Filters (client-side)
  // ------------------------------------------------------------
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final kw = _search.text.trim().toLowerCase();

    return docs.where((doc) {
      final d = doc.data();

      final createdAt = _dt(d['createdAt']);
      if (!_inRange(createdAt, _range)) return false;

      // type
      final type = _lower(d['type']);
      if (_type != _all) {
        final t = type.isEmpty ? 'unknown' : type;
        if (t != _type) return false;
      }

      // sign
      final delta = _n(d['points']);
      if (_sign == 'pos' && !(delta > 0)) return false;
      if (_sign == 'neg' && !(delta < 0)) return false;
      if (_sign == 'zero' && !(delta == 0)) return false;

      if (kw.isEmpty) return true;

      final userId = _lower(d['userId']);
      final uid = _lower(d['uid']); // 兼容
      final email = _lower(d['email']);
      final phone = _lower(d['phone']);
      final reason = _lower(d['reason']);
      final refId = _lower(d['refId']);
      final taskId = _lower(d['taskId']);
      final operatorUid = _lower(d['operatorUid']);

      return doc.id.toLowerCase().contains(kw) ||
          userId.contains(kw) ||
          uid.contains(kw) ||
          email.contains(kw) ||
          phone.contains(kw) ||
          reason.contains(kw) ||
          refId.contains(kw) ||
          taskId.contains(kw) ||
          operatorUid.contains(kw);
    }).toList();
  }

  // ------------------------------------------------------------
  // Stats
  // ------------------------------------------------------------
  _PointsStats _calcStats(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int total = docs.length;
    int pos = 0;
    int neg = 0;
    int zero = 0;
    num sum = 0;

    for (final doc in docs) {
      final d = doc.data();
      final delta = _n(d['points']);
      sum += delta;
      if (delta > 0) pos++;
      else if (delta < 0) neg++;
      else zero++;
    }

    return _PointsStats(total: total, pos: pos, neg: neg, zero: zero, sum: sum);
  }

  Widget _statsBar(_PointsStats s) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _pill('筆數', '${s.total}', cs.surfaceContainerHighest, cs.onSurfaceVariant),
          _pill('加分', '${s.pos}', Colors.green.shade50, Colors.green.shade800),
          _pill('扣分', '${s.neg}', Colors.red.shade50, Colors.red.shade800),
          _pill('0分', '${s.zero}', Colors.grey.shade200, Colors.grey.shade800),
          _pill('合計', s.sum >= 0 ? '+${s.sum}' : '${s.sum}',
              cs.surfaceContainerHighest, cs.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _pill(String k, String v, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text('$k：$v', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg)),
    );
  }

  // ------------------------------------------------------------
  // List
  // ------------------------------------------------------------
  Widget _buildList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
      itemCount: docs.length,
      itemBuilder: (context, i) => _logTile(docs[i]),
    );
  }

  Widget _logTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final cs = Theme.of(context).colorScheme;
    final d = doc.data();

    final userId = _s(d['userId']).trim();
    final uid = _s(d['uid']).trim();
    final email = _s(d['email']).trim();
    final phone = _s(d['phone']).trim();

    final delta = _i(d['points']);
    final reason = _s(d['reason']).trim();
    final type = _lower(d['type']);
    final createdAt = _dt(d['createdAt']);

    final isPositive = delta >= 0;
    final color = isPositive ? Colors.green : Colors.red;

    final who = userId.isNotEmpty
        ? userId
        : (uid.isNotEmpty ? uid : (email.isNotEmpty ? email : '—'));

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        title: Row(
          children: [
            Text(
              '${isPositive ? '+' : ''}$delta 分',
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(width: 10),
            if (type.isNotEmpty)
              _chip('type', type, cs.surfaceContainerHighest, cs.onSurfaceVariant),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _miniTag('docId', doc.id),
                  _miniTag('who', who),
                  if (email.isNotEmpty) _miniTag('email', email),
                  if (phone.isNotEmpty) _miniTag('phone', phone),
                  if (createdAt != null) _miniTag('time', _dtFmt.format(createdAt)),
                ],
              ),
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('原因：$reason', style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ],
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        onTap: () => _openDetail(doc),
      ),
    );
  }

  // ------------------------------------------------------------
  // Detail dialog
  // ------------------------------------------------------------
  Future<void> _openDetail(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final cs = Theme.of(context).colorScheme;
    final d = doc.data();

    final userId = _s(d['userId']).trim();
    final uid = _s(d['uid']).trim();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('紀錄詳情：${doc.id}', style: const TextStyle(fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 860,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _miniTag('docId', doc.id),
                    if (userId.isNotEmpty) _miniTag('userId', userId),
                    if (uid.isNotEmpty) _miniTag('uid', uid),
                    if (_dt(d['createdAt']) != null) _miniTag('createdAt', _dtFmt.format(_dt(d['createdAt'])!)),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('原始欄位（Debug）', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _prettyMap(d),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: doc.id));
              _toast('已複製 docId');
            },
            child: const Text('複製 docId'),
          ),
          TextButton(
            onPressed: (userId.isEmpty && uid.isEmpty)
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: userId.isNotEmpty ? userId : uid));
                    _toast('已複製 userId/uid');
                  },
            child: const Text('複製 userId/uid'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Small UI helpers
  // ------------------------------------------------------------
  Widget _chip(String k, String v, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text('$k:$v', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg)),
    );
  }

  Widget _miniTag(String k, String v) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$k：$v',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
      ),
    );
  }

  String _prettyMap(Map<String, dynamic> d) {
    // 避免 jsonEncode 遇到 Timestamp 例外
    final buf = StringBuffer();
    d.forEach((k, v) => buf.writeln('$k: ${_prettyValue(v)}'));
    return buf.toString();
  }

  String _prettyValue(dynamic v) {
    if (v == null) return 'null';
    if (v is Timestamp) return 'Timestamp(${v.toDate().toIso8601String()})';
    if (v is DateTime) return v.toIso8601String();
    if (v is Map) return '{...}';
    if (v is List) return '[${v.length}]';
    return v.toString();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ------------------------------------------------------------
// Stats model
// ------------------------------------------------------------
class _PointsStats {
  final int total;
  final int pos;
  final int neg;
  final int zero;
  final num sum;

  _PointsStats({
    required this.total,
    required this.pos,
    required this.neg,
    required this.zero,
    required this.sum,
  });
}

// ------------------------------------------------------------
// Common Views
// ------------------------------------------------------------
class _EmptyView extends StatelessWidget {
  final String title;
  const _EmptyView({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 6),
            Text('請調整篩選條件或新增資料後再試。', style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

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
        constraints: const BoxConstraints(maxWidth: 680),
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
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                  if (hint != null) ...[
                    const SizedBox(height: 10),
                    Text(hint!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
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
