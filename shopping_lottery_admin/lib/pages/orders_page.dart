// lib/pages/orders_page.dart
//
// ✅ OrdersPage（最終完整版｜可編譯｜vendorIds 相容）
//
// 功能：
// - Admin：看全部訂單；Vendor：只看 orders.vendorIds contains 自己 vendorId（符合你的 Firestore rules）
// - 搜尋（orderId / buyerEmail / buyer / vendorId/vendorIds）
// - 狀態篩選（status）
// - 匯出 CSV（套用目前篩選後結果）
// - 寬螢幕：左列表＋右側詳情；窄螢幕：點擊彈窗詳情
// - Admin：可更新訂單 status，並 append 到 timeline（PaymentStatusPage 可讀到）
// - 快捷：複製訂單號、前往付款狀態頁（/payment_status arguments: orderId）
//
// Firestore 假設：orders/{orderId}
//  - status: String
//  - paymentStatus: String? (optional)
//  - total / amount / priceTotal: num
//  - createdAt: Timestamp
//  - buyerEmail / buyer: String
//  - buyerUid: String? (optional, 若你要用通知功能可用)
//  - vendorId: String? (legacy)
//  - vendorIds: List<String> (new)
//  - timeline / paymentTimeline / paymentEvents: List<Map> (optional)
//
// 依賴：
// - cloud_firestore
// - firebase_auth
// - flutter/services
// - provider
// - services/admin_gate.dart（RoleInfo）
// - utils/csv_download.dart
//
// 可選整合：NotificationService（若你要做「通知買家」功能，可自行加）
//
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';
import '../utils/csv_download.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _db = FirebaseFirestore.instance;

  Future<RoleInfo>? _roleFuture;
  String? _lastUid;

  // UI state
  String _q = '';
  String _status = 'all';
  String? _selectedId;

  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------- utils ----------------
  String _s(dynamic v) => (v ?? '').toString().trim();

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse((v ?? '').toString().trim()) ?? 0;
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _copy(String text, {String done = '已複製'}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(done), duration: const Duration(seconds: 2)),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // vendor display helpers
  List<String> _extractVendorIds(Map<String, dynamic> d) {
    final raw = d['vendorIds'];
    if (raw is List) {
      return raw.map((e) => _s(e)).where((e) => e.isNotEmpty).toList();
    }
    final legacy = _s(d['vendorId']);
    return legacy.isEmpty ? <String>[] : <String>[legacy];
  }

  String _vendorShow(Map<String, dynamic> d) {
    final ids = _extractVendorIds(d);
    if (ids.isEmpty) return '-';
    return ids.join(', ');
  }

  bool _match(Map<String, dynamic> d, String id) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;

    final buyerEmail = _s(d['buyerEmail']).toLowerCase();
    final buyer = _s(d['buyer']).toLowerCase();
    final vendor = _vendorShow(d).toLowerCase();
    final oid = id.toLowerCase();

    return oid.contains(q) || buyerEmail.contains(q) || buyer.contains(q) || vendor.contains(q);
  }

  // ---------------- query ----------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _queryStream({
    required bool isAdmin,
    required bool isVendor,
    required String vendorId,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('orders').orderBy('createdAt', descending: true);

    // ✅ Vendor：必須用 vendorIds arrayContains（符合 rules）
    if (!isAdmin && isVendor) {
      final vid = vendorId.trim();
      if (vid.isNotEmpty) {
        q = q.where('vendorIds', arrayContains: vid);
      } else {
        // vendor 沒 vendorId：直接給空 stream，避免 permission error 或拿不到資料
        return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
      }
    }

    // status filter（可讓 Firestore 幫你縮小資料量）
    if (_status != 'all') {
      q = q.where('status', isEqualTo: _status);
    }

    // 避免一次拉太多（你可視需要調大/調小）
    q = q.limit(500);

    return q.snapshots();
  }

  // ---------------- admin: update status ----------------
  Future<void> _updateOrderStatus({
    required String orderId,
    required String newStatus,
    String note = '',
  }) async {
    final oid = orderId.trim();
    final ns = newStatus.trim();
    if (oid.isEmpty || ns.isEmpty) return;

    try {
      await _db.collection('orders').doc(oid).set(
        <String, dynamic>{
          'status': ns,
          'updatedAt': FieldValue.serverTimestamp(),
          // append timeline（PaymentStatusPage 會讀 timeline/paymentTimeline/paymentEvents）
          'timeline': FieldValue.arrayUnion([
            <String, dynamic>{
              'ts': Timestamp.now(),
              'label': '狀態更新',
              'status': ns,
              if (note.trim().isNotEmpty) 'note': note.trim(),
            }
          ]),
        },
        SetOptions(merge: true),
      );

      _snack('已更新狀態：$ns');
    } catch (e) {
      _snack('更新失敗：$e');
    }
  }

  Future<void> _openStatusDialog({
    required String orderId,
    required String currentStatus,
  }) async {
    String status = currentStatus.trim().isEmpty ? 'created' : currentStatus.trim();
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('更新訂單狀態：$orderId'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: status,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '狀態（status）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'created', child: Text('created（建立）')),
                  DropdownMenuItem(value: 'pending_payment', child: Text('pending_payment（待付款）')),
                  DropdownMenuItem(value: 'paid', child: Text('paid（已付款）')),
                  DropdownMenuItem(value: 'processing', child: Text('processing（處理中）')),
                  DropdownMenuItem(value: 'shipping', child: Text('shipping（出貨中）')),
                  DropdownMenuItem(value: 'completed', child: Text('completed（完成）')),
                  DropdownMenuItem(value: 'cancelled', child: Text('cancelled（取消）')),
                  DropdownMenuItem(value: 'failed', child: Text('failed（失敗）')),
                ],
                onChanged: (v) => status = (v ?? status),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: '備註（可留空）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('更新')),
        ],
      ),
    );

    if (ok == true) {
      await _updateOrderStatus(orderId: orderId, newStatus: status, note: noteCtrl.text);
    }

    noteCtrl.dispose();
  }

  // ---------------- export csv ----------------
  Future<void> _exportCsv(List<Map<String, dynamic>> orders) async {
    if (orders.isEmpty) return;

    final headers = [
      'orderId',
      'status',
      'paymentStatus',
      'total',
      'createdAt',
      'buyerEmail',
      'buyer',
      'vendorIds',
      'vendorId_legacy',
    ];

    final buffer = StringBuffer()..writeln(headers.join(','));

    for (final o in orders) {
      final id = _s(o['id']);
      final data = (o['data'] is Map<String, dynamic>) ? (o['data'] as Map<String, dynamic>) : <String, dynamic>{};

      final createdAt = _toDate(data['createdAt']);
      final vendorIds = _extractVendorIds(data).join('|');

      final row = [
        id,
        _s(data['status']),
        _s(data['paymentStatus']),
        _toNum(data['total'] ?? data['amount'] ?? data['priceTotal']).toString(),
        createdAt?.toIso8601String() ?? '',
        _s(data['buyerEmail']),
        _s(data['buyer']),
        vendorIds,
        _s(data['vendorId']),
      ].map((e) => e.toString().replaceAll(',', '，')).join(',');

      buffer.writeln(row);
    }

    await downloadCsv('orders_export.csv', buffer.toString());
    _snack('已匯出 orders_export.csv');
  }

  // ---------------- detail sheet/panel ----------------
  Future<void> _openDetailDialog({
    required bool isAdmin,
    required String orderId,
    required Map<String, dynamic> data,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: SizedBox(
          width: 520,
          child: _OrderDetail(
            isAdmin: isAdmin,
            orderId: orderId,
            data: data,
            onCopy: _copy,
            onGoPayment: () => Navigator.pushReplacementNamed(context, '/payment_status', arguments: orderId),
            onEditStatus: () => _openStatusDialog(orderId: orderId, currentStatus: _s(data['status'])),
          ),
        ),
      ),
    );
  }

  // ---------------- build ----------------
  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;

        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (user == null) {
          return const Scaffold(body: Center(child: Text('請先登入')));
        }

        if (_roleFuture == null || _lastUid != user.uid) {
          _lastUid = user.uid;
          _roleFuture = gate.ensureAndGetRole(user, forceRefresh: false);

          // reset view state
          _selectedId = null;
          _q = '';
          _status = 'all';
          _searchCtrl.clear();
        }

        return FutureBuilder<RoleInfo>(
          future: _roleFuture,
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (roleSnap.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('訂單管理')),
                body: Center(child: Text('讀取角色失敗：${roleSnap.error}')),
              );
            }

            final info = roleSnap.data;
            final role = _s(info?.role).toLowerCase();
            final isAdmin = role == 'admin';
            final isVendor = role == 'vendor';
            final vendorId = _s(info?.vendorId);

            if (!isAdmin && !isVendor) {
              return Scaffold(
                appBar: AppBar(title: const Text('訂單管理')),
                body: Center(child: Text(_s(info?.error).isNotEmpty ? _s(info?.error) : '此帳號無後台權限')),
              );
            }

            final stream = _queryStream(isAdmin: isAdmin, isVendor: isVendor, vendorId: vendorId);

            return Scaffold(
              appBar: AppBar(
                title: Text(isAdmin ? '訂單管理（Admin）' : '訂單管理（Vendor）', overflow: TextOverflow.ellipsis),
                actions: [
                  IconButton(
                    tooltip: '匯出 CSV（目前篩選）',
                    onPressed: null, // 由下方拿到資料後再決定
                    icon: const Icon(Icons.download_outlined),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: stream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('讀取失敗：${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs;

                  // local filter（搜尋）
                  final items = <Map<String, dynamic>>[];
                  for (final d in docs) {
                    final data = d.data();
                    if (_match(data, d.id)) {
                      items.add(<String, dynamic>{'id': d.id, 'data': data});
                    }
                  }

                  // 讓 AppBar 的匯出按鈕可用：用 Builder 重新包一層
                  return Builder(
                    builder: (context) {
                      return Column(
                        children: [
                          _OrderFilters(
                            qCtrl: _searchCtrl,
                            status: _status,
                            onQueryChanged: (v) => setState(() => _q = v),
                            onClearQuery: () {
                              _searchCtrl.clear();
                              setState(() => _q = '');
                            },
                            onStatusChanged: (v) => setState(() => _status = v),
                            countLabel: '${items.length} 筆',
                            onExport: items.isEmpty ? null : () => _exportCsv(items),
                            isVendor: isVendor,
                            vendorId: vendorId,
                          ),
                          const Divider(height: 1),

                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final isWide = c.maxWidth >= 980;

                                Widget list() => ListView.separated(
                                      itemCount: items.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (_, i) {
                                        final id = _s(items[i]['id']);
                                        final data = (items[i]['data'] is Map<String, dynamic>)
                                            ? (items[i]['data'] as Map<String, dynamic>)
                                            : <String, dynamic>{};

                                        final status = _s(data['status']);
                                        final paymentStatus = _s(data['paymentStatus']);
                                        final total = _toNum(data['total'] ?? data['amount'] ?? data['priceTotal']);
                                        final createdAt = _toDate(data['createdAt']);
                                        final buyer = _s(data['buyerEmail']).isNotEmpty ? _s(data['buyerEmail']) : _s(data['buyer']);

                                        final selected = id == _selectedId;

                                        return ListTile(
                                          selected: selected,
                                          onTap: () async {
                                            setState(() => _selectedId = id);
                                            if (!isWide) {
                                              await _openDetailDialog(isAdmin: isAdmin, orderId: id, data: data);
                                            }
                                          },
                                          title: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '訂單 $id',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _StatusChip(status: status),
                                            ],
                                          ),
                                          subtitle: Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Wrap(
                                              spacing: 10,
                                              runSpacing: 4,
                                              children: [
                                                Text('NT\$${total.toStringAsFixed(0)}'),
                                                Text('建立：${_fmt(createdAt)}'),
                                                if (buyer.isNotEmpty) Text('買家：$buyer'),
                                                if (paymentStatus.isNotEmpty) Text('付款：$paymentStatus'),
                                                Text('vendor：${_vendorShow(data)}'),
                                              ],
                                            ),
                                          ),
                                          trailing: Wrap(
                                            spacing: 6,
                                            children: [
                                              IconButton(
                                                tooltip: '複製訂單號',
                                                onPressed: () => _copy(id, done: '已複製訂單號'),
                                                icon: const Icon(Icons.copy, size: 20),
                                              ),
                                              IconButton(
                                                tooltip: '付款狀態',
                                                onPressed: () => Navigator.pushReplacementNamed(
                                                  context,
                                                  '/payment_status',
                                                  arguments: id,
                                                ),
                                                icon: const Icon(Icons.verified_outlined, size: 20),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );

                                Widget detail() {
                                  if (_selectedId == null) {
                                    return const Center(child: Text('請在左側選擇訂單'));
                                  }
                                  final hit = items.firstWhere(
                                    (e) => _s(e['id']) == _selectedId,
                                    orElse: () => <String, dynamic>{},
                                  );
                                  if (hit.isEmpty) {
                                    return const Center(child: Text('找不到選取的訂單資料'));
                                  }
                                  final data = (hit['data'] is Map<String, dynamic>)
                                      ? (hit['data'] as Map<String, dynamic>)
                                      : <String, dynamic>{};

                                  return _OrderDetail(
                                    isAdmin: isAdmin,
                                    orderId: _s(hit['id']),
                                    data: data,
                                    onCopy: _copy,
                                    onGoPayment: () => Navigator.pushReplacementNamed(
                                      context,
                                      '/payment_status',
                                      arguments: _s(hit['id']),
                                    ),
                                    onEditStatus: isAdmin
                                        ? () => _openStatusDialog(
                                              orderId: _s(hit['id']),
                                              currentStatus: _s(data['status']),
                                            )
                                        : null,
                                  );
                                }

                                if (!isWide) return list();

                                return Row(
                                  children: [
                                    Expanded(flex: 3, child: list()),
                                    const VerticalDivider(width: 1),
                                    Expanded(flex: 2, child: detail()),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ------------------------------------------------------------
// Filters UI
// ------------------------------------------------------------
class _OrderFilters extends StatelessWidget {
  const _OrderFilters({
    required this.qCtrl,
    required this.status,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onStatusChanged,
    required this.countLabel,
    required this.onExport,
    required this.isVendor,
    required this.vendorId,
  });

  final TextEditingController qCtrl;
  final String status;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<String> onStatusChanged;
  final String countLabel;
  final VoidCallback? onExport;

  final bool isVendor;
  final String vendorId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 720;

          final search = TextField(
            controller: qCtrl,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              hintText: '搜尋：訂單號 / 買家 / vendor',
              suffixIcon: qCtrl.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除',
                      onPressed: onClearQuery,
                      icon: const Icon(Icons.clear),
                    ),
            ),
            onChanged: onQueryChanged,
          );

          final statusDd = DropdownButtonFormField<String>(
            value: status,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              labelText: '狀態',
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('全部')),
              DropdownMenuItem(value: 'created', child: Text('created')),
              DropdownMenuItem(value: 'pending_payment', child: Text('pending_payment')),
              DropdownMenuItem(value: 'paid', child: Text('paid')),
              DropdownMenuItem(value: 'processing', child: Text('processing')),
              DropdownMenuItem(value: 'shipping', child: Text('shipping')),
              DropdownMenuItem(value: 'completed', child: Text('completed')),
              DropdownMenuItem(value: 'cancelled', child: Text('cancelled')),
              DropdownMenuItem(value: 'failed', child: Text('failed')),
            ],
            onChanged: (v) => onStatusChanged(v ?? 'all'),
          );

          final exportBtn = OutlinedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.download_outlined),
            label: const Text('匯出 CSV'),
          );

          final hint = Text(
            isVendor
                ? (vendorId.trim().isEmpty
                    ? 'Vendor：尚未設定 vendorId（將無法查到訂單）'
                    : 'Vendor：只顯示 vendorIds 包含 $vendorId 的訂單')
                : 'Admin：顯示全部訂單',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                search,
                const SizedBox(height: 10),
                statusDd,
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    exportBtn,
                    Text('共 $countLabel', style: const TextStyle(color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 6),
                hint,
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: search),
              const SizedBox(width: 10),
              SizedBox(width: 220, child: statusDd),
              const SizedBox(width: 10),
              exportBtn,
              const SizedBox(width: 10),
              Text('共 $countLabel', style: const TextStyle(color: Colors.black54)),
              const SizedBox(width: 10),
              Expanded(child: hint),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// Detail UI
// ------------------------------------------------------------
class _OrderDetail extends StatelessWidget {
  const _OrderDetail({
    required this.isAdmin,
    required this.orderId,
    required this.data,
    required this.onCopy,
    required this.onGoPayment,
    required this.onEditStatus,
  });

  final bool isAdmin;
  final String orderId;
  final Map<String, dynamic> data;

  final Future<void> Function(String text, {String done}) onCopy;
  final VoidCallback onGoPayment;
  final VoidCallback? onEditStatus;

  String _s(dynamic v) => (v ?? '').toString().trim();

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse((v ?? '').toString().trim()) ?? 0;
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  List<String> _vendorIds(Map<String, dynamic> d) {
    final raw = d['vendorIds'];
    if (raw is List) {
      return raw.map((e) => _s(e)).where((e) => e.isNotEmpty).toList();
    }
    final legacy = _s(d['vendorId']);
    return legacy.isEmpty ? <String>[] : <String>[legacy];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final status = _s(data['status']);
    final paymentStatus = _s(data['paymentStatus']);
    final total = _toNum(data['total'] ?? data['amount'] ?? data['priceTotal']);
    final createdAt = _toDate(data['createdAt']);
    final buyer = _s(data['buyerEmail']).isNotEmpty ? _s(data['buyerEmail']) : _s(data['buyer']);
    final vendorShow = _vendorIds(data).isEmpty ? '-' : _vendorIds(data).join(', ');

    // items（可選）
    final rawItems = data['items'];
    final items = <Map<String, dynamic>>[];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map) items.add(it.cast<String, dynamic>());
      }
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '訂單詳情 $orderId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: '複製訂單號',
                onPressed: () => onCopy(orderId, done: '已複製訂單號'),
                icon: const Icon(Icons.copy),
              ),
              IconButton(
                tooltip: '付款狀態',
                onPressed: onGoPayment,
                icon: const Icon(Icons.verified_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusChip(status: status),
              Text('NT\$${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              if (paymentStatus.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.secondary.withOpacity(0.25)),
                  ),
                  child: Text('付款：$paymentStatus', style: TextStyle(color: cs.secondary, fontWeight: FontWeight.w800)),
                ),
            ],
          ),

          const SizedBox(height: 12),
          _kv('狀態', status.isEmpty ? '-' : status),
          const SizedBox(height: 6),
          _kv('建立', _fmt(createdAt)),
          const SizedBox(height: 6),
          _kv('買家', buyer.isEmpty ? '-' : buyer),
          const SizedBox(height: 6),
          _kv('vendor', vendorShow),

          const SizedBox(height: 12),
          if (items.isNotEmpty) ...[
            const Text('品項', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: items.map((it) {
                  final name = _s(it['name']).isNotEmpty ? _s(it['name']) : _s(it['title']);
                  final qty = _s(it['qty']).isNotEmpty ? _s(it['qty']) : _s(it['quantity']);
                  final price = _s(it['price']).isNotEmpty ? _s(it['price']) : _s(it['amount']);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(name.isEmpty ? '（未命名）' : name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 10),
                        Text('x${qty.isEmpty ? '1' : qty}'),
                        const SizedBox(width: 10),
                        Text(price.isEmpty ? '' : 'NT\$$price'),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
          ],

          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onCopy(orderId, done: '已複製訂單號'),
                  icon: const Icon(Icons.copy),
                  label: const Text('複製訂單號'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onGoPayment,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('付款狀態'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isAdmin)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onEditStatus,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('更新訂單狀態（Admin）'),
              ),
            )
          else
            Text(
              'Vendor 為只讀檢視（避免觸發 rules 限制）',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 70, child: Text(k, style: const TextStyle(color: Colors.black54, fontSize: 12))),
        Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w800))),
      ],
    );
  }
}

// ------------------------------------------------------------
// Status chip
// ------------------------------------------------------------
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  Color _color(BuildContext context, String s) {
    final cs = Theme.of(context).colorScheme;
    final x = s.trim().toLowerCase();
    if (x.contains('paid') || x == 'completed') return cs.primary;
    if (x.contains('pending') || x.contains('processing')) return Colors.orange;
    if (x.contains('ship')) return Colors.blueGrey;
    if (x.contains('cancel') || x.contains('fail') || x.contains('error')) return cs.error;
    return cs.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final c = _color(context, status);
    final label = status.trim().isEmpty ? 'unknown' : status.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
