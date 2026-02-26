import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'orders/order_detail_page.dart';

/// ✅ OrderHistoryPage（訂單歷史｜修改後完整版）
/// ------------------------------------------------------------
/// ✅ 修正重點：
/// - 移除 FirestoreMockService.orderHistory（避免 undefined_getter）
/// - 改用 FirebaseAuth + Firestore 直接讀取
/// - ✅ 修正 deprecated_member_use：DropdownButtonFormField 的 value -> initialValue
///
/// 讀取優先順序：
/// 1) users/{uid}/orders（優先，符合前台常見結構）
/// 2) orders（fallback）
///
/// 訂單欄位建議：
/// - status: String
/// - paymentStatus: String
/// - shippingStatus: String
/// - totalAmount: num
/// - currency: String
/// - createdAt: Timestamp
/// - items: List<Map>
/// ------------------------------------------------------------
class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();

  String _statusFilter = 'all';
  String _payFilter = 'all';
  String _shipFilter = 'all';

  // 若 users/{uid}/orders 讀不到或錯誤，可自動 fallback 到 orders
  bool _useGlobalFallback = false;

  User? get _user => _auth.currentUser;

  // ✅ 下拉選單可用值（避免 initialValue 不在 items 造成 runtime error）
  static const List<String> _statusValues = [
    'all',
    'created',
    'processing',
    'completed',
    'canceled',
  ];
  static const List<String> _payValues = ['all', 'unpaid', 'paid', 'refunded'];
  static const List<String> _shipValues = [
    'all',
    'pending',
    'shipped',
    'delivered',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  DateTime? _asDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmtDateTime(DateTime? dt) {
    if (dt == null) return '';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $hh:$mm';
  }

  CollectionReference<Map<String, dynamic>> _userOrdersRef(String uid) =>
      _fs.collection('users').doc(uid).collection('orders');

  CollectionReference<Map<String, dynamic>> _globalOrdersRef() =>
      _fs.collection('orders');

  @override
  Widget build(BuildContext context) {
    final uid = _user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('訂單歷史'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: uid == null ? _needLogin(context) : _body(uid),
    );
  }

  Widget _needLogin(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    '請先登入才能查看訂單歷史',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed('/login'),
                    child: const Text('前往登入'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(String uid) {
    return Column(
      children: [
        _filterBar(),
        const Divider(height: 1),
        Expanded(child: _ordersStream(uid)),
      ],
    );
  }

  Widget _filterBar() {
    // ✅ 防呆：確保 initialValue 一定存在於 items
    final safeStatus = _statusValues.contains(_statusFilter)
        ? _statusFilter
        : 'all';
    final safePay = _payValues.contains(_payFilter) ? _payFilter : 'all';
    final safeShip = _shipValues.contains(_shipFilter) ? _shipFilter : 'all';

    if (safeStatus != _statusFilter ||
        safePay != _payFilter ||
        safeShip != _shipFilter) {
      // 這裡不 setState，避免 build-loop；只是用 safe 值渲染
      _statusFilter = safeStatus;
      _payFilter = safePay;
      _shipFilter = safeShip;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '搜尋（orderId / 狀態 / 金額）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  // ✅ value -> initialValue（修正 deprecated_member_use）
                  initialValue: _statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部狀態')),
                    DropdownMenuItem(value: 'created', child: Text('created')),
                    DropdownMenuItem(
                      value: 'processing',
                      child: Text('processing'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('completed'),
                    ),
                    DropdownMenuItem(
                      value: 'canceled',
                      child: Text('canceled'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                  decoration: const InputDecoration(
                    labelText: 'status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  // ✅ value -> initialValue（修正 deprecated_member_use）
                  initialValue: _payFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部付款')),
                    DropdownMenuItem(value: 'unpaid', child: Text('unpaid')),
                    DropdownMenuItem(value: 'paid', child: Text('paid')),
                    DropdownMenuItem(
                      value: 'refunded',
                      child: Text('refunded'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _payFilter = v ?? 'all'),
                  decoration: const InputDecoration(
                    labelText: 'paymentStatus',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  // ✅ value -> initialValue（修正 deprecated_member_use）
                  initialValue: _shipFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部物流')),
                    DropdownMenuItem(value: 'pending', child: Text('pending')),
                    DropdownMenuItem(value: 'shipped', child: Text('shipped')),
                    DropdownMenuItem(
                      value: 'delivered',
                      child: Text('delivered'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _shipFilter = v ?? 'all'),
                  decoration: const InputDecoration(
                    labelText: 'shippingStatus',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: _useGlobalFallback,
            onChanged: (v) => setState(() => _useGlobalFallback = v),
            title: Text(
              _useGlobalFallback
                  ? '資料來源：orders（全域）'
                  : '資料來源：users/{uid}/orders（優先）',
            ),
            subtitle: const Text('若你的訂單都存在全域 orders，可切換到全域'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _ordersStream(String uid) {
    final ref = _useGlobalFallback ? _globalOrdersRef() : _userOrdersRef(uid);

    // 先用 createdAt 排序（通常最符合需求）
    final stream = ref
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          // fallback：若 createdAt 欄位/索引不完整，改用 docId 排序
          final fallbackStream = ref
              .orderBy(FieldPath.documentId, descending: true)
              .limit(200)
              .snapshots();
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: fallbackStream,
            builder: (context, snap2) {
              if (snap2.hasError) {
                return _errorBox('讀取失敗：${snap2.error}');
              }
              if (!snap2.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _list(uid, snap2.data!.docs, note: '（已改用 docId 排序）');
            },
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _list(uid, snap.data!.docs);
      },
    );
  }

  Widget _list(
    String uid,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    String note = '',
  }) {
    final filtered = _applyFilters(docs);

    if (filtered.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(note, style: const TextStyle(color: Colors.grey)),
            ),
          _empty('沒有符合條件的訂單'),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(note, style: const TextStyle(color: Colors.grey)),
          ),
        _summaryCard(filtered),
        const SizedBox(height: 10),
        for (final doc in filtered) _orderTile(uid, doc),
      ],
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final q = _searchCtrl.text.trim().toLowerCase();

    return docs.where((doc) {
      final d = doc.data();
      final id = doc.id.toLowerCase();

      final status = _s(d['status'], '').toLowerCase();
      final pay = _s(d['paymentStatus'], '').toLowerCase();
      final ship = _s(d['shippingStatus'], '').toLowerCase();
      final total = _asNum(
        d['totalAmount'] ?? d['total'] ?? d['amount'],
        fallback: 0,
      );

      final matchStatus = _statusFilter == 'all' || status == _statusFilter;
      final matchPay = _payFilter == 'all' || pay == _payFilter;
      final matchShip = _shipFilter == 'all' || ship == _shipFilter;

      final matchSearch =
          q.isEmpty ||
          id.contains(q) ||
          status.contains(q) ||
          pay.contains(q) ||
          ship.contains(q) ||
          total.toString().toLowerCase().contains(q);

      return matchStatus && matchPay && matchShip && matchSearch;
    }).toList();
  }

  Widget _summaryCard(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int paid = 0;
    num totalSum = 0;

    for (final doc in docs) {
      final d = doc.data();
      final pay = _s(d['paymentStatus'], 'unpaid');
      final total = _asNum(
        d['totalAmount'] ?? d['total'] ?? d['amount'],
        fallback: 0,
      );

      totalSum += total;
      if (pay == 'paid') paid++;
    }

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Colors.blueGrey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '共 ${docs.length} 筆 • 已付款 $paid 筆 • 金額合計 ${totalSum.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderTile(
    String uid,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();

    final orderId = doc.id;
    final status = _s(d['status'], 'created');
    final pay = _s(d['paymentStatus'], 'unpaid');
    final ship = _s(d['shippingStatus'], 'pending');

    final total = _asNum(
      d['totalAmount'] ?? d['total'] ?? d['amount'],
      fallback: 0,
    );
    final currency = _s(d['currency'], 'TWD');

    final createdAt = _asDate(d['createdAt']);
    final timeText = _fmtDateTime(createdAt);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(
          '訂單 $orderId',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          [
            'status=$status  pay=$pay  ship=$ship',
            'total=$total $currency',
            if (timeText.isNotEmpty) 'createdAt=$timeText',
          ].join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailPage(orderId: orderId),
            ),
          );
        },
      ),
    );
  }

  Widget _empty(String text) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
