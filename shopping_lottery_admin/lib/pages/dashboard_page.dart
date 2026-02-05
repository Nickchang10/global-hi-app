// lib/pages/dashboard_page.dart
//
// ✅ DashboardPage v9.2 Final（最終完整版｜統計卡｜近況訂單｜快速入口｜支援簡潔/完整模式｜新增抽獎/購物車）
// ------------------------------------------------------------
// 相容：
// - AdminModeController: isSimpleMode / isFull / toggle()
// - AdminGate: ensureAndGetRole(user, forceRefresh: false), cachedRoleInfo / cachedVendorId
//
// 統計範圍：
// - Admin：全站統計
// - Vendor：僅 vendorId 範圍（products / orders / campaigns / coupons / lotteries / carts）
// - categories 多數情境可給 vendor 看（不範圍）
//
// Firestore 參考：
// - products/{id} (vendorId?)
// - orders/{id} (vendorId? / orderNo / userName / total / status / createdAt)
// - campaigns/{id} (vendorId?)
// - coupons/{id} (vendorId?)
// - lotteries/{id} (vendorId?)   ✅新增
// - carts/{id} (vendorId?)       ✅新增（若你的 carts 結構不同，告訴我我幫你改成可計數）
// - categories/{id}
// - vendors/{id}
// - users/{uid}
// - notifications/{uid}/items/{nid} (isRead)
// ------------------------------------------------------------

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/admin_mode_controller.dart';
import '../services/admin_gate.dart';

// 你專案已存在的簡潔儀表板
import 'admin_simple_dashboard_page.dart';

// 快速入口（請確認檔案存在）
import 'admin_products_page.dart';
import 'admin_campaigns_page.dart';
import 'admin_categories_page.dart';
import 'admin_vendors_page.dart';
import 'admin_notifications_page.dart';
import 'admin_reports_page.dart';
import 'admin_coupons_page.dart';
import 'admin_users_page.dart';
import 'admin_orders_page.dart';

// ✅ 新增：抽獎管理 / 購物車管理（請確認檔案存在）
import 'admin_lottery_page.dart';
import 'admin_cart_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _db = FirebaseFirestore.instance;

  Future<RoleInfo>? _roleFuture;
  String? _lastUid;

  // 每隔一段時間刷新一次統計（避免 count 無法 stream）
  static const Duration _refreshInterval = Duration(seconds: 12);

  Future<RoleInfo> _ensureRole(AdminGate gate, User user) {
    return gate.ensureAndGetRole(user, forceRefresh: false);
  }

  // ----------------------------
  // Count helpers (Aggregation + fallback)
  // ----------------------------
  Future<int> _countOnce(Query<Map<String, dynamic>> q) async {
    try {
      final agg = await q.count().get();
      final dynamic c = agg.count;
      return (c is int) ? c : int.tryParse('$c') ?? 0;
    } catch (_) {
      // fallback
      try {
        final snap = await q.get();
        return snap.size;
      } catch (_) {
        return 0;
      }
    }
  }

  Stream<int> _countStream(
    Query<Map<String, dynamic>> q, {
    Duration interval = _refreshInterval,
  }) async* {
    yield await _countOnce(q);
    yield* Stream.periodic(interval).asyncMap((_) => _countOnce(q));
  }

  // ----------------------------
  // UI helpers
  // ----------------------------
  String _fmtMoney(dynamic v) {
    final n = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    final f = NumberFormat('#,##0', 'zh_TW');
    return 'NT\$${f.format(n)}';
  }

  String _fmtDate(dynamic v) {
    DateTime? d;
    if (v is Timestamp) d = v.toDate();
    if (v is DateTime) d = v;
    if (d == null) return '-';
    return DateFormat('yyyy/MM/dd HH:mm').format(d);
  }

  Color _statusColor(String status, BuildContext context) {
    final s = status.toLowerCase().trim();
    if (s == 'paid') return Colors.green;
    if (s == 'shipped') return Colors.blue;
    if (s == 'completed') return Colors.teal;
    if (s == 'cancelled') return Colors.red;
    return Theme.of(context).colorScheme.primary;
  }

  String _statusLabel(String status) {
    final s = status.toLowerCase().trim();
    switch (s) {
      case 'pending':
        return '待付款';
      case 'paid':
        return '已付款';
      case 'shipped':
        return '已出貨';
      case 'completed':
        return '已完成';
      case 'cancelled':
        return '已取消';
      default:
        return status;
    }
  }

  // ----------------------------
  // Scoped queries
  // ----------------------------
  Query<Map<String, dynamic>> _productsQ({
    required bool isVendor,
    required String vendorId,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('products');
    if (isVendor && vendorId.isNotEmpty) {
      q = q.where('vendorId', isEqualTo: vendorId);
    }
    return q;
  }

  Query<Map<String, dynamic>> _ordersQ({
    required bool isVendor,
    required String vendorId,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('orders');
    if (isVendor && vendorId.isNotEmpty) {
      q = q.where('vendorId', isEqualTo: vendorId);
    }
    return q;
  }

  Query<Map<String, dynamic>> _campaignsQ({
    required bool isVendor,
    required String vendorId,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('campaigns');
    if (isVendor && vendorId.isNotEmpty) {
      q = q.where('vendorId', isEqualTo: vendorId);
    }
    return q;
  }

  Query<Map<String, dynamic>> _couponsQ({
    required bool isVendor,
    required String vendorId,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('coupons');
    if (isVendor && vendorId.isNotEmpty) {
      q = q.where('vendorId', isEqualTo: vendorId);
    }
    return q;
  }

  // ✅ 新增：抽獎
  Query<Map<String, dynamic>> _lotteriesQ({
    required bool isVendor,
    required String vendorId,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('lotteries');
    if (isVendor && vendorId.isNotEmpty) {
      q = q.where('vendorId', isEqualTo: vendorId);
    }
    return q;
  }

  // ✅ 新增：購物車
  // 若你的 carts 結構不是 top-level carts/{id}，告訴我你的結構（例如 carts/{uid}/items/{itemId}）
  // 我會改成可正確 count 的版本（collectionGroup/items 等）。
  Query<Map<String, dynamic>> _cartsQ({
    required bool isVendor,
    required String vendorId,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('carts');
    if (isVendor && vendorId.isNotEmpty) {
      q = q.where('vendorId', isEqualTo: vendorId);
    }
    return q;
  }

  Query<Map<String, dynamic>> _categoriesQ() => _db.collection('categories');
  Query<Map<String, dynamic>> _vendorsQ() => _db.collection('vendors');
  Query<Map<String, dynamic>> _usersQ() => _db.collection('users');

  Query<Map<String, dynamic>> _unreadNotifQ(String uid) {
    return _db
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .where('isRead', isEqualTo: false);
  }

  // ----------------------------
  // Quick nav
  // ----------------------------
  Future<void> _push(BuildContext context, Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('請先登入')));
    }

    final gate = context.read<AdminGate>();
    if (_roleFuture == null || _lastUid != user.uid) {
      _lastUid = user.uid;
      _roleFuture = _ensureRole(gate, user);
    }

    final modeCtrl = context.watch<AdminModeController>();
    if (modeCtrl.isSimpleMode) {
      // ✅ 簡潔模式：沿用你現有的 AdminSimpleDashboardPage
      return const AdminSimpleDashboardPage();
    }

    return FutureBuilder<RoleInfo>(
      future: _roleFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final info = snap.data ?? gate.cachedRoleInfo;
        final role = (info?.role ?? '').toLowerCase().trim();
        final isAdmin = role == 'admin';
        final isVendor = role == 'vendor';

        final vendorIdRaw =
            (info?.vendorId ?? gate.cachedVendorId ?? '').toString().trim();
        final vendorId = (isVendor && vendorIdRaw.isNotEmpty) ? vendorIdRaw : '';

        // Vendor 若缺 vendorId，避免後續混亂
        if (isVendor && vendorId.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text('Vendor 帳號缺少 vendorId，請在 users/{uid} 補上 vendorId'),
            ),
          );
        }

        // 主要統計 streams
        final productsCount$ =
            _countStream(_productsQ(isVendor: isVendor, vendorId: vendorId));
        final ordersCount$ =
            _countStream(_ordersQ(isVendor: isVendor, vendorId: vendorId));
        final campaignsCount$ =
            _countStream(_campaignsQ(isVendor: isVendor, vendorId: vendorId));
        final couponsCount$ =
            _countStream(_couponsQ(isVendor: isVendor, vendorId: vendorId));

        // ✅ 新增：抽獎 / 購物車 streams
        final lotteriesCount$ =
            _countStream(_lotteriesQ(isVendor: isVendor, vendorId: vendorId));
        final cartsCount$ =
            _countStream(_cartsQ(isVendor: isVendor, vendorId: vendorId));

        final categoriesCount$ = _countStream(_categoriesQ());
        final vendorsCount$ =
            isAdmin ? _countStream(_vendorsQ()) : Stream<int>.value(0);
        final usersCount$ =
            isAdmin ? _countStream(_usersQ()) : Stream<int>.value(0);

        final unreadNotifs$ = _countStream(
          _unreadNotifQ(user.uid),
          interval: const Duration(seconds: 8),
        );

        // 近況訂單（最近 10 筆）
        final recentOrdersQ = _ordersQ(isVendor: isVendor, vendorId: vendorId)
            .orderBy('createdAt', descending: true)
            .limit(10);

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              _roleFuture = _ensureRole(gate, user);
              setState(() {});
            },
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _buildHeader(
                  context,
                  isAdmin: isAdmin,
                  isVendor: isVendor,
                  vendorId: vendorId,
                ),
                const SizedBox(height: 12),

                _SectionTitle(
                  title: '即時統計',
                  subtitle: isVendor ? '僅顯示你的廠商範圍' : '全站概覽',
                ),
                const SizedBox(height: 10),

                LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final crossAxisCount = w >= 1100 ? 4 : (w >= 700 ? 3 : 2);

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 2.05,
                      children: [
                        _StatCard.stream(
                          icon: Icons.shopping_bag_outlined,
                          title: '商品數',
                          stream: productsCount$,
                          onTap: () => _push(context, const AdminProductsPage()),
                        ),
                        _StatCard.stream(
                          icon: Icons.receipt_long_outlined,
                          title: '訂單數',
                          stream: ordersCount$,
                          onTap: () => _push(context, const AdminOrdersPage()),
                        ),
                        _StatCard.stream(
                          icon: Icons.campaign_outlined,
                          title: '活動數',
                          stream: campaignsCount$,
                          onTap: () => _push(context, const AdminCampaignsPage()),
                        ),
                        _StatCard.stream(
                          icon: Icons.card_giftcard_outlined,
                          title: '優惠券數',
                          stream: couponsCount$,
                          onTap: () => _push(context, const AdminCouponsPage()),
                        ),

                        // ✅ 新增：抽獎 / 購物車統計卡
                        _StatCard.stream(
                          icon: Icons.celebration_outlined,
                          title: '抽獎數',
                          stream: lotteriesCount$,
                          onTap: () => _push(context, const AdminLotteryPage()),
                        ),
                        _StatCard.stream(
                          icon: Icons.shopping_cart_outlined,
                          title: '購物車數',
                          stream: cartsCount$,
                          onTap: () => _push(context, const AdminCartPage()),
                        ),

                        _StatCard.stream(
                          icon: Icons.category_outlined,
                          title: '分類數',
                          stream: categoriesCount$,
                          onTap: () => _push(context, const AdminCategoriesPage()),
                        ),
                        if (isAdmin)
                          _StatCard.stream(
                            icon: Icons.store_mall_directory_outlined,
                            title: '廠商數',
                            stream: vendorsCount$,
                            onTap: () => _push(context, const AdminVendorsPage()),
                          ),
                        if (isAdmin)
                          _StatCard.stream(
                            icon: Icons.people_alt_outlined,
                            title: '顧客數',
                            stream: usersCount$,
                            onTap: () => _push(context, const AdminUsersPage()),
                          ),
                        _StatCard.stream(
                          icon: Icons.notifications_outlined,
                          title: '未讀通知',
                          stream: unreadNotifs$,
                          onTap: () => _push(context, const AdminNotificationsPage()),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                const _SectionTitle(title: '快速入口', subtitle: '常用後台功能快捷操作'),
                const SizedBox(height: 10),

                _QuickActions(
                  isAdmin: isAdmin,
                  onProducts: () => _push(context, const AdminProductsPage()),
                  onOrders: () => _push(context, const AdminOrdersPage()),
                  onCampaigns: () => _push(context, const AdminCampaignsPage()),
                  onCoupons: () => _push(context, const AdminCouponsPage()),
                  onLottery: () => _push(context, const AdminLotteryPage()), // ✅新增
                  onCart: () => _push(context, const AdminCartPage()),       // ✅新增
                  onCategories: () => _push(context, const AdminCategoriesPage()),
                  onVendors: isAdmin
                      ? () => _push(context, const AdminVendorsPage())
                      : null,
                  onUsers: isAdmin
                      ? () => _push(context, const AdminUsersPage())
                      : null,
                  onReports: () => _push(context, const AdminReportsPage()),
                  onNotifications: () => _push(context, const AdminNotificationsPage()),
                ),

                const SizedBox(height: 16),

                const _SectionTitle(title: '近況訂單', subtitle: '最近 10 筆'),
                const SizedBox(height: 10),

                Card(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: recentOrdersQ.snapshots(),
                    builder: (context, s) {
                      if (!s.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final docs = s.data!.docs;
                      if (docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('目前沒有訂單資料'),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final d = docs[i].data();
                          final orderNo =
                              (d['orderNo'] ?? docs[i].id).toString();
                          final userName =
                              (d['userName'] ?? d['buyerName'] ?? d['name'] ?? '')
                                  .toString();
                          final status = (d['status'] ?? 'pending').toString();
                          final total = d['total'] ?? d['amount'] ?? 0;
                          final createdAt = d['createdAt'];

                          return ListTile(
                            leading: Icon(Icons.receipt_long_outlined,
                                color: _statusColor(status, context)),
                            title: Text('訂單：$orderNo',
                                style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Text(
                              [
                                if (userName.trim().isNotEmpty) '顧客：$userName',
                                '狀態：${_statusLabel(status)}',
                                '金額：${_fmtMoney(total)}',
                                '時間：${_fmtDate(createdAt)}',
                              ].join('｜'),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _statusColor(status, context)
                                    .withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _statusColor(status, context)
                                      .withOpacity(0.35),
                                ),
                              ),
                              child: Text(
                                _statusLabel(status),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _statusColor(status, context),
                                ),
                              ),
                            ),
                            onTap: () async {
                              await _push(context, const AdminOrdersPage());
                            },
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required bool isAdmin,
    required bool isVendor,
    required String vendorId,
  }) {
    final title =
        isAdmin ? '管理員儀表板' : (isVendor ? '廠商儀表板' : '儀表板');

    final subtitle = isVendor ? 'vendorId：$vendorId' : '快速掌握後台運作狀態';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.dashboard_outlined, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('刷新'),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Widgets
// ------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(width: 10),
        if (subtitle != null)
          Expanded(
            child: Text(
              subtitle!,
              style: const TextStyle(color: Colors.black54),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget valueWidget;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.valueWidget,
    this.onTap,
  });

  factory _StatCard.stream({
    required IconData icon,
    required String title,
    required Stream<int> stream,
    VoidCallback? onTap,
  }) {
    return _StatCard(
      icon: icon,
      title: title,
      onTap: onTap,
      valueWidget: StreamBuilder<int>(
        stream: stream,
        builder: (context, s) {
          final v = s.data ?? 0;
          return Text(
            NumberFormat('#,##0', 'zh_TW').format(v),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  valueWidget,
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );

    if (onTap == null) return card;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: card,
    );
  }
}

class _QuickActions extends StatelessWidget {
  final bool isAdmin;

  final VoidCallback onProducts;
  final VoidCallback onOrders;
  final VoidCallback onCampaigns;
  final VoidCallback onCoupons;

  // ✅ 新增
  final VoidCallback onLottery;
  final VoidCallback onCart;

  final VoidCallback onCategories;
  final VoidCallback? onVendors;
  final VoidCallback? onUsers;
  final VoidCallback onReports;
  final VoidCallback onNotifications;

  const _QuickActions({
    required this.isAdmin,
    required this.onProducts,
    required this.onOrders,
    required this.onCampaigns,
    required this.onCoupons,
    required this.onLottery,
    required this.onCart,
    required this.onCategories,
    required this.onVendors,
    required this.onUsers,
    required this.onReports,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <_ActionItem>[
      _ActionItem(icon: Icons.shopping_bag_outlined, label: '商品', onTap: onProducts),
      _ActionItem(icon: Icons.receipt_long_outlined, label: '訂單', onTap: onOrders),
      _ActionItem(icon: Icons.campaign_outlined, label: '活動', onTap: onCampaigns),
      _ActionItem(icon: Icons.card_giftcard_outlined, label: '優惠券', onTap: onCoupons),

      // ✅ 新增：抽獎 / 購物車
      _ActionItem(icon: Icons.celebration_outlined, label: '抽獎', onTap: onLottery),
      _ActionItem(icon: Icons.shopping_cart_outlined, label: '購物車', onTap: onCart),

      _ActionItem(icon: Icons.category_outlined, label: '分類', onTap: onCategories),
      _ActionItem(icon: Icons.notifications_outlined, label: '通知', onTap: onNotifications),
      _ActionItem(icon: Icons.bar_chart_outlined, label: '報表', onTap: onReports),
    ];

    if (isAdmin && onVendors != null) {
      actions.add(_ActionItem(
          icon: Icons.store_mall_directory_outlined, label: '廠商', onTap: onVendors!));
    }
    if (isAdmin && onUsers != null) {
      actions.add(_ActionItem(
          icon: Icons.people_alt_outlined, label: '顧客', onTap: onUsers!));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final cross = w >= 900 ? 8 : (w >= 650 ? 6 : 4);

            return GridView.count(
              crossAxisCount: cross,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.2,
              children: actions
                  .map(
                    (a) => InkWell(
                      onTap: a.onTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(a.icon, size: 26),
                            const SizedBox(height: 8),
                            Text(a.label,
                                style: const TextStyle(fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
