// lib/pages/vendor/reports/vendor_sales_report_page.dart
//
// ✅ VendorSalesReportPage（最終完整版｜可編譯｜修正 curly braces lint｜避免 deprecated 色彩 API｜移除未使用 _working）
// ------------------------------------------------------------
// 目標：Vendor 端銷售報表（可獨立運作、穩定編譯）
// - Firestore: orders
// - 篩選：日期區間 / 狀態 / 關鍵字（訂單ID / 買家email）
// - 只統計屬於該 vendor 的訂單：vendorId == currentVendorId（可自行調整 vendorIds List）
// - 彙總：總營收、訂單數、已付款數、取消/失敗數
// - 清單：每筆訂單概覽（可點擊查看 JSON）
//
// 你可依專案欄位調整：
// orders/{id} {
//   vendorId: String
//   vendorIds: List<String>?
//   total/amount/priceTotal: num
//   paymentStatus: String?
//   status: String?
//   buyerEmail/buyer: String?
//   createdAt: Timestamp|int|string
// }

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VendorSalesReportPage extends StatefulWidget {
  const VendorSalesReportPage({super.key});

  @override
  State<VendorSalesReportPage> createState() => _VendorSalesReportPageState();
}

class _VendorSalesReportPageState extends State<VendorSalesReportPage> {
  final _db = FirebaseFirestore.instance;

  final _qCtrl = TextEditingController();

  DateTime? _from;
  DateTime? _to;

  String _status = 'all'; // all / paid / pending / failed / cancelled
  bool _onlyPaid = false;

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  // ----------------------------
  // Utils
  // ----------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();

  num _n(dynamic v) {
    if (v is num) return v;
    return num.tryParse(_s(v)) ?? 0;
  }

  bool _b(dynamic v) => v == true;

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;

    if (v is int) {
      try {
        if (v < 10000000000) {
          return DateTime.fromMillisecondsSinceEpoch(v * 1000);
        }
        return DateTime.fromMillisecondsSinceEpoch(v);
      } catch (_) {
        return null;
      }
    }

    if (v is String) {
      final t = v.trim();
      final asInt = int.tryParse(t);
      if (asInt != null) {
        try {
          if (asInt < 10000000000) {
            return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
          }
          return DateTime.fromMillisecondsSinceEpoch(asInt);
        } catch (_) {
          return null;
        }
      }
      return DateTime.tryParse(t);
    }

    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  bool _isPaid(Map<String, dynamic> data) {
    final s =
        (_s(data['paymentStatus']).isNotEmpty
                ? _s(data['paymentStatus'])
                : _s(data['status']))
            .toLowerCase();
    if (s.contains('paid') || s == 'success' || s == 'completed') {
      return true;
    }
    return _b(data['paid']);
  }

  String _statusKey(Map<String, dynamic> data) {
    final s =
        (_s(data['paymentStatus']).isNotEmpty
                ? _s(data['paymentStatus'])
                : _s(data['status']))
            .toLowerCase();

    if (s.contains('paid') || s == 'success' || s == 'completed') return 'paid';
    if (s.contains('pending') || s.contains('wait')) return 'pending';
    if (s.contains('cancel')) return 'cancelled';
    if (s.contains('fail') || s.contains('error')) return 'failed';
    return s.isEmpty ? 'unknown' : s;
  }

  String _money(num v) {
    final s = v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
    final parts = s.split('.');
    final ints = parts.first;
    final buf = StringBuffer();
    for (int i = 0; i < ints.length; i++) {
      final idxFromEnd = ints.length - i;
      buf.write(ints[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) {
        buf.write(',');
      }
    }
    final out = parts.length == 2
        ? '${buf.toString()}.${parts[1]}'
        : buf.toString();
    return 'NT\$ $out';
  }

  Future<void> _copy(String text, {String done = '已複製'}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(done), duration: const Duration(seconds: 2)),
    );
  }

  // ----------------------------
  // Vendor identity (simple)
  // ----------------------------
  String _resolveVendorId(User user) {
    // 你若有 vendorId 自訂 claim / users/{uid}.vendorId，可在這裡改成查 profile
    // 先用 uid 當 vendorId（常見做法）
    return user.uid;
  }

  // ----------------------------
  // Query (index-safe)
  // ----------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream(String vendorId) {
    // ✅ 保守策略：只用 orderBy(createdAt)，避免複合索引
    // ⚠️ 這裡 vendorId 不放 where，改前端過濾，避免索引問題
    return _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(1200)
        .snapshots();
  }

  bool _match({
    required String docId,
    required Map<String, dynamic> d,
    required String vendorId,
  }) {
    // vendor filter: vendorId OR vendorIds contains
    final vId = _s(d['vendorId']);
    final vIds = d['vendorIds'];

    bool belongs = false;

    if (vId.isNotEmpty && vId == vendorId) {
      belongs = true;
    } else if (vIds is List) {
      final hit = vIds.map((e) => _s(e)).any((e) => e == vendorId);
      if (hit) {
        belongs = true;
      }
    }

    if (!belongs) return false;

    // date range (front-end filter)
    final createdAt = _toDate(d['createdAt'] ?? d['created_time'] ?? d['time']);
    if (_from != null && createdAt != null) {
      final start = DateTime(_from!.year, _from!.month, _from!.day);
      if (createdAt.isBefore(start)) return false;
    }
    if (_to != null && createdAt != null) {
      final end = DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59, 999);
      if (createdAt.isAfter(end)) return false;
    }

    // status filter
    final key = _statusKey(d);
    if (_status != 'all' && key != _status) return false;
    if (_onlyPaid && !_isPaid(d)) return false;

    // keyword
    final q = _qCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return true;

    final buyer = _s(d['buyerEmail']).isNotEmpty
        ? _s(d['buyerEmail'])
        : _s(d['buyer']);
    final text = '$docId ${_s(d['status'])} ${_s(d['paymentStatus'])} $buyer'
        .toLowerCase();
    return text.contains(q);
  }

  // ----------------------------
  // Date picker
  // ----------------------------
  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _to = picked);
  }

  // ----------------------------
  // UI
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;

        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (user == null) {
          return const Scaffold(body: Center(child: Text('請先登入')));
        }

        final vendorId = _resolveVendorId(user);

        return Scaffold(
          appBar: AppBar(
            title: const Text('銷售報表'),
            actions: [
              IconButton(
                tooltip: '清除條件',
                onPressed: () {
                  setState(() {
                    _qCtrl.clear();
                    _from = null;
                    _to = null;
                    _status = 'all';
                    _onlyPaid = false;
                  });
                },
                icon: const Icon(Icons.restart_alt),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _ordersStream(vendorId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('讀取失敗：${snap.error}'));
              }

              final docs = snap.data?.docs ?? const [];
              final rows = docs
                  .map((d) => _OrderRow(id: d.id, data: d.data()))
                  .where(
                    (r) => _match(docId: r.id, d: r.data, vendorId: vendorId),
                  )
                  .toList();

              // summary
              num revenue = 0;
              int paidCount = 0;
              int failCount = 0;
              int cancelCount = 0;

              for (final r in rows) {
                final d = r.data;
                final total = _n(
                  d['total'] ?? d['amount'] ?? d['priceTotal'] ?? 0,
                );
                final st = _statusKey(d);

                revenue += total;
                if (_isPaid(d)) paidCount += 1;
                if (st == 'failed') failCount += 1;
                if (st == 'cancelled') cancelCount += 1;
              }

              return Column(
                children: [
                  // Filters
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Column(
                      children: [
                        TextField(
                          controller: _qCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: '搜尋：訂單ID / 買家 / 狀態',
                            filled: true,
                            fillColor: cs.surfaceContainerHighest.withValues(
                              alpha: 36,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: cs.outlineVariant),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: cs.outlineVariant),
                            ),
                            suffixIcon: IconButton(
                              tooltip: '清除',
                              onPressed: () {
                                _qCtrl.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickFrom,
                              icon: const Icon(Icons.date_range),
                              label: Text(
                                _from == null
                                    ? '起日'
                                    : _fmt(_from).split(' ').first,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickTo,
                              icon: const Icon(Icons.event),
                              label: Text(
                                _to == null ? '迄日' : _fmt(_to).split(' ').first,
                              ),
                            ),
                            DropdownButton<String>(
                              value: _status,
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('全部狀態'),
                                ),
                                DropdownMenuItem(
                                  value: 'paid',
                                  child: Text('已付款'),
                                ),
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Text('待付款'),
                                ),
                                DropdownMenuItem(
                                  value: 'failed',
                                  child: Text('失敗'),
                                ),
                                DropdownMenuItem(
                                  value: 'cancelled',
                                  child: Text('取消'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _status = v ?? 'all'),
                            ),
                            FilterChip(
                              label: const Text('只看已付款'),
                              selected: _onlyPaid,
                              onSelected: (v) => setState(() => _onlyPaid = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Summary
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Wrap(
                          spacing: 14,
                          runSpacing: 10,
                          children: [
                            _KpiTile(label: '訂單數', value: '${rows.length}'),
                            _KpiTile(label: '總營收', value: _money(revenue)),
                            _KpiTile(label: '已付款', value: '$paidCount'),
                            _KpiTile(label: '失敗', value: '$failCount'),
                            _KpiTile(label: '取消', value: '$cancelCount'),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // List
                  Expanded(
                    child: rows.isEmpty
                        ? Center(
                            child: Text(
                              '沒有符合條件的訂單',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                            itemCount: rows.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final r = rows[i];
                              final d = r.data;

                              final createdAt = _toDate(
                                d['createdAt'] ?? d['created_time'],
                              );
                              final buyer = _s(d['buyerEmail']).isNotEmpty
                                  ? _s(d['buyerEmail'])
                                  : _s(d['buyer']);
                              final total = _n(
                                d['total'] ??
                                    d['amount'] ??
                                    d['priceTotal'] ??
                                    0,
                              );

                              final stRaw = _s(d['paymentStatus']).isNotEmpty
                                  ? _s(d['paymentStatus'])
                                  : _s(d['status']);
                              final stKey = _statusKey(d);
                              final stColor = _statusColor(cs, stKey);

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: cs.outlineVariant),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: stColor.withValues(alpha: 28),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: cs.outlineVariant,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.receipt_long_outlined,
                                      color: stColor,
                                    ),
                                  ),
                                  title: Text(
                                    r.id,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _money(total),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 6,
                                          children: [
                                            _MiniChip(
                                              icon: Icons.schedule,
                                              text: _fmt(createdAt),
                                            ),
                                            if (buyer.isNotEmpty)
                                              _MiniChip(
                                                icon: Icons.person_outline,
                                                text: buyer,
                                              ),
                                            if (stRaw.isNotEmpty)
                                              _MiniChip(
                                                icon: Icons.info_outline,
                                                text: stRaw,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      if (v == 'copy_id') {
                                        await _copy(r.id, done: '已複製訂單ID');
                                      } else if (v == 'copy_json') {
                                        await _copy(
                                          jsonEncode(d),
                                          done: 'JSON 已複製',
                                        );
                                      } else if (v == 'view') {
                                        if (!mounted) return;
                                        await showDialog<void>(
                                          context: context,
                                          builder: (dialogCtx) => AlertDialog(
                                            title: const Text('訂單資料'),
                                            content: SizedBox(
                                              width: 560,
                                              child: SingleChildScrollView(
                                                child: SelectableText(
                                                  const JsonEncoder.withIndent(
                                                    '  ',
                                                  ).convert(d),
                                                ),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(dialogCtx),
                                                child: const Text('關閉'),
                                              ),
                                              FilledButton(
                                                onPressed: () => _copy(
                                                  jsonEncode(d),
                                                  done: 'JSON 已複製',
                                                ),
                                                child: const Text('複製 JSON'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'view',
                                        child: Text('查看'),
                                      ),
                                      PopupMenuDivider(),
                                      PopupMenuItem(
                                        value: 'copy_id',
                                        child: Text('複製訂單ID'),
                                      ),
                                      PopupMenuItem(
                                        value: 'copy_json',
                                        child: Text('複製 JSON'),
                                      ),
                                    ],
                                  ),
                                  onTap: () async {
                                    // ✅ 避免 lint：async gap 後使用 context 前檢查 mounted
                                    if (!mounted) return;
                                    await showDialog<void>(
                                      context: context,
                                      builder: (dialogCtx) => AlertDialog(
                                        title: Text('訂單 ${r.id}'),
                                        content: SizedBox(
                                          width: 560,
                                          child: SingleChildScrollView(
                                            child: SelectableText(
                                              const JsonEncoder.withIndent(
                                                '  ',
                                              ).convert(d),
                                            ),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialogCtx),
                                            child: const Text('關閉'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                _copy(r.id, done: '已複製訂單ID'),
                                            child: const Text('複製訂單ID'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Color _statusColor(ColorScheme cs, String key) {
    if (key == 'paid') return cs.primary;
    if (key == 'pending') return Colors.orange;
    if (key == 'failed') return cs.error;
    if (key == 'cancelled') return Colors.grey;
    return cs.onSurfaceVariant;
  }
}

class _OrderRow {
  final String id;
  final Map<String, dynamic> data;
  _OrderRow({required this.id, required this.data});
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 30),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text.isEmpty ? '-' : text,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
