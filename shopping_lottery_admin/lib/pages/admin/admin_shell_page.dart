// lib/pages/admin/admin_shell_page.dart
//
// ✅ AdminShellPage（最終完整版｜可直接使用｜可編譯｜已移除 SOS）
// ------------------------------------------------------------
// - 左側導航列 + 主內容區
// - 支援 Admin / Super Admin 權限
// - 商城 / 會員 / App 控制中心 / 內容 / 內部 / 系統管理
//
// ✅ 已接入正式頁面：
//   - 會員管理：AdminMembersPage / AdminMemberOrdersPage / AdminMemberPointsTasksPage
//   - 內容管理：
//       - 最新消息：AdminNewsPage
//       - 頁面內容（About/Terms/Privacy）：AdminPagesPage（site_contents）
//       - FAQ：AdminFaqPage（faqs）
//   - 內部管理：
//       - 審核 / 工單：AdminApprovalsPage（approvals）
//       - 內部公告：AdminInternalAnnouncementsPage（announcements）
//   - ✅ 系統管理：
//       - ✅ 報表分析：AdminSystemAnalyticsPage
//       - ✅ 角色 / 權限：AdminRolesPage
//       - ✅ 系統設定：SystemSettingsPage（取代 placeholder）
//
// ✅ SOS：已移除（此檔案不包含 SOS 選單 / route / import）
//
// ✅ Route 修正：
//   - 新增「營收報表」入口，並用內層 Navigator 接住
//     RouteNames.adminSalesReport / RouteNames.adminSalesExport
//   - 避免 Unknown route: /admin_sales_report
// ------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/admin_mode_controller.dart';
import '../../services/admin_gate.dart';

// ✅ 新增：統一路由名稱
import '../../routes/route_names.dart';

// ✅ 新增：營收報表頁 / 匯出頁
import 'reports/admin_sales_report_page.dart';
import 'reports/admin_sales_export_page.dart';

// Admin-only
import 'reports/admin_reports_dashboard_page.dart';
import 'vendors/admin_vendors_page.dart';
import 'vendors/admin_vendors_dashboard_page.dart';
import 'vendors/admin_vendor_detail_page.dart';
import 'vendors/admin_vendors_report_page.dart';
import 'campaigns/admin_campaigns_page.dart';
import 'marketing/admin_marketing_shell_page.dart';

// App 控制中心
import 'app_center/admin_app_center_page.dart';

// 內容管理（✅ 用 alias 徹底解掉 AdminFaqPage 重複匯入與解析失敗）
import 'content/admin_news_page.dart';
import 'content/admin_pages_page.dart' as cms_pages;
import 'content/admin_faq_page.dart' as cms_faq;

// 內部管理
import 'internal/admin_approvals_page.dart';
import 'internal/admin_internal_announcements_page.dart';

// 商城
import 'orders/admin_orders_page.dart';
import 'products/admin_products_page.dart';
import 'categories/admin_categories_page.dart';
import 'products/admin_variants_page.dart';
import 'shipping/admin_shipping_management_page.dart' as ship;
import 'cart/admin_cart_management_page.dart' as cart;

// ❌ 移除：商城首頁設定
// import 'shop/admin_shop_home_settings_page.dart';

// 會員管理
import 'members/admin_members_page.dart';
import 'members/admin_member_orders_page.dart';
import 'members/admin_member_points_tasks_page.dart';

// ✅ 系統管理：報表分析（正式頁）
import 'system/admin_system_analytics_page.dart';
// ✅ 系統管理：角色/權限（正式頁）
import 'system/admin_roles_page.dart';
// ✅ 系統管理：系統設定（正式頁）
import 'system/system_settings_page.dart';

// 既有頁面
import '../notifications_page.dart';
import '../reports_page.dart';

class AdminShellPage extends StatefulWidget {
  const AdminShellPage({super.key});

  @override
  State<AdminShellPage> createState() => _AdminShellPageState();
}

class _AdminShellPageState extends State<AdminShellPage> {
  String _selected = 'shop.orders';

  bool _openShop = true;
  bool _openMembers = true;
  bool _openAppCenter = true;
  bool _openContent = true;
  bool _openInternal = true;
  bool _openSystemMgmt = true;
  bool _openAdminOnly = true;

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AdminModeController>().role.trim().toLowerCase();
    final isAdmin = role == 'admin' || role == 'super_admin';

    // ✅ 保險：若之前選到已移除的頁面 key，直接回到訂單管理
    if (_selected == 'shop.home_settings') {
      _selected = 'shop.orders';
    }

    // ✅ 不使用 const 建構：避免「Not a constant expression」踩雷（某些頁面 constructor 非 const）
    final pages = <String, Widget Function()>{
      // 管理者功能（admin-only）
      'admin.dashboard': () => AdminReportsDashboardPage(),
      'admin.vendors': () => AdminVendorsPage(),
      'admin.vendors.dashboard': () => AdminVendorsDashboardPage(),
      'admin.vendors.detail': () => AdminVendorDetailPage(vendorId: ''),
      'admin.vendors.report': () => AdminVendorReportPage(vendorId: '', vendorName: ''),
      'admin.campaigns': () => AdminCampaignsPage(),
      'admin.marketing': () => AdminMarketingShellPage(),

      // 商城管理
      'shop.orders': () => AdminOrdersPage(),
      'shop.products': () => AdminProductsPage(),
      'shop.categories': () => AdminCategoriesPage(),
      'shop.variants': () => AdminVariantsPage(),
      'shop.shipping': () => ship.AdminShippingManagementPage(),
      'shop.cart': () => cart.AdminCartManagementPage(),
      // ❌ 移除：'shop.home_settings'

      // 會員管理
      'member.list': () => AdminMembersPage(),
      'member.orders': () => AdminMemberOrdersPage(),
      'member.points_tasks': () => AdminMemberPointsTasksPage(),

      // App 控制中心
      'app.center': () => AdminAppCenterPage(),

      // 內容管理
      'content.news': () => AdminNewsPage(),
      'content.pages': () => cms_pages.AdminPagesPage(),
      'content.faq': () => cms_faq.AdminFaqPage(),

      // 內部管理
      'internal.approvals': () => AdminApprovalsPage(),
      'internal.staff_announcements': () => AdminInternalAnnouncementsPage(),

      // 系統管理
      'system.notifications': () => NotificationsPage(),
      'system.analytics': () => AdminSystemAnalyticsPage(),

      // ✅ 新增：營收報表（用內層 Navigator 接住 RouteNames.adminSalesReport/adminSalesExport）
      'system.sales_report': () => const _SalesReportNavigator(),

      'system.roles': () => AdminRolesPage(),
      'system.settings': () => SystemSettingsPage(),
      'system.reports_export': () => ReportsPage(),
    };

    // ✅ 非 admin 不可進入 admin-only 區塊
    if (!isAdmin && _selected.startsWith('admin.')) {
      _selected = 'shop.orders';
    }

    final currentPage = (pages[_selected] ?? () => AdminOrdersPage())();

    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(context, isAdmin),
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              child: currentPage,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // Sidebar
  // =====================================================
  Widget _buildSidebar(BuildContext context, bool isAdmin) {
    final cs = Theme.of(context).colorScheme;
    final role = context.watch<AdminModeController>().role.trim();

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 18),
          const Text(
            'Osmile 後台管理',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            '角色：$role',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),

                if (isAdmin) ...[
                  _groupHeader(
                    '管理者功能',
                    _openAdminOnly,
                    () => setState(() => _openAdminOnly = !_openAdminOnly),
                  ),
                  if (_openAdminOnly) ...[
                    _menuTile(Icons.dashboard_outlined, '報表總覽', 'admin.dashboard'),
                    _submenuGroup(
                      keyId: 'vendors_group',
                      title: '廠商管理',
                      icon: Icons.store_mall_directory_outlined,
                      items: [
                        _menuTile(Icons.dashboard, '廠商儀表板', 'admin.vendors.dashboard'),
                        _menuTile(Icons.people, '廠商列表', 'admin.vendors'),
                        _menuTile(Icons.analytics_outlined, '廠商報表', 'admin.vendors.report'),
                      ],
                    ),
                    _menuTile(Icons.campaign_outlined, '活動管理', 'admin.campaigns'),
                    _menuTile(Icons.local_offer_outlined, '行銷中心', 'admin.marketing'),
                  ],
                  const Divider(),
                ],

                _groupHeader('商城管理', _openShop, () => setState(() => _openShop = !_openShop)),
                if (_openShop) ...[
                  _menuTile(Icons.shopping_bag_outlined, '訂單管理', 'shop.orders'),
                  _menuTile(Icons.inventory_2_outlined, '商品管理', 'shop.products'),
                  _menuTile(Icons.category_outlined, '商品分類', 'shop.categories'),
                  _menuTile(Icons.tune, '規格 / 款式', 'shop.variants'),
                  _menuTile(Icons.local_shipping_outlined, '出貨 / 退款', 'shop.shipping'),
                  _menuTile(Icons.shopping_cart_outlined, '購物車管理', 'shop.cart'),
                ],
                const Divider(),

                _groupHeader('會員管理', _openMembers, () => setState(() => _openMembers = !_openMembers)),
                if (_openMembers) ...[
                  _menuTile(Icons.people_alt_outlined, '會員列表', 'member.list'),
                  _menuTile(Icons.receipt_long_outlined, '會員訂單', 'member.orders'),
                  _menuTile(Icons.stars_outlined, '積分 / 任務', 'member.points_tasks'),
                ],
                const Divider(),

                _groupHeader('App 控制中心', _openAppCenter, () => setState(() => _openAppCenter = !_openAppCenter)),
                if (_openAppCenter) ...[
                  _menuTile(Icons.settings_applications_outlined, 'App 控制中心', 'app.center'),
                ],
                const Divider(),

                _groupHeader('內容管理', _openContent, () => setState(() => _openContent = !_openContent)),
                if (_openContent) ...[
                  _menuTile(Icons.article_outlined, '最新消息', 'content.news'),
                  _menuTile(Icons.web_outlined, '頁面內容', 'content.pages'),
                  _menuTile(Icons.quiz_outlined, 'FAQ', 'content.faq'),
                ],
                const Divider(),

                _groupHeader('內部管理', _openInternal, () => setState(() => _openInternal = !_openInternal)),
                if (_openInternal) ...[
                  _menuTile(Icons.fact_check_outlined, '審核 / 工單', 'internal.approvals'),
                  _menuTile(Icons.campaign_outlined, '內部公告', 'internal.staff_announcements'),
                ],
                const Divider(),

                _groupHeader('系統管理', _openSystemMgmt, () => setState(() => _openSystemMgmt = !_openSystemMgmt)),
                if (_openSystemMgmt) ...[
                  _menuTile(Icons.notifications_active_outlined, '通知中心', 'system.notifications'),
                  _menuTile(Icons.query_stats_outlined, '報表分析', 'system.analytics'),

                  // ✅ 新增：營收報表（修正 Unknown route 用）
                  _menuTile(Icons.bar_chart_outlined, '營收報表', 'system.sales_report'),

                  _menuTile(Icons.admin_panel_settings_outlined, '角色 / 權限', 'system.roles'),
                  _menuTile(Icons.settings_outlined, '系統設定', 'system.settings'),
                  _menuTile(Icons.bar_chart_outlined, '報表導出', 'system.reports_export'),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('登出', style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () async {
              await context.read<AdminGate>().signOut();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }

  // =====================================================
  // 共用 UI
  // =====================================================
  Widget _groupHeader(String title, bool opened, VoidCallback onToggle) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Row(
          children: [
            Icon(opened ? Icons.expand_more : Icons.chevron_right, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _submenuGroup({
    required String keyId,
    required String title,
    required IconData icon,
    required List<Widget> items,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ExpansionTile(
      key: PageStorageKey<String>(keyId),
      leading: Icon(icon, color: cs.primary),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurfaceVariant),
      ),
      tilePadding: const EdgeInsets.only(left: 12, right: 8),
      childrenPadding: const EdgeInsets.only(left: 40),
      children: items,
    );
  }

  Widget _menuTile(IconData icon, String title, String id) {
    final selected = _selected == id;
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: selected ? cs.primary : Colors.grey[700]),
      title: Text(
        title,
        style: TextStyle(
          color: selected ? cs.primary : Colors.black87,
          fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
        ),
      ),
      selected: selected,
      selectedTileColor: cs.primaryContainer.withOpacity(0.4),
      onTap: () => setState(() => _selected = id),
    );
  }
}

// =====================================================
// ✅ 內層 Navigator：只負責 SalesReport / SalesExport 兩個 route
// 目的：讓 AdminSalesReportPage 內部 pushNamed(RouteNames.adminSalesExport) 不會 Unknown route
// =====================================================
class _SalesReportNavigator extends StatelessWidget {
  const _SalesReportNavigator();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      initialRoute: RouteNames.adminSalesReport,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case RouteNames.adminSalesReport:
            return MaterialPageRoute(
              builder: (_) => const AdminSalesReportPage(),
              settings: settings,
            );

          case RouteNames.adminSalesExport:
            return MaterialPageRoute(
              builder: (_) => const AdminSalesExportPage(),
              settings: settings,
            );

          default:
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                body: Center(child: Text('Unknown route: ${settings.name}')),
              ),
              settings: settings,
            );
        }
      },
    );
  }
}
