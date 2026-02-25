import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/news_home_section.dart'; // 最新消息輪播

// ------------------ Provider ------------------
class AdminSimpleProvider extends ChangeNotifier {
  final FirebaseFirestore? firestore;
  AdminSimpleProvider({this.firestore}) {
    _init();
  }

  bool loading = false;
  int totalOrders = 0;
  int totalProducts = 0;
  double monthlyRevenue = 0.0;
  List<Map<String, dynamic>> latestOrders = [];

  Future<void> _init() async {
    loading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400)); // 模擬延遲
    await _loadMockData(); // 可換成 firestore
    loading = false;
    notifyListeners();
  }

  Future<void> _loadMockData() async {
    totalOrders = 25;
    totalProducts = 8;
    monthlyRevenue = 12580.0;
    latestOrders = List.generate(5, (i) {
      return {
        'id': 'ORD-${1000 + i}',
        'buyer': 'user${i + 1}@osmile.com',
        'amount': 1000 + (i * 200),
        'status': (i % 2 == 0) ? '已付款' : '待付款',
        'date': DateTime.now().subtract(Duration(days: i)),
      };
    });
  }

  Future<void> refresh() async {
    await _init();
  }
}

// ------------------ Page ------------------
class AdminDashboardSimplePage extends StatelessWidget {
  const AdminDashboardSimplePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminSimpleProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('管理員儀表板'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新資料',
            onPressed: provider.refresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const NewsHomeSection(), // 最新消息輪播
                  const SizedBox(height: 20),
                  _buildSummaryRow(provider),
                  const SizedBox(height: 28),
                  const Text(
                    '快速入口',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildModuleGrid(context),
                  const SizedBox(height: 28),
                  _buildLatestOrders(provider),
                  const SizedBox(height: 40),
                  const Center(
                    child: Text(
                      '© Osmile Admin',
                      style: TextStyle(color: Colors.black45),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ---- Summary ----
  Widget _buildSummaryRow(AdminSimpleProvider p) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryCard(
          title: '全部訂單',
          value: '${p.totalOrders}',
          icon: Icons.receipt_long,
        ),
        _SummaryCard(
          title: '商品數',
          value: '${p.totalProducts}',
          icon: Icons.inventory_2_outlined,
        ),
        _SummaryCard(
          title: '本月營收',
          value: 'NT\$${p.monthlyRevenue.toStringAsFixed(0)}',
          icon: Icons.payments,
        ),
      ],
    );
  }

  // ---- Modules ----
  Widget _buildModuleGrid(BuildContext context) {
    final modules = [
      {'title': '訂單管理', 'icon': Icons.receipt_long},
      {'title': '商品管理', 'icon': Icons.inventory_2_outlined},
      {'title': '廠商管理', 'icon': Icons.apartment_outlined},
      {'title': '公告', 'icon': Icons.campaign_outlined},
      {'title': '報表', 'icon': Icons.bar_chart_outlined},
      {'title': '系統設定', 'icon': Icons.settings_outlined},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: modules.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 3.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, i) {
        final m = modules[i];
        return _ModuleCard(
          title: m['title'] as String,
          icon: m['icon'] as IconData,
        );
      },
    );
  }

  // ---- Latest Orders ----
  Widget _buildLatestOrders(AdminSimpleProvider p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '最近訂單',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        if (p.latestOrders.isEmpty)
          const Text('目前沒有訂單', style: TextStyle(color: Colors.black54))
        else
          Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              itemCount: p.latestOrders.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final o = p.latestOrders[i];
                return ListTile(
                  leading: Icon(
                    Icons.shopping_cart_outlined,
                    color: Colors.blue.shade700,
                  ),
                  title: Text('${o['id']}'),
                  subtitle: Text('${o['status']}｜${o['buyer']}'),
                  trailing: Text(
                    'NT\$${o['amount']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ------------------ Widgets ------------------
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // ✅ surfaceVariant deprecated → surfaceContainerHighest
      // ✅ withOpacity deprecated → withValues(alpha: ...)
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  const _ModuleCard({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      // ✅ surfaceVariant deprecated → surfaceContainerHighest
      // ✅ withOpacity deprecated → withValues(alpha: ...)
      color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('開啟 $title')));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
