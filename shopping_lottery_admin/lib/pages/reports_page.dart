// lib/pages/reports_page.dart
//
// ✅ ReportsPage（最終穩定完整版｜Admin/Vendor 共用報表）
// ------------------------------------------------------------
// 功能：
// - Admin 看全站報表
// - Vendor 看自己 vendorId 報表
// - 三個數字卡：商品數 / 訂單數 / 營收（近 200 筆）
// - 近 10 筆訂單清單（可點擊看詳情）
//
// Firestore 建議欄位：
// products/{id}: vendorId, isActive, createdAt
// orders/{id}: vendorId, createdAt(Timestamp), status, total, amount, buyerEmail
//
// 若遇到 "The query requires an index" → 前往 console 建索引即可
//
// 依賴：
// - services/admin_gate.dart (RoleInfo, ensureAndGetRole)
// - services/auth_service.dart (signOut)
// - firebase_auth, cloud_firestore, provider
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';
import '../services/auth_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _db = FirebaseFirestore.instance;
  Future<RoleInfo>? _roleFuture;
  String? _lastUid;
  late Future<_ReportSnapshot> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = Future.value(const _ReportSnapshot.empty());
  }

  void _resetRole(AdminGate gate, User user) {
    setState(() {
      gate.clearCache();
      _roleFuture = gate.ensureAndGetRole(user, forceRefresh: true);
    });
  }

  // ---------------- 工具函式 ----------------
  DateTime _toDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return DateTime.now();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();
  num _toNum(dynamic v) => v is num ? v : (num.tryParse(_s(v)) ?? 0);
  String _fmtDateTime(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  String _money(num v) => 'NT\$${v.toStringAsFixed(0)}';

  // ---------------- 報表主查詢 ----------------
  Future<_ReportSnapshot> _loadReports({
    required bool isVendor,
    required String vendorId,
  }) async {
    if (isVendor && vendorId.trim().isEmpty) {
      return const _ReportSnapshot.empty(note: 'Vendor 未設定 vendorId，無法顯示報表。');
    }

    final vid = vendorId.trim();
    Query<Map<String, dynamic>> productsQ = _db.collection('products');
    Query<Map<String, dynamic>> ordersQ = _db.collection('orders');

    if (isVendor) {
      productsQ = productsQ.where('vendorId', isEqualTo: vid);
      ordersQ = ordersQ.where('vendorId', isEqualTo: vid);
    }

    ordersQ = ordersQ.orderBy('createdAt', descending: true);

    const sumLimit = 200;
    const latestLimit = 10;

    final results = await Future.wait([
      productsQ.limit(1000).get(),
      ordersQ.limit(sumLimit).get(),
      ordersQ.limit(latestLimit).get(),
    ]);

    final productsSnap = results[0];
    final ordersForSumSnap = results[1];
    final latestOrdersSnap = results[2];

    final productCount = productsSnap.docs.length;
    final orderCount = ordersForSumSnap.docs.length;

    num revenue = 0;
    for (final d in ordersForSumSnap.docs) {
      final m = d.data();
      revenue += _toNum(m['total'] ?? m['amount'] ?? 0);
    }

    final latest = latestOrdersSnap.docs.map((d) {
      final m = d.data();
      return _OrderLite(
        docId: d.id,
        orderId: _s(m['id']).isNotEmpty ? _s(m['id']) : d.id,
        buyerEmail:
            _s(m['buyerEmail']).isNotEmpty ? _s(m['buyerEmail']) : _s(m['buyer']),
        status: _s(m['status']),
        createdAt: _toDate(m['createdAt']),
        total: _toNum(m['total'] ?? m['amount'] ?? 0),
        vendorId: _s(m['vendorId']),
      );
    }).toList();

    return _ReportSnapshot(
      productCount: productCount,
      orderCountApprox: orderCount,
      revenueApprox: revenue,
      latestOrders: latest,
      note: '（近 $sumLimit 筆訂單加總，非全站總額）',
    );
  }

  void _openOrderDetail(_OrderLite o) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('訂單 ${o.orderId}'),
        content: SingleChildScrollView(
          child: Text(
            '買家：${o.buyerEmail.isEmpty ? '-' : o.buyerEmail}\n'
            '狀態：${o.status.isEmpty ? '-' : o.status}\n'
            '金額：${_money(o.total)}\n'
            '時間：${_fmtDateTime(o.createdAt)}\n'
            '${o.vendorId.isEmpty ? '' : 'Vendor ID：${o.vendorId}\n'}'
            '\nDocID：${o.docId}',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
        ],
      ),
    );
  }

  // ---------------- 主畫面 ----------------
  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();
    final authSvc = context.read<AuthService>();
    final cs = Theme.of(context).colorScheme;

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
        }

        return FutureBuilder<RoleInfo>(
          future: _roleFuture,
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (roleSnap.hasError) {
              return _SimpleErrorPage(
                title: '讀取角色失敗',
                message: '${roleSnap.error}',
                onRetry: () => _resetRole(gate, user),
                onLogout: () async {
                  gate.clearCache();
                  await authSvc.signOut();
                  if (!context.mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                },
              );
            }

            final info = roleSnap.data!;
            final role = (info.role ?? '').toLowerCase();
            final vendorId = (info.vendorId ?? '').trim();
            final isAdmin = role == 'admin';
            final isVendor = role == 'vendor';

            if (!isAdmin && !isVendor) {
              return _SimpleErrorPage(
                title: '權限不足',
                message: '此頁僅限 admin / vendor 使用。',
                onRetry: () => _resetRole(gate, user),
                onLogout: () async {
                  gate.clearCache();
                  await authSvc.signOut();
                  if (!context.mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                },
              );
            }

            _reportFuture = _loadReports(isVendor: isVendor, vendorId: vendorId);

            return Scaffold(
              appBar: AppBar(
                title: const Text('報表分析'),
                centerTitle: true,
                actions: [
                  IconButton(
                    tooltip: '登出',
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      gate.clearCache();
                      await authSvc.signOut();
                      if (!context.mounted) return;
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                ],
              ),
              body: RefreshIndicator(
                onRefresh: () async => setState(() {}),
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    // 統計卡
                    FutureBuilder<_ReportSnapshot>(
                      future: _reportFuture,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return Text('報表載入錯誤：${snap.error}', style: TextStyle(color: cs.error));
                        }

                        final r = snap.data ?? const _ReportSnapshot.empty();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAdmin
                                  ? '角色：Admin（全站）'
                                  : (vendorId.isEmpty
                                      ? '角色：Vendor（未設定 vendorId）'
                                      : '角色：Vendor（$vendorId）'),
                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _MiniStatCard(title: '商品數', value: '${r.productCount}', icon: Icons.inventory_2_outlined),
                                _MiniStatCard(title: '訂單數', value: '${r.orderCountApprox}', icon: Icons.receipt_long_outlined),
                                _MiniStatCard(title: '營收', value: _money(r.revenueApprox), icon: Icons.payments_outlined),
                              ],
                            ),
                            if (r.note.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(r.note, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                              ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                    const Text('近 10 筆訂單',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),

                    FutureBuilder<_ReportSnapshot>(
                      future: _reportFuture,
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final latest = snap.data!.latestOrders;
                        if (latest.isEmpty) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: Text('目前沒有訂單')),
                            ),
                          );
                        }

                        return Card(
                          elevation: 0,
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: latest.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final o = latest[i];
                              return ListTile(
                                onTap: () => _openOrderDetail(o),
                                title: Text(
                                  o.orderId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                subtitle: Text(
                                  '${o.buyerEmail.isEmpty ? '-' : o.buyerEmail} · ${_fmtDateTime(o.createdAt)}\n${_money(o.total)}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(Icons.chevron_right),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// -------------------- Models --------------------
class _OrderLite {
  final String docId;
  final String orderId;
  final String buyerEmail;
  final String status;
  final DateTime createdAt;
  final num total;
  final String vendorId;
  const _OrderLite({
    required this.docId,
    required this.orderId,
    required this.buyerEmail,
    required this.status,
    required this.createdAt,
    required this.total,
    required this.vendorId,
  });
}

class _ReportSnapshot {
  final int productCount;
  final int orderCountApprox;
  final num revenueApprox;
  final List<_OrderLite> latestOrders;
  final String note;
  const _ReportSnapshot({
    required this.productCount,
    required this.orderCountApprox,
    required this.revenueApprox,
    required this.latestOrders,
    required this.note,
  });
  const _ReportSnapshot.empty({
    this.productCount = 0,
    this.orderCountApprox = 0,
    this.revenueApprox = 0,
    this.latestOrders = const <_OrderLite>[],
    this.note = '',
  });
}

// -------------------- 小卡元件 --------------------
class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------- 錯誤頁 --------------------
class _SimpleErrorPage extends StatelessWidget {
  const _SimpleErrorPage({
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });
  final String title;
  final String message;
  final VoidCallback onRetry;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('重試')),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () async => onLogout(),
                      icon: const Icon(Icons.logout),
                      label: const Text('登出'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
