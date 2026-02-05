// lib/pages/admin/members/admin_member_orders_page.dart
//
// ✅ AdminMemberOrdersPage（會員訂單｜專業版｜可編譯）
// ------------------------------------------------------------
// - 以 userId 查詢 orders（where userId == X）
// - 篩選：訂單狀態 / 付款狀態 / 出貨狀態（前端篩選，降低索引壓力）
// - 搜尋：orderId / customerName / recipient.name / phone（前端篩選）
// - 日期區間：createdAt（前端篩選）
// - 訂單詳情：收件資訊 / 付款資訊 / 出貨資訊 / 商品明細 / 金額
// - 後台快捷操作：
//   1) 標記已付款（payment.status = paid + payment.paidAt）
//   2) 標記已出貨（shippingInfo.status = shipped + shippingInfo.shippedAt）
//   3) 更新物流（courier / trackingNo）
//
// ------------------------------------------------------------
// 建議 orders/{orderId} 欄位（可彈性，缺了也不會炸）：
// {
//   userId: string,
//   vendorId: string, // 你若有多廠商拆單
//   customerName: string,
//   customerEmail: string,
//   customerPhone: string,
//
//   status: "pending" | "paid" | "processing" | "shipped" | "completed" | "cancelled" | "refunded",
//
//   createdAt: Timestamp,
//   updatedAt: Timestamp,
//
//   payment: {
//     method: "credit_card" | "linepay" | "cod" | ...,
//     status: "unpaid" | "paid" | "failed" | "refunded",
//     total: number,
//     transactionId: string,
//     paidAt: Timestamp
//   },
//
//   shippingInfo: {
//     status: "unshipped" | "processing" | "shipped" | "delivered" | "returned",
//     courier: string,
//     trackingNo: string,
//     shippedAt: Timestamp,
//     deliveredAt: Timestamp
//   },
//
//   recipient: {
//     name: string,
//     phone: string,
//     address: string,
//     note: string
//   },
//
//   items: [
//     {
//       productId: string,
//       productName: string,
//       variantName: string,
//       sku: string,
//       qty: number,
//       price: number,
//       subtotal: number
//     }
//   ],
//
//   totals: {
//     subtotal: number,
//     shippingFee: number,
//     discount: number,
//     total: number
//   }
// }
//
// ------------------------------------------------------------
// Firestore 索引提示：
// - where userId == X + orderBy createdAt 可能需要 index（控制台會給連結）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminMemberOrdersPage extends StatefulWidget {
  final String userId;
  final String? userName; // 可選，用於標題顯示
  final String? userEmail;

  const AdminMemberOrdersPage({
    super.key,
    required this.userId,
    this.userName,
    this.userEmail,
  });

  @override
  State<AdminMemberOrdersPage> createState() => _AdminMemberOrdersPageState();
}

class _AdminMemberOrdersPageState extends State<AdminMemberOrdersPage> {
  final _db = FirebaseFirestore.instance;

  final _search = TextEditingController();

  // filters (client-side)
  static const _all = 'all';

  // order status
  static const _osPending = 'pending';
  static const _osPaid = 'paid';
  static const _osProcessing = 'processing';
  static const _osShipped = 'shipped';
  static const _osCompleted = 'completed';
  static const _osCancelled = 'cancelled';
  static const _osRefunded = 'refunded';
  String _orderStatus = _all;

  // payment status
  static const _psUnpaid = 'unpaid';
  static const _psPaid = 'paid';
  static const _psFailed = 'failed';
  static const _psRefunded = 'refunded';
  String _paymentStatus = _all;

  // shipping status
  static const _ssUnshipped = 'unshipped';
  static const _ssProcessing = 'processing';
  static const _ssShipped = 'shipped';
  static const _ssDelivered = 'delivered';
  static const _ssReturned = 'returned';
  String _shippingStatus = _all;

  // date range (client-side)
  DateTime? _fromDate;
  DateTime? _toDate;

  final _moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
  final _dtFmt = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _baseQuery() {
    return _db
        .collection('orders')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('createdAt', descending: true)
        .limit(500);
  }

  // -------------------------
  // Safe helpers
  // -------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();
  num _n(dynamic v) => v is num ? v : (num.tryParse((v ?? '0').toString()) ?? 0);
  int _i(dynamic v) => v is int ? v : (int.tryParse((v ?? '0').toString()) ?? 0);

  DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  Map<String, dynamic> _map(dynamic v) => (v is Map<String, dynamic>) ? v : <String, dynamic>{};
  List _list(dynamic v) => (v is List) ? v : const [];

  // -------------------------
  // Client-side filter
  // -------------------------
  bool _matchFilters(String orderId, Map<String, dynamic> d) {
    final q = _search.text.trim().toLowerCase();

    final customerName = _s(d['customerName']).toLowerCase();
    final customerPhone = _s(d['customerPhone']).toLowerCase();
    final customerEmail = _s(d['customerEmail']).toLowerCase();

    final recipient = _map(d['recipient']);
    final recipientName = _s(recipient['name']).toLowerCase();
    final recipientPhone = _s(recipient['phone']).toLowerCase();

    final matchSearch = q.isEmpty ||
        orderId.toLowerCase().contains(q) ||
        customerName.contains(q) ||
        customerPhone.contains(q) ||
        customerEmail.contains(q) ||
        recipientName.contains(q) ||
        recipientPhone.contains(q);

    final status = _s(d['status']).toLowerCase();
    final payment = _map(d['payment']);
    final payStatus = _s(payment['status']).toLowerCase();
    final shipping = _map(d['shippingInfo']);
    final shipStatus = _s(shipping['status']).toLowerCase();

    final matchOrderStatus = _orderStatus == _all ? true : status == _orderStatus;
    final matchPaymentStatus = _paymentStatus == _all ? true : payStatus == _paymentStatus;
    final matchShippingStatus = _shippingStatus == _all ? true : shipStatus == _shippingStatus;

    final createdAt = _dt(d['createdAt']);
    final matchFrom = _fromDate == null || (createdAt != null && !createdAt.isBefore(_fromDate!));
    final matchTo = _toDate == null || (createdAt != null && !createdAt.isAfter(_toDate!));

    return matchSearch && matchOrderStatus && matchPaymentStatus && matchShippingStatus && matchFrom && matchTo;
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final title = widget.userName?.trim().isNotEmpty == true
        ? '會員訂單（${widget.userName}）'
        : '會員訂單';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '清除搜尋',
            onPressed: () {
              _search.clear();
              setState(() {});
            },
            icon: const Icon(Icons.clear),
          ),
          IconButton(
            tooltip: '重整（重建 Stream）',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _filterBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _baseQuery().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorView(
                    title: '載入訂單失敗',
                    message: snap.error.toString(),
                    hint:
                        '常見原因：\n'
                        '1) Firestore rules 未允許 admin 讀取 orders\n'
                        '2) where + orderBy 需要索引（控制台會提示建立）\n'
                        '3) createdAt 欄位缺失或型別不一致（必須 Timestamp）',
                    onRetry: () => setState(() {}),
                  );
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('此會員目前沒有訂單'));
                }

                final filtered = docs.where((doc) => _matchFilters(doc.id, doc.data())).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('沒有符合條件的訂單'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _orderTile(filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------
  // Filter Bar
  // -------------------------
  Widget _filterBar() {
    final searchField = TextField(
      controller: _search,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: '搜尋 orderId / 姓名 / 電話 / Email / 收件人',
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    final orderStatusDD = DropdownButtonFormField<String>(
      isExpanded: true,
      value: _orderStatus,
      decoration: InputDecoration(
        isDense: true,
        labelText: '訂單狀態',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: const [
        DropdownMenuItem(value: _all, child: Text('全部')),
        DropdownMenuItem(value: _osPending, child: Text('pending')),
        DropdownMenuItem(value: _osPaid, child: Text('paid')),
        DropdownMenuItem(value: _osProcessing, child: Text('processing')),
        DropdownMenuItem(value: _osShipped, child: Text('shipped')),
        DropdownMenuItem(value: _osCompleted, child: Text('completed')),
        DropdownMenuItem(value: _osCancelled, child: Text('cancelled')),
        DropdownMenuItem(value: _osRefunded, child: Text('refunded')),
      ],
      onChanged: (v) => setState(() => _orderStatus = v ?? _all),
    );

    final paymentStatusDD = DropdownButtonFormField<String>(
      isExpanded: true,
      value: _paymentStatus,
      decoration: InputDecoration(
        isDense: true,
        labelText: '付款狀態',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: const [
        DropdownMenuItem(value: _all, child: Text('全部')),
        DropdownMenuItem(value: _psUnpaid, child: Text('unpaid')),
        DropdownMenuItem(value: _psPaid, child: Text('paid')),
        DropdownMenuItem(value: _psFailed, child: Text('failed')),
        DropdownMenuItem(value: _psRefunded, child: Text('refunded')),
      ],
      onChanged: (v) => setState(() => _paymentStatus = v ?? _all),
    );

    final shippingStatusDD = DropdownButtonFormField<String>(
      isExpanded: true,
      value: _shippingStatus,
      decoration: InputDecoration(
        isDense: true,
        labelText: '出貨狀態',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: const [
        DropdownMenuItem(value: _all, child: Text('全部')),
        DropdownMenuItem(value: _ssUnshipped, child: Text('unshipped')),
        DropdownMenuItem(value: _ssProcessing, child: Text('processing')),
        DropdownMenuItem(value: _ssShipped, child: Text('shipped')),
        DropdownMenuItem(value: _ssDelivered, child: Text('delivered')),
        DropdownMenuItem(value: _ssReturned, child: Text('returned')),
      ],
      onChanged: (v) => setState(() => _shippingStatus = v ?? _all),
    );

    final dateBtn = OutlinedButton.icon(
      onPressed: _pickDateRange,
      icon: const Icon(Icons.date_range),
      label: Text(
        _fromDate == null && _toDate == null
            ? '日期區間'
            : '${DateFormat('yyyy/MM/dd').format(_fromDate ?? DateTime(2000))}'
              ' ~ ${DateFormat('yyyy/MM/dd').format(_toDate ?? DateTime.now())}',
      ),
    );

    final clearDateBtn = IconButton(
      tooltip: '清除日期篩選',
      onPressed: () => setState(() {
        _fromDate = null;
        _toDate = null;
      }),
      icon: const Icon(Icons.backspace_outlined),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 980;

          if (narrow) {
            return Column(
              children: [
                searchField,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: orderStatusDD),
                    const SizedBox(width: 10),
                    Expanded(child: paymentStatusDD),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: shippingStatusDD),
                    const SizedBox(width: 10),
                    dateBtn,
                    clearDateBtn,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: searchField),
              const SizedBox(width: 10),
              Expanded(child: orderStatusDD),
              const SizedBox(width: 10),
              Expanded(child: paymentStatusDD),
              const SizedBox(width: 10),
              Expanded(child: shippingStatusDD),
              const SizedBox(width: 10),
              dateBtn,
              clearDateBtn,
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialStart = _fromDate ?? DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
    final initialEnd = _toDate ?? DateTime(now.year, now.month, now.day);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
    );

    if (picked == null) return;
    setState(() {
      _fromDate = picked.start;
      _toDate = picked.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    });
  }

  // -------------------------
  // Tile
  // -------------------------
  Widget _orderTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final orderId = doc.id;

    final status = _s(d['status']).toLowerCase();
    final createdAt = _dt(d['createdAt']);
    final createdText = createdAt == null ? '' : _dtFmt.format(createdAt);

    final payment = _map(d['payment']);
    final payStatus = _s(payment['status']).toLowerCase();
    final payMethod = _s(payment['method']);
    final payTotal = payment.containsKey('total') ? _n(payment['total']) : _n(d['total']);

    final shipping = _map(d['shippingInfo']);
    final shipStatus = _s(shipping['status']).toLowerCase();
    final courier = _s(shipping['courier']);
    final trackingNo = _s(shipping['trackingNo']);

    final customerName = _s(d['customerName']);
    final recipient = _map(d['recipient']);
    final recipientName = _s(recipient['name']);
    final phone = _s(recipient['phone']).isNotEmpty ? _s(recipient['phone']) : _s(d['customerPhone']);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(orderId.substring(0, orderId.length >= 2 ? 2 : 1).toUpperCase()),
        ),
        title: Text(
          customerName.isNotEmpty ? customerName : (recipientName.isNotEmpty ? recipientName : orderId),
          style: const TextStyle(fontWeight: FontWeight.w900),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            'order: $orderId',
            if (createdText.isNotEmpty) 'created: $createdText',
            if (phone.isNotEmpty) 'phone: $phone',
            if (status.isNotEmpty) 'status: $status',
            if (payStatus.isNotEmpty) 'pay: $payStatus${payMethod.isNotEmpty ? '($payMethod)' : ''}',
            if (shipStatus.isNotEmpty) 'ship: $shipStatus',
            if (courier.isNotEmpty || trackingNo.isNotEmpty) '物流: ${courier.isEmpty ? '-' : courier} / ${trackingNo.isEmpty ? '-' : trackingNo}',
          ].join('  •  '),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(_moneyFmt.format(payTotal), style: const TextStyle(fontWeight: FontWeight.w900)),
        onTap: () => _openOrderDetail(doc),
      ),
    );
  }

  // -------------------------
  // Detail Dialog + Admin Actions
  // -------------------------
  Future<void> _openOrderDetail(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data();
    final orderId = doc.id;

    final recipient = _map(d['recipient']);
    final shipping = _map(d['shippingInfo']);
    final payment = _map(d['payment']);
    final totals = _map(d['totals']);

    final items = _list(d['items']);

    final createdAt = _dt(d['createdAt']);
    final updatedAt = _dt(d['updatedAt']);

    final payTotal = payment.containsKey('total')
        ? _n(payment['total'])
        : (totals.containsKey('total') ? _n(totals['total']) : _n(d['total']));

    final courierCtrl = TextEditingController(text: _s(shipping['courier']));
    final trackingCtrl = TextEditingController(text: _s(shipping['trackingNo']));

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('訂單詳情：$orderId', style: const TextStyle(fontWeight: FontWeight.w900)),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv('UserId', _s(d['userId'])),
                  _kv('Status', _s(d['status']).isEmpty ? '-' : _s(d['status'])),
                  _kv('Created', createdAt == null ? '-' : _dtFmt.format(createdAt)),
                  _kv('Updated', updatedAt == null ? '-' : _dtFmt.format(updatedAt)),
                  const Divider(height: 22),

                  Text('收件資訊', style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  _kv('Name', _s(recipient['name']).isEmpty ? _s(d['customerName']) : _s(recipient['name'])),
                  _kv('Phone', _s(recipient['phone']).isEmpty ? _s(d['customerPhone']) : _s(recipient['phone'])),
                  _kv('Address', _s(recipient['address']).isEmpty ? '-' : _s(recipient['address'])),
                  if (_s(recipient['note']).isNotEmpty) _kv('Note', _s(recipient['note'])),
                  const Divider(height: 22),

                  Text('付款資訊', style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  _kv('Method', _s(payment['method']).isEmpty ? '-' : _s(payment['method'])),
                  _kv('Status', _s(payment['status']).isEmpty ? '-' : _s(payment['status'])),
                  _kv('Total', _moneyFmt.format(payTotal), bold: true),
                  if (_s(payment['transactionId']).isNotEmpty) _kv('TxnId', _s(payment['transactionId'])),
                  final payAt = _dt(payment['paidAt']);
                  _kv('PaidAt', payAt == null ? '-' : _dtFmt.format(payAt)),
                  const Divider(height: 22),

                  Text('出貨資訊', style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  _kv('ShipStatus', _s(shipping['status']).isEmpty ? '-' : _s(shipping['status'])),
                  const SizedBox(height: 10),
                  TextField(
                    controller: courierCtrl,
                    decoration: const InputDecoration(
                      labelText: '物流商 courier',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: trackingCtrl,
                    decoration: const InputDecoration(
                      labelText: '追蹤號 trackingNo',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  final shipAt = _dt(shipping['shippedAt']);
                  _kv('ShippedAt', shipAt == null ? '-' : _dtFmt.format(shipAt)),
                  final deliveredAt = _dt(shipping['deliveredAt']);
                  _kv('DeliveredAt', deliveredAt == null ? '-' : _dtFmt.format(deliveredAt)),
                  const Divider(height: 22),

                  Text('商品明細（${items.length}）', style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  if (items.isEmpty)
                    const Text('（items 為空或未寫入）')
                  else
                    ...items.map((raw) {
                      final item = _map(raw);
                      final name = _s(item['productName']).isNotEmpty ? _s(item['productName']) : _s(item['name']);
                      final variant = _s(item['variantName']);
                      final sku = _s(item['sku']);
                      final qty = _i(item['qty'] ?? item['quantity'] ?? 1);
                      final price = _n(item['price'] ?? item['unitPrice'] ?? 0);
                      final lineTotal = price * qty;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  '),
                            Expanded(
                              child: Text(
                                [
                                  name.isEmpty ? '未命名商品' : name,
                                  if (variant.isNotEmpty) '($variant)',
                                  if (sku.isNotEmpty) 'SKU:$sku',
                                  '×$qty',
                                ].join(' '),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(_moneyFmt.format(lineTotal), style: const TextStyle(fontWeight: FontWeight.w900)),
                          ],
                        ),
                      );
                    }),

                  const Divider(height: 22),
                  Text('金額彙總', style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  if (totals.isNotEmpty) ...[
                    _kv('Subtotal', _moneyFmt.format(_n(totals['subtotal']))),
                    _kv('ShippingFee', _moneyFmt.format(_n(totals['shippingFee']))),
                    _kv('Discount', _moneyFmt.format(_n(totals['discount']))),
                    _kv('Total', _moneyFmt.format(_n(totals['total'])), bold: true),
                  ] else ...[
                    _kv('Total', _moneyFmt.format(payTotal), bold: true),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),

            // ✅ Admin action: update shipping info
            FilledButton.tonalIcon(
              onPressed: () async {
                Navigator.pop(context);
                await _updateShippingInfo(
                  docRef: doc.reference,
                  courier: courierCtrl.text.trim(),
                  trackingNo: trackingCtrl.text.trim(),
                );
              },
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('更新物流'),
            ),

            // ✅ Admin action: mark paid
            FilledButton.tonalIcon(
              onPressed: () async {
                Navigator.pop(context);
                await _markPaid(doc.reference);
              },
              icon: const Icon(Icons.payments_outlined),
              label: const Text('標記已付款'),
            ),

            // ✅ Admin action: mark shipped
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _markShipped(doc.reference);
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('標記已出貨'),
            ),
          ],
        );
      },
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700))),
          Expanded(child: Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700))),
        ],
      ),
    );
  }

  // -------------------------
  // Admin Ops
  // -------------------------
  Future<void> _updateShippingInfo({
    required DocumentReference<Map<String, dynamic>> docRef,
    required String courier,
    required String trackingNo,
  }) async {
    try {
      await docRef.update({
        'shippingInfo.courier': courier,
        'shippingInfo.trackingNo': trackingNo,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已更新物流資訊')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新物流失敗：$e')));
    }
  }

  Future<void> _markPaid(DocumentReference<Map<String, dynamic>> docRef) async {
    final ok = await _confirm(
      title: '標記已付款',
      message: '確定要將此訂單標記為已付款（payment.status=paid）嗎？',
      confirmText: '確認',
    );
    if (ok != true) return;

    try {
      await docRef.update({
        'status': _osPaid, // 若你不想動 status，可刪掉這行
        'payment.status': _psPaid,
        'payment.paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已標記為已付款')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('標記付款失敗：$e')));
    }
  }

  Future<void> _markShipped(DocumentReference<Map<String, dynamic>> docRef) async {
    final ok = await _confirm(
      title: '標記已出貨',
      message: '確定要將此訂單標記為已出貨（shippingInfo.status=shipped）嗎？',
      confirmText: '確認',
    );
    if (ok != true) return;

    try {
      await docRef.update({
        'status': _osShipped, // 若你不想動 status，可刪掉這行
        'shippingInfo.status': _ssShipped,
        'shippingInfo.shippedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已標記為已出貨')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('標記出貨失敗：$e')));
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
  }) {
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

// ============================================================================
// Error View
// ============================================================================
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
