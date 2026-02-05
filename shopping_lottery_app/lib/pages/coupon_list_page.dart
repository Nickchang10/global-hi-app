import 'package:flutter/material.dart';
import '../services/coupon_service.dart';

class CouponListPage extends StatefulWidget {
  const CouponListPage({super.key});
  @override
  State<CouponListPage> createState() => _CouponListPageState();
}

class _CouponListPageState extends State<CouponListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final cs = CouponService.instance;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    cs.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的折價券', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        bottom: const TabBar(
          tabs: [
            Tab(text: '可使用'),
            Tab(text: '已使用'),
            Tab(text: '已過期'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildList(cs.available, '目前無可用折價券'),
          _buildList(cs.used, '目前無已使用折價券'),
          _buildList(cs.expired, '目前無過期折價券'),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list, String emptyMsg) {
    if (list.isEmpty) {
      return Center(child: Text(emptyMsg, style: const TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = list[i];
        final title = (c['title'] ?? '優惠券').toString();
        final code = (c['code'] ?? '').toString();
        final type = (c['type'] ?? 'amount').toString();
        final amount = c['amount'] ?? 0;
        final percent = c['percent'] ?? 0;
        final exp = DateTime.fromMillisecondsSinceEpoch(c['expiresAt']);
        final expired = exp.isBefore(DateTime.now());

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: expired
              ? Colors.grey.shade100
              : (c['used'] == true ? Colors.grey.shade200 : Colors.orange.shade50),
          child: ListTile(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              c['used'] == true
                  ? '已使用'
                  : (expired ? '已過期' : '有效至：${exp.toString().substring(0, 10)}'),
            ),
            trailing: Text(
              type == 'percent'
                  ? '-${percent.toString()}%'
                  : '-\$${amount.toString()}',
              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.orange),
            ),
          ),
        );
      },
    );
  }
}
