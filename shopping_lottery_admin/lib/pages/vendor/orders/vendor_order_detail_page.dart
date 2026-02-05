// lib/pages/vendor/orders/vendor_order_detail_page.dart
//
// ✅ VendorOrderDetailPage（最終完整版｜Vendor 訂單詳情｜僅出貨欄位可編輯）
// ------------------------------------------------------------
// - Vendor 僅能：填寫/更新 shipping（carrier, trackingNo, note）
// - 狀態：若目前為 paid 才允許「確認出貨」
// - 出貨寫入：orders/{orderId}
//   - status: "shipping"
//   - shipping: { carrier, trackingNo, note, shippedAt }
//   - logs: arrayUnion shipping log
// - 寫入後：交由 Cloud Function orderShippingNotify → 建立 notifications → FCM 推播
//
// 依賴：cloud_firestore, firebase_auth, intl, flutter/material
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VendorOrderDetailPage extends StatelessWidget {
  final String orderId;
  final String vendorId;

  const VendorOrderDetailPage({
    super.key,
    required this.orderId,
    required this.vendorId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Scaffold(body: Center(child: Text('讀取訂單失敗')));
        }
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.data!.exists) {
          return const Scaffold(body: Center(child: Text('訂單不存在')));
        }

        final data = snap.data!.data() ?? {};
        return _VendorOrderDetailContent(orderId: orderId, vendorId: vendorId, data: data);
      },
    );
  }
}

class _VendorOrderDetailContent extends StatefulWidget {
  final String orderId;
  final String vendorId;
  final Map<String, dynamic> data;

  const _VendorOrderDetailContent({
    required this.orderId,
    required this.vendorId,
    required this.data,
  });

  @override
  State<_VendorOrderDetailContent> createState() => _VendorOrderDetailContentState();
}

class _VendorOrderDetailContentState extends State<_VendorOrderDetailContent> {
  final _moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

  late final TextEditingController _carrierCtrl;
  late final TextEditingController _trackingCtrl;
  late final TextEditingController _noteCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final shipping = (widget.data['shipping'] as Map?) ?? {};
    _carrierCtrl = TextEditingController(text: (shipping['carrier'] ?? '').toString());
    _trackingCtrl = TextEditingController(text: (shipping['trackingNo'] ?? '').toString());
    _noteCtrl = TextEditingController(text: (shipping['note'] ?? '').toString());
  }

  @override
  void didUpdateWidget(covariant _VendorOrderDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 若訂單資料更新（例如 shipping 在別處被寫入），同步輸入框
    final oldShipping = (oldWidget.data['shipping'] as Map?) ?? {};
    final newShipping = (widget.data['shipping'] as Map?) ?? {};
    if (oldShipping.toString() != newShipping.toString()) {
      _carrierCtrl.text = (newShipping['carrier'] ?? '').toString();
      _trackingCtrl.text = (newShipping['trackingNo'] ?? '').toString();
      _noteCtrl.text = (newShipping['note'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _carrierCtrl.dispose();
    _trackingCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    final orderNo = (data['orderNo'] ?? widget.orderId).toString();
    final status = (data['status'] ?? '').toString();
    final createdAt = (data['createdAt'] is Timestamp)
        ? (data['createdAt'] as Timestamp).toDate()
        : null;

    final totalAmount = _num(data['totalAmount']);
    final discountAmount = _num(data['discountAmount']);
    final finalAmount = _num(data['finalAmount']);

    final items = (data['items'] is List) ? (data['items'] as List) : const [];
    final myItems = _filterVendorItems(items, widget.vendorId);

    final canShip = status == 'paid' && !_saving;

    return Scaffold(
      appBar: AppBar(
        title: Text('訂單詳情（Vendor）｜$orderNo', style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (canShip)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ElevatedButton(
                onPressed: () => _confirmShip(context),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('確認出貨', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            '訂單狀態',
            Row(
              children: [
                Chip(
                  label: Text(status),
                  backgroundColor: Colors.blue.withOpacity(0.12),
                ),
                const SizedBox(width: 10),
                if (createdAt != null) Text(DateFormat('yyyy/MM/dd HH:mm').format(createdAt)),
              ],
            ),
          ),
          _section('金額（全單）', _amountBlock(totalAmount, discountAmount, finalAmount)),
          _section('本 Vendor 商品', _itemsBlock(myItems)),
          _section('出貨資訊（可編輯）', _shippingEditor(status)),
          _section('操作紀錄（只讀）', _logsBlock((data['logs'] as List?) ?? const [])),
        ],
      ),
    );
  }

  // =========================
  // UI blocks
  // =========================

  Widget _section(String title, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _amountBlock(num total, num discount, num finalAmount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kv('商品總額', _moneyFmt.format(total)),
        _kv('折扣', _moneyFmt.format(discount)),
        const Divider(),
        _kv('實付金額', _moneyFmt.format(finalAmount), highlight: true),
      ],
    );
  }

  Widget _itemsBlock(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const Text('此訂單沒有屬於你的商品');

    return Column(
      children: items.map((i) {
        final name = (i['name'] ?? i['title'] ?? '-').toString();
        final qty = (i['qty'] ?? i['quantity'] ?? 1);
        final price = _num(i['price']);
        return ListTile(
          dense: true,
          title: Text(name),
          subtitle: Text('x$qty'),
          trailing: Text(_moneyFmt.format(price)),
        );
      }).toList(),
    );
  }

  Widget _shippingEditor(String status) {
    final shipping = (widget.data['shipping'] as Map?) ?? {};
    final shippedAt = (shipping['shippedAt'] is Timestamp)
        ? (shipping['shippedAt'] as Timestamp).toDate()
        : null;

    final locked = status != 'paid' || _saving; // paid 才允許填寫並送出

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status != 'paid')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              status == 'shipping'
                  ? '此訂單已出貨，僅供檢視'
                  : '此訂單狀態為 $status，無法進行出貨操作',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        TextField(
          controller: _carrierCtrl,
          enabled: !locked,
          decoration: const InputDecoration(
            labelText: '物流公司（carrier）',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _trackingCtrl,
          enabled: !locked,
          decoration: const InputDecoration(
            labelText: '追蹤編號（trackingNo）',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _noteCtrl,
          enabled: !locked,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: '備註（note）',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        if (shippedAt != null) Text('出貨時間：${DateFormat('yyyy/MM/dd HH:mm').format(shippedAt)}'),
        if (status == 'paid')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '按「確認出貨」後將寫入 shipping 並觸發通知（買家 + Admin）。',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _logsBlock(List logs) {
    if (logs.isEmpty) return const Text('尚無操作紀錄');

    final sorted = [...logs];
    try {
      sorted.sort((a, b) {
        final ta = a is Map && a['at'] is Timestamp ? a['at'] as Timestamp : Timestamp(0, 0);
        final tb = b is Map && b['at'] is Timestamp ? b['at'] as Timestamp : Timestamp(0, 0);
        return tb.compareTo(ta);
      });
    } catch (_) {}

    return Column(
      children: sorted.map<Widget>((l) {
        final m = (l is Map) ? l : <String, dynamic>{};
        final at = m['at'] is Timestamp ? (m['at'] as Timestamp).toDate() : null;
        return ListTile(
          dense: true,
          title: Text((m['action'] ?? '-').toString()),
          subtitle: Text((m['note'] ?? '').toString()),
          trailing: at == null ? null : Text(DateFormat('MM/dd HH:mm').format(at)),
        );
      }).toList(),
    );
  }

  Widget _kv(String k, String v, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k)),
          Text(
            v,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.w900 : FontWeight.normal,
              color: highlight ? Colors.redAccent : null,
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // Actions
  // =========================

  Future<void> _confirmShip(BuildContext context) async {
    final carrier = _carrierCtrl.text.trim();
    final trackingNo = _trackingCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    if (carrier.isEmpty || trackingNo.isEmpty) {
      _toast(context, '請填寫物流公司與追蹤編號');
      return;
    }

    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'system';
      final ref = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('訂單不存在');

        final data = snap.data() as Map<String, dynamic>;
        final status = (data['status'] ?? '').toString();

        // Vendor 僅允許 paid → shipping（符合你之前的狀態機）
        if (status != 'paid') {
          throw Exception('只有已付款訂單才能出貨（目前：$status）');
        }

        // 再次確認 vendor 權限（保險）
        final singleVendorId = (data['vendorId'] ?? '').toString();
        final vendorIds = (data['vendorIds'] is List)
            ? (data['vendorIds'] as List).map((e) => e.toString()).toList()
            : <String>[];

        final allowed = singleVendorId == widget.vendorId || vendorIds.contains(widget.vendorId);
        if (!allowed) {
          throw Exception('你無權限操作此訂單');
        }

        tx.update(ref, {
          'status': 'shipping',
          'shipping': {
            'carrier': carrier,
            'trackingNo': trackingNo,
            'note': note,
            'shippedAt': FieldValue.serverTimestamp(),
          },
          'logs': FieldValue.arrayUnion([
            {
              'action': 'shipping',
              'by': uid,
              'note': '$carrier｜$trackingNo${note.isNotEmpty ? '｜$note' : ''}',
              'at': Timestamp.now(),
            }
          ]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      _toast(context, '已標記出貨，通知將自動發送');
    } catch (e) {
      _toast(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // =========================
  // Helpers
  // =========================

  num _num(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  List<Map<String, dynamic>> _filterVendorItems(List items, String vendorId) {
    final out = <Map<String, dynamic>>[];
    for (final it in items) {
      if (it is! Map) continue;
      final m = Map<String, dynamic>.from(it as Map);
      final vid = (m['vendorId'] ?? '').toString();
      if (vid == vendorId) out.add(m);
    }
    return out;
  }
}
