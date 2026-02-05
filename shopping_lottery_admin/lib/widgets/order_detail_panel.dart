// lib/widgets/order_detail_panel.dart
//
// ✅ OrderDetailPanel（完整版・可編譯強化版）
// ------------------------------------------------------------
// - 給 OrdersPage 使用：寬螢幕右側面板 / 窄螢幕 Dialog 內容
// - 顯示：訂單摘要、買家資訊、付款資訊、商品明細、物流資訊、Timeline
// - 支援：更新訂單 status、更新物流 shipping（carrier/tracking/address...）
// - 權限：
//   - Admin：可改所有狀態、可改所有物流欄位
//   - Vendor：僅能改物流欄位 +（可選）將狀態改為 shipped / delivered / completed
//     並且 vendorId 必須存在於 orders.vendorIds 內才可編輯
//
// Firestore assumed: orders/{orderId}
// - status: String
// - buyerEmail / buyerName / buyerPhone
// - total/amount/payment.amount
// - payment: { status, provider, method, amount, updatedAt }
// - items: List<Map> (title/name, qty/quantity, price, subtotal, productId, sku...)
// - shipping: { name, phone, address, carrier, trackingNo, note, status, updatedAt }
// - vendorIds: List<String>
// - timeline: Array<{type, at, msg, ...}>
//
// 依賴：cloud_firestore, flutter/material.dart, flutter/services.dart
// ------------------------------------------------------------

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OrderDetailPanel extends StatefulWidget {
  const OrderDetailPanel({
    super.key,
    required this.order,
    required this.isAdmin,
    required this.vendorId,
    this.onUpdated,
  });

  final Map<String, dynamic> order;
  final bool isAdmin;
  final String vendorId;
  final VoidCallback? onUpdated;

  @override
  State<OrderDetailPanel> createState() => _OrderDetailPanelState();
}

class _OrderDetailPanelState extends State<OrderDetailPanel> {
  final _db = FirebaseFirestore.instance;

  bool _savingStatus = false;
  bool _savingShipping = false;
  String? _error;

  // shipping editors
  final _shipNameCtrl = TextEditingController();
  final _shipPhoneCtrl = TextEditingController();
  final _shipAddressCtrl = TextEditingController();
  final _carrierCtrl = TextEditingController();
  final _trackingCtrl = TextEditingController();
  final _shipNoteCtrl = TextEditingController();

  // status selection
  String _status = 'unknown';

  String _s(dynamic v) => (v ?? '').toString().trim();

  String _norm(dynamic v) =>
      _s(v).toLowerCase().replaceAll(' ', '').replaceAll('_', '').replaceAll('-', '');

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic v) => v is List ? List<dynamic>.from(v) : <dynamic>[];

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(_s(v)) ?? 0;
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(_s(v)) ?? 0;
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String get _orderId => _s(widget.order['id']).isEmpty ? _s(widget.order['orderId']) : _s(widget.order['id']);

  List<String> get _vendorIds =>
      _asList(widget.order['vendorIds']).map((e) => _s(e)).where((e) => e.isNotEmpty).toList();

  bool get _vendorScopedAllowed {
    if (widget.isAdmin) return true;
    final vid = _s(widget.vendorId);
    if (vid.isEmpty) return false;
    return _vendorIds.contains(vid);
  }

  // Admin can do all; Vendor limited to shipping + a subset statuses
  static const _allStatuses = <String>[
    'draft',
    'pending_payment',
    'paid',
    'cod_pending',
    'shipped',
    'delivered',
    'completed',
    'failed',
    'cancelled',
    'refunded',
  ];

  static const _vendorAllowedStatuses = <String>[
    'shipped',
    'delivered',
    'completed',
  ];

  static const _statusLabels = <String, String>{
    'draft': '草稿',
    'pending_payment': '待付款',
    'paid': '已付款',
    'cod_pending': '貨到待處理',
    'shipped': '已出貨',
    'delivered': '已到貨',
    'completed': '已完成',
    'failed': '付款失敗',
    'cancelled': '已取消',
    'refunded': '已退款',
    'unknown': '未知',
  };

  @override
  void initState() {
    super.initState();
    _hydrateFromOrder(widget.order);
  }

  @override
  void didUpdateWidget(covariant OrderDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 若切換到另一筆訂單，重刷 controllers/狀態
    if (_s(oldWidget.order['id']) != _s(widget.order['id']) ||
        jsonEncode(oldWidget.order) != jsonEncode(widget.order)) {
      _hydrateFromOrder(widget.order);
    }
  }

  void _hydrateFromOrder(Map<String, dynamic> order) {
    final shipping = _asMap(order['shipping']);
    final status = _s(order['status']);
    setState(() {
      _error = null;
      _status = status.isEmpty ? 'unknown' : status;
    });

    _shipNameCtrl.text = _s(shipping['name']);
    _shipPhoneCtrl.text = _s(shipping['phone']);
    _shipAddressCtrl.text = _s(shipping['address']);
    _carrierCtrl.text = _s(shipping['carrier']);
    _trackingCtrl.text = _s(shipping['trackingNo']);
    _shipNoteCtrl.text = _s(shipping['note']);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  Future<void> _copy(String text, {String done = '已複製'}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    _snack(done);
  }

  String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    final ss = d.second.toString().padLeft(2, '0');
    return '$y-$m-$dd $hh:$mm:$ss';
  }

  String _labelForStatus(String s) {
    final k = _norm(s);
    // normalize to underscore keys
    String key = s.trim().toLowerCase();
    if (k == 'pendingpayment') key = 'pending_payment';
    if (k == 'codpending') key = 'cod_pending';
    return _statusLabels[key] ?? s;
  }

  Color _toneForStatus(BuildContext context, String s) {
    final key = _norm(s);
    final cs = Theme.of(context).colorScheme;

    if (key == 'paid' || key == 'completed' || key == 'delivered') return cs.primary;
    if (key == 'pendingpayment' || key == 'codpending') return Colors.orange.shade700;
    if (key == 'shipped') return Colors.indigo.shade600;
    if (key == 'failed' || key == 'cancelled' || key == 'refunded') return cs.error;
    return Colors.grey.shade700;
  }

  double _pickAmount(Map<String, dynamic> o) {
    final direct = o['total'] ?? o['amount'];
    if (direct != null) return (num.tryParse('$direct') ?? 0).toDouble();
    final payment = _asMap(o['payment']);
    final a = payment['amount'];
    return (num.tryParse('$a') ?? 0).toDouble();
  }

  bool _canSetStatus(String target) {
    if (widget.isAdmin) return true;
    if (!_vendorScopedAllowed) return false;
    final t = target.trim().toLowerCase();
    return _vendorAllowedStatuses.contains(t);
  }

  Future<void> _appendUpdate({
    required Map<String, dynamic> setPayload,
    required String type,
    String? msg,
    Map<String, dynamic>? extra,
  }) async {
    final oid = _orderId;
    if (oid.isEmpty) throw StateError('orderId missing');

    final ref = _db.collection('orders').doc(oid);

    final timelineEntry = <String, dynamic>{
      'type': type,
      'at': FieldValue.serverTimestamp(),
      if (msg != null && msg.trim().isNotEmpty) 'msg': msg.trim(),
      if (extra != null) ...extra,
    };

    await ref.set(
      <String, dynamic>{
        ...setPayload,
        'updatedAt': FieldValue.serverTimestamp(),
        'timeline': FieldValue.arrayUnion([timelineEntry]),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _saveStatus() async {
    if (_orderId.isEmpty) return;
    if (!_canSetStatus(_status)) {
      setState(() => _error = '權限不足：無法修改狀態為 $_status');
      return;
    }

    setState(() {
      _savingStatus = true;
      _error = null;
    });

    try {
      final target = _status.trim().toLowerCase();

      final extras = <String, dynamic>{
        'status': target,
        'by': widget.isAdmin ? 'admin' : 'vendor',
        if (!widget.isAdmin) 'vendorId': _s(widget.vendorId),
      };

      // optional timestamps for key states
      final payload = <String, dynamic>{
        'status': target,
        if (target == 'paid') 'paidAt': FieldValue.serverTimestamp(),
        if (target == 'shipped') 'shippedAt': FieldValue.serverTimestamp(),
        if (target == 'delivered') 'deliveredAt': FieldValue.serverTimestamp(),
        if (target == 'completed') 'completedAt': FieldValue.serverTimestamp(),
        if (target == 'cancelled') 'cancelledAt': FieldValue.serverTimestamp(),
        if (target == 'refunded') 'refundedAt': FieldValue.serverTimestamp(),
        if (target == 'failed') 'failedAt': FieldValue.serverTimestamp(),
      };

      await _appendUpdate(
        setPayload: payload,
        type: 'order_status_update',
        msg: 'status -> $target',
        extra: extras,
      );

      widget.onUpdated?.call();
      _snack('已更新狀態：$target');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (!mounted) return;
      setState(() => _savingStatus = false);
    }
  }

  Future<void> _saveShipping() async {
    if (_orderId.isEmpty) return;
    if (!(_vendorScopedAllowed || widget.isAdmin)) {
      setState(() => _error = '權限不足：此訂單不屬於你的 vendor scope，無法更新物流資訊');
      return;
    }

    setState(() {
      _savingShipping = true;
      _error = null;
    });

    try {
      final existing = _asMap(widget.order['shipping']);

      final shipping = <String, dynamic>{
        ...existing,
        'name': _shipNameCtrl.text.trim(),
        'phone': _shipPhoneCtrl.text.trim(),
        'address': _shipAddressCtrl.text.trim(),
        'carrier': _carrierCtrl.text.trim(),
        'trackingNo': _trackingCtrl.text.trim(),
        'note': _shipNoteCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 讓空字串不要覆蓋成「有值但空」，你若希望保留空值可移除這段
      void clean(String k) {
        if (_s(shipping[k]).isEmpty) shipping.remove(k);
      }

      clean('name');
      clean('phone');
      clean('address');
      clean('carrier');
      clean('trackingNo');
      clean('note');

      await _appendUpdate(
        setPayload: {'shipping': shipping},
        type: 'shipping_update',
        msg: 'update shipping fields',
        extra: {
          'by': widget.isAdmin ? 'admin' : 'vendor',
          if (!widget.isAdmin) 'vendorId': _s(widget.vendorId),
          if (_s(shipping['carrier']).isNotEmpty) 'carrier': shipping['carrier'],
          if (_s(shipping['trackingNo']).isNotEmpty) 'trackingNo': shipping['trackingNo'],
        },
      );

      widget.onUpdated?.call();
      _snack('已更新物流資訊');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (!mounted) return;
      setState(() => _savingShipping = false);
    }
  }

  @override
  void dispose() {
    _shipNameCtrl.dispose();
    _shipPhoneCtrl.dispose();
    _shipAddressCtrl.dispose();
    _carrierCtrl.dispose();
    _trackingCtrl.dispose();
    _shipNoteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final oid = _orderId;
    final cs = Theme.of(context).colorScheme;

    final payment = _asMap(widget.order['payment']);
    final shipping = _asMap(widget.order['shipping']);
    final items = _asList(widget.order['items']);

    final buyerEmail = _s(widget.order['buyerEmail']);
    final buyerName = _s(widget.order['buyerName']);
    final buyerPhone = _s(widget.order['buyerPhone']);

    final currency = _s(widget.order['currency']).isEmpty ? 'TWD' : _s(widget.order['currency']);
    final total = _pickAmount(widget.order);

    final createdAt = _toDate(widget.order['createdAt']);
    final updatedAt = _toDate(widget.order['updatedAt']);

    final payStatus = _s(payment['status']);
    final payProvider = _s(payment['provider']);
    final payMethod = _s(payment['method']);

    final statusTone = _toneForStatus(context, _status);

    final canEdit = widget.isAdmin || _vendorScopedAllowed;

    final timeline = _asList(widget.order['timeline']);
    final timelineReversed = List<dynamic>.from(timeline.reversed);

    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  '訂單詳情',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: '複製訂單號',
                onPressed: oid.isEmpty ? null : () => _copy(oid, done: '已複製訂單號'),
                icon: const Icon(Icons.copy),
              ),
              IconButton(
                tooltip: '前往付款狀態',
                onPressed: oid.isEmpty
                    ? null
                    : () => Navigator.pushNamed(
                          context,
                          '/payment_status',
                          arguments: {'orderId': oid},
                        ),
                icon: const Icon(Icons.receipt_long),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (!canEdit)
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  widget.isAdmin
                      ? '提示：目前無法編輯（未知原因）'
                      : '提示：此訂單不在你的 vendorIds 範圍內（vendorId=${_s(widget.vendorId)}），僅能查看。',
                  style: TextStyle(color: cs.error),
                ),
              ),
            ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_error!, style: TextStyle(color: cs.error)),
            ),

          Expanded(
            child: ListView(
              children: [
                // Summary card
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              oid.isEmpty ? '（缺少 orderId）' : oid,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusTone.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _labelForStatus(_status),
                              style: TextStyle(color: statusTone, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _kvChip('金額', '$currency ${total.toStringAsFixed(0)}'),
                            _kvChip('付款', _s(payStatus).isEmpty ? '—' : payStatus),
                            _kvChip('Provider', _s(payProvider).isEmpty ? '—' : payProvider),
                            _kvChip('Method', _s(payMethod).isEmpty ? '—' : payMethod),
                          ],
                        ),

                        const SizedBox(height: 10),
                        if (createdAt != null || updatedAt != null)
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              if (createdAt != null) Text('建立：${_fmt(createdAt)}', style: const TextStyle(color: Colors.black54)),
                              if (updatedAt != null) Text('更新：${_fmt(updatedAt)}', style: const TextStyle(color: Colors.black54)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Status editor
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('訂單狀態', style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _status.trim().isEmpty ? 'unknown' : _status,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  for (final st in _allStatuses)
                                    DropdownMenuItem(
                                      value: st,
                                      enabled: _canSetStatus(st),
                                      child: Text('${st}（${_labelForStatus(st)}）'),
                                    ),
                                ],
                                onChanged: (!canEdit || _savingStatus)
                                    ? null
                                    : (v) {
                                        if (v == null) return;
                                        setState(() => _status = v);
                                      },
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              onPressed: (!canEdit || _savingStatus) ? null : _saveStatus,
                              icon: _savingStatus
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.save_outlined),
                              label: Text(_savingStatus ? '儲存中' : '儲存'),
                            ),
                          ],
                        ),
                        if (!widget.isAdmin)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'Vendor 權限：僅允許 shipped / delivered / completed；付款相關狀態請由管理端處理。',
                              style: TextStyle(color: Colors.black.withOpacity(0.55)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Buyer
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('買家資訊', style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        _kvRow('Email', buyerEmail.isEmpty ? '—' : buyerEmail, onCopy: buyerEmail.isEmpty ? null : () => _copy(buyerEmail)),
                        _kvRow('姓名', buyerName.isEmpty ? '—' : buyerName),
                        _kvRow('電話', buyerPhone.isEmpty ? '—' : buyerPhone, onCopy: buyerPhone.isEmpty ? null : () => _copy(buyerPhone)),
                        const SizedBox(height: 8),
                        if (_vendorIds.isNotEmpty)
                          Text('vendorIds：${_vendorIds.join(', ')}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Items
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('商品明細', style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        if (items.isEmpty)
                          const Text('（無 items 資料）', style: TextStyle(color: Colors.black54))
                        else
                          Column(
                            children: items.map((it) {
                              final m = _asMap(it);
                              final title = _s(m['title']).isNotEmpty
                                  ? _s(m['title'])
                                  : (_s(m['name']).isNotEmpty ? _s(m['name']) : '（未命名商品）');
                              final qty = _toInt(m['qty'] ?? m['quantity'] ?? 1);
                              final price = _toDouble(m['price']);
                              final subtotal = _toDouble(m['subtotal'] ?? (price * qty));
                              final pid = _s(m['productId']).isNotEmpty ? _s(m['productId']) : _s(m['id']);
                              final sku = _s(m['sku']);

                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 4,
                                            children: [
                                              Text('數量：$qty', style: const TextStyle(color: Colors.black54)),
                                              Text('單價：${price.toStringAsFixed(0)}', style: const TextStyle(color: Colors.black54)),
                                              Text('小計：${subtotal.toStringAsFixed(0)}', style: const TextStyle(color: Colors.black54)),
                                            ],
                                          ),
                                          if (pid.isNotEmpty || sku.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              [
                                                if (pid.isNotEmpty) 'productId: $pid',
                                                if (sku.isNotEmpty) 'sku: $sku',
                                              ].join('   '),
                                              style: const TextStyle(color: Colors.black54, fontSize: 12),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Shipping editor
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('物流 / 收件資訊', style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _s(shipping['address']).isEmpty ? '（尚未填寫地址）' : _s(shipping['address']),
                                style: const TextStyle(color: Colors.black54),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: _s(shipping['trackingNo']).isEmpty ? null : () => _copy(_s(shipping['trackingNo']), done: '已複製追蹤碼'),
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('複製追蹤碼'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        _field(
                          controller: _shipNameCtrl,
                          label: '收件人',
                          enabled: canEdit && !_savingShipping,
                        ),
                        const SizedBox(height: 10),
                        _field(
                          controller: _shipPhoneCtrl,
                          label: '收件電話',
                          enabled: canEdit && !_savingShipping,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 10),
                        _field(
                          controller: _shipAddressCtrl,
                          label: '地址',
                          enabled: canEdit && !_savingShipping,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                controller: _carrierCtrl,
                                label: '物流商（carrier）',
                                enabled: canEdit && !_savingShipping,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _field(
                                controller: _trackingCtrl,
                                label: '追蹤碼（trackingNo）',
                                enabled: canEdit && !_savingShipping,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _field(
                          controller: _shipNoteCtrl,
                          label: '物流備註（note）',
                          enabled: canEdit && !_savingShipping,
                          maxLines: 2,
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: (!canEdit || _savingShipping) ? null : _saveShipping,
                                icon: _savingShipping
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.local_shipping_outlined),
                                label: Text(_savingShipping ? '儲存中' : '儲存物流資訊'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        Text(
                          widget.isAdmin
                              ? 'Admin 可更新所有物流欄位。'
                              : (canEdit ? 'Vendor 可更新此訂單的物流資訊。' : 'Vendor 無法更新：此訂單不在你的 vendorIds 範圍內。'),
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Timeline
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Timeline', style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        if (timelineReversed.isEmpty)
                          const Text('（無 timeline 資料）', style: TextStyle(color: Colors.black54))
                        else
                          Column(
                            children: timelineReversed.take(25).map((e) {
                              final m = _asMap(e);
                              final type = _s(m['type']);
                              final msg = _s(m['msg']);
                              final at = _toDate(m['at']);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.fiber_manual_record, size: 10, color: Colors.black38),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(type.isEmpty ? '(unknown)' : type, style: const TextStyle(fontWeight: FontWeight.w800)),
                                          if (msg.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(msg),
                                          ],
                                          if (at != null) ...[
                                            const SizedBox(height: 2),
                                            Text(_fmt(at), style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Debug raw json
                ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 10),
                  title: const Text('Debug：Order Raw JSON', style: TextStyle(fontWeight: FontWeight.w800)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: SelectableText(
                        const JsonEncoder.withIndent('  ').convert(widget.order),
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- UI helpers ----------

  Widget _kvChip(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Text('$k：$v', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _kvRow(String k, String v, {VoidCallback? onCopy}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 92, child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(v)),
          if (onCopy != null) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: '複製',
              onPressed: onCopy,
              icon: const Icon(Icons.copy, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required bool enabled,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
