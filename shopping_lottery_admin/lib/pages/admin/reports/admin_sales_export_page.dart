// lib/pages/admin/reports/admin_sales_export_page.dart
//
// ✅ AdminSalesExportPage（銷售匯出｜單檔完整版｜可直接編譯）
// -----------------------------------------------------------------------------
// - Firestore 直連 orders（不依賴你現有 Service）
// - 篩選：日期區間（createdAt）＋狀態（本地過濾，避免複合索引）＋關鍵字搜尋（本地過濾）
// - 分頁載入：Load more
// - 匯出 CSV（目前「可見」資料）→ 使用你的 saveReportBytes（Web/IO 自動分流）
//
// 依賴：cloud_firestore / intl / csv / utils/report_file_saver.dart
//
// Firestore 建議欄位（沒有也不會崩，會顯示空值）：
// orders/{id}
//  - orderId: String?
//  - status: String?
//  - createdAt: Timestamp?
//  - finalAmount: num?  (或 total)
//  - customerName/userName/displayName
//  - customerEmail/userEmail
//  - phone/customerPhone
//  - items: List<Map> ?（可選）
//  - shipping: { carrier, trackingNo, shippedAt, deliveredAt }
//  - refund: { status, amount, processedAt, completedAt }
//
// 索引提示：
// - 本頁只在 server 端套「createdAt 範圍 + orderBy createdAt」，通常不需要複合索引
// - 狀態/關鍵字全部做本地過濾，避免 status + createdAt 的複合索引麻煩
// -----------------------------------------------------------------------------

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:osmile_admin/utils/report_file_saver.dart';

class AdminSalesExportPage extends StatefulWidget {
  const AdminSalesExportPage({super.key});

  @override
  State<AdminSalesExportPage> createState() => _AdminSalesExportPageState();
}

class _AdminSalesExportPageState extends State<AdminSalesExportPage> {
  final _db = FirebaseFirestore.instance;

  // Filters
  final TextEditingController _searchCtrl = TextEditingController();
  DateTimeRange? _range;
  String _status =
      'all'; // all/paid/processing/shipping/shipped/delivered/completed/refund...
  bool _onlyPositiveAmount = false; // 只匯出 finalAmount > 0

  // Pagination
  static const int _pageSize = 200;
  bool _loading = true;
  String? _error;

  final List<_OrderRow> _rows = <_OrderRow>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _loadingMore = false;

  // Export feedback
  String? _exportResult;

  @override
  void initState() {
    super.initState();
    _initDefaultRange();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _initDefaultRange() {
    final now = DateTime.now();
    // 預設：當月 1 號 ~ 今日
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  // ===========================================================================
  // Firestore query
  // ===========================================================================
  Query<Map<String, dynamic>> _baseQuery() {
    Query<Map<String, dynamic>> q = _db.collection('orders');

    final r = _range;
    if (r != null) {
      q = q.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(r.start),
      );
      q = q.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(r.end));
    }

    // orderBy(createdAt) 搭配 createdAt 範圍通常 OK
    q = q.orderBy('createdAt', descending: true);
    return q;
  }

  Future<void> _load({required bool reset}) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _error = null;
      _exportResult = null;
      if (reset) {
        _loading = true;
        _rows.clear();
        _lastDoc = null;
        _hasMore = true;
      }
    });

    try {
      Query<Map<String, dynamic>> q = _baseQuery();

      if (!reset && _lastDoc != null) {
        q = q.startAfterDocument(_lastDoc!);
      }

      final snap = await q.limit(_pageSize).get();
      final docs = snap.docs;

      final page = docs
          .map((d) => _OrderRow(id: d.id, data: d.data()))
          .toList();
      final last = docs.isEmpty ? _lastDoc : docs.last;

      if (!mounted) {
        return;
      }
      setState(() {
        _rows.addAll(page);
        _lastDoc = last;
        _hasMore = docs.length == _pageSize;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = e.toString());
    } finally {
      if (mounted && reset) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      await _load(reset: false);
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  // ===========================================================================
  // Local filters (status/search/onlyPositive)
  // ===========================================================================
  List<_OrderRow> get _visibleRows {
    final q = _searchCtrl.text.trim().toLowerCase();
    final statusFilter = _status;
    final onlyPositive = _onlyPositiveAmount;

    bool hit(_OrderRow row) {
      final d = row.data;

      // status filter (local)
      if (statusFilter != 'all') {
        final st = (d['status'] ?? '').toString();
        if (st != statusFilter) {
          return false;
        }
      }

      // amount filter
      if (onlyPositive) {
        final amt = _toNum(d['finalAmount'] ?? d['total']);
        if (amt <= 0) {
          return false;
        }
      }

      // keyword filter
      if (q.isEmpty) {
        return true;
      }

      final docId = row.id.toLowerCase();
      final orderId = (d['orderId'] ?? '').toString().toLowerCase();
      final status = (d['status'] ?? '').toString().toLowerCase();

      final name =
          (d['customerName'] ?? d['userName'] ?? d['displayName'] ?? '')
              .toString()
              .toLowerCase();
      final email = (d['customerEmail'] ?? d['userEmail'] ?? '')
          .toString()
          .toLowerCase();
      final phone = (d['phone'] ?? d['customerPhone'] ?? '')
          .toString()
          .toLowerCase();

      final shipping = _readMap(d['shipping']);
      final trackingNo = (shipping['trackingNo'] ?? '')
          .toString()
          .toLowerCase();

      return docId.contains(q) ||
          orderId.contains(q) ||
          status.contains(q) ||
          name.contains(q) ||
          email.contains(q) ||
          phone.contains(q) ||
          trackingNo.contains(q);
    }

    return _rows.where(hit).toList();
  }

  // ===========================================================================
  // Date range UI
  // ===========================================================================
  Future<void> _pickRange() async {
    final now = DateTime.now();
    final init =
        _range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
      initialDateRange: init,
      helpText: '選擇匯出日期區間（createdAt）',
      confirmText: '套用',
      cancelText: '取消',
    );

    if (!mounted) {
      return;
    }
    if (picked == null) {
      return;
    }

    setState(() {
      _range = DateTimeRange(
        start: DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        end: DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        ),
      );
    });

    await _load(reset: true);
  }

  Future<void> _clearRange() async {
    setState(() => _range = null);
    await _load(reset: true);
  }

  // ===========================================================================
  // Export CSV (visible rows)
  // ===========================================================================
  Future<void> _exportVisibleCsv() async {
    final rows = _visibleRows;

    if (rows.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('目前沒有可匯出的資料（可見列表為空）')));
      return;
    }

    try {
      final bytes = _buildCsvBytes(rows);

      final fmt = DateFormat('yyyyMMdd_HHmm');
      final filename = 'sales_export_${fmt.format(DateTime.now())}.csv';

      final saved = await saveReportBytes(
        filename: filename,
        bytes: bytes,
        mimeType: 'text/csv',
      );

      if (!mounted) {
        return;
      }
      setState(() => _exportResult = saved);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('CSV 匯出完成')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('匯出失敗：$e')));
    }
  }

  List<int> _buildCsvBytes(List<_OrderRow> rows) {
    final csvData = <List<dynamic>>[];

    csvData.add([
      'docId',
      'orderId',
      'status',
      'createdAt',
      'customerName',
      'customerEmail',
      'phone',
      'finalAmount',
      'itemsCount',
      'carrier',
      'trackingNo',
      'refundStatus',
      'refundAmount',
    ]);

    final fmtDt = DateFormat('yyyy-MM-dd HH:mm');

    for (final r in rows) {
      final d = r.data;

      final createdAt = _toDateTime(d['createdAt']);
      final createdText = createdAt == null ? '' : fmtDt.format(createdAt);

      final shipping = _readMap(d['shipping']);
      final refund = _readMap(d['refund']);

      final itemsCount = _countItems(d['items']);

      csvData.add([
        r.id,
        (d['orderId'] ?? '').toString(),
        (d['status'] ?? '').toString(),
        createdText,
        (d['customerName'] ?? d['userName'] ?? d['displayName'] ?? '')
            .toString(),
        (d['customerEmail'] ?? d['userEmail'] ?? '').toString(),
        (d['phone'] ?? d['customerPhone'] ?? '').toString(),
        _toNum(d['finalAmount'] ?? d['total']).toString(),
        itemsCount,
        (shipping['carrier'] ?? '').toString(),
        (shipping['trackingNo'] ?? '').toString(),
        (refund['status'] ?? '').toString(),
        _toNum(refund['amount']).toString(),
      ]);
    }

    final csvString = const ListToCsvConverter().convert(csvData);
    // BOM for Excel
    return utf8.encode('\uFEFF$csvString');
  }

  int _countItems(dynamic v) {
    if (v is List) {
      return v.length;
    }
    return 0;
  }

  // ===========================================================================
  // UI
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            '銷售匯出',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              tooltip: '重新整理',
              onPressed: () => _load(reset: true),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _ErrorView(
          title: '載入訂單失敗',
          message: _error!,
          hint:
              '常見原因：需要 createdAt 欄位、或 Firestore Rules 阻擋、或 createdAt+range 需要索引（少見）。',
          onRetry: () => _load(reset: true),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final visible = _visibleRows;

    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
    final sum = visible.fold<num>(0, (p, r) {
      final d = r.data;
      return p + _toNum(d['finalAmount'] ?? d['total']);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '銷售匯出',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '匯出目前可見 CSV',
            onPressed: _exportVisibleCsv,
            icon: const Icon(Icons.download),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _filtersCard(cs),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _miniStat('可見筆數', visible.length.toString()),
                    _miniStat('金額合計', fmtMoney.format(sum)),
                    _miniStat('狀態', _status),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (_exportResult != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '匯出結果',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _exportResult!,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (visible.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '目前沒有符合條件的訂單。\n\n'
                    '提示：本頁狀態/關鍵字是針對「已載入列表」做本地過濾；可按「載入更多」擴大範圍。',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              ...visible.map(_orderTile),

            const SizedBox(height: 12),

            if (_hasMore)
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: _loadingMore ? null : _loadMore,
                  icon: _loadingMore
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more),
                  label: Text(_loadingMore ? '載入中...' : '載入更多'),
                ),
              ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _filtersCard(ColorScheme cs) {
    final fmt = DateFormat('yyyy/MM/dd');
    final rangeText = _range == null
        ? '未設定'
        : '${fmt.format(_range!.start)} - ${fmt.format(_range!.end)}';

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '篩選與搜尋',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '日期區間：',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(rangeText),
                    ),
                    if (_range != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _clearRange,
                        child: const Text('清除'),
                      ),
                    ],
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '狀態：',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 8),

                    // ✅ 不用 DropdownButtonFormField（避免 FormField.value deprecated）
                    DropdownButton<String>(
                      value: _status,
                      onChanged: (v) {
                        if (v == null) {
                          return;
                        }
                        setState(() => _status = v);
                      },
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('全部')),
                        DropdownMenuItem(value: 'paid', child: Text('paid')),
                        DropdownMenuItem(
                          value: 'processing',
                          child: Text('processing'),
                        ),
                        DropdownMenuItem(
                          value: 'shipping',
                          child: Text('shipping'),
                        ),
                        DropdownMenuItem(
                          value: 'shipped',
                          child: Text('shipped'),
                        ),
                        DropdownMenuItem(
                          value: 'delivered',
                          child: Text('delivered'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('completed'),
                        ),
                        DropdownMenuItem(
                          value: 'refund_requested',
                          child: Text('refund_requested'),
                        ),
                        DropdownMenuItem(
                          value: 'refunding',
                          child: Text('refunding'),
                        ),
                        DropdownMenuItem(
                          value: 'refunded',
                          child: Text('refunded'),
                        ),
                        DropdownMenuItem(
                          value: 'refund_rejected',
                          child: Text('refund_rejected'),
                        ),
                        DropdownMenuItem(
                          value: 'cancelled',
                          child: Text('cancelled'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '只顯示金額 > 0',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '避免匯出 0 元或測試資料（本地過濾）',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              value: _onlyPositiveAmount,
              onChanged: (v) => setState(() => _onlyPositiveAmount = v),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋 docId/orderId/姓名/email/電話/status/物流單號（本頁已載入資料）',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchCtrl.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除',
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),

            const SizedBox(height: 8),
            Text(
              '提示：狀態/關鍵字/金額為本地過濾；日期區間會影響 Firestore 查詢範圍。',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
      ],
    );
  }

  Widget _orderTile(_OrderRow row) {
    final d = row.data;
    final cs = Theme.of(context).colorScheme;
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

    final orderId = (d['orderId'] ?? row.id).toString();
    final status = (d['status'] ?? '').toString();

    final createdAt = _toDateTime(d['createdAt']);
    final createdText = createdAt == null
        ? '-'
        : DateFormat('yyyy/MM/dd HH:mm').format(createdAt);

    final amount = _toNum(d['finalAmount'] ?? d['total']);
    final customer =
        (d['customerName'] ?? d['userName'] ?? d['displayName'] ?? '')
            .toString();
    final email = (d['customerEmail'] ?? d['userEmail'] ?? '').toString();

    final shipping = _readMap(d['shipping']);
    final carrier = (shipping['carrier'] ?? '').toString();
    final trackingNo = (shipping['trackingNo'] ?? '').toString();

    final refund = _readMap(d['refund']);
    final refundStatus = (refund['status'] ?? '').toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order：$orderId',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                    maxLines: 1,
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
                    color: cs.primaryContainer,
                  ),
                  child: Text(
                    status.isEmpty ? 'unknown' : status,
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _kv('建立', createdText),
                _kv('顧客', customer.isEmpty ? '-' : customer),
                _kv('Email', email.isEmpty ? '-' : email),
                _kv('金額', fmtMoney.format(amount)),
              ],
            ),

            const Divider(height: 18),

            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _kv('物流商', carrier.isEmpty ? '-' : carrier),
                _kv('單號', trackingNo.isEmpty ? '-' : trackingNo),
                if (refundStatus.isNotEmpty) _kv('退款', refundStatus),
              ],
            ),
          ],
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

  // ===========================================================================
  // Utils
  // ===========================================================================
  Map<String, dynamic> _readMap(dynamic v) {
    if (v is Map<String, dynamic>) {
      return v;
    }
    if (v is Map) {
      return Map<String, dynamic>.from(v);
    }
    return <String, dynamic>{};
  }

  DateTime? _toDateTime(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is DateTime) {
      return v;
    }
    if (v is Timestamp) {
      return v.toDate();
    }
    try {
      final dynamic d = v;
      final dt = d.toDate();
      if (dt is DateTime) {
        return dt;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  num _toNum(dynamic v) {
    if (v is num) {
      return v;
    }
    return num.tryParse(v?.toString() ?? '0') ?? 0;
  }
}

// =============================================================================
// Models
// =============================================================================
class _OrderRow {
  final String id;
  final Map<String, dynamic> data;
  _OrderRow({required this.id, required this.data});
}

// =============================================================================
// Error View
// =============================================================================
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
        constraints: const BoxConstraints(maxWidth: 760),
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
