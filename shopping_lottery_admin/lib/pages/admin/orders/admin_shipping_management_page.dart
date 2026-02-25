// lib/pages/admin/orders/admin_shipping_management_page.dart
//
// ✅ AdminShippingManagementPage（出貨管理｜完整版｜可編譯）
// ------------------------------------------------------------
// - Firestore: orders collection
// - 篩選：shippingStatus（all/pending/packed/shipped/delivered）
// - 搜尋：orderId / userId / 收件人 / 電話 / tracking / carrier
// - 操作：
//    1) 編輯物流資訊（carrier / trackingNumber / shippingNote）
//    2) 標記已出貨（shippedAt + shippingStatus=shipped）
//    3) 標記已送達（deliveredAt + shippingStatus=delivered）
// - ✅ FIX: control_flow_in_finally（完全不在 finally 裡 return）
// - ✅ FIX: DropdownButtonFormField deprecated: value → initialValue（含 key 強制重建）
// - ✅ FIX: withOpacity deprecated → withValues(alpha:)
// - 相容 Web / 桌面 / 手機
//
// 你可以在路由註冊：
// '/admin_shipping_management': (_) => const AdminShippingManagementPage(),
//
// 注意：
// - 若你的 orders 欄位命名不同（例如 logistics/trackingNo），告訴我我直接改成你的結構。

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ✅ FIX: withOpacity deprecated → withValues(alpha: 0~1)
Color _withOpacity(Color c, double opacity01) {
  final o = opacity01.clamp(0.0, 1.0).toDouble();
  return c.withValues(alpha: o);
}

class AdminShippingManagementPage extends StatefulWidget {
  const AdminShippingManagementPage({super.key});

  @override
  State<AdminShippingManagementPage> createState() =>
      _AdminShippingManagementPageState();
}

class _AdminShippingManagementPageState
    extends State<AdminShippingManagementPage> {
  final _db = FirebaseFirestore.instance;

  final _kwCtrl = TextEditingController();
  Timer? _debounce;
  String _keyword = '';

  bool _busy = false;

  String _statusFilter = 'all';
  static const _statusOptions = <String>[
    'all',
    'pending', // 待出貨
    'packed', // 已包裝
    'shipped', // 已出貨
    'delivered', // 已送達
  ];

  final _df = DateFormat('yyyy/MM/dd HH:mm');
  final _mf = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

  @override
  void dispose() {
    _debounce?.cancel();
    _kwCtrl.dispose();
    super.dispose();
  }

  void _onKeywordChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }
      setState(() => _keyword = v.trim().toLowerCase());
    });
  }

  Query<Map<String, dynamic>> _query() {
    // 預設以 createdAt 排序，若你沒有該欄位也沒關係（缺值依序排列）
    var q = _db.collection('orders').orderBy('createdAt', descending: true);

    if (_statusFilter != 'all') {
      q = q.where('shippingStatus', isEqualTo: _statusFilter);
    }

    return q.limit(300);
  }

  bool _hit(Map<String, dynamic> d, String orderId) {
    if (_keyword.isEmpty) {
      return true;
    }

    String s(dynamic v) => (v ?? '').toString().toLowerCase();

    final userId = s(d['userId']);
    final status = s(d['status']);
    final shippingStatus = s(d['shippingStatus']);
    final carrier = s(d['carrier']);
    final tracking = s(d['trackingNumber']);
    final receiver = s(d['receiverName'] ?? d['shippingName']);
    final phone = s(d['receiverPhone'] ?? d['shippingPhone']);
    final address = s(d['receiverAddress'] ?? d['shippingAddress']);
    final note = s(d['shippingNote'] ?? d['adminNote']);

    final oid = orderId.toLowerCase();

    return oid.contains(_keyword) ||
        userId.contains(_keyword) ||
        status.contains(_keyword) ||
        shippingStatus.contains(_keyword) ||
        carrier.contains(_keyword) ||
        tracking.contains(_keyword) ||
        receiver.contains(_keyword) ||
        phone.contains(_keyword) ||
        address.contains(_keyword) ||
        note.contains(_keyword);
  }

  DateTime? _toDt(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is Timestamp) {
      return v.toDate();
    }
    if (v is DateTime) {
      return v;
    }
    if (v is int) {
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    return null;
  }

  num _asNum(dynamic v) {
    if (v is num) {
      return v;
    }
    return num.tryParse((v ?? '').toString()) ?? 0;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmText = '確認',
    bool danger = false,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: danger ? cs.error : null,
              foregroundColor: danger ? cs.onError : null,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<String?> _askText({
    required String title,
    required String hint,
    String initial = '',
    String confirmText = '儲存',
  }) async {
    final c = TextEditingController(text: initial);
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: c,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    c.dispose();
    return res;
  }

  // ===========================================================
  // Actions (no "return" inside finally)
  // ===========================================================
  Future<void> _updateShippingInfo({
    required String orderId,
    required String carrier,
    required String trackingNumber,
    required String shippingNote,
  }) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);

    Object? err;
    try {
      await _db.collection('orders').doc(orderId).update({
        'carrier': carrier.trim(),
        'trackingNumber': trackingNumber.trim(),
        'shippingNote': shippingNote.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      err = e;
    }

    if (mounted) {
      setState(() => _busy = false);
    }

    if (err != null) {
      _snack('更新物流資訊失敗：$err');
      return;
    }
    _snack('已更新物流資訊');
  }

  Future<void> _markShipped({
    required String orderId,
    required String carrier,
    required String trackingNumber,
  }) async {
    if (_busy) {
      return;
    }

    final ok = await _confirm(
      title: '標記已出貨',
      message: '確定標記此訂單已出貨嗎？\norderId: $orderId',
      confirmText: '標記',
    );
    if (!ok) {
      return;
    }

    setState(() => _busy = true);

    Object? err;
    try {
      await _db.collection('orders').doc(orderId).update({
        'shippingStatus': 'shipped',
        'shippedAt': FieldValue.serverTimestamp(),
        if (carrier.trim().isNotEmpty) 'carrier': carrier.trim(),
        if (trackingNumber.trim().isNotEmpty)
          'trackingNumber': trackingNumber.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      err = e;
    }

    if (mounted) {
      setState(() => _busy = false);
    }

    if (err != null) {
      _snack('標記出貨失敗：$err');
      return;
    }
    _snack('已標記已出貨');
  }

  Future<void> _markDelivered({required String orderId}) async {
    if (_busy) {
      return;
    }

    final ok = await _confirm(
      title: '標記已送達',
      message: '確定標記此訂單已送達嗎？\norderId: $orderId',
      confirmText: '標記',
    );
    if (!ok) {
      return;
    }

    setState(() => _busy = true);

    Object? err;
    try {
      await _db.collection('orders').doc(orderId).update({
        'shippingStatus': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      err = e;
    }

    if (mounted) {
      setState(() => _busy = false);
    }

    if (err != null) {
      _snack('標記送達失敗：$err');
      return;
    }
    _snack('已標記已送達');
  }

  Future<void> _openEditShippingDialog({
    required String orderId,
    required String carrier,
    required String trackingNumber,
    required String shippingNote,
  }) async {
    final carrierText = await _askText(
      title: '編輯物流資訊（1/3）',
      hint: 'carrier（例如：黑貓 / 新竹物流 / 郵局）',
      initial: carrier,
      confirmText: '下一步',
    );
    if (carrierText == null) {
      return;
    }

    final trackingText = await _askText(
      title: '編輯物流資訊（2/3）',
      hint: 'trackingNumber（物流單號）',
      initial: trackingNumber,
      confirmText: '下一步',
    );
    if (trackingText == null) {
      return;
    }

    final noteText = await _askText(
      title: '編輯物流資訊（3/3）',
      hint: 'shippingNote（備註，可留空）',
      initial: shippingNote,
      confirmText: '儲存',
    );
    if (noteText == null) {
      return;
    }

    await _updateShippingInfo(
      orderId: orderId,
      carrier: carrierText,
      trackingNumber: trackingText,
      shippingNote: noteText,
    );
  }

  // ===========================================================
  // UI
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('出貨管理'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _busy ? null : () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: LayoutBuilder(
              builder: (context, c) {
                final isNarrow = c.maxWidth < 720;

                final kw = TextField(
                  controller: _kwCtrl,
                  onChanged: _onKeywordChanged,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: '搜尋：orderId / userId / 收件人 / 電話 / 單號 / 物流',
                    isDense: true,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                );

                final status = DropdownButtonFormField<String>(
                  key: ValueKey('shipStatus_$_statusFilter'),
                  initialValue: _statusOptions.contains(_statusFilter)
                      ? _statusFilter
                      : 'all',
                  items: _statusOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (v) {
                          setState(() => _statusFilter = v ?? 'all');
                        },
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'shippingStatus',
                    isDense: true,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    children: [kw, const SizedBox(height: 10), status],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: kw),
                    const SizedBox(width: 10),
                    SizedBox(width: 260, child: status),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('讀取失敗：${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs
                    .where((d) => _hit(d.data(), d.id))
                    .toList(growable: false);

                if (docs.isEmpty) {
                  return const Center(child: Text('沒有符合條件的訂單'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    final orderId = doc.id;

                    final userId = (d['userId'] ?? '').toString().trim();
                    final status = (d['status'] ?? '').toString().trim();
                    final shipStatus = (d['shippingStatus'] ?? 'pending')
                        .toString()
                        .trim();

                    final carrier = (d['carrier'] ?? '').toString().trim();
                    final tracking = (d['trackingNumber'] ?? '')
                        .toString()
                        .trim();
                    final note = (d['shippingNote'] ?? '').toString().trim();

                    final receiver =
                        (d['receiverName'] ?? d['shippingName'] ?? '')
                            .toString()
                            .trim();
                    final phone =
                        (d['receiverPhone'] ?? d['shippingPhone'] ?? '')
                            .toString()
                            .trim();
                    final address =
                        (d['receiverAddress'] ?? d['shippingAddress'] ?? '')
                            .toString()
                            .trim();

                    final createdAt = _toDt(d['createdAt']);
                    final createdText = createdAt == null
                        ? '-'
                        : _df.format(createdAt);

                    final amount = _asNum(
                      d['finalAmount'] ?? d['total'] ?? d['amount'] ?? 0,
                    );

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final isNarrow = c.maxWidth < 820;

                            final header = Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '訂單 $orderId',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _ShipStatusChip(status: shipStatus),
                              ],
                            );

                            final line1 = Text(
                              'userId: ${userId.isEmpty ? '-' : userId}   status: ${status.isEmpty ? '-' : status}',
                              style: TextStyle(color: Colors.grey.shade700),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );

                            final line2 = Text(
                              '金額：${_mf.format(amount)}   建立：$createdText',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            );

                            final recv = Text(
                              '收件：${receiver.isEmpty ? '-' : receiver}  '
                              '電話：${phone.isEmpty ? '-' : phone}',
                              style: TextStyle(color: Colors.grey.shade700),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );

                            final addr = Text(
                              '地址：${address.isEmpty ? '-' : address}',
                              style: TextStyle(color: Colors.grey.shade700),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );

                            final shipInfo = Text(
                              '物流：${carrier.isEmpty ? '-' : carrier}   '
                              '單號：${tracking.isEmpty ? '-' : tracking}',
                              style: TextStyle(color: Colors.grey.shade700),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );

                            final noteView = note.isEmpty
                                ? const SizedBox.shrink()
                                : Text(
                                    '備註：$note',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  );

                            final btnEdit = OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _openEditShippingDialog(
                                      orderId: orderId,
                                      carrier: carrier,
                                      trackingNumber: tracking,
                                      shippingNote: note,
                                    ),
                              icon: const Icon(
                                Icons.local_shipping_outlined,
                                size: 18,
                              ),
                              label: const Text('物流資訊'),
                            );

                            final btnShipped = FilledButton.tonalIcon(
                              onPressed:
                                  _busy ||
                                      shipStatus == 'shipped' ||
                                      shipStatus == 'delivered'
                                  ? null
                                  : () => _markShipped(
                                      orderId: orderId,
                                      carrier: carrier,
                                      trackingNumber: tracking,
                                    ),
                              icon: const Icon(Icons.outbox_outlined),
                              label: const Text('已出貨'),
                            );

                            final btnDelivered = FilledButton.icon(
                              onPressed: _busy || shipStatus == 'delivered'
                                  ? null
                                  : () => _markDelivered(orderId: orderId),
                              icon: const Icon(Icons.done_all_rounded),
                              label: const Text('已送達'),
                            );

                            final btnDetail = TextButton.icon(
                              onPressed: () {
                                try {
                                  Navigator.pushNamed(
                                    context,
                                    '/admin_order_detail',
                                    arguments: {'orderId': orderId},
                                  );
                                } catch (_) {
                                  _snack('尚未註冊路由：/admin_order_detail');
                                }
                              },
                              icon: const Icon(
                                Icons.receipt_long_outlined,
                                size: 18,
                              ),
                              label: const Text('訂單詳情'),
                            );

                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  header,
                                  const SizedBox(height: 6),
                                  line1,
                                  const SizedBox(height: 6),
                                  line2,
                                  const SizedBox(height: 8),
                                  recv,
                                  const SizedBox(height: 4),
                                  addr,
                                  const SizedBox(height: 6),
                                  shipInfo,
                                  if (note.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    noteView,
                                  ],
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      btnEdit,
                                      btnShipped,
                                      btnDelivered,
                                      btnDetail,
                                    ],
                                  ),
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      header,
                                      const SizedBox(height: 6),
                                      line1,
                                      const SizedBox(height: 6),
                                      line2,
                                      const SizedBox(height: 8),
                                      recv,
                                      const SizedBox(height: 4),
                                      addr,
                                      const SizedBox(height: 6),
                                      shipInfo,
                                      if (note.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        noteView,
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 320,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      btnEdit,
                                      const SizedBox(height: 10),
                                      btnShipped,
                                      const SizedBox(height: 10),
                                      btnDelivered,
                                      const SizedBox(height: 10),
                                      btnDetail,
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShipStatusChip extends StatelessWidget {
  const _ShipStatusChip({required this.status});
  final String status;

  Color _color(String s) {
    final v = s.trim().toLowerCase();
    switch (v) {
      case 'packed':
        return Colors.orange;
      case 'shipped':
        return Colors.teal;
      case 'delivered':
        return Colors.green;
      case 'pending':
      default:
        return Colors.blueGrey;
    }
  }

  String _label(String s) {
    final v = s.trim().toLowerCase();
    switch (v) {
      case 'packed':
        return '已包裝';
      case 'shipped':
        return '已出貨';
      case 'delivered':
        return '已送達';
      case 'pending':
      default:
        return '待出貨';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _withOpacity(c, 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _withOpacity(c, 0.28)),
      ),
      child: Text(
        _label(status),
        style: TextStyle(color: c, fontWeight: FontWeight.w900),
      ),
    );
  }
}
