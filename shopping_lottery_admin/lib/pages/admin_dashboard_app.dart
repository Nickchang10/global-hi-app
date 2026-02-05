import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_summary_card.dart';
import '../widgets/admin_home_carousel.dart';

class AdminDashboardApp extends StatefulWidget {
  const AdminDashboardApp({super.key});

  @override
  State<AdminDashboardApp> createState() => _AdminDashboardAppState();
}

class _AdminDashboardAppState extends State<AdminDashboardApp> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Osmile 管理後台', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: cs.surface,
        elevation: 0.5,
      ),
      backgroundColor: cs.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 最新消息輪播
            const AdminHomeCarousel(),
            const SizedBox(height: 16),

            // 快捷入口
            _buildQuickActions(cs),
            const SizedBox(height: 16),

            // 今日摘要
            const Text('今日摘要', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildSummaryCards(cs),
            const SizedBox(height: 24),

            // 最新訂單
            const Text('最新訂單', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildLatestOrders(),

            const SizedBox(height: 24),

            // 最新商品
            const Text('最新商品', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildLatestProducts(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(ColorScheme cs) {
    final actions = [
      {'icon': Icons.receipt_long, 'label': '訂單管理'},
      {'icon': Icons.inventory_2_outlined, 'label': '商品管理'},
      {'icon': Icons.campaign_outlined, 'label': '公告管理'},
      {'icon': Icons.bar_chart_outlined, 'label': '報表分析'},
      {'icon': Icons.people_outline, 'label': '會員管理'},
    ];

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final a = actions[i];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('開啟：${a['label']}')));
            },
            child: Container(
              width: 100,
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(a['icon'] as IconData, size: 30, color: cs.primary),
                  const SizedBox(height: 8),
                  Text(a['label'] as String,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(ColorScheme cs) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: const [
        AdminSummaryCard(title: '今日營收', value: 'NT\$4,980', icon: Icons.paid_outlined),
        AdminSummaryCard(title: '今日訂單', value: '1', icon: Icons.receipt_long),
        AdminSummaryCard(title: '商品數量', value: '5', icon: Icons.inventory_2_outlined),
      ],
    );
  }

  Widget _buildLatestOrders() {
    final query = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(3);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Text('目前沒有訂單');
        }

        return Column(
          children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final id = data['id'] ?? d.id;
            final status = data['status'] ?? '未知';
            final amount = data['total'] ?? 0;
            final date = (data['createdAt'] is Timestamp)
                ? (data['createdAt'] as Timestamp).toDate().toString().split(' ').first
                : '';

            return Card(
              elevation: 0.5,
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text('訂單 $id'),
                subtitle: Text('$status • $date'),
                trailing: Text('NT\$${amount.toString()}'),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildLatestProducts() {
    final query = FirebaseFirestore.instance
        .collection('products')
        .orderBy('createdAt', descending: true)
        .limit(3);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Text('目前沒有商品');
        }

        return Column(
          children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final title = data['title'] ?? '';
            final price = data['price'] ?? 0;
            final imageUrl = data['imageUrl'] ?? '';

            return Card(
              elevation: 0.5,
              child: ListTile(
                leading: imageUrl != ''
                    ? Image.network(imageUrl, width: 45, fit: BoxFit.cover)
                    : const Icon(Icons.image_not_supported_outlined),
                title: Text(title),
                trailing: Text('NT\$${price.toString()}'),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
