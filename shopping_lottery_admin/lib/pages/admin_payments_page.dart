// lib/pages/admin_payments_page.dart
//
// ✅ AdminPaymentsPage（最終完整版｜金流管理系統）
// ------------------------------------------------------------
// Firestore 結構：payments/{paymentId}
//   - orderId: String
//   - vendorId: String?
//   - userId: String?
//   - method: String (credit_card, linepay, etc.)
//   - amount: num
//   - currency: String (TWD, USD...)
//   - status: String (pending, success, failed, refunded)
//   - transactionId: String
//   - gateway: String
//   - message: String
//   - createdAt, updatedAt: Timestamp
//
// 功能：
// - Admin/Vendor 分流
// - 即時查詢 + 搜尋 + 篩選
// - 批次更新 / 刪除
// - 匯出 CSV
// - 點擊可查看付款詳情
// ------------------------------------------------------------

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _status = 'all';
  String _method = 'all';
  bool _ascending = false;

  final List<_PaymentRow> _rows = [];
  final Set<String> _selectedIds = {};

  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _loading = false;

  static const int _pageSize = 30;

  String? _vendorId;
  String _role = '';
  Future<RoleInfo>? _roleFuture;
  String? _lastUid;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _s(dynamic v) => (v ?? '').toString().trim();
  num _toNum(dynamic v) => v is num ? v : (num.tryParse('$v') ?? 0);
  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  Future<void> _load({bool refresh = false, required bool isAdmin, required bool isVendor}) async {
    if (_loading || (!_hasMore && !refresh)) return;
    setState(() => _loading = true);

    try {
      if (refresh) {
        _rows.clear();
        _lastDoc = null;
        _hasMore = true;
      }

      Query<Map<String, dynamic>> q = _db.collection('payments');

      if (isVendor) {
        q = q.where('vendorId', isEqualTo: _vendorId ?? '__none__');
      }

      if (_status != 'all') q = q.where('status', isEqualTo: _status);
      if (_method != 'all') q = q.where('method', isEqualTo: _method);

      q = q.orderBy('createdAt', descending: !_ascending).limit(_pageSize);
      if (_lastDoc != null && !refresh) q = q.startAfterDocument(_lastDoc!);

      final snap = await q.get();

      final list = snap.docs.map((d) {
        final data = d.data();
        return _PaymentRow(
          id: d.id,
          orderId: _s(data['orderId']),
          vendorId: _s(data['vendorId']),
          userId: _s(data['userId']),
          method: _s(data['method']),
          amount: _toNum(data['amount']),
          currency: _s(data['currency']),
          status: _s(data['status']),
          transactionId: _s(data['transactionId']),
          gateway: _s(data['gateway']),
          createdAt: _toDate(data['createdAt']),
          updatedAt: _toDate(data['updatedAt']),
        );
      }).toList();

      // client-side 搜尋
      final qtext = _query.toLowerCase();
      final filtered = qtext.isEmpty
          ? list
          : list.where((p) {
              final hay = [
                p.id,
                p.orderId,
                p.transactionId,
                p.method,
                p.gateway,
              ].join(' ').toLowerCase();
              return hay.contains(qtext);
            }).toList();

      if (!mounted) return;
      setState(() {
        _rows.addAll(filtered);
        _hasMore = snap.docs.length == _pageSize;
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
      });
    } catch (e) {
      _snack('載入失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      await _db.collection('payments').doc(id).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack('已更新付款狀態為 $newStatus');
      setState(() {
        final i = _rows.indexWhere((r) => r.id == id);
        if (i >= 0) _rows[i] = _rows[i].copyWith(status: newStatus);
      });
    } catch (e) {
      _snack('更新失敗：$e');
    }
  }

  Future<void> _exportCSV() async {
    if (_rows.isEmpty) {
      _snack('無資料可匯出');
      return;
    }
    final table = <List<dynamic>>[
      [
        'PaymentID',
        'OrderID',
        'VendorID',
        'UserID',
        'Method',
        'Amount',
        'Currency',
        'Status',
        'TransactionID',
        'Gateway',
        'CreatedAt',
        'UpdatedAt'
      ],
      ..._rows.map((p) => [
            p.id,
            p.orderId,
            p.vendorId,
            p.userId,
            p.method,
            p.amount,
            p.currency,
            p.status,
            p.transactionId,
            p.gateway,
            p.createdAt?.toIso8601String() ?? '',
            p.updatedAt?.toIso8601String() ?? '',
          ]),
    ];
    final csv = const ListToCsvConverter().convert(table);
    final bytes = Uint8List.fromList(utf8.encode(csv));
    await FileSaver.instance.saveFile(
      name: 'payments_export_${DateTime.now().millisecondsSinceEpoch}',
      bytes: bytes,
      ext: 'csv',
      mimeType: MimeType.csv,
    );
    _snack('匯出成功（共 ${_rows.length} 筆）');
  }

  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('請登入')));

    if (_roleFuture == null || _lastUid != user.uid) {
      _lastUid = user.uid;
      _roleFuture = gate.ensureAndGetRole(user, forceRefresh: false);
    }

    return FutureBuilder<RoleInfo>(
      future: _roleFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final info = snap.data;
        final role = (info?.role ?? '').toLowerCase().trim();
        final isAdmin = role == 'admin';
        final isVendor = role == 'vendor';
        _vendorId = info?.vendorId;

        if (_rows.isEmpty && !_loading) {
          _load(refresh: true, isAdmin: isAdmin, isVendor: isVendor);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('金流管理'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _load(refresh: true, isAdmin: isAdmin, isVendor: isVendor),
              ),
              IconButton(
                icon: const Icon(Icons.download_outlined),
                onPressed: _exportCSV,
              ),
            ],
          ),
          body: Column(
            children: [
              _buildFilters(isAdmin: isAdmin, isVendor: isVendor),
              const Divider(height: 1),
              Expanded(
                child: _rows.isEmpty
                    ? Center(
                        child: Text(_loading ? '載入中...' : '無資料'),
                      )
                    : ListView.builder(
                        itemCount: _rows.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _rows.length) {
                            if (!_loading) _load(isAdmin: isAdmin, isVendor: isVendor);
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final r = _rows[i];
                          final selected = _selectedIds.contains(r.id);
                          return Card(
                            color: selected ? Colors.blue.withOpacity(0.1) : null,
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              leading: Checkbox(
                                value: selected,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedIds.add(r.id);
                                    } else {
                                      _selectedIds.remove(r.id);
                                    }
                                  });
                                },
                              ),
                              title: Text('付款編號：${r.id}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '訂單：${r.orderId} · 狀態：${_statusLabel(r.status)} · 金額：${r.amount} ${r.currency}',
                              ),
                              trailing: Text(
                                r.createdAt != null ? _fmt(r.createdAt!) : '-',
                                style: const TextStyle(color: Colors.black54),
                              ),
                              onTap: () => _showDetail(r),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: _selectedIds.isNotEmpty
              ? FloatingActionButton.extended(
                  icon: const Icon(Icons.edit),
                  label: Text('批次操作 (${_selectedIds.length})'),
                  onPressed: _showBatchMenu,
                )
              : null,
        );
      },
    );
  }

  Widget _buildFilters({required bool isAdmin, required bool isVendor}) {
    const statuses = ['all', 'pending', 'success', 'failed', 'refunded'];
    const methods = ['all', 'credit_card', 'linepay', 'applepay', 'bank', 'cash'];

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜尋 Payment ID / Transaction ID',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          DropdownButton<String>(
            value: _status,
            items: statuses
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text('狀態：${_statusLabel(s)}'),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => _status = v ?? 'all');
              _load(refresh: true, isAdmin: isAdmin, isVendor: isVendor);
            },
          ),
          DropdownButton<String>(
            value: _method,
            items: methods
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text('方式：$s'),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => _method = v ?? 'all');
              _load(refresh: true, isAdmin: isAdmin, isVendor: isVendor);
            },
          ),
        ],
      ),
    );
  }

  void _showBatchMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(title: Text('批次設定付款狀態')),
            ListTile(
              leading: const Icon(Icons.task_alt),
              title: const Text('設為成功 (success)'),
              onTap: () {
                Navigator.pop(context);
                _batchSet('status', 'success');
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: const Text('設為失敗 (failed)'),
              onTap: () {
                Navigator.pop(context);
                _batchSet('status', 'failed');
              },
            ),
            ListTile(
              leading: const Icon(Icons.replay),
              title: const Text('設為退款 (refunded)'),
              onTap: () {
                Navigator.pop(context);
                _batchSet('status', 'refunded');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _batchSet(String field, dynamic value) async {
    if (_selectedIds.isEmpty) return;
    try {
      final batch = _db.batch();
      for (final id in _selectedIds) {
        batch.update(_db.collection('payments').doc(id), {field: value});
      }
      await batch.commit();
      _snack('已批次更新 ${_selectedIds.length} 筆');
      setState(() => _selectedIds.clear());
    } catch (e) {
      _snack('批次更新失敗：$e');
    }
  }

  void _showDetail(_PaymentRow r) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('付款詳情：${r.id}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('訂單編號', r.orderId),
              _kv('廠商', r.vendorId),
              _kv('用戶', r.userId),
              _kv('金額', '${r.amount} ${r.currency}'),
              _kv('方式', r.method),
              _kv('狀態', _statusLabel(r.status)),
              _kv('Transaction', r.transactionId),
              _kv('Gateway', r.gateway),
              _kv('建立時間', r.createdAt?.toIso8601String() ?? '-'),
              _kv('更新時間', r.updatedAt?.toIso8601String() ?? '-'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(r.id, 'refunded');
            },
            child: const Text('退款'),
          ),
        ],
      ),
    );
  }

  static Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 100, child: Text(k, style: const TextStyle(fontWeight: FontWeight.bold))),
            Expanded(child: Text(v)),
          ],
        ),
      );

  static String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return '待處理';
      case 'success':
        return '成功';
      case 'failed':
        return '失敗';
      case 'refunded':
        return '已退款';
      default:
        return '未知';
    }
  }

  static String _fmt(DateTime d) => '${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

class _PaymentRow {
  final String id;
  final String orderId;
  final String vendorId;
  final String userId;
  final String method;
  final num amount;
  final String currency;
  final String status;
  final String transactionId;
  final String gateway;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  _PaymentRow({
    required this.id,
    required this.orderId,
    required this.vendorId,
    required this.userId,
    required this.method,
    required this.amount,
    required this.currency,
    required this.status,
    required this.transactionId,
    required this.gateway,
    required this.createdAt,
    required this.updatedAt,
  });

  _PaymentRow copyWith({String? status}) => _PaymentRow(
        id: id,
        orderId: orderId,
        vendorId: vendorId,
        userId: userId,
        method: method,
        amount: amount,
        currency: currency,
        status: status ?? this.status,
        transactionId: transactionId,
        gateway: gateway,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
