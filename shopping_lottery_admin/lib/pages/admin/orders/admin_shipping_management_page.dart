// lib/pages/admin/orders/admin_shipping_management_page.dart
//
// ✅ AdminShippingManagementPage（出貨管理｜完整版｜可直接編譯）
// -----------------------------------------------------------------------------
// 功能：
// - 訂單出貨管理（以 orders 為主資料源）
// - 篩選：狀態、日期區間（createdAt）、只看未填追蹤碼
// - 搜尋：orderId 精準查詢（避免 Firestore contains 限制）
// - 出貨編輯：物流商、追蹤碼、出貨日、備註、出貨狀態（會同步更新 order.status）
// - 可導向訂單詳情：/admin/orders/detail（arguments 帶 {id: orderDocId}）
//
// Firestore 假設（你可以依你的 schema 微調欄位名稱）：
// - orders/{docId}
//   - status: String
//   - createdAt: Timestamp
//   - finalAmount: num
//   - customerName/userName/displayName: String?
//   - items: List<Map>?
//   - shipping: Map<String,dynamic>?
//       - carrier: String?
//       - trackingNo: String?
//       - shippedAt: Timestamp?
//       - deliveredAt: Timestamp?
//       - note: String?
//       - status: String?  (shipped/delivered/cancelled)
//       - updatedAt: serverTimestamp
//
// ⚠️ 索引提醒：
// - 若你同時用 where(status==...) + where(createdAt 範圍) + orderBy(createdAt)
//   Firestore 常需要複合索引（UI 內會提示）
// -----------------------------------------------------------------------------

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminShippingManagementPage extends StatefulWidget {
  const AdminShippingManagementPage({super.key});

  @override
  State<AdminShippingManagementPage> createState() => _AdminShippingManagementPageState();
}

class _AdminShippingManagementPageState extends State<AdminShippingManagementPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // -----------------------------
  // UI State
  // -----------------------------
  bool _loading = true;
  String? _error;

  // filters
  String _statusFilter = 'all'; // all / paid / shipping / completed / cancelled / refunded ...
  DateTimeRange? _dateRange; // createdAt range
  bool _onlyMissingTracking = false;

  // search (exact)
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchOrderId = '';

  // data + pagination
  final List<_OrderRow> _rows = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _loadingMore = false;
  bool _hasMore = true;

  static const int _pageSize = 30;

  // status options (可依你系統實際狀態調整/增減)
  static const List<String> _statusOptions = [
    'all',
    'paid',
    'shipping',
    'completed',
    'cancelled',
    'refunded',
  ];

  // shipping sub-status options (寫在 shipping.status)
  static const List<String> _shippingStatusOptions = [
    'shipped',
    'delivered',
    'cancelled',
  ];

  // carrier presets
  static const List<String> _carrierPresets = [
    '黑貓宅急便',
    '7-11',
    '全家',
    '郵局',
    '新竹物流',
    '其他',
  ];

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
  // Data Loading
  // =============================================================================
  Future<void> _load({required bool reset}) async {
    if (!mounted) return;

    setState(() {
      _loading = reset ? true : _loading;
      _error = null;
      if (reset) {
        _rows.clear();
        _lastDoc = null;
        _hasMore = true;
      }
    });

    try {
      final fetched = await _fetchOrdersPage(
        limit: _pageSize,
        startAfter: reset ? null : _lastDoc,
      );

      if (!mounted) return;

      setState(() {
        _rows.addAll(fetched.rows);
        _lastDoc = fetched.lastDoc;
        _hasMore = fetched.hasMore;
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

  Future<_PagedOrders> _fetchOrdersPage({
    required int limit,
    required DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> q = _db.collection('orders');

    // status filter
    if (_statusFilter != 'all') {
      q = q.where('status', isEqualTo: _statusFilter);
    }

    // date range filter (createdAt)
    if (_dateRange != null) {
      final start = Timestamp.fromDate(_floorToStartOfDay(_dateRange!.start));
      final end = Timestamp.fromDate(_ceilToEndOfDay(_dateRange!.end));
      q = q.where('createdAt', isGreaterThanOrEqualTo: start).where('createdAt', isLessThanOrEqualTo: end);
    }

    // search exact orderId
    final search = _searchOrderId.trim();
    if (search.isNotEmpty) {
      // 如果你的 orderId 是 docId，也可以改成查 docId（本頁仍以 orderId 欄位優先）
      q = q.where('orderId', isEqualTo: search);
    }

    // sorting
    // ⚠️ 若同時有 status + createdAt range，Firestore 可能要求複合索引
    q = q.orderBy('createdAt', descending: true);

    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snap = await q.limit(limit).get();

    final docs = snap.docs;
    final rows = docs.map((d) => _OrderRow(id: d.id, data: d.data())).toList();

    // client-side filter: onlyMissingTracking
    final filteredRows = _onlyMissingTracking
        ? rows.where((r) {
            final shipping = _readMap(r.data['shipping']);
            final tracking = (shipping?['trackingNo'] ?? '').toString().trim();
            return tracking.isEmpty;
          }).toList()
        : rows;

    final lastDoc = docs.isEmpty ? startAfter : docs.last;
    final hasMore = docs.length == limit;

    return _PagedOrders(rows: filteredRows, lastDoc: lastDoc, hasMore: hasMore);
  }

  // =============================================================================
  // UI Actions
  // =============================================================================
  Future<void> _onRefresh() => _load(reset: true);

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial = _dateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      helpText: '選擇訂單建立日期區間',
      confirmText: '套用',
      cancelText: '取消',
    );
    if (picked == null) return;

    setState(() => _dateRange = picked);
    await _load(reset: true);
  }

  Future<void> _clearDateRange() async {
    setState(() => _dateRange = null);
    await _load(reset: true);
  }

  Future<void> _applySearch() async {
    setState(() => _searchOrderId = _searchCtrl.text.trim());
    await _load(reset: true);
  }

  Future<void> _clearSearch() async {
    _searchCtrl.clear();
    setState(() => _searchOrderId = '');
    await _load(reset: true);
  }

  Future<void> _editShipping(_OrderRow row) async {
    final initial = _ShippingFormState.fromOrder(row);

    final result = await showModalBottomSheet<_ShippingFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ShippingEditSheet(
        initial: initial,
        carrierPresets: _carrierPresets,
        shippingStatusOptions: _shippingStatusOptions,
      ),
    );

    if (result == null) return;

    try {
      await _saveShippingToOrder(
        orderDocId: row.id,
        orderData: row.data,
        result: result,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('出貨資訊已更新')));

      // reload list (保守：避免本地 patch 欄位漏掉)
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  Future<void> _saveShippingToOrder({
    required String orderDocId,
    required Map<String, dynamic> orderData,
    required _ShippingFormResult result,
  }) async {
    final orderRef = _db.collection('orders').doc(orderDocId);

    // 你可以依自己狀態規則調整：
    // - 若填了 trackingNo → order.status 設為 shipping
    // - 若 shipping.status == delivered → order.status 可設 completed
    // - 若 shipping.status == cancelled → 不強制改 order.status（或改 cancelled）
    String? newOrderStatus;

    final hasTracking = result.trackingNo.trim().isNotEmpty;
    final shippingStatus = result.shippingStatus.trim();

    if (shippingStatus == 'delivered') {
      newOrderStatus = 'completed';
    } else if (shippingStatus == 'cancelled') {
      // 視你的業務規則，這裡可改成 'cancelled' 或不改
      // newOrderStatus = 'cancelled';
      newOrderStatus = null;
    } else {
      // shipped
      if (hasTracking) newOrderStatus = 'shipping';
    }

    final shippingMap = <String, dynamic>{
      'carrier': result.carrier.trim(),
      'trackingNo': result.trackingNo.trim(),
      'shippedAt': result.shippedAt == null ? null : Timestamp.fromDate(result.shippedAt!),
      'deliveredAt': result.deliveredAt == null ? null : Timestamp.fromDate(result.deliveredAt!),
      'note': result.note.trim(),
      'status': shippingStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final update = <String, dynamic>{
      'shipping': shippingMap,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (newOrderStatus != null && newOrderStatus.isNotEmpty) {
      update['status'] = newOrderStatus;
    }

    await orderRef.set(update, SetOptions(merge: true));
  }

  // =============================================================================
  // Build
  // =============================================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('出貨 / 物流管理', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh)),
          ],
        ),
        body: _ErrorView(
          title: '載入失敗',
          message: _error!,
          onRetry: () => _load(reset: true),
          hint: '常見原因：Firestore 權限不足、缺少複合索引（status + createdAt + orderBy createdAt）。',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('出貨 / 物流管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _filtersCard(cs),
            const SizedBox(height: 12),

            _summaryBar(cs),
            const SizedBox(height: 12),

            if (_rows.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '目前沒有符合條件的訂單。\n\n'
                    '提示：若你用了「狀態 + 日期區間」篩選，Firestore 可能要求建立索引；或確認 orders 有 createdAt (Timestamp) 與 status 欄位。',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              ..._rows.map(_orderCard).toList(),

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

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _filtersCard(ColorScheme cs) {
    final rangeText = _dateRange == null
        ? '未設定'
        : '${DateFormat('yyyy/MM/dd').format(_dateRange!.start)} - ${DateFormat('yyyy/MM/dd').format(_dateRange!.end)}';

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('篩選與搜尋', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),

            // status + date range
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _statusDropdown(cs),
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range),
                  label: Text('建立日期：$rangeText'),
                ),
                if (_dateRange != null)
                  TextButton(
                    onPressed: _clearDateRange,
                    child: const Text('清除日期'),
                  ),
                FilterChip(
                  label: const Text('只看未填追蹤碼'),
                  selected: _onlyMissingTracking,
                  onSelected: (v) async {
                    setState(() => _onlyMissingTracking = v);
                    await _load(reset: true);
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            // search
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.search),
                      hintText: '訂單編號 orderId（精準查詢）',
                      suffixIcon: _searchCtrl.text.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清除',
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _applySearch(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _applySearch,
                  icon: const Icon(Icons.search),
                  label: const Text('查詢'),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Text(
              '提示：Firestore 不支援 contains 搜尋，本頁採用 orderId 精準查詢以確保速度與可編譯性。',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusDropdown(ColorScheme cs) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _statusFilter,
        items: _statusOptions
            .map(
              (s) => DropdownMenuItem(
                value: s,
                child: Text(_statusLabel(s)),
              ),
            )
            .toList(),
        onChanged: (v) async {
          if (v == null) return;
          setState(() => _statusFilter = v);
          await _load(reset: true);
        },
      ),
    );
  }

  Widget _summaryBar(ColorScheme cs) {
    final total = _rows.length;

    final pending = _rows.where((r) => (r.data['status'] ?? '').toString() == 'paid').length;
    final shipping = _rows.where((r) => (r.data['status'] ?? '').toString() == 'shipping').length;
    final completed = _rows.where((r) => (r.data['status'] ?? '').toString() == 'completed').length;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _badge('筆數', '$total'),
            _badge('待出貨(paid)', '$pending'),
            _badge('出貨中(shipping)', '$shipping'),
            _badge('完成(completed)', '$completed'),
          ],
        ),
      ),
    );
  }

  Widget _badge(String title, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.black.withValues(alpha: 0.06),
          ),
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Widget _orderCard(_OrderRow row) {
    final cs = Theme.of(context).colorScheme;
    final createdAt = _readDate(row.data['createdAt']);
    final orderId = (row.data['orderId'] ?? row.id).toString();
    final status = (row.data['status'] ?? '').toString();
    final amount = _readNum(row.data['finalAmount']);

    final customer = (row.data['customerName'] ??
            row.data['userName'] ??
            row.data['displayName'] ??
            row.data['buyerName'] ??
            '')
        .toString();

    final shipping = _readMap(row.data['shipping']);
    final carrier = (shipping?['carrier'] ?? '').toString();
    final tracking = (shipping?['trackingNo'] ?? '').toString();
    final shippedAt = _readDate(shipping?['shippedAt']);
    final deliveredAt = _readDate(shipping?['deliveredAt']);
    final shipStatus = (shipping?['status'] ?? '').toString();

    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
    final createdText = createdAt == null ? '-' : DateFormat('yyyy/MM/dd HH:mm').format(createdAt);
    final shippedText = shippedAt == null ? '-' : DateFormat('yyyy/MM/dd').format(shippedAt);
    final deliveredText = deliveredAt == null ? '-' : DateFormat('yyyy/MM/dd').format(deliveredAt);

    final statusColor = _statusColor(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            Row(
              children: [
                Expanded(
                  child: Text(
                    '訂單：$orderId',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: statusColor.withValues(alpha: 0.12),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 12),
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
                _kv('金額', fmtMoney.format(amount)),
              ],
            ),

            const Divider(height: 18),

            // shipping info
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _kv('物流商', carrier.isEmpty ? '-' : carrier),
                _kv('追蹤碼', tracking.isEmpty ? '-' : tracking),
                _kv('出貨日', shippedText),
                _kv('送達日', deliveredText),
                _kv('出貨狀態', shipStatus.isEmpty ? '-' : shipStatus),
              ],
            ),

            const SizedBox(height: 10),

            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _editShipping(row),
                  icon: const Icon(Icons.local_shipping),
                  label: Text(tracking.isEmpty ? '設定出貨' : '編輯出貨'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _goOrderDetail(row.id),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('訂單詳情'),
                ),
                if (tracking.trim().isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: tracking.trim()));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('追蹤碼已複製')));
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('複製追蹤碼'),
                  ),
              ],
            ),

            const SizedBox(height: 6),
            Text(
              'docId：${row.id}',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
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
        Text('$k：', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
        Text(v, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  void _goOrderDetail(String orderDocId) {
    try {
      Navigator.pushNamed(
        context,
        '/admin/orders/detail',
        arguments: {'id': orderDocId},
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('尚未註冊 /admin/orders/detail 路由（請在 main.dart onGenerateRoute 加上）')),
      );
    }
  }

  // =============================================================================
  // Helpers
  // =============================================================================
  String _statusLabel(String s) {
    switch (s) {
      case 'all':
        return '全部';
      case 'paid':
        return '待出貨';
      case 'shipping':
        return '出貨中';
      case 'completed':
        return '已完成';
      case 'cancelled':
        return '已取消';
      case 'refunded':
        return '已退款';
      default:
        return s.isEmpty ? '-' : s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':
        return Colors.orange;
      case 'shipping':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'refunded':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Map<String, dynamic>? _readMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    return null;
  }

  num _readNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  DateTime? _readDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  DateTime _floorToStartOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 0, 0, 0);
  DateTime _ceilToEndOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);
}

// =============================================================================
// Bottom Sheet: Shipping Edit
// =============================================================================

class _ShippingEditSheet extends StatefulWidget {
  final _ShippingFormState initial;
  final List<String> carrierPresets;
  final List<String> shippingStatusOptions;

  const _ShippingEditSheet({
    required this.initial,
    required this.carrierPresets,
    required this.shippingStatusOptions,
  });

  @override
  State<_ShippingEditSheet> createState() => _ShippingEditSheetState();
}

class _ShippingEditSheetState extends State<_ShippingEditSheet> {
  final _formKey = GlobalKey<FormState>();

  late String _carrierPreset;
  late String _carrierCustom;
  late String _trackingNo;
  late DateTime? _shippedAt;
  late DateTime? _deliveredAt;
  late String _note;
  late String _shippingStatus;

  @override
  void initState() {
    super.initState();
    _carrierPreset = widget.initial.carrierPreset;
    _carrierCustom = widget.initial.carrierCustom;
    _trackingNo = widget.initial.trackingNo;
    _shippedAt = widget.initial.shippedAt;
    _deliveredAt = widget.initial.deliveredAt;
    _note = widget.initial.note;
    _shippingStatus = widget.initial.shippingStatus;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final cs = Theme.of(context).colorScheme;

    final carrier = _effectiveCarrier();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('設定 / 編輯出貨', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 10),
              Text('會同步更新 orders.shipping（必要時更新 order.status）', style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 14),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // carrier preset
                    DropdownButtonFormField<String>(
                      value: _carrierPreset,
                      items: widget.carrierPresets
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _carrierPreset = v ?? '其他'),
                      decoration: const InputDecoration(
                        labelText: '物流商（預設）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (_carrierPreset == '其他')
                      TextFormField(
                        initialValue: _carrierCustom,
                        decoration: const InputDecoration(
                          labelText: '物流商（自訂）',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => _carrierCustom = v,
                        validator: (v) {
                          if (_carrierPreset == '其他' && (v ?? '').trim().isEmpty) {
                            return '請填寫自訂物流商';
                          }
                          return null;
                        },
                      ),

                    if (_carrierPreset == '其他') const SizedBox(height: 10),

                    TextFormField(
                      initialValue: _trackingNo,
                      decoration: const InputDecoration(
                        labelText: '追蹤碼',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => _trackingNo = v,
                    ),
                    const SizedBox(height: 10),

                    // shipping status
                    DropdownButtonFormField<String>(
                      value: _shippingStatus,
                      items: widget.shippingStatusOptions
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _shippingStatus = v ?? 'shipped'),
                      decoration: const InputDecoration(
                        labelText: '出貨狀態（shipping.status）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // shippedAt
                    _dateRow(
                      title: '出貨日（shippedAt）',
                      value: _shippedAt,
                      onPick: () => _pickDate(
                        context: context,
                        initial: _shippedAt ?? DateTime.now(),
                        onSelected: (d) => setState(() => _shippedAt = d),
                      ),
                      onToday: () => setState(() => _shippedAt = DateTime.now()),
                      onClear: () => setState(() => _shippedAt = null),
                    ),
                    const SizedBox(height: 10),

                    // deliveredAt
                    _dateRow(
                      title: '送達日（deliveredAt）',
                      value: _deliveredAt,
                      onPick: () => _pickDate(
                        context: context,
                        initial: _deliveredAt ?? DateTime.now(),
                        onSelected: (d) => setState(() => _deliveredAt = d),
                      ),
                      onToday: () => setState(() => _deliveredAt = DateTime.now()),
                      onClear: () => setState(() => _deliveredAt = null),
                    ),

                    const SizedBox(height: 10),

                    TextFormField(
                      initialValue: _note,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: '備註',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => _note = v,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;

                      final finalCarrier = carrier.trim();
                      final res = _ShippingFormResult(
                        carrier: finalCarrier,
                        trackingNo: _trackingNo.trim(),
                        shippedAt: _shippedAt,
                        deliveredAt: _deliveredAt,
                        note: _note,
                        shippingStatus: _shippingStatus.trim(),
                      );

                      Navigator.pop(context, res);
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('儲存'),
                  ),
                ],
              ),

              const SizedBox(height: 6),
              Text(
                '提示：若你使用「狀態 + 日期區間」篩選且出現索引錯誤，請依 Firestore Console 建立建議索引。',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _effectiveCarrier() {
    if (_carrierPreset == '其他') return _carrierCustom;
    return _carrierPreset;
  }

  Widget _dateRow({
    required String title,
    required DateTime? value,
    required VoidCallback onPick,
    required VoidCallback onToday,
    required VoidCallback onClear,
  }) {
    final text = value == null ? '-' : DateFormat('yyyy/MM/dd').format(value);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('$title：$text', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          TextButton(onPressed: onPick, child: const Text('選擇')),
          TextButton(onPressed: onToday, child: const Text('今天')),
          TextButton(onPressed: onClear, child: const Text('清除')),
        ],
      ),
    );
  }

  Future<void> _pickDate({
    required BuildContext context,
    required DateTime initial,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(DateTime.now().year + 3, 12, 31),
      initialDate: initial,
      helpText: '選擇日期',
      confirmText: '套用',
      cancelText: '取消',
    );
    if (picked == null) return;
    onSelected(DateTime(picked.year, picked.month, picked.day, 12, 0, 0));
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

class _PagedOrders {
  final List<_OrderRow> rows;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;

  _PagedOrders({required this.rows, required this.lastDoc, required this.hasMore});
}

class _ShippingFormState {
  final String carrierPreset; // preset or '其他'
  final String carrierCustom;
  final String trackingNo;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final String note;
  final String shippingStatus;

  _ShippingFormState({
    required this.carrierPreset,
    required this.carrierCustom,
    required this.trackingNo,
    required this.shippedAt,
    required this.deliveredAt,
    required this.note,
    required this.shippingStatus,
  });

  static _ShippingFormState fromOrder(_OrderRow row) {
    final shipping = _readMap(row.data['shipping']);
    final carrier = (shipping?['carrier'] ?? '').toString().trim();
    final tracking = (shipping?['trackingNo'] ?? '').toString();
    final note = (shipping?['note'] ?? '').toString();
    final status = (shipping?['status'] ?? 'shipped').toString();
    final shippedAt = _readDate(shipping?['shippedAt']);
    final deliveredAt = _readDate(shipping?['deliveredAt']);

    // 判斷 carrier 是否屬於 presets，否則歸到 "其他"
    const presets = _carrierPresetsMirror;
    String preset = '其他';
    String custom = carrier;

    if (carrier.isNotEmpty && presets.contains(carrier)) {
      preset = carrier;
      custom = '';
    }

    return _ShippingFormState(
      carrierPreset: preset,
      carrierCustom: custom,
      trackingNo: tracking,
      shippedAt: shippedAt,
      deliveredAt: deliveredAt,
      note: note,
      shippingStatus: status.isEmpty ? 'shipped' : status,
    );
  }

  static Map<String, dynamic>? _readMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    return null;
  }

  static DateTime? _readDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}

class _ShippingFormResult {
  final String carrier;
  final String trackingNo;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final String note;
  final String shippingStatus;

  _ShippingFormResult({
    required this.carrier,
    required this.trackingNo,
    required this.shippedAt,
    required this.deliveredAt,
    required this.note,
    required this.shippingStatus,
  });
}

// 用於 _ShippingFormState.fromOrder 判斷 preset（避免跨 class 取 state）
const List<String> _carrierPresetsMirror = [
  '黑貓宅急便',
  '7-11',
  '全家',
  '郵局',
  '新竹物流',
  '其他',
];

// =============================================================================
// Error View
// =============================================================================
class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String? hint;

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
        constraints: const BoxConstraints(maxWidth: 720),
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
