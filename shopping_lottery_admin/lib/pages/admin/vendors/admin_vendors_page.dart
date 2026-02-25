// lib/pages/admin/vendors/admin_vendors_report_page.dart
// =====================================================
// ✅ AdminVendorReportPage（完整版｜可直接編譯）
// - 顯示廠商資料（vendors/<vendorId>）
// - 統計該廠商訂單（orders where vendorId == <vendorId>）
// - 支援日期區間篩選
// - 安全處理欄位不存在 / 型別不一致
// =====================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminVendorReportPage extends StatefulWidget {
  final String vendorId;
  final String? vendorName;

  const AdminVendorReportPage({
    super.key,
    required this.vendorId,
    this.vendorName,
  });

  @override
  State<AdminVendorReportPage> createState() => _AdminVendorReportPageState();
}

/// ✅ 相容舊命名（如果你其它地方用複數）
class AdminVendorsReportPage extends AdminVendorReportPage {
  const AdminVendorsReportPage({
    super.key,
    required super.vendorId,
    super.vendorName,
  });
}

class _AdminVendorReportPageState extends State<AdminVendorReportPage> {
  final _db = FirebaseFirestore.instance;
  final _money = NumberFormat.decimalPattern('zh_TW');
  DateTimeRange? _range;

  DocumentReference<Map<String, dynamic>> get _vendorRef =>
      _db.collection('vendors').doc(widget.vendorId);

  Query<Map<String, dynamic>> _ordersQuery() {
    Query<Map<String, dynamic>> q = _db
        .collection('orders')
        .where('vendorId', isEqualTo: widget.vendorId)
        .orderBy('createdAt', descending: true);

    if (_range != null) {
      // Firestore Timestamp/DateTime 比較：用 DateTime 做 where
      q = q
          .where('createdAt', isGreaterThanOrEqualTo: _range!.start)
          .where('createdAt', isLessThanOrEqualTo: _range!.end);
    }
    return q.limit(200);
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  num _numFrom(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  String _fmtDate(dynamic ts) {
    final d = _toDate(ts);
    if (d == null) return '-';
    return DateFormat('yyyy/MM/dd HH:mm').format(d);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initial =
        _range ??
        DateTimeRange(
          start: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 30)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      helpText: '選擇報表日期區間',
    );

    if (!mounted) return;
    setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final titleName = (widget.vendorName ?? '').trim().isNotEmpty
        ? widget.vendorName!.trim()
        : widget.vendorId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '廠商報表：$titleName',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '選擇日期區間',
            icon: const Icon(Icons.date_range_outlined),
            onPressed: _pickRange,
          ),
          IconButton(
            tooltip: '清除日期篩選',
            icon: const Icon(Icons.filter_alt_off_outlined),
            onPressed: () => setState(() => _range = null),
          ),
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildRangeCard(),
          const SizedBox(height: 10),
          _buildVendorCard(),
          const SizedBox(height: 10),
          _buildOrdersStatsCard(),
          const SizedBox(height: 10),
          _buildRecentOrdersCard(),
        ],
      ),
    );
  }

  Widget _buildRangeCard() {
    String text;
    if (_range == null) {
      text = '未指定（顯示最近 200 筆訂單）';
    } else {
      final s = DateFormat('yyyy/MM/dd').format(_range!.start);
      final e = DateFormat('yyyy/MM/dd').format(_range!.end);
      text = '$s ～ $e';
    }

    return Card(
      elevation: 0,
      child: ListTile(
        leading: const Icon(Icons.query_stats_outlined),
        title: const Text(
          '日期區間',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(text),
        trailing: Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: const Text('選擇'),
            ),
            if (_range != null)
              OutlinedButton.icon(
                onPressed: () => setState(() => _range = null),
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('清除'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorCard() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _vendorRef.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _errCard('讀取廠商資料失敗：${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final data = snap.data!.data() ?? <String, dynamic>{};

        final name = (data['name'] ?? widget.vendorName ?? '')
            .toString()
            .trim();
        final status = (data['status'] ?? 'unknown').toString();
        final phone = (data['phone'] ?? '').toString().trim();
        final email = (data['email'] ?? '').toString().trim();
        final address = (data['address'] ?? '').toString().trim();
        final updatedAt = data['updatedAt'];
        final createdAt = data['createdAt'];

        return Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name.isEmpty ? '(未命名廠商)' : name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusChip(status),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'vendorId：${widget.vendorId}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (phone.isNotEmpty) _miniInfo(Icons.phone, phone),
                    if (email.isNotEmpty)
                      _miniInfo(Icons.email_outlined, email),
                    if (address.isNotEmpty)
                      _miniInfo(Icons.place_outlined, address),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'created：${_fmtDate(createdAt)}   updated：${_fmtDate(updatedAt)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrdersStatsCard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ordersQuery().snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _errCard('讀取訂單統計失敗：${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final docs = snap.data!.docs;

        int count = docs.length;
        int paidCount = 0;
        int refundedCount = 0;

        num totalAmount = 0;
        num paidAmount = 0;
        num refundedAmount = 0;

        for (final d in docs) {
          final m = d.data();
          final status = (m['status'] ?? '').toString().toLowerCase();
          final payStatus = (m['paymentStatus'] ?? '').toString().toLowerCase();

          // 金額欄位：盡量容錯（total / amount / totalAmount）
          final amount =
              _numFrom(m['totalAmount']) +
              _numFrom(m['total']) +
              _numFrom(m['amount']);
          final finalAmount = amount == 0 ? _numFrom(m['grandTotal']) : amount;

          totalAmount += finalAmount;

          final isPaid =
              payStatus == 'paid' || status == 'paid' || status == 'completed';
          if (isPaid) {
            paidCount += 1;
            paidAmount += finalAmount;
          }

          final isRefunded =
              status.contains('refund') || payStatus == 'refunded';
          if (isRefunded) {
            refundedCount += 1;
            refundedAmount += finalAmount;
          }
        }

        return Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '訂單統計',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _statBox('訂單數', '$count'),
                    _statBox('已付款', '$paidCount'),
                    _statBox('退款相關', '$refundedCount'),
                    _statBox('總金額', 'NT\$ ${_money.format(totalAmount)}'),
                    _statBox('已付款金額', 'NT\$ ${_money.format(paidAmount)}'),
                    _statBox(
                      '退款金額(估)',
                      'NT\$ ${_money.format(refundedAmount)}',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '※ 欄位容錯：會嘗試 totalAmount / total / amount / grandTotal；狀態會檢查 status / paymentStatus。',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentOrdersCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最近訂單（最多 200）',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _ordersQuery().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text('讀取失敗：${snap.error}');
                }
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('目前沒有訂單'),
                  );
                }

                return Column(
                  children: docs.take(20).map((d) {
                    final m = d.data();
                    final status = (m['status'] ?? '').toString();
                    final createdAt = _fmtDate(m['createdAt']);
                    final amount =
                        _numFrom(m['totalAmount']) +
                        _numFrom(m['total']) +
                        _numFrom(m['amount']);
                    final finalAmount = amount == 0
                        ? _numFrom(m['grandTotal'])
                        : amount;

                    final customer =
                        (m['userName'] ?? m['customerName'] ?? m['uid'] ?? '')
                            .toString();

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(
                        '訂單 ${d.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '$createdAt · $status${customer.isNotEmpty ? " · $customer" : ""}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        'NT\$ ${_money.format(finalAmount)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color c;
    switch (status.toLowerCase()) {
      case 'active':
        c = Colors.green;
        break;
      case 'inactive':
        c = Colors.grey;
        break;
      case 'suspended':
        c = Colors.red;
        break;
      default:
        c = Colors.blueGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.25)),
        color: c.withValues(alpha: 0.10),
      ),
      child: Text(
        status,
        style: TextStyle(color: c, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _miniInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade800),
          ),
        ),
      ],
    );
  }

  Widget _statBox(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          const SizedBox(height: 4),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _errCard(String msg) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
      ),
    );
  }
}
