// lib/pages/dashboard_page.dart
//
// ✅ DashboardPage（完整版｜修正 count int? 型別｜Admin/Vendor 共用｜Web/Chrome OK｜可編譯）
//
// 特色：
// - 使用 Firestore AggregateQuery.count() 統計：全部做 int 兼容轉換（解決 int? 問題）
// - 支援 Admin / Vendor：Vendor 使用 orders.vendorIds arrayContains vendorId（符合你前面規則）
// - 顯示：今日訂單、待付款、上架商品、未讀通知（stream）
// - 額外：近 10 筆訂單列表（含狀態/金額/時間）
// - 提供快捷入口：訂單 / 商品 / 通知 / 報表 等
//
// 依賴：
// - firebase_auth
// - cloud_firestore
// - provider
// - services/admin_gate.dart（RoleInfo, AdminGate）
// - services/notification_service.dart（NotificationService v1.3.x）
//
// 注意：請確認 main.dart Provider 註冊的是「services/notification_service.dart」這個 NotificationService（見下方第 2 點）。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';
import '../services/notification_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<RoleInfo>? _roleFuture;
  String? _lastUid;

  final _db = FirebaseFirestore.instance;

  bool _loading = false;
  DateTime? _updatedAt;

  int _todayOrders = 0;
  int _pendingPayment = 0;
  int _activeProducts = 0;

  // Admin only extra KPIs (optional)
  int _totalUsers = 0;
  int _totalVendors = 0;

  // ---------------------------
  // Utils
  // ---------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();

  DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _endOfToday() => _startOfToday().add(const Duration(days: 1));

  DateTime? _toDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse((v ?? '').toString()) ?? 0;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<int> _countQuery(Query<Map<String, dynamic>> q) async {
    // ✅ 兼容不同 cloud_firestore 版本：agg.count 可能是 int 或 int? 或 dynamic
    final agg = await q.count().get();
    final dynamic c = agg.count;
    if (c == null) return 0;
    if (c is int) return c;
    return int.tryParse('$c') ?? 0;
  }

  // ---------------------------
  // KPI Refresh
  // ---------------------------
  Future<void> _refresh({
    required bool isAdmin,
    required bool isVendor,
    required String vendorId,
  }) async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final vid = vendorId.trim();
      if (isVendor && vid.isEmpty) {
        // Vendor 沒 vendorId → 全部 0
        if (!mounted) return;
        setState(() {
          _todayOrders = 0;
          _pendingPayment = 0;
          _activeProducts = 0;
          _totalUsers = 0;
          _totalVendors = 0;
          _updatedAt = DateTime.now();
        });
        return;
      }

      final start = Timestamp.fromDate(_startOfToday());
      final end = Timestamp.fromDate(_endOfToday());

      Query<Map<String, dynamic>> todayQ = _db
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .where('createdAt', isLessThan: end);

      Query<Map<String, dynamic>> pendingQ =
          _db.collection('orders').where('status', isEqualTo: 'pending_payment');

      Query<Map<String, dynamic>> activeProdQ =
          _db.collection('products').where('isActive', isEqualTo: true);

      if (isVendor) {
        // ✅ 依你前面規則：orders.vendorIds arrayContains vendorId
        todayQ = todayQ.where('vendorIds', arrayContains: vid);
        pendingQ = pendingQ.where('vendorIds', arrayContains: vid);

        // 商品通常用 vendorId
        activeProdQ = activeProdQ.where('vendorId', isEqualTo: vid);
      }

      final futures = <Future<int>>[
        _countQuery(todayQ),
        _countQuery(pendingQ),
        _countQuery(activeProdQ),
      ];

      // Admin extra
      if (isAdmin) {
        futures.add(_countQuery(_db.collection('users')));
        futures.add(_countQuery(_db.collection('users').where('role', isEqualTo: 'vendor')));
      }

      final results = await Future.wait(futures);

      if (!mounted) return;
      setState(() {
        _todayOrders = results[0];
        _pendingPayment = results[1];
        _activeProducts = results[2];

        if (isAdmin) {
          _totalUsers = results.length > 3 ? results[3] : 0;
          _totalVendors = results.length > 4 ? results[4] : 0;
        } else {
          _totalUsers = 0;
          _totalVendors = 0;
        }

        _updatedAt = DateTime.now();
      });
    } catch (e) {
      _snack('KPI 更新失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _recentOrdersStream({
    required bool isVendor,
    required String vendorId,
  }) {
    Query<Map<String, dynamic>> q = _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(10);

    final vid = vendorId.trim();
    if (isVendor && vid.isNotEmpty) {
      q = q.where('vendorIds', arrayContains: vid);
    }
    return q.snapshots();
  }

  // ---------------------------
  // UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();
    final notifSvc = context.read<NotificationService>();
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
              return _ErrorCard(
                title: '讀取角色失敗',
                message: '${roleSnap.error}',
                onRetry: () => setState(() => _roleFuture = gate.ensureAndGetRole(user, forceRefresh: true)),
              );
            }

            final info = roleSnap.data;
            final role = _s(info?.role).toLowerCase();
            final isAdmin = role == 'admin';
            final isVendor = role == 'vendor';
            final vendorId = _s(info?.vendorId);

            if (!isAdmin && !isVendor) {
              return const Scaffold(
                body: Center(child: Text('此帳號無後台權限，請聯繫管理員')),
              );
            }

            // 初次進來自動刷新一次
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (_updatedAt == null && !_loading) {
                _refresh(isAdmin: isAdmin, isVendor: isVendor, vendorId: vendorId);
              }
            });

            Widget kpiCard({
              required IconData icon,
              required String label,
              required Widget value,
              required VoidCallback onTap,
            }) {
              return InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outline.withOpacity(0.14)),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(label,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                )),
                            const SizedBox(height: 6),
                            DefaultTextStyle(
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                              child: value,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Scaffold(
              appBar: AppBar(
                title: Text(isAdmin ? 'Dashboard（Admin）' : 'Dashboard（Vendor）'),
                centerTitle: true,
                actions: [
                  // 未讀通知（自己的）
                  StreamBuilder<int>(
                    stream: notifSvc.streamUnreadCount(user.uid),
                    builder: (_, s) {
                      final unread = s.data ?? 0;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            tooltip: '通知中心',
                            onPressed: () => Navigator.pushNamed(context, '/notifications'),
                            icon: const Icon(Icons.notifications_outlined),
                          ),
                          if (unread > 0)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cs.error,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  unread > 99 ? '99+' : '$unread',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  IconButton(
                    tooltip: '刷新',
                    onPressed: () => _refresh(isAdmin: isAdmin, isVendor: isVendor, vendorId: vendorId),
                    icon: const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              body: RefreshIndicator(
                onRefresh: () => _refresh(isAdmin: isAdmin, isVendor: isVendor, vendorId: vendorId),
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    // Header Card
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isAdmin ? '系統概覽' : '商家概覽',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                if (isVendor && vendorId.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceVariant.withOpacity(0.35),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: cs.outline.withOpacity(0.18)),
                                    ),
                                    child: Text(
                                      'vendorId: $vendorId',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '更新：${_fmt(_updatedAt)}${_loading ? '（計算中）' : ''}',
                                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // KPI Grid
                    LayoutBuilder(
                      builder: (_, c) {
                        final cols = c.maxWidth < 520 ? 2 : 4;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: cols,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: cols == 2 ? 2.7 : 3.1,
                          children: [
                            kpiCard(
                              icon: Icons.receipt_long_outlined,
                              label: '今日訂單',
                              value: Text('$_todayOrders'),
                              onTap: () => Navigator.pushNamed(context, '/orders'),
                            ),
                            kpiCard(
                              icon: Icons.pending_actions_outlined,
                              label: '待付款',
                              value: Text('$_pendingPayment'),
                              onTap: () => Navigator.pushNamed(context, '/orders'),
                            ),
                            kpiCard(
                              icon: Icons.inventory_2_outlined,
                              label: '上架商品',
                              value: Text('$_activeProducts'),
                              onTap: () => Navigator.pushNamed(
                                context,
                                isVendor ? '/vendor_products' : '/products',
                              ),
                            ),
                            kpiCard(
                              icon: Icons.notifications_outlined,
                              label: '未讀通知',
                              value: StreamBuilder<int>(
                                stream: notifSvc.streamUnreadCount(user.uid),
                                builder: (_, s) => Text('${s.data ?? 0}'),
                              ),
                              onTap: () => Navigator.pushNamed(context, '/notifications'),
                            ),
                          ],
                        );
                      },
                    ),

                    if (isAdmin) ...[
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (_, c) {
                          final cols = c.maxWidth < 520 ? 2 : 4;
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: cols,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: cols == 2 ? 2.7 : 3.1,
                            children: [
                              kpiCard(
                                icon: Icons.people_alt_outlined,
                                label: '使用者數',
                                value: Text('$_totalUsers'),
                                onTap: () => Navigator.pushNamed(context, '/users'),
                              ),
                              kpiCard(
                                icon: Icons.store_outlined,
                                label: 'Vendor 數',
                                value: Text('$_totalVendors'),
                                onTap: () => Navigator.pushNamed(context, '/vendors'),
                              ),
                              kpiCard(
                                icon: Icons.bar_chart_outlined,
                                label: '報表',
                                value: const Text('開啟'),
                                onTap: () => Navigator.pushNamed(context, '/reports'),
                              ),
                              kpiCard(
                                icon: Icons.settings_outlined,
                                label: 'App 設定',
                                value: const Text('開啟'),
                                onTap: () => Navigator.pushNamed(context, '/app_config'),
                              ),
                            ],
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Quick actions
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _QuickBtn(
                              icon: Icons.receipt_long_outlined,
                              label: '訂單',
                              onTap: () => Navigator.pushNamed(context, '/orders'),
                            ),
                            _QuickBtn(
                              icon: isVendor ? Icons.storefront_outlined : Icons.inventory_2_outlined,
                              label: isVendor ? '我的商品' : '商品',
                              onTap: () => Navigator.pushNamed(
                                context,
                                isVendor ? '/vendor_products' : '/products',
                              ),
                            ),
                            if (isAdmin)
                              _QuickBtn(
                                icon: Icons.category_outlined,
                                label: '分類',
                                onTap: () => Navigator.pushNamed(context, '/categories'),
                              ),
                            if (isAdmin)
                              _QuickBtn(
                                icon: Icons.store_outlined,
                                label: '廠商',
                                onTap: () => Navigator.pushNamed(context, '/vendors'),
                              ),
                            _QuickBtn(
                              icon: Icons.notifications_outlined,
                              label: '通知',
                              onTap: () => Navigator.pushNamed(context, '/notifications'),
                            ),
                            _QuickBtn(
                              icon: Icons.bar_chart_outlined,
                              label: '報表',
                              onTap: () => Navigator.pushNamed(context, '/reports'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Recent Orders
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text('近 10 筆訂單', style: TextStyle(fontWeight: FontWeight.w900)),
                                ),
                                TextButton.icon(
                                  onPressed: () => Navigator.pushNamed(context, '/orders'),
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  label: const Text('訂單管理'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: _recentOrdersStream(isVendor: isVendor, vendorId: vendorId),
                              builder: (context, snap) {
                                if (snap.hasError) {
                                  return Text(
                                    '讀取失敗：${snap.error}',
                                    style: TextStyle(color: cs.error),
                                  );
                                }
                                if (!snap.hasData) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 18),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }

                                final docs = snap.data!.docs;
                                if (docs.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 10),
                                    child: Text('目前沒有訂單'),
                                  );
                                }

                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: docs.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (_, i) {
                                    final d = docs[i];
                                    final data = d.data();

                                    final status = _s(data['status']);
                                    final total = _toNum(data['total'] ?? data['amount'] ?? 0);
                                    final createdAt = _toDate(data['createdAt']);

                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        '訂單 ${d.id}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                      subtitle: Text(
                                        '${status.isEmpty ? '-' : status} ・ NT\$${total.toStringAsFixed(0)} ・ ${_fmt(createdAt)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () {
                                        // 你若有 /payment_status 路由可帶 id
                                        try {
                                          Navigator.pushNamed(context, '/payment_status', arguments: d.id);
                                        } catch (_) {
                                          Navigator.pushNamed(context, '/orders');
                                        }
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
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

class _QuickBtn extends StatelessWidget {
  const _QuickBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withOpacity(0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
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
