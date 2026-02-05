// lib/pages/admin/orders/admin_orders_batch_ops_page.dart
//
// ✅ AdminOrdersBatchOpsPage（訂單批次操作｜完整版｜可直接編譯）
// -----------------------------------------------------------------------------
// 功能：
// - 分頁載入 orders
// - 篩選：status（all/pending/paid/shipping/completed/cancelled/refunded）
// - 日期區間：createdAt 範圍
// - 搜尋：列表內關鍵字過濾（local filter）
// - 勾選多筆訂單（含本頁全選）
// - 批次操作：
//    1) 批次更新 status
//    2) 批次設定出貨資訊（carrier + trackingNo + shippedAt）
//    3) 批次更新 refundStatus（pending/approved/rejected/completed）
//    4) 匯出已選訂單 CSV（跨平台：Web 下載 / App 桌面寫檔）
//
// 依賴：
// - cloud_firestore
// - intl
// - csv
// - 你的 utils/report_file_saver.dart（需提供 saveReportBytes）
//
// 資料欄位（容錯）：
// - createdAt (Timestamp)  ※建議必備，否則 orderBy 會報錯
// - status (String)
// - finalAmount (num)
// - userEmail/userName/phone
// - shippingCarrier/trackingNo/shippedAt
// - refundStatus
// -----------------------------------------------------------------------------

import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:osmile_admin/utils/report_file_saver.dart';

class AdminOrdersBatchOpsPage extends StatefulWidget {
  const AdminOrdersBatchOpsPage({super.key});

  @override
  State<AdminOrdersBatchOpsPage> createState() => _AdminOrdersBatchOpsPageState();
}

class _AdminOrdersBatchOpsPageState extends State<AdminOrdersBatchOpsPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Filters
  String _status = 'all';
  DateTimeRange? _range;
  final TextEditingController _searchCtrl = TextEditingController();
  String _localKeyword = '';

  // Loading / Error
  bool _loading = true;
  String? _error;

  // Pagination
  static const int _pageSize = 30;
  final List<_OrderRow> _rows = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _loadingMore = false;

  // Selection
  final Set<String> _selected = {};
  bool _selectAllOnPage = false;

  // Export result (optional display)
  String? _exportResult;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // =============================================================================
  // Query builder
  // =============================================================================
  Query<Map<String, dynamic>> _baseQuery() {
    Query<Map<String, dynamic>> q = _db.collection('orders');

    // status filter
    if (_status != 'all') {
      q = q.where('status', isEqualTo: _status);
    }

    // createdAt range filter (requires orderBy createdAt)
    final r = _range;
    if (r != null) {
      q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(r.start));
      q = q.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(r.end));
    }

    // orderBy (needs createdAt field exist)
    q = q.orderBy('createdAt', descending: true);

    return q;
  }

  // =============================================================================
  // Load
  // =============================================================================
  Future<void> _load({required bool reset}) async {
    if (!mounted) return;

    setState(() {
      if (reset) _loading = true;
      _error = null;
      if (reset) {
        _rows.clear();
        _lastDoc = null;
        _hasMore = true;
        _selected.clear();
        _selectAllOnPage = false;
        _exportResult = null;
      }
    });

    try {
      Query<Map<String, dynamic>> q = _baseQuery();
      if (!reset && _lastDoc != null) {
        q = q.startAfterDocument(_lastDoc!);
      }

      final snap = await q.limit(_pageSize).get();
      final docs = snap.docs;

      final pageRows = docs
          .map((d) => _OrderRow(
                id: d.id,
                data: d.data(),
              ))
          .toList();

      final last = docs.isEmpty ? _lastDoc : docs.last;

      if (!mounted) return;
      setState(() {
        _rows.addAll(pageRows);
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

  // =============================================================================
  // Filters UI actions
  // =============================================================================
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

  void _applyLocalSearch() {
    setState(() {
      _localKeyword = _searchCtrl.text.trim().toLowerCase();
    });
  }

  void _clearLocalSearch() {
    _searchCtrl.clear();
    setState(() => _localKeyword = '');
  }

  // =============================================================================
  // Selection helpers
  // =============================================================================
  List<_OrderRow> get _visibleRows {
    final kw = _localKeyword;
    if (kw.isEmpty) return _rows;

    bool hit(_OrderRow r) {
      final id = r.id.toLowerCase();
      final status = (r.data['status'] ?? '').toString().toLowerCase();
      final email = (r.data['userEmail'] ?? r.data['email'] ?? '').toString().toLowerCase();
      final name = (r.data['userName'] ?? r.data['displayName'] ?? '').toString().toLowerCase();
      final phone = (r.data['phone'] ?? r.data['userPhone'] ?? '').toString().toLowerCase();
      final tracking = (r.data['trackingNo'] ?? '').toString().toLowerCase();
      final carrier = (r.data['shippingCarrier'] ?? '').toString().toLowerCase();

      return id.contains(kw) ||
          status.contains(kw) ||
          email.contains(kw) ||
          name.contains(kw) ||
          phone.contains(kw) ||
          tracking.contains(kw) ||
          carrier.contains(kw);
    }

    return _rows.where(hit).toList();
  }

  void _toggleSelectAllOnPage(bool v) {
    final pageIds = _visibleRows.map((e) => e.id).toList();
    setState(() {
      _selectAllOnPage = v;
      if (v) {
        _selected.addAll(pageIds);
      } else {
        _selected.removeAll(pageIds);
      }
    });
  }

  void _toggleOne(String id, bool v) {
    setState(() {
      if (v) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }

      // recompute selectAllOnPage
      final pageIds = _visibleRows.map((e) => e.id).toSet();
      _selectAllOnPage = pageIds.isNotEmpty && pageIds.every((x) => _selected.contains(x));
    });
  }

  void _clearSelection() {
    setState(() {
      _selected.clear();
      _selectAllOnPage = false;
    });
  }

  // =============================================================================
  // Batch operations
  // =============================================================================
  Future<void> _batchUpdateStatus() async {
    if (_selected.isEmpty) return;

    final newStatus = await _pickOne(
      title: '批次更新訂單狀態',
      items: const [
        'pending',
        'paid',
        'shipping',
        'completed',
        'cancelled',
        'refunded',
      ],
      labelOf: (s) => s,
    );
    if (newStatus == null) return;

    final ok = await _confirm(
      title: '確認更新',
      message: '將 ${_selected.length} 筆訂單 status 更新為 "$newStatus"？',
      confirmText: '更新',
    );
    if (!ok) return;

    await _runWriteBatches(
      ids: _selected.toList(),
      dataOf: () => {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      successMsg: '已更新狀態',
    );
  }

  Future<void> _batchSetShipping() async {
    if (_selected.isEmpty) return;

    final carrierCtrl = TextEditingController();
    final trackingCtrl = TextEditingController();

    final res = await showDialog<_ShippingInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('批次設定出貨資訊', style: TextStyle(fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: carrierCtrl,
                decoration: InputDecoration(
                  labelText: '物流商（shippingCarrier）',
                  hintText: '例如：黑貓 / 新竹 / 郵局 / 宅配',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: trackingCtrl,
                decoration: InputDecoration(
                  labelText: '追蹤碼（trackingNo）',
                  hintText: '可留空（若你要稍後再補）',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '備註：同時會寫入 shippedAt（serverTimestamp）。\n'
                  '如你希望批次一併把 status 改 shipping，可先用「批次更新狀態」。',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _ShippingInput(
                carrier: carrierCtrl.text.trim(),
                trackingNo: trackingCtrl.text.trim(),
              ),
            ),
            child: const Text('套用'),
          ),
        ],
      ),
    );

    if (res == null) return;

    await _runWriteBatches(
      ids: _selected.toList(),
      dataOf: () => {
        if (res.carrier.isNotEmpty) 'shippingCarrier': res.carrier,
        if (res.trackingNo.isNotEmpty) 'trackingNo': res.trackingNo,
        'shippedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      successMsg: '已更新出貨資訊',
    );
  }

  Future<void> _batchUpdateRefundStatus() async {
    if (_selected.isEmpty) return;

    final newStatus = await _pickOne(
      title: '批次更新 refundStatus',
      items: const [
        'pending',
        'approved',
        'rejected',
        'completed',
      ],
      labelOf: (s) => s,
    );
    if (newStatus == null) return;

    final ok = await _confirm(
      title: '確認更新',
      message: '將 ${_selected.length} 筆訂單 refundStatus 更新為 "$newStatus"？',
      confirmText: '更新',
    );
    if (!ok) return;

    await _runWriteBatches(
      ids: _selected.toList(),
      dataOf: () => {
        'refundStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      successMsg: '已更新 refundStatus',
    );
  }

  Future<void> _runWriteBatches({
    required List<String> ids,
    required Map<String, dynamic> Function() dataOf,
    required String successMsg,
  }) async {
    if (!mounted) return;

    // Firestore batch limit: 500 writes per batch
    const chunkSize = 450;
    final chunks = <List<String>>[];
    for (int i = 0; i < ids.length; i += chunkSize) {
      chunks.add(ids.sublist(i, math.min(i + chunkSize, ids.length)));
    }

    _showBusyToast('處理中（${ids.length} 筆）...');

    try {
      for (final chunk in chunks) {
        final batch = _db.batch();
        for (final id in chunk) {
          final ref = _db.collection('orders').doc(id);
          batch.set(ref, dataOf(), SetOptions(merge: true));
        }
        await batch.commit();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg)));
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('批次操作失敗：$e')));
    }
  }

  // =============================================================================
  // Export CSV (selected)
  // =============================================================================
  Future<void> _exportSelectedCsv() async {
    if (_selected.isEmpty) return;

    // Fetch docs by ids in small whereIn chunks (safe for Firestore whereIn limits)
    final ids = _selected.toList();
    final fetched = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    _showBusyToast('匯出中（抓取資料）...');

    try {
      const whereInLimit = 10;
      for (int i = 0; i < ids.length; i += whereInLimit) {
        final chunk = ids.sublist(i, math.min(i + whereInLimit, ids.length));
        final snap = await _db
            .collection('orders')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        fetched.addAll(snap.docs);
      }

      // Map by docId for stable ordering by selection list
      final map = {for (final d in fetched) d.id: d.data()};
      final rows = <Map<String, dynamic>>[];
      for (final id in ids) {
        rows.add(map[id] ?? <String, dynamic>{});
      }

      final bytes = _buildSelectedCsv(ids: ids, rows: rows);

      final now = DateTime.now();
      final filename = 'orders_selected_${DateFormat('yyyyMMdd_HHmm').format(now)}.csv';
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

  List<int> _buildSelectedCsv({
    required List<String> ids,
    required List<Map<String, dynamic>> rows,
  }) {
    final csvData = <List<dynamic>>[];

    // headers
    csvData.add([
      'orderId',
      'createdAt',
      'status',
      'finalAmount',
      'userEmail',
      'userName',
      'phone',
      'shippingCarrier',
      'trackingNo',
      'refundStatus',
    ]);

    String fmtDate(dynamic v) {
      if (v is Timestamp) {
        return DateFormat('yyyy-MM-dd HH:mm').format(v.toDate());
      }
      return '';
    }

    dynamic safe(Map<String, dynamic> m, String k) => m[k];

    for (int i = 0; i < ids.length; i++) {
      final id = ids[i];
      final m = rows.length > i ? rows[i] : <String, dynamic>{};

      csvData.add([
        (safe(m, 'orderId') ?? id).toString(),
        fmtDate(safe(m, 'createdAt')),
        (safe(m, 'status') ?? '').toString(),
        (safe(m, 'finalAmount') ?? 0).toString(),
        (safe(m, 'userEmail') ?? safe(m, 'email') ?? '').toString(),
        (safe(m, 'userName') ?? safe(m, 'displayName') ?? '').toString(),
        (safe(m, 'phone') ?? safe(m, 'userPhone') ?? '').toString(),
        (safe(m, 'shippingCarrier') ?? '').toString(),
        (safe(m, 'trackingNo') ?? '').toString(),
        (safe(m, 'refundStatus') ?? '').toString(),
      ]);
    }

    final csvString = const ListToCsvConverter().convert(csvData);
    return utf8.encode('\uFEFF$csvString'); // BOM for Excel
  }

  // =============================================================================
  // UI
  // =============================================================================
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('訂單批次操作', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [IconButton(onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh))],
        ),
        body: _ErrorView(
          title: '載入訂單失敗',
          message: _error!,
          hint: '常見原因：orders 缺少 createdAt 欄位導致 orderBy 失敗、或需要建立複合索引。',
          onRetry: () => _load(reset: true),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final visible = _visibleRows;

    return Scaffold(
      appBar: AppBar(
        title: const Text('訂單批次操作', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(tooltip: '重新整理', onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _filtersCard(cs),
            const SizedBox(height: 12),
            _selectionBar(cs, visibleCount: visible.length),
            const SizedBox(height: 12),

            if (_exportResult != null) _exportResultCard(cs),
            if (_exportResult != null) const SizedBox(height: 12),

            if (visible.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _localKeyword.isNotEmpty
                        ? '沒有符合關鍵字的訂單。'
                        : '目前沒有符合條件的訂單。\n\n提示：尚未上架或尚未建立測試訂單時沒有數字是正常狀況。',
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

            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _selected.isEmpty ? null : _batchActionBar(cs),
    );
  }

  Widget _filtersCard(ColorScheme cs) {
    final fmt = DateFormat('yyyy/MM/dd');
    final rangeText = _range == null ? '未設定' : '${fmt.format(_range!.start)} - ${fmt.format(_range!.end)}';

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('篩選與搜尋', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),

            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('狀態：', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _status,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('全部')),
                        DropdownMenuItem(value: 'pending', child: Text('pending')),
                        DropdownMenuItem(value: 'paid', child: Text('paid')),
                        DropdownMenuItem(value: 'shipping', child: Text('shipping')),
                        DropdownMenuItem(value: 'completed', child: Text('completed')),
                        DropdownMenuItem(value: 'cancelled', child: Text('cancelled')),
                        DropdownMenuItem(value: 'refunded', child: Text('refunded')),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() => _status = v);
                        await _load(reset: true);
                      },
                    ),
                  ],
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('日期：', style: TextStyle(fontWeight: FontWeight.w900)),
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

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _applyLocalSearch(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '列表內搜尋（orderId / email / name / phone / status / tracking）',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: _searchCtrl.text.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清除',
                              onPressed: () {
                                _clearLocalSearch();
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _applyLocalSearch,
                  icon: const Icon(Icons.filter_alt),
                  label: const Text('套用'),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Text(
              '提示：此搜尋為「本頁已載入清單」過濾，不是全庫搜尋。要全庫查請用訂單詳情或訂單列表頁的精準查。',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectionBar(ColorScheme cs, {required int visibleCount}) {
    final pageIds = _visibleRows.map((e) => e.id).toSet();
    final selectedOnPage = pageIds.where((x) => _selected.contains(x)).length;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Checkbox(
              value: _selectAllOnPage,
              onChanged: (v) => _toggleSelectAllOnPage(v ?? false),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '本頁可見 $visibleCount 筆｜本頁已選 $selectedOnPage 筆｜總已選 ${_selected.length} 筆',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            TextButton.icon(
              onPressed: _selected.isEmpty ? null : _clearSelection,
              icon: const Icon(Icons.clear),
              label: const Text('清空選取'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderTile(_OrderRow row) {
    final cs = Theme.of(context).colorScheme;
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

    final createdAt = row.data['createdAt'];
    String createdText = '-';
    if (createdAt is Timestamp) {
      createdText = DateFormat('yyyy/MM/dd HH:mm').format(createdAt.toDate());
    }

    final status = (row.data['status'] ?? '').toString();
    final amount = row.data['finalAmount'];
    final amountNum = (amount is num) ? amount : num.tryParse(amount?.toString() ?? '0') ?? 0;

    final email = (row.data['userEmail'] ?? row.data['email'] ?? '').toString();
    final name = (row.data['userName'] ?? row.data['displayName'] ?? '').toString();
    final phone = (row.data['phone'] ?? row.data['userPhone'] ?? '').toString();

    final carrier = (row.data['shippingCarrier'] ?? '').toString();
    final tracking = (row.data['trackingNo'] ?? '').toString();
    final refundStatus = (row.data['refundStatus'] ?? '').toString();

    final isSelected = _selected.contains(row.id);

    Color chipColor;
    if (status == 'pending') chipColor = Colors.orange;
    else if (status == 'paid') chipColor = Colors.blue;
    else if (status == 'shipping') chipColor = Colors.purple;
    else if (status == 'completed') chipColor = Colors.green;
    else if (status == 'cancelled') chipColor = cs.error;
    else chipColor = Colors.grey;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _toggleOne(row.id, !isSelected),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header
              Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (v) => _toggleOne(row.id, v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'Order：${(row.data['orderId'] ?? row.id).toString()}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: chipColor.withValues(alpha: 0.12),
                    ),
                    child: Text(
                      status.isEmpty ? 'unknown' : status,
                      style: TextStyle(color: chipColor, fontWeight: FontWeight.w900, fontSize: 12),
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
                  _kv('金額', fmtMoney.format(amountNum)),
                  _kv('Email', email.isEmpty ? '-' : email),
                  _kv('姓名', name.isEmpty ? '-' : name),
                  _kv('電話', phone.isEmpty ? '-' : phone),
                ],
              ),

              const SizedBox(height: 8),

              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _kv('物流', carrier.isEmpty ? '-' : carrier),
                  _kv('追蹤碼', tracking.isEmpty ? '-' : tracking),
                  _kv('refundStatus', refundStatus.isEmpty ? '-' : refundStatus),
                ],
              ),

              const Divider(height: 18),

              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _goOrderDetail(row),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('開啟詳情'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final text = (row.data['orderId'] ?? row.id).toString();
                      await Clipboard.setData(ClipboardData(text: text));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製')));
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('複製編號'),
                  ),
                ],
              ),
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
        Text('$k：', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
        Text(v, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _batchActionBar(ColorScheme cs) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('已選 ${_selected.length} 筆', style: const TextStyle(fontWeight: FontWeight.w900)),
            FilledButton.tonalIcon(
              onPressed: _batchUpdateStatus,
              icon: const Icon(Icons.sync_alt),
              label: const Text('批次改狀態'),
            ),
            FilledButton.tonalIcon(
              onPressed: _batchSetShipping,
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('批次出貨資訊'),
            ),
            FilledButton.tonalIcon(
              onPressed: _batchUpdateRefundStatus,
              icon: const Icon(Icons.money_off_csred_outlined),
              label: const Text('批次 refundStatus'),
            ),
            OutlinedButton.icon(
              onPressed: _exportSelectedCsv,
              icon: const Icon(Icons.download),
              label: const Text('匯出已選 CSV'),
            ),
            TextButton.icon(
              onPressed: _clearSelection,
              icon: const Icon(Icons.clear),
              label: const Text('清空'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportResultCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('匯出結果', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(_exportResult ?? '-', style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  void _goOrderDetail(_OrderRow row) {
    final id = (row.data['orderId'] ?? row.id).toString();
    Navigator.pushNamed(context, '/admin/orders/detail', arguments: id);
  }

  // =============================================================================
  // Dialog utils
  // =============================================================================
  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final res = await showDialog<bool>(
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
    return res ?? false;
  }

  Future<String?> _pickOne({
    required String title,
    required List<String> items,
    required String Function(String) labelOf,
  }) async {
    String value = items.first;
    final res = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(labelOf(e)))).toList(),
          onChanged: (v) => value = v ?? value,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, value), child: const Text('確定')),
        ],
      ),
    );
    return res;
  }

  void _showBusyToast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 1)),
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

class _ShippingInput {
  final String carrier;
  final String trackingNo;

  _ShippingInput({required this.carrier, required this.trackingNo});
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
