// lib/pages/payment_status_page.dart
//
// ✅ PaymentStatusPage（最終完整版 v2｜可編譯｜timeline 最新在上｜型別防呆更完整）
//
// 功能：
// - 以訂單ID讀取 Firestore orders/{orderId}
// - 顯示付款狀態/金額/建立時間/買家/vendor
// - 顯示時間軸 timeline（支援：paymentTimeline / timeline / paymentEvents）
// - timeline 最新在上：list = list.reversed.toList()
// - 支援 Navigator arguments 帶入 orderId（/payment_status arguments: oid）
// - timeline item 欄位相容：ts / time / createdAt / at / timestamp
//
// 依賴：cloud_firestore, flutter/services

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PaymentStatusPage extends StatefulWidget {
  const PaymentStatusPage({super.key, this.orderId});

  final String? orderId;

  @override
  State<PaymentStatusPage> createState() => _PaymentStatusPageState();
}

class _PaymentStatusPageState extends State<PaymentStatusPage> {
  final _db = FirebaseFirestore.instance;

  // ---------- utils ----------
  String _s(dynamic v) => (v ?? '').toString().trim();

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse((v ?? '').toString().trim()) ?? 0;
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;

    // epoch seconds / milliseconds
    if (v is int) {
      try {
        if (v < 10000000000) {
          return DateTime.fromMillisecondsSinceEpoch(v * 1000);
        }
        return DateTime.fromMillisecondsSinceEpoch(v);
      } catch (_) {}
    }

    // epoch in String
    if (v is String) {
      final t = v.trim();
      final asInt = int.tryParse(t);
      if (asInt != null) {
        try {
          if (asInt < 10000000000) {
            return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
          }
          return DateTime.fromMillisecondsSinceEpoch(asInt);
        } catch (_) {}
      }
    }

    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
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

  String _resolveOrderId(BuildContext context) {
    final arg = ModalRoute.of(context)?.settings.arguments;
    final fromArg = arg is String ? arg.trim() : '';
    final fromCtor = (widget.orderId ?? '').trim();
    return fromArg.isNotEmpty ? fromArg : fromCtor;
  }

  // ---------- timeline ----------
  DateTime? _pickTimelineTs(Map<String, dynamic> t) {
    return _toDate(
      t['ts'] ?? t['time'] ?? t['createdAt'] ?? t['at'] ?? t['timestamp'],
    );
  }

  List<Map<String, dynamic>> _extractTimeline(Map<String, dynamic> data) {
    dynamic raw =
        data['paymentTimeline'] ?? data['timeline'] ?? data['paymentEvents'];
    if (raw is! List) return <Map<String, dynamic>>[];

    final out = <Map<String, dynamic>>[];

    for (final item in raw) {
      if (item is Map) {
        out.add(item.cast<String, dynamic>());
      } else {
        out.add(<String, dynamic>{
          'label': item.toString(),
          'status': '',
          'note': '',
          'ts': null,
        });
      }
    }

    // 舊 -> 新
    out.sort((a, b) {
      final da = _pickTimelineTs(a);
      final db = _pickTimelineTs(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });

    // ✅ 最新在上
    return out.reversed.toList();
  }

  // ---------- status ----------
  Color _statusColor(BuildContext context, String status) {
    final cs = Theme.of(context).colorScheme;
    final s = status.trim().toLowerCase();

    if (s.contains('paid') || s == 'success' || s == 'completed') {
      return cs.primary;
    }
    if (s.contains('pending') || s.contains('wait')) return Colors.orange;
    if (s.contains('fail') || s.contains('cancel') || s.contains('error')) {
      return cs.error;
    }

    return cs.onSurfaceVariant;
  }

  String _statusLabel(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '未知';
    return s;
  }

  // ---------- UI helpers ----------
  Widget _kv(String k, String v, {VoidCallback? onCopy}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            k,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        if (onCopy != null)
          IconButton(
            tooltip: '複製',
            onPressed: onCopy,
            icon: const Icon(Icons.copy, size: 18),
          ),
      ],
    );
  }

  Widget _miniChip(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // ✅ withOpacity deprecated -> withValues(alpha:)
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderId = _resolveOrderId(context);

    if (orderId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('付款狀態')),
        body: const Center(child: Text('缺少訂單ID（請從訂單或指令面板進入）')),
      );
    }

    final ref = _db.collection('orders').doc(orderId);

    return Scaffold(
      appBar: AppBar(
        title: Text('付款狀態 $orderId', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: '複製訂單號',
            onPressed: () => _copy(orderId, done: '已複製訂單號'),
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: '返回訂單列表',
            onPressed: () => Navigator.pushReplacementNamed(context, '/orders'),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                '讀取失敗：${snap.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final doc = snap.data!;
          if (!doc.exists) {
            return Center(child: Text('找不到訂單：$orderId'));
          }

          final data = doc.data() ?? <String, dynamic>{};

          // status：優先 paymentStatus，否則 status
          final status = _s(data['paymentStatus']).isNotEmpty
              ? _s(data['paymentStatus'])
              : _s(data['status']);

          final total = _toNum(
            data['total'] ?? data['amount'] ?? data['priceTotal'] ?? 0,
          );
          final createdAt = _toDate(data['createdAt'] ?? data['created_time']);
          final buyer = _s(data['buyerEmail']).isNotEmpty
              ? _s(data['buyerEmail'])
              : _s(data['buyer']);

          // vendor 顯示：優先 vendorIds（list），否則 vendorId
          String vendorShow = '';
          final vendorIdsRaw = data['vendorIds'];
          if (vendorIdsRaw is List) {
            final ids = vendorIdsRaw
                .map((e) => _s(e))
                .where((e) => e.isNotEmpty)
                .toList();
            if (ids.isNotEmpty) vendorShow = ids.join(', ');
          }
          if (vendorShow.isEmpty) vendorShow = _s(data['vendorId']);

          final timeline = _extractTimeline(data);

          final cs = Theme.of(context).colorScheme;
          final stColor = _statusColor(context, status);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Summary
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _StatusChip(
                            label: _statusLabel(status),
                            color: stColor,
                          ),
                          Text(
                            'NT\$${total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _kv(
                        '訂單ID',
                        orderId,
                        onCopy: () => _copy(orderId, done: '已複製訂單ID'),
                      ),
                      const SizedBox(height: 6),
                      _kv('建立時間', _fmt(createdAt)),
                      const SizedBox(height: 6),
                      _kv('買家', buyer.isEmpty ? '-' : buyer),
                      const SizedBox(height: 6),
                      _kv('vendor', vendorShow.isEmpty ? '-' : vendorShow),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pushReplacementNamed(
                                context,
                                '/orders',
                              ),
                              icon: const Icon(Icons.receipt_long_outlined),
                              label: const Text('訂單管理'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _copy(orderId, done: '已複製訂單號'),
                              icon: const Icon(Icons.copy),
                              label: const Text('複製訂單號'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Timeline title
              Row(
                children: [
                  const Text(
                    '付款時間軸',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '（最新在上）',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Timeline list
              if (timeline.isEmpty)
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      '尚無 timeline 資料（可在 orders/$orderId 寫入 paymentTimeline/timeline/paymentEvents）',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                )
              else
                Card(
                  elevation: 0,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: timeline.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final t = timeline[i];

                      final ts = _pickTimelineTs(t);
                      final label = _s(t['label']).isNotEmpty
                          ? _s(t['label'])
                          : _s(t['title']);
                      final st = _s(t['status']);
                      final note = _s(t['note']).isNotEmpty
                          ? _s(t['note'])
                          : _s(t['message']);

                      final c = _statusColor(context, st);

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            // ✅ withOpacity deprecated -> withValues(alpha:)
                            color: c.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: c.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Icon(Icons.timeline, color: c),
                        ),
                        title: Text(
                          label.isEmpty ? '（未命名事件）' : label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    _fmt(ts),
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (st.isNotEmpty) _miniChip(st, c),
                                ],
                              ),
                              if (note.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  note,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        // ✅ withOpacity deprecated -> withValues(alpha:)
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}
