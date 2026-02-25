// lib/pages/admin/marketing/admin_coupon_reports_page.dart
//
// ✅ AdminCouponReportsPage（優惠券報表｜完整版｜可編譯）
// -----------------------------------------------------------------------------
// 修正重點：argument_type_not_assignable
// - Flutter 很多 widget 的 value/percent 參數是 double?，但你可能傳了 num
// - 本檔統一用 _toDouble(...) 或 .toDouble() 轉型，避免 num -> double? 報錯
//
// 功能（管理用報表，盡量不掃大量 orders）：
// - 列出 coupons（可搜尋/狀態篩選）
// - 顯示用量/上限與進度條
// - 匯出目前可見 coupons CSV
// - 檢視單一 coupon 概況，並可匯出「最多 500 筆」使用訂單（orders where couponCode==code）
//
// 依賴：
// - cloud_firestore
// - intl
// - csv
// - utils/report_file_saver.dart（需提供 saveReportBytes；本檔做 filename/fileName/name 相容）
//
// Firestore 假設：
// - coupons/{couponId} fields: code, title/name, type(amount/percent), value, usageLimit,
//   usedCount, isActive, startAt, endAt, updatedAt
// - orders collection (可選): couponCode, orderNo, userId, userEmail, total, createdAt
// -----------------------------------------------------------------------------

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../layouts/scaffold_with_drawer.dart';
import '../../../utils/report_file_saver.dart' as report_saver;

class AdminCouponReportsPage extends StatefulWidget {
  const AdminCouponReportsPage({super.key});

  @override
  State<AdminCouponReportsPage> createState() => _AdminCouponReportsPageState();
}

class _AdminCouponReportsPageState extends State<AdminCouponReportsPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _keyword = '';

  String _status = 'all'; // all/active/expired/disabled
  bool _loadingExport = false;
  String? _exportResult;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------------
  // compat saver: filename / fileName / name
  // -----------------------------------------------------------------------------
  Future<String?> _saveReportBytesCompat({
    required String filename,
    required List<int> bytes,
    required String mimeType,
  }) async {
    final dynamic fn = report_saver.saveReportBytes;

    // ✅ FIX: no_leading_underscores_for_local_identifiers
    // 區域函式/變數不能用 "_" 開頭
    Future<String?> tryInvoke(Map<Symbol, dynamic> named) async {
      final dynamic res = Function.apply(fn, const [], named);
      if (res is Future) {
        final v = await res;
        return v?.toString();
      }
      return res?.toString();
    }

    try {
      return await tryInvoke({
        #filename: filename,
        #bytes: bytes,
        #mimeType: mimeType,
      });
    } catch (_) {}

    try {
      return await tryInvoke({
        #fileName: filename,
        #bytes: bytes,
        #mimeType: mimeType,
      });
    } catch (_) {}

    try {
      return await tryInvoke({
        #name: filename,
        #bytes: bytes,
        #mimeType: mimeType,
      });
    } catch (e) {
      rethrow;
    }
  }

  // -----------------------------------------------------------------------------
  // query
  // -----------------------------------------------------------------------------
  Query<Map<String, dynamic>> _queryCoupons() {
    Query<Map<String, dynamic>> q = _db.collection('coupons');

    // 狀態篩選（以 endAt / isActive 推估；你可按你的資料欄位調整）
    final now = DateTime.now();

    if (_status == 'active') {
      q = q.where('isActive', isEqualTo: true);
    } else if (_status == 'disabled') {
      q = q.where('isActive', isEqualTo: false);
    } else if (_status == 'expired') {
      q = q.where('endAt', isLessThan: Timestamp.fromDate(now));
    }

    // 建議：有 updatedAt 才好排序
    q = q.orderBy('updatedAt', descending: true);
    return q;
  }

  // -----------------------------------------------------------------------------
  // helpers
  // -----------------------------------------------------------------------------
  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmtDate(dynamic v) {
    final d = _toDate(v);
    if (d == null) return '-';
    return DateFormat('yyyy/MM/dd').format(d);
  }

  String _fmtDateTime(dynamic v) {
    final d = _toDate(v);
    if (d == null) return '-';
    return DateFormat('yyyy/MM/dd HH:mm').format(d);
  }

  bool _isExpired(Map<String, dynamic> d) {
    final endAt = _toDate(d['endAt']);
    if (endAt == null) return false;
    return endAt.isBefore(DateTime.now());
  }

  bool _isActive(Map<String, dynamic> d) {
    final isActive = d['isActive'];
    final active = (isActive is bool)
        ? isActive
        : (isActive?.toString() == 'true');
    if (!active) return false;
    return !_isExpired(d);
  }

  // -----------------------------------------------------------------------------
  // export visible coupons
  // -----------------------------------------------------------------------------
  Future<void> _exportVisible(List<_CouponRow> rows) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('目前沒有可匯出的資料')));
      return;
    }
    if (_loadingExport) return;

    setState(() {
      _loadingExport = true;
      _exportResult = null;
    });

    try {
      final csv = _buildCouponsCsv(rows);
      final filename =
          'coupon_reports_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';

      final saved = await _saveReportBytesCompat(
        filename: filename,
        bytes: utf8.encode('\uFEFF$csv'),
        mimeType: 'text/csv',
      );

      if (!mounted) return;
      setState(() => _exportResult = saved ?? '已匯出（但 saver 未回傳路徑/訊息）');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('CSV 匯出完成')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('匯出失敗：$e')));
    } finally {
      if (mounted) setState(() => _loadingExport = false);
    }
  }

  String _buildCouponsCsv(List<_CouponRow> rows) {
    final data = <List<dynamic>>[];
    data.add([
      'couponId',
      'code',
      'title',
      'type',
      'value',
      'usageLimit',
      'usedCount',
      'isActive',
      'startAt',
      'endAt',
      'updatedAt',
    ]);

    for (final r in rows) {
      final d = r.data;
      data.add([
        r.id,
        (d['code'] ?? '').toString(),
        (d['title'] ?? d['name'] ?? '').toString(),
        (d['type'] ?? '').toString(),
        _toDouble(d['value']).toString(),
        _toInt(d['usageLimit']).toString(),
        _toInt(d['usedCount']).toString(),
        (d['isActive'] ?? '').toString(),
        _fmtDate(d['startAt']),
        _fmtDate(d['endAt']),
        _fmtDateTime(d['updatedAt']),
      ]);
    }

    return const ListToCsvConverter().convert(data);
  }

  // -----------------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return ScaffoldWithDrawer(
      title: '優惠券報表',
      currentRoute: '/reports',
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _filtersCard(),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _queryCoupons().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _errorCard('讀取失敗：${snap.error}');
                }

                if (snap.connectionState != ConnectionState.active &&
                    !snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 28),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final docs =
                    snap.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                final all = docs
                    .map((d) => _CouponRow(id: d.id, data: d.data()))
                    .toList();

                // local keyword filter
                final kw = _keyword.trim().toLowerCase();
                final visible = kw.isEmpty
                    ? all
                    : all.where((r) {
                        final d = r.data;
                        final code = (d['code'] ?? '').toString().toLowerCase();
                        final title = (d['title'] ?? d['name'] ?? '')
                            .toString()
                            .toLowerCase();
                        final type = (d['type'] ?? '').toString().toLowerCase();
                        return r.id.toLowerCase().contains(kw) ||
                            code.contains(kw) ||
                            title.contains(kw) ||
                            type.contains(kw);
                      }).toList();

                return Column(
                  children: [
                    _summaryBar(visible),
                    if (_exportResult != null) ...[
                      const SizedBox(height: 10),
                      _exportResultCard(_exportResult!),
                    ],
                    const SizedBox(height: 10),
                    if (visible.isEmpty)
                      _emptyCard()
                    else
                      ...visible.map(_couponTile), // ✅ FIX: remove .toList()
                    const SizedBox(height: 50),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtersCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '篩選 / 搜尋',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '狀態：',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _status,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('全部')),
                        DropdownMenuItem(value: 'active', child: Text('啟用中')),
                        DropdownMenuItem(value: 'expired', child: Text('已過期')),
                        DropdownMenuItem(value: 'disabled', child: Text('已停用')),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'all'),
                    ),
                  ],
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) =>
                        setState(() => _keyword = _searchCtrl.text),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search),
                      hintText: '搜尋 code / title / couponId',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _searchCtrl.text.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清除',
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _keyword = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => setState(() => _keyword = _searchCtrl.text),
                  icon: const Icon(Icons.filter_alt),
                  label: const Text('套用'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '提示：expired 篩選依賴 coupons.endAt；若你資料沒有 endAt，請改成你的欄位規則。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryBar(List<_CouponRow> visible) {
    final total = visible.length;
    final active = visible.where((r) => _isActive(r.data)).length;
    final expired = visible.where((r) => _isExpired(r.data)).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _miniStat('可見數', '$total'),
                  _miniStat('啟用中', '$active'),
                  _miniStat('已過期', '$expired'),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _loadingExport ? null : () => _exportVisible(visible),
              icon: _loadingExport
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_loadingExport ? '匯出中...' : '匯出 CSV'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String k, String v) {
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

  Widget _exportResultCard(String text) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard() {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '目前沒有符合條件的優惠券資料。',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _errorCard(String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  Widget _couponTile(_CouponRow row) {
    final d = row.data;
    final cs = Theme.of(context).colorScheme;

    final code = (d['code'] ?? row.id).toString();
    final title = (d['title'] ?? d['name'] ?? '').toString();
    final type = (d['type'] ?? '').toString();
    final value = _toDouble(d['value']);

    final used = _toInt(d['usedCount']);
    final limit = _toInt(d['usageLimit']);

    // ✅ LinearProgressIndicator.value 是 double?
    double? progress;
    if (limit > 0) {
      final raw = used / limit; // double
      final safe = raw < 0 ? 0.0 : (raw > 1 ? 1.0 : raw);
      progress = safe;
    } else {
      progress = null;
    }

    final active = _isActive(d);
    final expired = _isExpired(d);

    Color badge;
    String badgeText;
    if (expired) {
      badge = Colors.orange;
      badgeText = 'expired';
    } else if (active) {
      badge = Colors.green;
      badgeText = 'active';
    } else {
      badge = Colors.grey;
      badgeText = 'disabled';
    }

    final valueText = (type == 'percent')
        ? '${value.toStringAsFixed(0)}%'
        : 'NT\$${value.toStringAsFixed(0)}';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(row),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      code,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: badge.withValues(alpha: 0.12),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badge,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (title.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(title, style: TextStyle(color: cs.onSurfaceVariant)),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _kv('type', type.isEmpty ? '-' : type),
                  _kv('value', valueText),
                  _kv('used/limit', limit > 0 ? '$used / $limit' : '$used / -'),
                  _kv('start', _fmtDate(d['startAt'])),
                  _kv('end', _fmtDate(d['endAt'])),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: progress),
            ],
          ),
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

  // -----------------------------------------------------------------------------
  // detail dialog + export redemptions
  // -----------------------------------------------------------------------------
  Future<void> _openDetail(_CouponRow row) async {
    final d = row.data;
    final code = (d['code'] ?? row.id).toString();

    await showDialog<void>(
      context: context,
      builder: (_) => _CouponDetailDialog(
        couponId: row.id,
        couponData: d,
        loadOrders: () async {
          final snap = await _db
              .collection('orders')
              .where('couponCode', isEqualTo: code)
              .orderBy('createdAt', descending: true)
              .limit(500)
              .get();
          return snap.docs.map((e) => {'_id': e.id, ...e.data()}).toList();
        },
        exportOrdersCsv: (List<Map<String, dynamic>> orders) async {
          final csv = _buildOrdersCsv(code: code, orders: orders);
          final filename =
              'coupon_${code}_orders_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
          return _saveReportBytesCompat(
            filename: filename,
            bytes: utf8.encode('\uFEFF$csv'),
            mimeType: 'text/csv',
          );
        },
      ),
    );
  }

  String _buildOrdersCsv({
    required String code,
    required List<Map<String, dynamic>> orders,
  }) {
    final data = <List<dynamic>>[];
    data.add(['couponCode', code]);
    data.add([]);
    data.add([
      'orderId',
      'orderNo',
      'userId',
      'userEmail',
      'total',
      'createdAt',
    ]);

    for (final o in orders) {
      data.add([
        (o['_id'] ?? '').toString(),
        (o['orderNo'] ?? o['orderNumber'] ?? '').toString(),
        (o['userId'] ?? '').toString(),
        (o['userEmail'] ?? '').toString(),
        _toDouble(o['total']).toString(),
        _fmtDateTime(o['createdAt']),
      ]);
    }
    return const ListToCsvConverter().convert(data);
  }
}

// =============================================================================
// dialog
// =============================================================================
class _CouponDetailDialog extends StatefulWidget {
  final String couponId;
  final Map<String, dynamic> couponData;
  final Future<List<Map<String, dynamic>>> Function() loadOrders;
  final Future<String?> Function(List<Map<String, dynamic>> orders)
  exportOrdersCsv;

  const _CouponDetailDialog({
    required this.couponId,
    required this.couponData,
    required this.loadOrders,
    required this.exportOrdersCsv,
  });

  @override
  State<_CouponDetailDialog> createState() => _CouponDetailDialogState();
}

class _CouponDetailDialogState extends State<_CouponDetailDialog> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _orders = const [];
  String? _exportResult;

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmtDateTime(dynamic v) {
    final d = _toDate(v);
    if (d == null) return '-';
    return DateFormat('yyyy/MM/dd HH:mm').format(d);
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _exportResult = null;
    });
    try {
      final orders = await widget.loadOrders();
      if (!mounted) return;
      setState(() => _orders = orders);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export() async {
    if (_orders.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('目前沒有可匯出的訂單資料')));
      return;
    }
    setState(() => _exportResult = null);
    try {
      final saved = await widget.exportOrdersCsv(_orders);
      if (!mounted) return;
      setState(() => _exportResult = saved ?? '已匯出（但 saver 未回傳路徑/訊息）');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('訂單 CSV 匯出完成')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('匯出失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.couponData;
    final code = (d['code'] ?? widget.couponId).toString();
    final title = (d['title'] ?? d['name'] ?? '').toString();
    final type = (d['type'] ?? '').toString();
    final value = _toDouble(d['value']);

    final used = _toInt(d['usedCount']);
    final limit = _toInt(d['usageLimit']);

    return AlertDialog(
      title: const Text(
        'Coupon 詳情',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'code：$code',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              if (title.isNotEmpty) ...[const SizedBox(height: 6), Text(title)],
              const SizedBox(height: 8),
              Text('type：${type.isEmpty ? '-' : type}'),
              Text('value：$value'),
              Text('used/limit：${limit > 0 ? '$used / $limit' : '$used / -'}'),
              Text('updatedAt：${_fmtDateTime(d['updatedAt'])}'),
              const SizedBox(height: 12),
              const Divider(),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _loading ? null : _load,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: const Text('載入使用訂單（最多 500）'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _orders.isEmpty ? null : _export,
                    icon: const Icon(Icons.download),
                    label: const Text('匯出訂單 CSV'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text('錯誤：$_error', style: const TextStyle(color: Colors.red)),
              ],
              if (_exportResult != null) ...[
                const SizedBox(height: 10),
                Text(
                  _exportResult!,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
              if (_orders.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '已載入 ${_orders.length} 筆訂單（僅顯示前 20 筆）',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ..._orders.take(20).map((o) {
                  final orderNo =
                      (o['orderNo'] ?? o['orderNumber'] ?? o['_id'] ?? '')
                          .toString();
                  final email = (o['userEmail'] ?? '').toString();
                  final total = _toDouble(o['total']);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• $orderNo | $email | $total | ${_fmtDateTime(o['createdAt'])}',
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('關閉'),
        ),
      ],
    );
  }
}

// =============================================================================
// model
// =============================================================================
class _CouponRow {
  final String id;
  final Map<String, dynamic> data;
  _CouponRow({required this.id, required this.data});
}
