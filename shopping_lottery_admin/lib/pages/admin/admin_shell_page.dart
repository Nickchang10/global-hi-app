import 'package:flutter/material.dart';
import '../../layouts/scaffold_with_drawer.dart';

// ✅ 重要：引入商品模組
import 'products/admin_products_page.dart';

class AdminShellPage extends StatelessWidget {
  const AdminShellPage({super.key});

  static const String routeName = '/admin';

  @override
  Widget build(BuildContext context) {
    final raw = ModalRoute.of(context)?.settings.name ?? routeName;
    final normalized = _normalize(raw);

    return ScaffoldWithDrawer(
      title: _title(normalized),
      currentRoute: normalized,
      body: _body(normalized, context),
    );
  }

  Widget _body(String route, BuildContext context) {
    switch (route) {
      case '/admin/products':
        return const AdminProductsModule();

      case '/admin/orders':
        return const _ModulePlaceholder(title: '訂單管理（待接上）');

      case '/admin/campaigns':
        return const _ModulePlaceholder(title: '活動管理（待接上）');

      // 讓商品新增/詳情 route 也先不 Unknown（先顯示 placeholder）
      case '/admin_product_edit':
        final args = ModalRoute.of(context)?.settings.arguments;
        final pid = (args is Map) ? (args['productId']?.toString() ?? '') : '';
        return _ModulePlaceholder(
          title: pid.isEmpty ? '新增商品（待接上編輯頁）' : '編輯商品 $pid（待接上編輯頁）',
        );

      case '/admin_product_detail':
        final args = ModalRoute.of(context)?.settings.arguments;
        final pid = (args is Map) ? (args['productId']?.toString() ?? '') : '';
        return _ModulePlaceholder(
          title: pid.isEmpty ? '商品詳情（缺 productId）' : '商品詳情 $pid（待接上詳情頁）',
        );

      default:
        return const _DashboardBody();
    }
  }

  String _title(String route) {
    switch (route) {
      case '/admin/products':
        return '商品管理';
      case '/admin/orders':
        return '訂單管理';
      case '/admin/campaigns':
        return '活動管理';
      default:
        return '管理總覽';
    }
  }
}

/// hyphen → slash 統一
String _normalize(String r) {
  if (r == '/admin-products') return '/admin/products';
  if (r == '/admin-orders') return '/admin/orders';
  if (r == '/admin-campaigns') return '/admin/campaigns';
  return r.isEmpty ? '/admin' : r;
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context) {
    final items = <_Entry>[
      _Entry(
        '商品管理',
        '新增/編輯/上架/庫存',
        Icons.inventory_2_outlined,
        '/admin/products',
      ),
      _Entry(
        '訂單管理',
        '查詢/出貨/退款/批次',
        Icons.receipt_long_outlined,
        '/admin/orders',
      ),
      _Entry(
        '活動管理',
        '優惠券/抽獎/分群/派發',
        Icons.campaign_outlined,
        '/admin/campaigns',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _header(context),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (_, i) => _Card(entry: items[i]),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.dashboard_outlined, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Osmile 後台管理',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text('從這裡快速進入各功能模組'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final _Entry entry;
  const _Card({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pushNamed(context, entry.route),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(entry.icon, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.subtitle,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _Entry {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  const _Entry(this.title, this.subtitle, this.icon, this.route);
}

class _ModulePlaceholder extends StatelessWidget {
  final String title;
  const _ModulePlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}
