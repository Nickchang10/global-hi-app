import 'package:flutter/material.dart';

/// AdminHomeActionsPage (正式版｜完整版｜可直接編譯)
///
/// - 修正重點：移除非註解的雜字元（例如 `—`），避免 expected_token
/// - 功能：
///   - 後台快捷入口（Grid）
///   - 搜尋過濾
///   - 常用(星號)置頂（僅本頁記憶體狀態；你也可改成 SharedPreferences）
///   - 使用 Navigator.pushNamed 跳轉（不依賴其他頁面 import，確保可編譯）
///
/// 注意：路由字串請依你專案實際 routes 對齊（下方 const 已列好）。
class AdminHomeActionsPage extends StatefulWidget {
  const AdminHomeActionsPage({super.key});

  @override
  State<AdminHomeActionsPage> createState() => _AdminHomeActionsPageState();
}

class _AdminHomeActionsPageState extends State<AdminHomeActionsPage> {
  final _searchCtrl = TextEditingController();
  final Set<String> _pinned = <String>{}; // action.id

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_AdminAction> _allActions() {
    return const <_AdminAction>[
      _AdminAction(
        id: 'dashboard',
        title: '總覽',
        icon: Icons.dashboard,
        routeName: kRouteAdminDashboard,
      ),
      _AdminAction(
        id: 'shop',
        title: '商城設定',
        icon: Icons.storefront,
        routeName: kRouteAdminShopSettings,
      ),
      _AdminAction(
        id: 'products',
        title: '商品管理',
        icon: Icons.inventory_2,
        routeName: kRouteAdminProducts,
      ),
      _AdminAction(
        id: 'orders',
        title: '訂單管理',
        icon: Icons.receipt_long,
        routeName: kRouteAdminOrders,
      ),
      _AdminAction(
        id: 'refunds',
        title: '退款管理',
        icon: Icons.currency_exchange,
        routeName: kRouteAdminRefunds,
      ),
      _AdminAction(
        id: 'shipping',
        title: '出貨管理',
        icon: Icons.local_shipping,
        routeName: kRouteAdminShipping,
      ),
      _AdminAction(
        id: 'members',
        title: '會員管理',
        icon: Icons.group,
        routeName: kRouteAdminMembers,
      ),
      _AdminAction(
        id: 'points',
        title: '點數任務',
        icon: Icons.stars,
        routeName: kRouteAdminPointsTasks,
      ),
      _AdminAction(
        id: 'vendors',
        title: '商家管理',
        icon: Icons.store,
        routeName: kRouteAdminVendors,
      ),
      _AdminAction(
        id: 'campaigns',
        title: '活動管理',
        icon: Icons.campaign,
        routeName: kRouteAdminCampaigns,
      ),
      _AdminAction(
        id: 'lottery',
        title: '抽獎管理',
        icon: Icons.casino,
        routeName: kRouteAdminLottery,
      ),
      _AdminAction(
        id: 'news',
        title: '最新消息',
        icon: Icons.article,
        routeName: kRouteAdminNews,
      ),
      _AdminAction(
        id: 'pages',
        title: '頁面內容',
        icon: Icons.description,
        routeName: kRouteAdminPages,
      ),
      _AdminAction(
        id: 'faq',
        title: 'FAQ',
        icon: Icons.help_center,
        routeName: kRouteAdminFaq,
      ),
      _AdminAction(
        id: 'approvals',
        title: '審核/工單',
        icon: Icons.rule,
        routeName: kRouteAdminApprovals,
      ),
      _AdminAction(
        id: 'announcements',
        title: '內部公告',
        icon: Icons.announcement,
        routeName: kRouteAdminAnnouncements,
      ),
      _AdminAction(
        id: 'contact',
        title: '聯絡訊息',
        icon: Icons.support_agent,
        routeName: kRouteAdminContact,
      ),
      _AdminAction(
        id: 'analytics',
        title: '報表分析',
        icon: Icons.query_stats,
        routeName: kRouteAdminAnalytics,
      ),
      _AdminAction(
        id: 'roles',
        title: '角色/權限',
        icon: Icons.admin_panel_settings,
        routeName: kRouteAdminRoles,
      ),
      _AdminAction(
        id: 'system',
        title: '系統設定',
        icon: Icons.settings,
        routeName: kRouteAdminSystemSettings,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final all = _allActions();
    final keyword = _searchCtrl.text.trim().toLowerCase();

    final filtered = all.where((a) {
      if (keyword.isEmpty) return true;
      return a.title.toLowerCase().contains(keyword) ||
          a.id.toLowerCase().contains(keyword);
    }).toList();

    filtered.sort((a, b) {
      final ap = _pinned.contains(a.id) ? 0 : 1;
      final bp = _pinned.contains(b.id) ? 0 : 1;
      final c = ap.compareTo(bp);
      if (c != 0) return c;
      return a.title.compareTo(b.title);
    });

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1200
        ? 5
        : width >= 980
        ? 4
        : width >= 680
        ? 3
        : 2;

    final titleStyle =
        Theme.of(context).textTheme.titleLarge ??
        const TextStyle(fontSize: 18, fontWeight: FontWeight.w900);

    return Scaffold(
      appBar: AppBar(
        title: const Text('後台快捷入口'),
        actions: [
          IconButton(
            tooltip: '清除置頂',
            onPressed: _pinned.isEmpty
                ? null
                : () {
                    setState(_pinned.clear);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已清除置頂')));
                  },
            icon: const Icon(Icons.auto_delete),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋快捷入口…（例如：訂單、商品、會員）',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  tooltip: '清除',
                  onPressed: () {
                    _searchCtrl.clear();
                    FocusScope.of(context).unfocus();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      '沒有符合的入口',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final a = filtered[i];
                      final pinned = _pinned.contains(a.id);

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _go(context, a),
                        child: Card(
                          elevation: 0.8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      // ✅ 修正：withOpacity(0.12) -> withValues(alpha: 31)
                                      backgroundColor: cs.primary.withValues(
                                        alpha: 31,
                                      ),
                                      child: Icon(a.icon, color: cs.primary),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: pinned ? '取消置頂' : '置頂',
                                      onPressed: () {
                                        setState(() {
                                          if (pinned) {
                                            _pinned.remove(a.id);
                                          } else {
                                            _pinned.add(a.id);
                                          }
                                        });
                                      },
                                      icon: Icon(
                                        pinned ? Icons.star : Icons.star_border,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  a.title,
                                  style: titleStyle.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  a.routeName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: FilledButton.tonalIcon(
                                    onPressed: () => _go(context, a),
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('開啟'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _go(BuildContext context, _AdminAction a) {
    Navigator.of(context).pushNamed(a.routeName);
  }
}

class _AdminAction {
  const _AdminAction({
    required this.id,
    required this.title,
    required this.icon,
    required this.routeName,
  });

  final String id;
  final String title;
  final IconData icon;
  final String routeName;
}

/// 你可以把這些 routeName 改成你專案已存在的命名路由
const String kRouteAdminDashboard = '/admin/dashboard';
const String kRouteAdminShopSettings = '/admin/shop_settings';
const String kRouteAdminProducts = '/admin/products';
const String kRouteAdminOrders = '/admin/orders';
const String kRouteAdminRefunds = '/admin/refunds';
const String kRouteAdminShipping = '/admin/shipping';
const String kRouteAdminMembers = '/admin/members';
const String kRouteAdminPointsTasks = '/admin/points_tasks';
const String kRouteAdminVendors = '/admin/vendors';
const String kRouteAdminCampaigns = '/admin/campaigns';
const String kRouteAdminLottery = '/admin/lottery';
const String kRouteAdminNews = '/admin/news';
const String kRouteAdminPages = '/admin/pages';
const String kRouteAdminFaq = '/admin/faq';
const String kRouteAdminApprovals = '/admin/approvals';
const String kRouteAdminAnnouncements = '/admin/announcements';
const String kRouteAdminContact = '/admin/contact';
const String kRouteAdminAnalytics = '/admin/analytics';
const String kRouteAdminRoles = '/admin/roles';
const String kRouteAdminSystemSettings = '/admin/system_settings';
