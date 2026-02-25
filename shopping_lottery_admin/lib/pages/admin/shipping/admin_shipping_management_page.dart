// lib/pages/admin/shipping/admin_shipping_management_page.dart
// =====================================================
// ✅ AdminShippingManagementPage（出貨管理｜修正版完整版｜可編譯）
// - ✅ 修正 curly_braces_in_flow_control_structures：所有 if 都有大括號
// - ✅ 避免 control_flow_in_finally：本檔案不在 finally 使用 return
// - ✅ withOpacity deprecated → withValues(alpha:)
// - ✅ DropdownButtonFormField deprecated: value → initialValue
//
// Firestore（預設）
// - orders/{orderId}
//   - createdAt: Timestamp
//   - userId: String
//   - status: String（可有可無）
//   - finalAmount/total/amount: num
//   - shippingStatus: pending/shipped/delivered（可無，無則視為 pending）
//   - carrier: String
//   - trackingNumber: String
//   - shippedAt: Timestamp
//   - deliveredAt: Timestamp
//   - shippingNote: String（管理員備註）
// =====================================================

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

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _keyword = '';

  _ShipFilter _filter = _ShipFilter.pending;

  final _df = DateFormat('yyyy/MM/dd HH:mm');
  final _money = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }
      setState(() => _keyword = v.trim().toLowerCase());
    });
  }

  Query<Map<String, dynamic>> _baseQuery() {
    // ✅ 用 createdAt 排序（若你沒有 createdAt，改成 FieldPath.documentId）
    return _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(300);
  }

  bool _hitKeyword(Map<String, dynamic> m, String orderId) {
    if (_keyword.isEmpty) {
      return true;
    }

    final id = orderId.toLowerCase();
    final userId = (m['userId'] ?? m['uid'] ?? '').toString().toLowerCase();
    final phone = (m['phone'] ?? '').toString().toLowerCase();
    final email = (m['email'] ?? '').toString().toLowerCase();
    final carrier = (m['carrier'] ?? '').toString().toLowerCase();
    final tracking = (m['trackingNumber'] ?? '').toString().toLowerCase();
    final status = (m['status'] ?? '').toString().toLowerCase();
    final shipStatus = (m['shippingStatus'] ?? '')
        .toString()
        .toLowerCase()
        .trim();

    return id.contains(_keyword) ||
        userId.contains(_keyword) ||
        phone.contains(_keyword) ||
        email.contains(_keyword) ||
        carrier.contains(_keyword) ||
        tracking.contains(_keyword) ||
        status.contains(_keyword) ||
        shipStatus.contains(_keyword);
  }

  String _shipStatusOf(Map<String, dynamic> m) {
    final s = (m['shippingStatus'] ?? '').toString().trim().toLowerCase();
    if (s.isEmpty) {
      return 'pending';
    }
    return s;
  }

  bool _hitFilter(Map<String, dynamic> m) {
    final s = _shipStatusOf(m);
    switch (_filter) {
      case _ShipFilter.all:
        return true;
      case _ShipFilter.pending:
        return s == 'pending';
      case _ShipFilter.shipped:
        return s == 'shipped';
      case _ShipFilter.delivered:
        return s == 'delivered';
    }
  }

  Color _statusColor(ColorScheme cs, String shipStatus) {
    switch (shipStatus) {
      case 'delivered':
        return cs.tertiary;
      case 'shipped':
        return cs.primary;
      default:
        return cs.error; // pending
    }
  }

  String _statusLabel(String shipStatus) {
    switch (shipStatus) {
      case 'delivered':
        return '已送達';
      case 'shipped':
        return '已出貨';
      default:
        return '待出貨';
    }
  }

  String _fmtTs(dynamic v) {
    if (v is Timestamp) {
      return _df.format(v.toDate());
    }
    return '-';
  }

  num _asNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse((v ?? '').toString()) ?? 0;
  }

  // =====================================================
  // Actions
  // =====================================================
  Future<void> _markShipped({
    required String orderId,
    required Map<String, dynamic> m,
  }) async {
    final initialCarrier = (m['carrier'] ?? '').toString();
    final initialTracking = (m['trackingNumber'] ?? '').toString();

    final res = await showDialog<_ShipEditResult>(
      context: context,
      builder: (_) => _ShipEditDialog(
        title: '設定出貨資訊',
        initialCarrier: initialCarrier,
        initialTracking: initialTracking,
      ),
    );

    if (res == null) {
      return;
    }

    try {
      await _db.collection('orders').doc(orderId).update({
        'shippingStatus': 'shipped',
        'carrier': res.carrier.trim(),
        'trackingNumber': res.trackingNumber.trim(),
        'shippedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已更新為：已出貨')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新出貨失敗：$e')));
    }
  }

  Future<void> _markDelivered({required String orderId}) async {
    final ok = await _confirm(
      title: '標記送達',
      message: '確定要將訂單標記為「已送達」？\n訂單：$orderId',
      confirmText: '確認送達',
    );

    if (ok != true) {
      return;
    }

    try {
      await _db.collection('orders').doc(orderId).update({
        'shippingStatus': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已更新為：已送達')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新送達失敗：$e')));
    }
  }

  Future<void> _editShippingNote({
    required String orderId,
    required Map<String, dynamic> m,
  }) async {
    final initial = (m['shippingNote'] ?? '').toString();

    final text = await _askText(
      title: '出貨備註（管理員）',
      hint: '輸入備註（可留空）',
      initial: initial,
      confirmText: '儲存',
    );

    if (text == null) {
      return;
    }

    try {
      await _db.collection('orders').doc(orderId).update({
        'shippingNote': text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('備註已更新')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新備註失敗：$e')));
    }
  }

  void _openOrderDetail(String orderId) {
    try {
      Navigator.pushNamed(
        context,
        '/admin_order_detail',
        arguments: {'orderId': orderId},
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('尚未註冊路由：/admin_order_detail')),
      );
    }
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('出貨管理'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _filters(cs),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _baseQuery().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _ErrorView(
                    title: '讀取失敗',
                    message: snap.error.toString(),
                    hint:
                        '若你 orders 沒有 createdAt，請把 query 改成 orderBy(FieldPath.documentId)。',
                    onRetry: () => setState(() {}),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs
                    .where((d) => _hitFilter(d.data()))
                    .where((d) => _hitKeyword(d.data(), d.id))
                    .toList(growable: false);

                if (docs.isEmpty) {
                  return const _EmptyView(
                    title: '沒有資料',
                    message: '目前條件下沒有出貨訂單。',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final m = d.data();
                    final orderId = d.id;

                    final shipStatus = _shipStatusOf(m);
                    final statusColor = _statusColor(cs, shipStatus);

                    final createdAt = _fmtTs(m['createdAt']);
                    final shippedAt = _fmtTs(m['shippedAt']);
                    final deliveredAt = _fmtTs(m['deliveredAt']);

                    final amount = _asNum(
                      m['finalAmount'] ?? m['total'] ?? m['amount'] ?? 0,
                    );
                    final amountText = _money.format(amount);

                    final userId = (m['userId'] ?? m['uid'] ?? '').toString();
                    final carrier = (m['carrier'] ?? '').toString();
                    final tracking = (m['trackingNumber'] ?? '').toString();
                    final note = (m['shippingNote'] ?? '').toString();

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final isNarrow = c.maxWidth < 720;

                            final statusChip = Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _withOpacity(statusColor, 0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _withOpacity(statusColor, 0.28),
                                ),
                              ),
                              child: Text(
                                _statusLabel(shipStatus),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            );

                            final titleLine = Row(
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
                                statusChip,
                              ],
                            );

                            final subLine = Text(
                              [
                                if (userId.isNotEmpty) 'userId：$userId',
                                '金額：$amountText',
                                '建立：$createdAt',
                              ].join('  •  '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: cs.onSurfaceVariant),
                            );

                            final shipLine = Text(
                              [
                                if (carrier.isNotEmpty) '物流：$carrier',
                                if (tracking.isNotEmpty) '追蹤：$tracking',
                                if (shipStatus == 'shipped' ||
                                    shipStatus == 'delivered')
                                  '出貨：$shippedAt',
                                if (shipStatus == 'delivered')
                                  '送達：$deliveredAt',
                              ].where((e) => e.trim().isNotEmpty).join('  •  '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: cs.onSurfaceVariant),
                            );

                            final noteLine = note.isEmpty
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      '備註：$note',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );

                            final btnDetail = OutlinedButton.icon(
                              onPressed: () => _openOrderDetail(orderId),
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('訂單詳情'),
                            );

                            final btnNote = OutlinedButton.icon(
                              onPressed: () =>
                                  _editShippingNote(orderId: orderId, m: m),
                              icon: const Icon(Icons.edit_note, size: 18),
                              label: const Text('備註'),
                            );

                            final btnShip = FilledButton.icon(
                              onPressed: shipStatus == 'delivered'
                                  ? null
                                  : () => _markShipped(orderId: orderId, m: m),
                              icon: const Icon(Icons.local_shipping_outlined),
                              label: const Text('設定出貨'),
                            );

                            final btnDelivered = FilledButton.tonalIcon(
                              onPressed: shipStatus == 'shipped'
                                  ? () => _markDelivered(orderId: orderId)
                                  : null,
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('標記送達'),
                            );

                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  titleLine,
                                  const SizedBox(height: 6),
                                  subLine,
                                  const SizedBox(height: 6),
                                  shipLine,
                                  noteLine,
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      btnShip,
                                      btnDelivered,
                                      btnNote,
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
                                      titleLine,
                                      const SizedBox(height: 6),
                                      subLine,
                                      const SizedBox(height: 6),
                                      shipLine,
                                      noteLine,
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
                                      btnShip,
                                      const SizedBox(height: 10),
                                      btnDelivered,
                                      const SizedBox(height: 10),
                                      btnNote,
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

  Widget _filters(ColorScheme cs) {
    final search = TextField(
      controller: _searchCtrl,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: '搜尋：orderId / userId / phone / email / 物流 / 追蹤 / 狀態',
        isDense: true,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );

    final filterDropdown = DropdownButtonFormField<_ShipFilter>(
      key: ValueKey('shipFilter_${_filter.name}'),
      initialValue: _filter,
      items: _ShipFilter.values
          .map(
            (e) =>
                DropdownMenuItem<_ShipFilter>(value: e, child: Text(e.label)),
          )
          .toList(),
      onChanged: (v) {
        if (v == null) {
          return;
        }
        setState(() => _filter = v);
      },
      isExpanded: true,
      decoration: InputDecoration(
        labelText: '出貨狀態',
        isDense: true,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 720;

          if (isNarrow) {
            return Column(
              children: [search, const SizedBox(height: 10), filterDropdown],
            );
          }

          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 10),
              SizedBox(width: 260, child: filterDropdown),
            ],
          );
        },
      ),
    );
  }

  // =====================================================
  // Dialog helpers
  // =====================================================
  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool isDanger = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
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
              backgroundColor: isDanger ? cs.error : null,
              foregroundColor: isDanger ? cs.onError : null,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  Future<String?> _askText({
    required String title,
    required String hint,
    required String initial,
    required String confirmText,
    bool isDanger = false,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final ctrl = TextEditingController(text: initial);

    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
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
            style: FilledButton.styleFrom(
              backgroundColor: isDanger ? cs.error : null,
              foregroundColor: isDanger ? cs.onError : null,
            ),
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    ctrl.dispose();
    return res;
  }
}

// =====================================================
// Enums / Dialogs / Views
// =====================================================
enum _ShipFilter {
  all('全部'),
  pending('待出貨'),
  shipped('已出貨'),
  delivered('已送達');

  final String label;
  const _ShipFilter(this.label);
}

class _ShipEditResult {
  final String carrier;
  final String trackingNumber;

  _ShipEditResult({required this.carrier, required this.trackingNumber});
}

class _ShipEditDialog extends StatefulWidget {
  final String title;
  final String initialCarrier;
  final String initialTracking;

  const _ShipEditDialog({
    required this.title,
    required this.initialCarrier,
    required this.initialTracking,
  });

  @override
  State<_ShipEditDialog> createState() => _ShipEditDialogState();
}

class _ShipEditDialogState extends State<_ShipEditDialog> {
  late final TextEditingController _carrier = TextEditingController(
    text: widget.initialCarrier,
  );
  late final TextEditingController _tracking = TextEditingController(
    text: widget.initialTracking,
  );

  @override
  void dispose() {
    _carrier.dispose();
    _tracking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _carrier,
              decoration: InputDecoration(
                labelText: '物流商（例如：黑貓/新竹/郵局）',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tracking,
              decoration: InputDecoration(
                labelText: '追蹤碼/託運單號',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '儲存後會將 shippingStatus 設為 shipped 並寫入 shippedAt。',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(
              context,
              _ShipEditResult(
                carrier: _carrier.text,
                trackingNumber: _tracking.text,
              ),
            );
          },
          icon: const Icon(Icons.save),
          label: const Text('儲存'),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyView({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
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
