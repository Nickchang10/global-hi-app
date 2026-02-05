// lib/pages/admin/members/admin_member_orders_page.dart
//
// ✅ AdminMemberOrdersPage（會員訂單｜專業單檔完整版｜可編譯｜欄位容錯）
// ------------------------------------------------------------
// - 讀取 Firestore orders 集合（orderBy createdAt desc）
// - 搜尋：orderId / userId / customerName / phone / email（有就搜）
// - 篩選：訂單狀態 / 付款狀態 / 出貨狀態 + 日期區間（client filter，避免複合索引）
// - 檢視：訂單列表視圖 + 會員彙總視圖（依 userId 聚合）
// - 詳情 Dialog：
//   - 顧客 / 收件 / 付款 / 出貨 / 商品 items
//   - 原始欄位（Debug）
//   - ✅ 可直接更新：status / paymentStatus / shippingStatus（容錯：值不在 options 也可顯示）
//
// 建議 orders 結構（可彈性）：
// orders/{oid}
// {
//   userId: string,
//   customerName: string?,
//   phone: string?,
//   email: string?,
//   total: number,
//   status: "pending"|"paid"|"shipped"|"completed"|"cancelled"|...,
//   paymentStatus: "unpaid"|"paid"|"refunded"|"partial_refund"|...,
//   shippingStatus: "unshipped"|"packed"|"shipped"|"delivered"|"returned"|...,
//   createdAt: Timestamp,
//   updatedAt: Timestamp?,
//   items: [ { productId, productName, name, qty, quantity, price, unitPrice, ... } ],
//   shipping: { receiverName, receiverPhone, address, city, district, zipcode, note, carrier, trackingNo },
//   payment: { method, transactionId, paidAt },
// }
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminMemberOrdersPage extends StatefulWidget {
  const AdminMemberOrdersPage({super.key});

  @override
  State<AdminMemberOrdersPage> createState() => _AdminMemberOrdersPageState();
}

class _AdminMemberOrdersPageState extends State<AdminMemberOrdersPage> {
  final _db = FirebaseFirestore.instance;

  // view mode
  static const int _viewOrders = 0;
  static const int _viewMembers = 1;
  int _view = _viewOrders;

  // filters
  final _search = TextEditingController();
  DateTimeRange? _range;

  static const String _all = 'all';

  // order status
  static const String _stPending = 'pending';
  static const String _stPaid = 'paid';
  static const String _stShipped = 'shipped';
  static const String _stCompleted = 'completed';
  static const String _stCancelled = 'cancelled';
  String _status = _all;

  // payment status
  static const String _payUnpaid = 'unpaid';
  static const String _payPaid = 'paid';
  static const String _payRefunded = 'refunded';
  static const String _payPartialRefund = 'partial_refund';
  String _payment = _all;

  // shipping status
  static const String _shipUnshipped = 'unshipped';
  static const String _shipPacked = 'packed';
  static const String _shipShipped = 'shipped';
  static const String _shipDelivered = 'delivered';
  static const String _shipReturned = 'returned';
  String _shipping = _all;

  bool _busy = false;

  final _moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
  final _dtFmt = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _baseQuery() {
    // 建議 createdAt 為 Timestamp，否則 orderBy 會噴錯
    return _db.collection('orders').orderBy('createdAt', descending: true).limit(800);
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

  Map<String, dynamic> _m(dynamic v) => (v is Map<String, dynamic>) ? v : <String, dynamic>{};
  List _l(dynamic v) => (v is List) ? v : const [];

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
        title: const Text('會員訂單', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '清除篩選',
            icon: const Icon(Icons.filter_alt_off),
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _search.clear();
                      _range = null;
                      _status = _all;
                      _payment = _all;
                      _shipping = _all;
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
                        title: '載入訂單失敗',
                        message: '${snap.error}',
                        hint: '請確認 orders 集合存在、createdAt 欄位為 Timestamp，並檢查 Firestore rules。',
                        onRetry: () => setState(() {}),
                      );
                    }

                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) return const _EmptyView(title: '目前沒有訂單');

                    final filtered = _applyFilters(docs);
                    if (filtered.isEmpty) return const _EmptyView(title: '沒有符合條件的訂單');

                    if (_view == _viewMembers) {
                      return _buildMembersSummary(filtered);
                    }
                    return _buildOrdersList(filtered);
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
  // Filters UI
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
              hintText: '搜尋（orderId / userId / 客戶名 / phone / email）',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          final viewToggle = ToggleButtons(
            isSelected: [_view == _viewOrders, _view == _viewMembers],
            onPressed: (i) => setState(() => _view = i),
            borderRadius: BorderRadius.circular(12),
            constraints: const BoxConstraints(minHeight: 40, minWidth: 92),
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('訂單列表')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('會員彙總')),
            ],
          );

          final statusDD = _dropdown(
            label: '訂單狀態',
            value: _status,
            items: const [
              MapEntry(_all, '全部'),
              MapEntry(_stPending, '待處理'),
              MapEntry(_stPaid, '已付款'),
              MapEntry(_stShipped, '已出貨'),
              MapEntry(_stCompleted, '已完成'),
              MapEntry(_stCancelled, '已取消'),
            ],
            onChanged: (v) => setState(() => _status = v),
          );

          final paymentDD = _dropdown(
            label: '付款狀態',
            value: _payment,
            items: const [
              MapEntry(_all, '全部'),
              MapEntry(_payUnpaid, '未付款'),
              MapEntry(_payPaid, '已付款'),
              MapEntry(_payRefunded, '已退款'),
              MapEntry(_payPartialRefund, '部分退款'),
            ],
            onChanged: (v) => setState(() => _payment = v),
          );

          final shippingDD = _dropdown(
            label: '出貨狀態',
            value: _shipping,
            items: const [
              MapEntry(_all, '全部'),
              MapEntry(_shipUnshipped, '未出貨'),
              MapEntry(_shipPacked, '已包裝'),
              MapEntry(_shipShipped, '已出貨'),
              MapEntry(_shipDelivered, '已送達'),
              MapEntry(_shipReturned, '已退回'),
            ],
            onChanged: (v) => setState(() => _shipping = v),
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

          if (narrow) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 10),
                    viewToggle,
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: statusDD),
                    const SizedBox(width: 10),
                    Expanded(child: paymentDD),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: shippingDD),
                    const SizedBox(width: 10),
                    Expanded(child: rangeBtn),
                    const SizedBox(width: 6),
                    clearRange,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 5, child: search),
              const SizedBox(width: 10),
              viewToggle,
              const SizedBox(width: 10),
              Expanded(flex: 2, child: statusDD),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: paymentDD),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: shippingDD),
              const SizedBox(width: 10),
              rangeBtn,
              const SizedBox(width: 6),
              clearRange,
            ],
          );
        },
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<MapEntry<String, String>> items,
    required ValueChanged<String> onChanged,
  }) {
    final allowed = items.map((e) => e.key).toList();
    final v = allowed.contains(value) ? value : _all;

    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: v,
      onChanged: (nv) => onChanged(nv ?? _all),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
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
      helpText: '選擇訂單日期區間（createdAt）',
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
  // Apply filters (client-side)
  // ------------------------------------------------------------
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final s = _search.text.trim().toLowerCase();

    return docs.where((doc) {
      final d = doc.data();

      final createdAt = _dt(d['createdAt']);
      if (!_inRange(createdAt, _range)) return false;

      final st = _lower(d['status']);
      final pay = _lower(d['paymentStatus']);
      final ship = _lower(d['shippingStatus']);

      if (_status != _all && st != _status) return false;
      if (_payment != _all && pay != _payment) return false;
      if (_shipping != _all && ship != _shipping) return false;

      if (s.isEmpty) return true;

      final userId = _lower(d['userId']);
      final customerName = _lower(d['customerName']);
      final userName = _lower(d['userName']); // 兼容
      final phone = _lower(d['phone']);
      final email = _lower(d['email']);

      final shipping = _m(d['shipping']);
      final receiverName = _lower(shipping['receiverName']);
      final receiverPhone = _lower(shipping['receiverPhone']);

      final orderId = doc.id.toLowerCase();

      return orderId.contains(s) ||
          userId.contains(s) ||
          customerName.contains(s) ||
          userName.contains(s) ||
          phone.contains(s) ||
          email.contains(s) ||
          receiverName.contains(s) ||
          receiverPhone.contains(s);
    }).toList();
  }

  // ------------------------------------------------------------
  // Orders list view
  // ------------------------------------------------------------
  Widget _buildOrdersList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
      itemCount: docs.length,
      itemBuilder: (context, i) => _orderTile(docs[i]),
    );
  }

  Widget _orderTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final cs = Theme.of(context).colorScheme;
    final d = doc.data();

    final userId = _s(d['userId']).trim();
    final customerName = _s(d['customerName']).trim();
    final userName = _s(d['userName']).trim();

    final title = customerName.isNotEmpty
        ? customerName
        : (userName.isNotEmpty ? userName : (userId.isNotEmpty ? userId : '未知會員'));

    final total = _n(d['total']);
    final createdAt = _dt(d['createdAt']);

    final st = _lower(d['status']);
    final pay = _lower(d['paymentStatus']);
    final ship = _lower(d['shippingStatus']);

    final items = _l(d['items']);
    final itemCount = items.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            _chip('訂單', st.isEmpty ? '—' : st, cs.surfaceContainerHighest, cs.onSurfaceVariant),
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
                  _miniTag('orderId', doc.id),
                  if (userId.isNotEmpty) _miniTag('userId', userId),
                  _miniTag('items', '$itemCount'),
                  if (createdAt != null) _miniTag('createdAt', _dtFmt.format(createdAt)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip('付款', pay.isEmpty ? '—' : pay, Colors.blue.shade50, Colors.blue.shade800),
                  _chip('出貨', ship.isEmpty ? '—' : ship, Colors.orange.shade50, Colors.orange.shade800),
                ],
              ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_moneyFmt.format(total), style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
        onTap: () => _openOrderDetail(doc),
      ),
    );
  }

  // ------------------------------------------------------------
  // Members summary view (group by userId)
  // ------------------------------------------------------------
  Widget _buildMembersSummary(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final map = <String, _MemberAgg>{};

    for (final doc in docs) {
      final d = doc.data();
      final userId = _s(d['userId']).trim();
      final key = userId.isEmpty ? '(unknown)' : userId;

      final name = _s(d['customerName']).trim().isNotEmpty
          ? _s(d['customerName']).trim()
          : _s(d['userName']).trim();

      final total = _n(d['total']);
      map.putIfAbsent(key, () => _MemberAgg(userId: key, name: name));
      map[key]!.orders.add(doc);
      map[key]!.sumTotal += total;
      if (name.isNotEmpty && map[key]!.name.isEmpty) map[key]!.name = name;
    }

    final members = map.values.toList()
      ..sort((a, b) => b.orders.length.compareTo(a.orders.length));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
      itemCount: members.length,
      itemBuilder: (context, i) {
        final m = members[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            title: Text(
              m.name.isNotEmpty ? m.name : m.userId,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text('userId：${m.userId}  •  訂單：${m.orders.length}  •  總額：${_moneyFmt.format(m.sumTotal)}'),
            children: [
              const Divider(height: 1),
              ...m.orders.take(30).map((o) {
                final d = o.data();
                final total = _n(d['total']);
                final createdAt = _dt(d['createdAt']);
                final st = _lower(d['status']);
                final pay = _lower(d['paymentStatus']);
                final ship = _lower(d['shippingStatus']);
                return ListTile(
                  dense: true,
                  title: Text('orderId：${o.id}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    [
                      if (createdAt != null) _dtFmt.format(createdAt),
                      if (st.isNotEmpty) '訂單:$st',
                      if (pay.isNotEmpty) '付款:$pay',
                      if (ship.isNotEmpty) '出貨:$ship',
                    ].join('  •  '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(_moneyFmt.format(total), style: const TextStyle(fontWeight: FontWeight.w900)),
                  onTap: () => _openOrderDetail(o),
                );
              }),
              if (m.orders.length > 30)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '（僅顯示前 30 筆，可用搜尋/日期範圍縮小）',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // Detail dialog + update statuses
  // ------------------------------------------------------------
  Future<void> _openOrderDetail(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final cs = Theme.of(context).colorScheme;
    final d = doc.data();

    final userId = _s(d['userId']).trim();
    final customerName = _s(d['customerName']).trim();
    final phone = _s(d['phone']).trim();
    final email = _s(d['email']).trim();

    final createdAt = _dt(d['createdAt']);
    final updatedAt = _dt(d['updatedAt']);

    final total = _n(d['total']);
    final items = _l(d['items']);

    final shipping = _m(d['shipping']);
    final payment = _m(d['payment']);

    String status = _lower(d['status']);
    String paymentStatus = _lower(d['paymentStatus']);
    String shippingStatus = _lower(d['shippingStatus']);

    final orderStatusOptions = <String, String>{
      _stPending: '待處理',
      _stPaid: '已付款',
      _stShipped: '已出貨',
      _stCompleted: '已完成',
      _stCancelled: '已取消',
    };
    final paymentOptions = <String, String>{
      _payUnpaid: '未付款',
      _payPaid: '已付款',
      _payRefunded: '已退款',
      _payPartialRefund: '部分退款',
    };
    final shippingOptions = <String, String>{
      _shipUnshipped: '未出貨',
      _shipPacked: '已包裝',
      _shipShipped: '已出貨',
      _shipDelivered: '已送達',
      _shipReturned: '已退回',
    };

    bool saving = false;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> save() async {
            try {
              setLocal(() => saving = true);
              setState(() => _busy = true);

              final patch = <String, dynamic>{
                'status': status.isEmpty ? null : status,
                'paymentStatus': paymentStatus.isEmpty ? null : paymentStatus,
                'shippingStatus': shippingStatus.isEmpty ? null : shippingStatus,
                'updatedAt': FieldValue.serverTimestamp(),
              }..removeWhere((k, v) => v == null);

              await doc.reference.update(patch);

              if (!mounted) return;
              Navigator.pop(context);
              _toast('已更新訂單狀態');
            } catch (e) {
              _toast('更新失敗：$e');
            } finally {
              if (!mounted) return;
              setState(() => _busy = false);
              setLocal(() => saving = false);
            }
          }

          return AlertDialog(
            title: Text('訂單詳情：${doc.id}', style: const TextStyle(fontWeight: FontWeight.w900)),
            content: SizedBox(
              width: 820,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _miniTag('orderId', doc.id),
                        if (userId.isNotEmpty) _miniTag('userId', userId),
                        if (createdAt != null) _miniTag('createdAt', _dtFmt.format(createdAt)),
                        if (updatedAt != null) _miniTag('updatedAt', _dtFmt.format(updatedAt)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _kv('客戶', customerName.isEmpty ? '—' : customerName)),
                        const SizedBox(width: 10),
                        Expanded(child: _kv('Email', email.isEmpty ? '—' : email)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: _kv('電話', phone.isEmpty ? '—' : phone)),
                        const SizedBox(width: 10),
                        Expanded(child: _kv('總額', _moneyFmt.format(total))),
                      ],
                    ),
                    const Divider(height: 22),

                    const Text('狀態管理（可直接修改）', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),

                    _statusEditorRow(
                      label: '訂單狀態',
                      value: status,
                      options: orderStatusOptions,
                      onChanged: (v) => setLocal(() => status = v),
                    ),
                    const SizedBox(height: 10),
                    _statusEditorRow(
                      label: '付款狀態',
                      value: paymentStatus,
                      options: paymentOptions,
                      onChanged: (v) => setLocal(() => paymentStatus = v),
                    ),
                    const SizedBox(height: 10),
                    _statusEditorRow(
                      label: '出貨狀態',
                      value: shippingStatus,
                      options: shippingOptions,
                      onChanged: (v) => setLocal(() => shippingStatus = v),
                    ),

                    const Divider(height: 22),

                    const Text('收件 / 出貨資訊', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    _kv('收件人', _s(shipping['receiverName']).isEmpty ? '—' : _s(shipping['receiverName'])),
                    _kv('收件電話', _s(shipping['receiverPhone']).isEmpty ? '—' : _s(shipping['receiverPhone'])),
                    _kv('地址', _s(shipping['address']).isEmpty ? '—' : _s(shipping['address'])),
                    _kv('物流商', _s(shipping['carrier']).isEmpty ? '—' : _s(shipping['carrier'])),
                    _kv('追蹤號', _s(shipping['trackingNo']).isEmpty ? '—' : _s(shipping['trackingNo'])),
                    if (_s(shipping['note']).trim().isNotEmpty) _kv('備註', _s(shipping['note']).trim()),

                    const Divider(height: 22),

                    const Text('付款資訊', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    _kv('方式', _s(payment['method']).isEmpty ? '—' : _s(payment['method'])),
                    _kv('交易號', _s(payment['transactionId']).isEmpty ? '—' : _s(payment['transactionId'])),
                    _kv('付款時間', _dt(payment['paidAt']) == null ? '—' : _dtFmt.format(_dt(payment['paidAt'])!)),

                    const Divider(height: 22),

                    Text('商品明細（${items.length}）', style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    if (items.isEmpty)
                      Text('（items 欄位為空或不存在）', style: TextStyle(color: cs.onSurfaceVariant))
                    else
                      ...items.map((raw) {
                        final it = (raw is Map) ? (raw as Map).cast<String, dynamic>() : <String, dynamic>{};
                        final name = _s(it['productName']).trim().isNotEmpty
                            ? _s(it['productName']).trim()
                            : (_s(it['name']).trim().isNotEmpty ? _s(it['name']).trim() : '未命名商品');
                        final qty = _i(it['qty'] ?? it['quantity'] ?? 1);
                        final price = _n(it['price'] ?? it['unitPrice'] ?? 0);
                        final line = price * qty;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('•  '),
                              Expanded(
                                child: Text('$name  ×$qty', style: const TextStyle(fontWeight: FontWeight.w700)),
                              ),
                              Text(_moneyFmt.format(line), style: const TextStyle(fontWeight: FontWeight.w900)),
                            ],
                          ),
                        );
                      }),

                    const Divider(height: 22),

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
                  _toast('已複製 orderId');
                },
                child: const Text('複製 orderId'),
              ),
              TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('關閉')),
              FilledButton.icon(
                onPressed: saving ? null : save,
                icon: saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: const Text('儲存狀態'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusEditorRow({
    required String label,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    // 容錯：若目前 value 不在 options，仍可顯示
    final items = <DropdownMenuItem<String>>[
      if (value.isNotEmpty && !options.containsKey(value))
        DropdownMenuItem(value: value, child: Text('（自訂）$value')),
      ...options.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
    ];

    final v = value.isEmpty
        ? (options.keys.isNotEmpty ? options.keys.first : '')
        : value;

    return Row(
      children: [
        SizedBox(width: 92, child: Text(label, style: const TextStyle(color: Colors.black54))),
        Expanded(
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: v,
            items: items,
            onChanged: (nv) => onChanged((nv ?? v).trim().toLowerCase()),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
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
      child: Text('$k：$v', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 86, child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  String _prettyMap(Map<String, dynamic> d) {
    // 簡單格式化（避免引入 jsonEncode 造成 Timestamp 例外）
    final buf = StringBuffer();
    d.forEach((k, v) {
      buf.writeln('$k: ${_prettyValue(v)}');
    });
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
// Models
// ------------------------------------------------------------
class _MemberAgg {
  final String userId;
  String name;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> orders = [];
  num sumTotal = 0;

  _MemberAgg({required this.userId, required this.name});
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
