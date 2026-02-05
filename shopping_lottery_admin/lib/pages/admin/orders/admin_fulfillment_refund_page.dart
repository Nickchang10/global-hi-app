// lib/pages/admin/orders/admin_fulfillment_refund_page.dart
//
// ✅ 出貨 / 退款工作台（Shipping + Refund Workbench｜完整版｜可直接編譯）
// -----------------------------------------------------------------------------
// 特色：
// - 兩個分頁：出貨管理 / 退款管理
// - Firestore 直連 orders collection（不依賴你現有 OrderService，避免缺方法造成編譯失敗）
// - 支援：搜尋、狀態篩選、日期區間、分頁載入
// - 出貨操作：填寫物流資訊、標記出貨、標記送達
// - 退款操作：同意退款（填金額/備註）、標記退款完成、駁回退款
// - 匯出 CSV（目前列表可見資料）→ 使用你的 saveReportBytes（Web/IO 自動分流）
//
// 依賴：cloud_firestore / intl / csv / utils/report_file_saver.dart
//
// Firestore 建議欄位（若沒有也不會崩，但會顯示空值）：
// orders/{id}
//  - status: String  (paid/processing/shipping/shipped/delivered/refund_requested/refunding/refunded/refund_rejected/...)
//  - createdAt: Timestamp
//  - finalAmount: num
//  - customerName/userName/displayName
//  - customerEmail/userEmail
//  - shipping: { carrier, trackingNo, trackingUrl, shippedAt, deliveredAt, note }
//  - refund:   { status, requestedAt, processedAt, amount, reason, note }
//
// 索引提示：若你同時用 where(status==...) + orderBy(createdAt)，Firestore 可能要求建立複合索引。
// -----------------------------------------------------------------------------


import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:osmile_admin/utils/report_file_saver.dart';

class AdminFulfillmentRefundPage extends StatefulWidget {
  const AdminFulfillmentRefundPage({super.key});

  @override
  State<AdminFulfillmentRefundPage> createState() => _AdminFulfillmentRefundPageState();
}

class _AdminFulfillmentRefundPageState extends State<AdminFulfillmentRefundPage> with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;

  late final TabController _tab;

  // Filters
  final TextEditingController _searchCtrl = TextEditingController();
  String _shippingStatus = 'shipping_todo'; // shipping_todo / shipping_in_progress / shipped / delivered / all
  String _refundStatus = 'refund_requested'; // refund_requested / refunding / refunded / refund_rejected / all
  DateTimeRange? _range; // by createdAt

  // Pagination
  static const int _pageSize = 25;
  bool _loading = true;
  String? _error;

  final List<_OrderRow> _rows = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _loadingMore = false;

  // Export feedback
  String? _exportResult;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (_tab.indexIsChanging) return;
      _load(reset: true);
    });
    _load(reset: true);
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Query builder
  // ===========================================================================
  Query<Map<String, dynamic>> _baseQuery() {
    Query<Map<String, dynamic>> q = _db.collection('orders');

    final isShippingTab = _tab.index == 0;

    // Status filter
    if (isShippingTab) {
      final whereStatuses = _shippingWhereStatuses(_shippingStatus);
      if (whereStatuses != null) {
        // Firestore in 查询最多 30（目前很安全）
        q = q.where('status', whereIn: whereStatuses);
      }
    } else {
      final whereStatuses = _refundWhereStatuses(_refundStatus);
      if (whereStatuses != null) {
        q = q.where('status', whereIn: whereStatuses);
      }
    }

    // Date range filter
    final r = _range;
    if (r != null) {
      q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(r.start));
      q = q.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(r.end));
    }

    // Always order by createdAt desc
    q = q.orderBy('createdAt', descending: true);
    return q;
  }

  List<String>? _shippingWhereStatuses(String key) {
    switch (key) {
      case 'shipping_todo':
        // 待出貨（已付款/處理中）
        return const ['paid', 'processing'];
      case 'shipping_in_progress':
        return const ['shipping'];
      case 'shipped':
        return const ['shipped'];
      case 'delivered':
        return const ['delivered', 'completed'];
      case 'all':
        return null;
      default:
        return null;
    }
  }

  List<String>? _refundWhereStatuses(String key) {
    switch (key) {
      case 'refund_requested':
        return const ['refund_requested'];
      case 'refunding':
        return const ['refunding'];
      case 'refunded':
        return const ['refunded'];
      case 'refund_rejected':
        return const ['refund_rejected'];
      case 'all':
        return null;
      default:
        return null;
    }
  }

  // ===========================================================================
  // Load / paginate
  // ===========================================================================
  Future<void> _load({required bool reset}) async {
    if (!mounted) return;

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

      final page = docs.map((d) => _OrderRow(id: d.id, data: d.data())).toList();
      final last = docs.isEmpty ? _lastDoc : docs.last;

      if (!mounted) return;
      setState(() {
        _rows.addAll(page);
        _lastDoc = last;
        _hasMore = docs.length == _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      if (reset) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      await _load(reset: false);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ===========================================================================
  // Search helpers (local filter only, to avoid index pain)
  // ===========================================================================
  List<_OrderRow> get _visibleRows {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _rows;

    bool hit(_OrderRow r) {
      final d = r.data;
      final id = r.id.toLowerCase();
      final orderId = (d['orderId'] ?? '').toString().toLowerCase();
      final email = (d['customerEmail'] ?? d['userEmail'] ?? '').toString().toLowerCase();
      final name = (d['customerName'] ?? d['userName'] ?? d['displayName'] ?? '').toString().toLowerCase();
      final phone = (d['phone'] ?? '').toString().toLowerCase();
      final status = (d['status'] ?? '').toString().toLowerCase();
      final trackingNo = _readShipping(d)['trackingNo'].toString().toLowerCase();

      return id.contains(q) ||
          orderId.contains(q) ||
          email.contains(q) ||
          name.contains(q) ||
          phone.contains(q) ||
          status.contains(q) ||
          trackingNo.contains(q);
    }

    return _rows.where(hit).toList();
  }

  // ===========================================================================
  // Date range filter
  // ===========================================================================
  Future<void> _pickRange() async {
    final now = DateTime.now();
    final init = _range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
      initialDateRange: init,
      helpText: '選擇訂單日期區間（createdAt）',
      confirmText: '套用',
      cancelText: '取消',
    );
    if (picked == null) return;

    setState(() {
      _range = DateTimeRange(
        start: DateTime(picked.start.year, picked.start.month, picked.start.day),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
      );
    });

    await _load(reset: true);
  }

  Future<void> _clearRange() async {
    setState(() => _range = null);
    await _load(reset: true);
  }

  // ===========================================================================
  // Export CSV
  // ===========================================================================
  Future<void> _exportVisibleCsv() async {
    final rows = _visibleRows;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('目前沒有可匯出的資料')));
      return;
    }

    try {
      final bytes = _buildCsvBytes(rows);
      final tabName = _tab.index == 0 ? 'shipping' : 'refund';
      final filename = '${tabName}_orders_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';

      final saved = await saveReportBytes(
        filename: filename,
        bytes: bytes,
        mimeType: 'text/csv',
      );

      if (!mounted) return;
      setState(() => _exportResult = saved);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV 匯出完成')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('匯出失敗：$e')));
    }
  }

  List<int> _buildCsvBytes(List<_OrderRow> rows) {
    final csvData = <List<dynamic>>[];

    csvData.add([
      'docId',
      'orderId',
      'status',
      'createdAt',
      'customer',
      'email',
      'amount',
      'carrier',
      'trackingNo',
      'refundStatus',
      'refundAmount',
    ]);

    final fmt = DateFormat('yyyy-MM-dd HH:mm');

    for (final r in rows) {
      final d = r.data;
      final createdAt = _toDateTime(d['createdAt']);
      final shipping = _readShipping(d);
      final refund = _readRefund(d);

      csvData.add([
        r.id,
        (d['orderId'] ?? '').toString(),
        (d['status'] ?? '').toString(),
        createdAt == null ? '' : fmt.format(createdAt),
        (d['customerName'] ?? d['userName'] ?? d['displayName'] ?? '').toString(),
        (d['customerEmail'] ?? d['userEmail'] ?? '').toString(),
        _toNum(d['finalAmount'] ?? d['total']).toString(),
        (shipping['carrier'] ?? '').toString(),
        (shipping['trackingNo'] ?? '').toString(),
        (refund['status'] ?? '').toString(),
        _toNum(refund['amount']).toString(),
      ]);
    }

    final csvString = const ListToCsvConverter().convert(csvData);
    return utf8.encode('\uFEFF$csvString');
  }

  // ===========================================================================
  // Actions - Shipping
  // ===========================================================================
  Future<void> _openShippingDialog(_OrderRow row) async {
    final d = row.data;
    final shipping = _readShipping(d);

    final result = await showDialog<_ShippingInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ShippingDialog(
        orderDocId: row.id,
        orderId: (d['orderId'] ?? row.id).toString(),
        initialCarrier: (shipping['carrier'] ?? '').toString(),
        initialTrackingNo: (shipping['trackingNo'] ?? '').toString(),
        initialTrackingUrl: (shipping['trackingUrl'] ?? '').toString(),
        initialNote: (shipping['note'] ?? '').toString(),
      ),
    );

    if (result == null) return;

    try {
      final ref = _db.collection('orders').doc(row.id);

      // Mark as shipped (or shipping) depending on current status
      final currentStatus = (d['status'] ?? '').toString();
      final nextStatus = (currentStatus == 'paid' || currentStatus == 'processing') ? 'shipping' : currentStatus;

      await ref.set(
        {
          'status': nextStatus,
          'shipping': {
            'carrier': result.carrier,
            'trackingNo': result.trackingNo,
            'trackingUrl': result.trackingUrl,
            'note': result.note,
            'shippedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已更新出貨資訊')));
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新出貨失敗：$e')));
    }
  }

  Future<void> _markDelivered(_OrderRow row) async {
    final ok = await _confirm(
      title: '標記送達',
      message: '確定要將此訂單標記為「已送達」？\nDocId：${row.id}',
      confirmText: '標記送達',
    );
    if (ok != true) return;

    try {
      final ref = _db.collection('orders').doc(row.id);
      await ref.set(
        {
          'status': 'delivered',
          'shipping': {'deliveredAt': FieldValue.serverTimestamp()},
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已標記送達')));
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失敗：$e')));
    }
  }

  // ===========================================================================
  // Actions - Refund
  // ===========================================================================
  Future<void> _approveRefund(_OrderRow row) async {
    final d = row.data;
    final refund = _readRefund(d);

    final result = await showDialog<_RefundInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RefundDialog(
        orderDocId: row.id,
        orderId: (d['orderId'] ?? row.id).toString(),
        initialAmount: _toNum(refund['amount'] ?? d['finalAmount'] ?? d['total']).toDouble(),
        initialReason: (refund['reason'] ?? '').toString(),
        initialNote: (refund['note'] ?? '').toString(),
        mode: _RefundDialogMode.approve,
      ),
    );
    if (result == null) return;

    try {
      final ref = _db.collection('orders').doc(row.id);
      await ref.set(
        {
          'status': 'refunding',
          'refund': {
            'status': 'refunding',
            'amount': result.amount,
            'reason': result.reason,
            'note': result.note,
            'processedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已同意退款（狀態：refunding）')));
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失敗：$e')));
    }
  }

  Future<void> _markRefunded(_OrderRow row) async {
    final ok = await _confirm(
      title: '標記退款完成',
      message: '確定要將此訂單標記為「退款完成」？\nDocId：${row.id}',
      confirmText: '退款完成',
    );
    if (ok != true) return;

    try {
      final ref = _db.collection('orders').doc(row.id);
      await ref.set(
        {
          'status': 'refunded',
          'refund': {
            'status': 'refunded',
            'completedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已標記退款完成')));
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失敗：$e')));
    }
  }

  Future<void> _rejectRefund(_OrderRow row) async {
    final d = row.data;
    final result = await showDialog<_RefundInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RefundDialog(
        orderDocId: row.id,
        orderId: (d['orderId'] ?? row.id).toString(),
        initialAmount: 0,
        initialReason: '',
        initialNote: '',
        mode: _RefundDialogMode.reject,
      ),
    );
    if (result == null) return;

    try {
      final ref = _db.collection('orders').doc(row.id);
      await ref.set(
        {
          'status': 'refund_rejected',
          'refund': {
            'status': 'refund_rejected',
            'note': result.note,
            'processedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已駁回退款')));
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失敗：$e')));
    }
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
          title: const Text('出貨 / 退款工作台', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [IconButton(onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh))],
          bottom: TabBar(
            controller: _tab,
            tabs: const [
              Tab(text: '出貨管理'),
              Tab(text: '退款管理'),
            ],
          ),
        ),
        body: _ErrorView(
          title: '載入訂單失敗',
          message: _error!,
          hint: '常見原因：需要 Firestore 複合索引（status + createdAt）。\n請依錯誤訊息中的索引建立連結到 Firebase Console 建立索引。',
          onRetry: () => _load(reset: true),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final visible = _visibleRows;

    final sum = visible.fold<num>(0, (p, r) => p + _toNum(r.data['finalAmount'] ?? r.data['total']));
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('出貨 / 退款工作台', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(tooltip: '重新整理', onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh)),
          IconButton(tooltip: '匯出目前可見 CSV', onPressed: _exportVisibleCsv, icon: const Icon(Icons.download)),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '出貨管理'),
            Tab(text: '退款管理'),
          ],
        ),
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
                    _miniStat('模式', _tab.index == 0 ? '出貨' : '退款'),
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
                      const Text('匯出結果', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text(_exportResult!, style: TextStyle(color: cs.onSurfaceVariant)),
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
                    '提示：尚未上架或尚未建立測試訂單時，沒有數字是正常狀況。',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              ...visible.map(_orderTile).toList(),

            const SizedBox(height: 12),

            if (_hasMore)
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: _loadingMore ? null : _loadMore,
                  icon: _loadingMore
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
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
    final rangeText = _range == null ? '未設定' : '${fmt.format(_range!.start)} - ${fmt.format(_range!.end)}';

    final isShippingTab = _tab.index == 0;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isShippingTab ? '出貨篩選與搜尋' : '退款篩選與搜尋',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),

            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isShippingTab ? '出貨狀態：' : '退款狀態：', style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: isShippingTab ? _shippingStatus : _refundStatus,
                      items: isShippingTab
                          ? const [
                              DropdownMenuItem(value: 'shipping_todo', child: Text('待出貨（paid/processing）')),
                              DropdownMenuItem(value: 'shipping_in_progress', child: Text('出貨中（shipping）')),
                              DropdownMenuItem(value: 'shipped', child: Text('已出貨（shipped）')),
                              DropdownMenuItem(value: 'delivered', child: Text('已送達（delivered/completed）')),
                              DropdownMenuItem(value: 'all', child: Text('全部')),
                            ]
                          : const [
                              DropdownMenuItem(value: 'refund_requested', child: Text('待處理（refund_requested）')),
                              DropdownMenuItem(value: 'refunding', child: Text('退款中（refunding）')),
                              DropdownMenuItem(value: 'refunded', child: Text('已退款（refunded）')),
                              DropdownMenuItem(value: 'refund_rejected', child: Text('已駁回（refund_rejected）')),
                              DropdownMenuItem(value: 'all', child: Text('全部')),
                            ],
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() {
                          if (isShippingTab) {
                            _shippingStatus = v;
                          } else {
                            _refundStatus = v;
                          }
                        });
                        await _load(reset: true);
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('日期區間：', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(rangeText),
                    ),
                    if (_range != null) ...[
                      const SizedBox(width: 8),
                      TextButton(onPressed: _clearRange, child: const Text('清除')),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '本頁關鍵字搜尋（docId/orderId/email/姓名/電話/status/物流單號）',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              '提示：此頁的搜尋為「本頁已載入列表」過濾；若要做跨全庫精準查詢，建議另外做查詢頁或新增索引。',
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
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
      ],
    );
  }

  Widget _orderTile(_OrderRow row) {
    final d = row.data;
    final cs = Theme.of(context).colorScheme;
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

    final status = (d['status'] ?? '').toString();
    final createdAt = _toDateTime(d['createdAt']);
    final createdText = createdAt == null ? '-' : DateFormat('yyyy/MM/dd HH:mm').format(createdAt);

    final amount = _toNum(d['finalAmount'] ?? d['total']);
    final customer = (d['customerName'] ?? d['userName'] ?? d['displayName'] ?? '').toString();
    final email = (d['customerEmail'] ?? d['userEmail'] ?? '').toString();

    final shipping = _readShipping(d);
    final refund = _readRefund(d);

    final isShippingTab = _tab.index == 0;

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
                    'Order：${(d['orderId'] ?? row.id).toString()}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: cs.primaryContainer,
                  ),
                  child: Text(
                    status.isEmpty ? 'unknown' : status,
                    style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w900, fontSize: 12),
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

            if (isShippingTab) ...[
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _kv('物流商', (shipping['carrier'] ?? '').toString().isEmpty ? '-' : (shipping['carrier'] ?? '').toString()),
                  _kv('單號', (shipping['trackingNo'] ?? '').toString().isEmpty ? '-' : (shipping['trackingNo'] ?? '').toString()),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _openShippingDialog(row),
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('填寫物流/標記出貨'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _markDelivered(row),
                    icon: const Icon(Icons.task_alt),
                    label: const Text('標記送達'),
                  ),
                  TextButton(
                    onPressed: () => _openOrderDetail(row.id),
                    child: const Text('查看訂單詳情'),
                  ),
                ],
              ),
            ] else ...[
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _kv('退款狀態', (refund['status'] ?? '').toString().isEmpty ? '-' : (refund['status'] ?? '').toString()),
                  _kv('退款金額', _toNum(refund['amount']).toString()),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _approveRefund(row),
                    icon: const Icon(Icons.approval),
                    label: const Text('同意退款'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _markRefunded(row),
                    icon: const Icon(Icons.verified),
                    label: const Text('退款完成'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _rejectRefund(row),
                    icon: Icon(Icons.block, color: cs.error),
                    label: Text('駁回', style: TextStyle(color: cs.error)),
                  ),
                  TextButton(
                    onPressed: () => _openOrderDetail(row.id),
                    child: const Text('查看訂單詳情'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$k：', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
        Text(v, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  // ===========================================================================
  // Route helper
  // ===========================================================================
  void _openOrderDetail(String orderDocId) {
    try {
      Navigator.pushNamed(context, '/admin/orders/detail', arguments: orderDocId);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('尚未註冊 /admin/orders/detail 路由（請確認 main.dart onGenerateRoute）'),
      ));
    }
  }

  // ===========================================================================
  // Utils
  // ===========================================================================
  Map<String, dynamic> _readShipping(Map<String, dynamic> d) {
    final s = d['shipping'];
    if (s is Map<String, dynamic>) return s;
    if (s is Map) return Map<String, dynamic>.from(s);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _readRefund(Map<String, dynamic> d) {
    final r = d['refund'];
    if (r is Map<String, dynamic>) return r;
    if (r is Map) return Map<String, dynamic>.from(r);
    return <String, dynamic>{};
  }

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    try {
      final dynamic d = v;
      final dt = d.toDate();
      if (dt is DateTime) return dt;
      return null;
    } catch (_) {
      return null;
    }
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '0') ?? 0;
  }

  Future<bool?> _confirm({required String title, required String message, required String confirmText}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmText)),
        ],
      ),
    );
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
// Dialogs - Shipping
// =============================================================================
class _ShippingInput {
  final String carrier;
  final String trackingNo;
  final String trackingUrl;
  final String note;

  const _ShippingInput({
    required this.carrier,
    required this.trackingNo,
    required this.trackingUrl,
    required this.note,
  });
}

class _ShippingDialog extends StatefulWidget {
  final String orderDocId;
  final String orderId;

  final String initialCarrier;
  final String initialTrackingNo;
  final String initialTrackingUrl;
  final String initialNote;

  const _ShippingDialog({
    required this.orderDocId,
    required this.orderId,
    required this.initialCarrier,
    required this.initialTrackingNo,
    required this.initialTrackingUrl,
    required this.initialNote,
  });

  @override
  State<_ShippingDialog> createState() => _ShippingDialogState();
}

class _ShippingDialogState extends State<_ShippingDialog> {
  late final TextEditingController _carrier;
  late final TextEditingController _no;
  late final TextEditingController _url;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _carrier = TextEditingController(text: widget.initialCarrier);
    _no = TextEditingController(text: widget.initialTrackingNo);
    _url = TextEditingController(text: widget.initialTrackingUrl);
    _note = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _carrier.dispose();
    _no.dispose();
    _url.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('填寫物流資訊', style: TextStyle(fontWeight: FontWeight.w900)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_carrier, '物流商（carrier）', hint: '例如：黑貓/新竹物流/郵局'),
            const SizedBox(height: 10),
            _field(_no, '物流單號（trackingNo）', hint: '例如：1234567890'),
            const SizedBox(height: 10),
            _field(_url, '追蹤網址（trackingUrl）', hint: '可留空'),
            const SizedBox(height: 10),
            _field(_note, '備註（note）', hint: '可留空', maxLines: 2),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Order：${widget.orderId}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(
              context,
              _ShippingInput(
                carrier: _carrier.text.trim(),
                trackingNo: _no.text.trim(),
                trackingUrl: _url.text.trim(),
                note: _note.text.trim(),
              ),
            );
          },
          icon: const Icon(Icons.check),
          label: const Text('保存並標記出貨'),
        )
      ],
    );
  }

  Widget _field(TextEditingController c, String label, {String? hint, int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// =============================================================================
// Dialogs - Refund
// =============================================================================
enum _RefundDialogMode { approve, reject }

class _RefundInput {
  final double amount;
  final String reason;
  final String note;

  const _RefundInput({required this.amount, required this.reason, required this.note});
}

class _RefundDialog extends StatefulWidget {
  final String orderDocId;
  final String orderId;

  final double initialAmount;
  final String initialReason;
  final String initialNote;

  final _RefundDialogMode mode;

  const _RefundDialog({
    required this.orderDocId,
    required this.orderId,
    required this.initialAmount,
    required this.initialReason,
    required this.initialNote,
    required this.mode,
  });

  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  late final TextEditingController _amount;
  late final TextEditingController _reason;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: widget.initialAmount.toStringAsFixed(0));
    _reason = TextEditingController(text: widget.initialReason);
    _note = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReject = widget.mode == _RefundDialogMode.reject;

    return AlertDialog(
      title: Text(isReject ? '駁回退款' : '同意退款', style: const TextStyle(fontWeight: FontWeight.w900)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isReject) ...[
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '退款金額（amount）',
                  hintText: '例如：1990',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reason,
                decoration: InputDecoration(
                  labelText: '原因（reason）',
                  hintText: '可留空',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: '備註（note）',
                hintText: isReject ? '請填寫駁回原因（建議）' : '可留空',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Order：${widget.orderId}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
        FilledButton.icon(
          onPressed: () {
            final amount = double.tryParse(_amount.text.trim()) ?? 0;
            Navigator.pop(
              context,
              _RefundInput(
                amount: amount,
                reason: _reason.text.trim(),
                note: _note.text.trim(),
              ),
            );
          },
          icon: const Icon(Icons.check),
          label: Text(isReject ? '確認駁回' : '確認同意'),
        )
      ],
    );
  }
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
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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
