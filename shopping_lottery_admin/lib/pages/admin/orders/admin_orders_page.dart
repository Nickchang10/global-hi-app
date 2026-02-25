// lib/pages/admin/orders/admin_orders_page.dart
//
// ✅ AdminOrdersPage（訂單管理｜單檔完整版｜可直接編譯｜已消除 curly_braces_in_flow_control_structures）
// -----------------------------------------------------------------------------
// - Firestore 直連 orders（不依賴既有 OrderService）
// - 支援：搜尋 / 狀態篩選 / 日期區間（本地過濾，避免複合索引）
// - 分頁載入（Load more）
// - 跳轉：訂單詳情（pushNamed）/ 出貨退款工作台（pushNamed，不直接 new 類別）
//
// 依賴：cloud_firestore / intl / flutter
//
// ⚠️ 你需要在 main.dart / onGenerateRoute 註冊工作台路由，例如：
// '/admin/orders/fulfillment-refund' => 你的工作台頁面 Widget
// -----------------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  final _db = FirebaseFirestore.instance;

  // ✅ 工作台路由（只用 pushNamed，避免 creation_with_non_type）
  static const String _workbenchRoute = '/admin/orders/fulfillment-refund';

  // Filters
  final TextEditingController _searchCtrl = TextEditingController();
  String _status = 'all';
  DateTimeRange? _range;

  // Pagination
  static const int _pageSize = 30;
  bool _loading = true;
  String? _error;

  final List<_OrderRow> _rows = <_OrderRow>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _loadingMore = false;

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

  // ===========================================================================
  // Firestore load
  // ===========================================================================
  Query<Map<String, dynamic>> _baseQuery() {
    // ✅ 只做 orderBy(createdAt)，避免複合索引；其他條件全部本地過濾
    return _db.collection('orders').orderBy('createdAt', descending: true);
  }

  Future<void> _load({required bool reset}) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _error = null;
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
  // Local filters (avoid index pain)
  // ===========================================================================
  List<_OrderRow> get _visibleRows {
    final q = _searchCtrl.text.trim().toLowerCase();
    final statusFilter = _status;
    final r = _range;

    bool hit(_OrderRow row) {
      final d = row.data;

      // status filter
      if (statusFilter != 'all') {
        final st = (d['status'] ?? '').toString();
        if (st != statusFilter) {
          return false;
        }
      }

      // date range filter
      if (r != null) {
        final createdAt = _toDateTime(d['createdAt']);
        if (createdAt == null) {
          return false;
        }
        if (createdAt.isBefore(r.start) || createdAt.isAfter(r.end)) {
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

      final shipping = _readShipping(d);
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
  // Date range
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
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
      initialDateRange: init,
      helpText: '選擇訂單日期區間（createdAt）',
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
  }

  void _clearRange() {
    setState(() => _range = null);
  }

  // ===========================================================================
  // Navigation
  // ===========================================================================
  void _openOrderDetail(String orderDocId) {
    try {
      Navigator.pushNamed(
        context,
        '/admin/orders/detail',
        arguments: orderDocId,
      );
    } catch (_) {
      _toast('尚未註冊 /admin/orders/detail 路由（請確認 main.dart onGenerateRoute）');
    }
  }

  void _openWorkbench() {
    try {
      Navigator.pushNamed(context, _workbenchRoute);
    } catch (_) {
      _toast(
        '尚未註冊出貨/退款工作台路由：$_workbenchRoute\n'
        '請在 main.dart / onGenerateRoute 加上該路由。',
      );
    }
  }

  void _toast(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
            '訂單管理',
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
          hint: '常見原因：orders 缺少 createdAt、或 Firestore 權限/規則阻擋。',
          onRetry: () => _load(reset: true),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final visible = _visibleRows;

    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
    final sum = visible.fold<num>(
      0,
      (p, r) => p + _toNum(r.data['finalAmount'] ?? r.data['total']),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '訂單管理',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '出貨/退款工作台',
            onPressed: _openWorkbench,
            icon: const Icon(Icons.local_shipping_outlined),
          ),
          IconButton(
            tooltip: '重新整理',
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh),
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

            if (visible.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '目前沒有符合條件的訂單。\n\n'
                    '提示：此頁篩選/搜尋是針對「已載入列表」做本地過濾；需要更大範圍請多按「載入更多」。',
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
                      '狀態：',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _status,
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
                      onChanged: (v) {
                        if (v == null) {
                          return;
                        }
                        setState(() => _status = v);
                      },
                    ),
                  ],
                ),
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
              ],
            ),

            const SizedBox(height: 12),

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
              '提示：此頁為本地過濾，避免 Firestore 複合索引；需要更完整範圍請多按「載入更多」。',
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
    final phone = (d['phone'] ?? d['customerPhone'] ?? '').toString();

    final shipping = _readShipping(d);
    final carrier = (shipping['carrier'] ?? '').toString();
    final trackingNo = (shipping['trackingNo'] ?? '').toString();

    final refund = _readRefund(d);
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
                if (phone.isNotEmpty) _kv('電話', phone),
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

            const SizedBox(height: 10),

            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _openOrderDetail(row.id),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('查看訂單詳情'),
                ),
                OutlinedButton.icon(
                  onPressed: _openWorkbench,
                  icon: const Icon(Icons.local_shipping),
                  label: const Text('出貨/退款工作台'),
                ),
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
  Map<String, dynamic> _readShipping(Map<String, dynamic> d) {
    final s = d['shipping'];
    if (s is Map<String, dynamic>) {
      return s;
    }
    if (s is Map) {
      return Map<String, dynamic>.from(s);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _readRefund(Map<String, dynamic> d) {
    final r = d['refund'];
    if (r is Map<String, dynamic>) {
      return r;
    }
    if (r is Map) {
      return Map<String, dynamic>.from(r);
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

class _OrderRow {
  final String id;
  final Map<String, dynamic> data;
  _OrderRow({required this.id, required this.data});
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
