// lib/pages/admin/orders/admin_order_detail_page.dart
//
// ✅ AdminOrderDetailPage（訂單詳情｜出貨/退款整合｜完整版｜可直接編譯）
// -----------------------------------------------------------------------------
// 目的：
// - 在「訂單詳情」直接完成出貨 / 送達 / 退款同意 / 退款完成 / 駁回退款
// - 不依賴既有 OrderService（避免缺方法造成編譯失敗）
// - Firestore 直連 orders collection
//
// 相容：AdminOrderDetailPage(orderId: docId)
// 注意：若你路由不小心傳入 "{orderId}" 或 "orderId" 這種 placeholder，
// 本頁會自動偵測並避免顯示錯誤 placeholder。
// -----------------------------------------------------------------------------
//
// Firestore 建議欄位（非必須，缺了會顯示空值）：
// orders/{id}
//  - status: String
//  - createdAt: Timestamp
//  - finalAmount: num
//  - subtotal / shippingFee / discountAmount 等（可選）
//  - paymentMethod: String
//  - customerName / userName / displayName
//  - customerEmail / userEmail / phone
//  - items: [{name, quantity, price, ...}]
//
//  - shipping: { carrier, trackingNo, trackingUrl, note, shippedAt, deliveredAt }
//  - refund:   { status, amount, reason, note, requestedAt, processedAt, completedAt }
// -----------------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminOrderDetailPage extends StatefulWidget {
  final String orderId; // 預期是 orders 的 docId（main.dart 會傳進來）

  const AdminOrderDetailPage({super.key, required this.orderId});

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;

  DocumentSnapshot<Map<String, dynamic>>? _doc;
  Map<String, dynamic>? _data;

  // ===========================================================================
  // ✅ 防呆：清掉 "{orderId}" 這種 placeholder、decode uri component
  // ===========================================================================
  String get _sanitizedOrderKey {
    final raw = widget.orderId.trim();
    if (raw.isEmpty) return '';

    // 例如："{orderId}" -> "orderId"
    final m = RegExp(r'^\{(.+)\}$').firstMatch(raw);
    final cleaned = (m != null ? (m.group(1) ?? '') : raw).trim();

    // 一些 web 可能會帶 url encode
    final decoded = Uri.decodeComponent(cleaned).trim();

    // 若仍是 placeholder（常見錯誤：直接把 /detail/{orderId} 寫死）
    final lower = decoded.toLowerCase();
    if (lower == 'orderid' || lower == 'id' || lower == '{orderid}') return '';

    return decoded;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ===========================================================================
  // Load order (docId first, fallback by orderId field)
  // ===========================================================================
  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final key = _sanitizedOrderKey;

      if (key.isEmpty) {
        setState(() {
          _doc = null;
          _data = null;
        });
        return;
      }

      // 1) 先用 docId 讀
      final ref = _db.collection('orders').doc(key);
      final snap = await ref.get();

      if (snap.exists) {
        if (!mounted) return;
        setState(() {
          _doc = snap;
          _data = snap.data();
        });
        return;
      }

      // 2) fallback：如果有人傳的是 orderId 欄位（非 docId）
      final q = await _db
          .collection('orders')
          .where('orderId', isEqualTo: key)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        if (!mounted) return;
        setState(() {
          _doc = null;
          _data = null;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _doc = q.docs.first;
        _data = q.docs.first.data();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ===========================================================================
  // Firestore helpers
  // ===========================================================================
  Map<String, dynamic> _readMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _readListMap(dynamic v) {
    if (v is List) {
      return v
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return <Map<String, dynamic>>[];
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

  // ===========================================================================
  // Actions - Shipping
  // ===========================================================================
  Future<void> _editShipping() async {
    final doc = _doc;
    final data = _data;
    if (doc == null || data == null) return;

    final shipping = _readMap(data['shipping']);

    final input = await showDialog<_ShippingInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ShippingDialog(
        orderIdLabel: (data['orderId'] ?? doc.id).toString(),
        initialCarrier: (shipping['carrier'] ?? '').toString(),
        initialTrackingNo: (shipping['trackingNo'] ?? '').toString(),
        initialTrackingUrl: (shipping['trackingUrl'] ?? '').toString(),
        initialNote: (shipping['note'] ?? '').toString(),
      ),
    );

    if (input == null) return;

    try {
      final ref = _db.collection('orders').doc(doc.id);

      // 建議：填物流=「已出貨」
      await ref.set(
        {
          'status': _nextShippingStatus((data['status'] ?? '').toString()),
          'shipping': {
            'carrier': input.carrier,
            'trackingNo': input.trackingNo,
            'trackingUrl': input.trackingUrl,
            'note': input.note,
            'shippedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已更新出貨資訊')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('更新出貨失敗：$e')));
    }
  }

  String _nextShippingStatus(String current) {
    switch (current) {
      case 'delivered':
      case 'completed':
        return 'delivered';
      default:
        return 'shipped';
    }
  }

  Future<void> _markDelivered() async {
    final doc = _doc;
    if (doc == null) return;

    final ok = await _confirm(
      title: '標記送達',
      message: '確定要將此訂單標記為「已送達」？\nDocId：${doc.id}',
      confirmText: '標記送達',
    );
    if (ok != true) return;

    try {
      final ref = _db.collection('orders').doc(doc.id);
      await ref.set(
        {
          'status': 'delivered',
          'shipping': {
            'deliveredAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已標記送達')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失敗：$e')));
    }
  }

  // ===========================================================================
  // Actions - Refund
  // ===========================================================================
  Future<void> _approveRefund() async {
    final doc = _doc;
    final data = _data;
    if (doc == null || data == null) return;

    final refund = _readMap(data['refund']);
    final suggestedAmount =
        _toNum(refund['amount'] ?? data['finalAmount'] ?? data['total'])
            .toDouble();

    final input = await showDialog<_RefundInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RefundDialog(
        mode: _RefundDialogMode.approve,
        orderIdLabel: (data['orderId'] ?? doc.id).toString(),
        initialAmount: suggestedAmount,
        initialReason: (refund['reason'] ?? '').toString(),
        initialNote: (refund['note'] ?? '').toString(),
      ),
    );

    if (input == null) return;

    try {
      final ref = _db.collection('orders').doc(doc.id);
      await ref.set(
        {
          'status': 'refunding',
          'refund': {
            'status': 'refunding',
            'amount': input.amount,
            'reason': input.reason,
            'note': input.note,
            'processedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已同意退款（狀態：refunding）')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失敗：$e')));
    }
  }

  Future<void> _markRefunded() async {
    final doc = _doc;
    if (doc == null) return;

    final ok = await _confirm(
      title: '標記退款完成',
      message: '確定要將此訂單標記為「退款完成」？\nDocId：${doc.id}',
      confirmText: '退款完成',
    );
    if (ok != true) return;

    try {
      final ref = _db.collection('orders').doc(doc.id);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已標記退款完成')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失敗：$e')));
    }
  }

  Future<void> _rejectRefund() async {
    final doc = _doc;
    final data = _data;
    if (doc == null || data == null) return;

    final input = await showDialog<_RefundInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RefundDialog(
        mode: _RefundDialogMode.reject,
        orderIdLabel: (data['orderId'] ?? doc.id).toString(),
        initialAmount: 0,
        initialReason: '',
        initialNote: '',
      ),
    );

    if (input == null) return;

    try {
      final ref = _db.collection('orders').doc(doc.id);
      await ref.set(
        {
          'status': 'refund_rejected',
          'refund': {
            'status': 'refund_rejected',
            'note': input.note,
            'processedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已駁回退款')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失敗：$e')));
    }
  }

  // ===========================================================================
  // UI
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('訂單詳情', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
        ),
        body: _ErrorView(
          title: '載入失敗',
          message: _error!,
          hint: '常見原因：Firestore 權限不足 / 欄位型別不一致（createdAt 非 Timestamp）。',
          onRetry: _load,
        ),
      );
    }

    final doc = _doc;
    final data = _data;

    if (doc == null || data == null) {
      final key = _sanitizedOrderKey;
      return Scaffold(
        appBar: AppBar(
          title: const Text('訂單詳情', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              key.isEmpty
                  ? '缺少 orderId（你可能把路由寫成 /detail/{orderId} 但沒替換成真實ID）'
                  : '找不到訂單資料：$key',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
    final fmtDT = DateFormat('yyyy/MM/dd HH:mm');

    final orderIdLabel = (data['orderId'] ?? doc.id).toString().trim();
    final status = (data['status'] ?? '').toString();
    final createdAt = _toDateTime(data['createdAt']);
    final customer = (data['customerName'] ??
            data['userName'] ??
            data['displayName'] ??
            '')
        .toString();
    final email = (data['customerEmail'] ?? data['userEmail'] ?? '').toString();
    final phone = (data['phone'] ?? '').toString();

    final subtotal = _toNum(data['subtotal']);
    final shippingFee = _toNum(data['shippingFee'] ?? data['shipping']);
    final discount = _toNum(data['discountAmount'] ?? data['discount']);
    final finalAmount = _toNum(data['finalAmount'] ?? data['total']);

    final payment = (data['paymentMethod'] ?? data['payment'] ?? '').toString();

    final items = _readListMap(data['items']);
    final shipping = _readMap(data['shipping']);
    final refund = _readMap(data['refund']);

    return Scaffold(
      appBar: AppBar(
        // ✅ 修正：不再顯示 {orderId}，而是顯示真實 label
        title: Text('訂單詳情：$orderIdLabel',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
              tooltip: '重新整理',
              onPressed: _load,
              icon: const Icon(Icons.refresh)),
          IconButton(
            tooltip: '前往出貨/退款工作台',
            onPressed: () => _pushNamedSafe('/admin/orders/fulfillment'),
            icon: const Icon(Icons.dashboard_customize),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Order：$orderIdLabel',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
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
                        _kv('建立時間',
                            createdAt == null ? '-' : fmtDT.format(createdAt)),
                        _kv('付款方式', payment.isEmpty ? '-' : payment),
                        _kv('DocId', doc.id),
                      ],
                    ),
                    const Divider(height: 18),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        _kv('顧客', customer.isEmpty ? '-' : customer),
                        _kv('Email', email.isEmpty ? '-' : email),
                        _kv('電話', phone.isEmpty ? '-' : phone),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Amounts
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('金額資訊',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    _moneyRow('小計', subtotal == 0 ? '-' : fmtMoney.format(subtotal)),
                    _moneyRow('運費',
                        shippingFee == 0 ? '-' : fmtMoney.format(shippingFee)),
                    _moneyRow('折扣', discount == 0 ? '-' : fmtMoney.format(discount)),
                    const Divider(height: 18),
                    _moneyRow('應付總額', fmtMoney.format(finalAmount), strong: true),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Items
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('商品明細',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      Text('（無 items 資料）',
                          style: TextStyle(color: cs.onSurfaceVariant))
                    else
                      ...items.map((it) {
                        final name =
                            (it['name'] ?? it['title'] ?? '').toString();
                        final qty = _toNum(it['quantity'] ?? it['qty']).toInt();
                        final price = _toNum(it['price'] ?? it['unitPrice']);
                        final lineTotal = (qty > 0 ? price * qty : price);

                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(name.isEmpty ? '(未命名商品)' : name),
                          subtitle: Text(
                            '數量：$qty  單價：${price == 0 ? '-' : fmtMoney.format(price)}',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                          trailing: Text(
                            lineTotal == 0 ? '-' : fmtMoney.format(lineTotal),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Shipping
            _shippingCard(shipping),

            const SizedBox(height: 12),

            // Refund
            _refundCard(refund, suggestedAmount: finalAmount.toDouble()),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _shippingCard(Map<String, dynamic> shipping) {
    final cs = Theme.of(context).colorScheme;
    final fmtDT = DateFormat('yyyy/MM/dd HH:mm');

    final carrier = (shipping['carrier'] ?? '').toString();
    final no = (shipping['trackingNo'] ?? '').toString();
    final url = (shipping['trackingUrl'] ?? '').toString();
    final note = (shipping['note'] ?? '').toString();
    final shippedAt = _toDateTime(shipping['shippedAt']);
    final deliveredAt = _toDateTime(shipping['deliveredAt']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('出貨資訊', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _kv('物流商', carrier.isEmpty ? '-' : carrier),
                _kv('單號', no.isEmpty ? '-' : no),
              ],
            ),
            const SizedBox(height: 6),
            _kv('追蹤網址', url.isEmpty ? '-' : url),
            const SizedBox(height: 6),
            _kv('備註', note.isEmpty ? '-' : note),
            const Divider(height: 18),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _kv('出貨時間', shippedAt == null ? '-' : fmtDT.format(shippedAt)),
                _kv('送達時間', deliveredAt == null ? '-' : fmtDT.format(deliveredAt)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _editShipping,
                  icon: const Icon(Icons.local_shipping),
                  label: const Text('填寫物流 / 標記出貨'),
                ),
                OutlinedButton.icon(
                  onPressed: _markDelivered,
                  icon: const Icon(Icons.task_alt),
                  label: const Text('標記送達'),
                ),
                Text(
                  '提示：尚未上架或尚未建立測試訂單時，沒有數字是正常狀況。',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _refundCard(Map<String, dynamic> refund, {required double suggestedAmount}) {
    final cs = Theme.of(context).colorScheme;
    final fmtDT = DateFormat('yyyy/MM/dd HH:mm');

    final rStatus = (refund['status'] ?? '').toString();
    final amount = _toNum(refund['amount']).toDouble();
    final reason = (refund['reason'] ?? '').toString();
    final note = (refund['note'] ?? '').toString();
    final requestedAt = _toDateTime(refund['requestedAt']);
    final processedAt = _toDateTime(refund['processedAt']);
    final completedAt = _toDateTime(refund['completedAt']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('退款資訊', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _kv('退款狀態', rStatus.isEmpty ? '-' : rStatus),
                _kv(
                  '退款金額',
                  amount == 0
                      ? (suggestedAmount == 0 ? '-' : suggestedAmount.toStringAsFixed(0))
                      : amount.toStringAsFixed(0),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _kv('原因', reason.isEmpty ? '-' : reason),
            const SizedBox(height: 6),
            _kv('備註', note.isEmpty ? '-' : note),
            const Divider(height: 18),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _kv('申請時間', requestedAt == null ? '-' : fmtDT.format(requestedAt)),
                _kv('處理時間', processedAt == null ? '-' : fmtDT.format(processedAt)),
                _kv('完成時間', completedAt == null ? '-' : fmtDT.format(completedAt)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _approveRefund,
                  icon: const Icon(Icons.check_circle_outline), // ✅ 保證存在的 icon
                  label: const Text('同意退款'),
                ),
                OutlinedButton.icon(
                  onPressed: _markRefunded,
                  icon: const Icon(Icons.verified),
                  label: const Text('退款完成'),
                ),
                OutlinedButton.icon(
                  onPressed: _rejectRefund,
                  icon: Icon(Icons.block, color: cs.error),
                  label: Text('駁回', style: TextStyle(color: cs.error)),
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
        Text('$k：', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
        Flexible(
          child: Text(v, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _moneyRow(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700)),
          ),
          Text(value, style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700)),
        ],
      ),
    );
  }

  void _pushNamedSafe(String route, {Object? arguments}) {
    try {
      Navigator.pushNamed(context, route, arguments: arguments);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('尚未註冊路由：$route（請在 main.dart onGenerateRoute 設定）')),
      );
    }
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
  final String orderIdLabel;
  final String initialCarrier;
  final String initialTrackingNo;
  final String initialTrackingUrl;
  final String initialNote;

  const _ShippingDialog({
    required this.orderIdLabel,
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
              child: Text('Order：${widget.orderIdLabel}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
          label: const Text('保存'),
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
  final _RefundDialogMode mode;
  final String orderIdLabel;

  final double initialAmount;
  final String initialReason;
  final String initialNote;

  const _RefundDialog({
    required this.mode,
    required this.orderIdLabel,
    required this.initialAmount,
    required this.initialReason,
    required this.initialNote,
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
              child: Text('Order：${widget.orderIdLabel}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
