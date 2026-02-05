// lib/pages/coupons_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/coupon_service.dart';

class CouponsPage extends StatefulWidget {
  const CouponsPage({super.key});

  @override
  State<CouponsPage> createState() => _CouponsPageState();
}

class _CouponsPageState extends State<CouponsPage>
    with SingleTickerProviderStateMixin {
  static const Color _bg = Color(0xFFF6F7FA);
  static const Color _primary = Colors.blueAccent;
  static const Color _brand = Colors.orangeAccent;

  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);

    // 雙保險 init（已 init 不會重複做事）
    Future.microtask(() async {
      try {
        await CouponService.instance.init();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1300),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    final i = int.tryParse(v.toString());
    if (i != null) return DateTime.fromMillisecondsSinceEpoch(i);
    return null;
  }

  String _fmtDate(dynamic v) {
    final dt = _toDate(v);
    if (dt == null) return '-';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  Future<void> _confirmClearAll(CouponService cs) async {
    if (cs.all.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空優惠券', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('確定要清空全部折價券/優惠券嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await CouponService.instance.clearAll();
      _toast('已清空全部優惠券');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.watch<CouponService>();

    final unused = cs.available;
    final used = cs.used;
    final expired = cs.expired;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('折價券 / 優惠券',
            style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.6,
        actions: [
          IconButton(
            tooltip: '清空全部',
            onPressed: cs.all.isEmpty ? null : () => _confirmClearAll(cs),
            icon: const Icon(Icons.delete_outline),
          ),
          const SizedBox(width: 6),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _primary,
          labelColor: _primary,
          unselectedLabelColor: Colors.grey.shade600,
          tabs: [
            Tab(text: '未使用 ${unused.length}'),
            Tab(text: '已使用 ${used.length}'),
            Tab(text: '已過期 ${expired.length}'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSummaryBar(
            unused: unused.length,
            used: used.length,
            expired: expired.length,
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildList(unused, state: 'unused'),
                _buildList(used, state: 'used'),
                _buildList(expired, state: 'expired'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        onPressed: () async {
          await CouponService.instance.addCoupon(
            title: '限時｜折抵 NT\$100',
            type: 'amount',
            amountOrPercent: 100,
            minSpend: 500,
            expiresAt: DateTime.now().add(const Duration(days: 14)),
            source: 'demo',
          );
          _toast('已新增示範優惠券');
        },
        icon: const Icon(Icons.add),
        label: const Text('新增示範券'),
      ),
    );
  }

  Widget _buildSummaryBar({
    required int unused,
    required int used,
    required int expired,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer_outlined, color: _primary),
          const SizedBox(width: 8),
          const Text('我的優惠券', style: TextStyle(fontWeight: FontWeight.w900)),
          const Spacer(),
          _miniChip('未用 $unused', color: _brand),
          const SizedBox(width: 6),
          _miniChip('已用 $used', color: Colors.grey),
          const SizedBox(width: 6),
          _miniChip('過期 $expired', color: Colors.grey),
        ],
      ),
    );
  }

  Widget _miniChip(String text, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list, {required String state}) {
    if (list.isEmpty) return _buildEmpty(state);

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: list.length,
      itemBuilder: (_, i) => _CouponCard(
        data: list[i],
        state: state,
        formatDate: _fmtDate,
        onCopy: (code) async {
          await Clipboard.setData(ClipboardData(text: code));
          _toast('已複製券碼：$code');
        },
        onMarkUsed: (id) async {
          await CouponService.instance.markUsed(id);
          _toast('已設為已使用');
        },
        onRemove: (id) async {
          await CouponService.instance.remove(id);
          _toast('已移除');
        },
      ),
    );
  }

  Widget _buildEmpty(String state) {
    String title;
    String desc;
    IconData icon;

    switch (state) {
      case 'used':
        title = '尚無已使用優惠券';
        desc = '結帳使用過的券會顯示在這裡。';
        icon = Icons.lock_outline;
        break;
      case 'expired':
        title = '尚無已過期優惠券';
        desc = '過期的券會自動移到這裡。';
        icon = Icons.event_busy_outlined;
        break;
      default:
        title = '尚無可用優惠券';
        desc = '活動或抽獎後即可獲得優惠券。';
        icon = Icons.local_offer_outlined;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              desc,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String state;
  final String Function(dynamic expiresAt) formatDate;
  final Future<void> Function(String code) onCopy;
  final Future<void> Function(String id) onMarkUsed;
  final Future<void> Function(String id) onRemove;

  const _CouponCard({
    required this.data,
    required this.state,
    required this.formatDate,
    required this.onCopy,
    required this.onMarkUsed,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? '優惠券').toString();
    final type = (data['type'] ?? 'amount').toString();
    final amount = (data['amount'] ?? 0).toString();
    final percent = (data['percent'] ?? 0).toString();
    final minSpend = (data['minSpend'] ?? 0).toString();
    final code = (data['code'] ?? '').toString();
    final id = (data['id'] ?? '').toString();

    final isInactive = state != 'unused';

    final borderColor = isInactive ? Colors.grey.shade300 : Colors.orangeAccent;
    final bg = isInactive ? Colors.grey.shade100 : Colors.white;

    final valueText = type == 'percent' ? '$percent%' : 'NT\$$amount';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isInactive ? 0.02 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isInactive
                    ? Colors.grey.shade200
                    : Colors.orangeAccent.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_offer_outlined,
                color: isInactive ? Colors.grey : Colors.orangeAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: isInactive ? Colors.grey.shade700 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '最低消費：NT\$$minSpend ｜ 有效期限：${formatDate(data['expiresAt'])}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (code.isNotEmpty)
                        InkWell(
                          onTap: isInactive ? null : () => onCopy(code),
                          borderRadius: BorderRadius.circular(999),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '券碼：$code',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        valueText,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: isInactive ? Colors.grey : Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              children: [
                IconButton(
                  tooltip: '刪除',
                  onPressed: () => onRemove(id),
                  icon: const Icon(Icons.delete_outline),
                ),
                if (!isInactive)
                  TextButton(
                    onPressed: () => onMarkUsed(id),
                    child: const Text(
                      '設為已用',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
