// lib/pages/admin/system/admin_analytics_page.dart
//
// ✅ AdminSystemAnalyticsPage（正式版｜完整版｜可直接編譯｜已移除 unnecessary_cast）
// ------------------------------------------------------------
// - 讀取/寫入：system_analytics/overview
// - 顯示：會員數 / 商品數 / 訂單數 / 優惠券數 / 近30天營收 / 近30天付款單數
// - 提供「重新計算」按鈕：即時計算後寫回 overview
//
// ⚠️ 注意：此版本用 get() + snapshot.size 計數（示範/小型資料可用）。
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSystemAnalyticsPage extends StatelessWidget {
  const AdminSystemAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) => const AdminAnalyticsPage();
}

/// 兼容你可能在路由或 shell 內使用的名稱
class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  DocumentReference<Map<String, dynamic>> get _overviewRef =>
      FirebaseFirestore.instance.collection('system_analytics').doc('overview');

  bool _busy = false;

  Future<void> _recompute() async {
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final from30d = now.subtract(const Duration(days: 30));

      // ✅ 計數（示範：直接 get 取 size）
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .get();
      final productsSnap = await FirebaseFirestore.instance
          .collection('products')
          .get();
      final ordersSnap = await FirebaseFirestore.instance
          .collection('orders')
          .get();
      final couponsSnap = await FirebaseFirestore.instance
          .collection('coupons')
          .get();

      // ✅ 近30天訂單（已付款）統計
      final paid30dSnap = await FirebaseFirestore.instance
          .collection('orders')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(from30d),
          )
          .where('status', isEqualTo: 'paid')
          .get();

      double revenue30d = 0;
      for (final d in paid30dSnap.docs) {
        final m = d.data();
        revenue30d += _toDouble(
          m['totalAmount'] ?? m['amount'] ?? m['total'] ?? 0,
        );
      }

      final payload = <String, dynamic>{
        'usersCount': usersSnap.size,
        'productsCount': productsSnap.size,
        'ordersCount': ordersSnap.size,
        'couponsCount': couponsSnap.size,
        'paidOrders30d': paid30dSnap.size,
        'revenue30d': revenue30d,
        'computedAt': FieldValue.serverTimestamp(),
      };

      await _overviewRef.set(payload, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已重新計算並更新報表')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('重新計算失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('系統分析'),
        actions: [
          IconButton(
            tooltip: '重新計算',
            onPressed: _busy ? null : _recompute,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _overviewRef.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorView(message: '讀取失敗：${snap.error}');
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // ✅ 這裡完全不需要任何 as cast
          final data = snap.data!.data() ?? <String, dynamic>{};

          final usersCount = _toInt(data['usersCount']);
          final productsCount = _toInt(data['productsCount']);
          final ordersCount = _toInt(data['ordersCount']);
          final couponsCount = _toInt(data['couponsCount']);

          final paidOrders30d = _toInt(data['paidOrders30d']);
          final revenue30d = _toDouble(data['revenue30d']);

          DateTime? computedAt;
          final ca = data['computedAt'];
          if (ca is Timestamp) computedAt = ca.toDate();
          if (ca is DateTime) computedAt = ca;

          return RefreshIndicator(
            onRefresh: _busy ? () async {} : _recompute,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeaderCard(
                  computedAt: computedAt,
                  busy: _busy,
                  onRecompute: _busy ? null : _recompute,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(
                      title: '會員數',
                      value: usersCount.toString(),
                      icon: Icons.people,
                    ),
                    _MetricCard(
                      title: '商品數',
                      value: productsCount.toString(),
                      icon: Icons.inventory_2,
                    ),
                    _MetricCard(
                      title: '訂單數',
                      value: ordersCount.toString(),
                      icon: Icons.receipt_long,
                    ),
                    _MetricCard(
                      title: '優惠券數',
                      value: couponsCount.toString(),
                      icon: Icons.confirmation_number,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SectionTitle(title: '近 30 天'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(
                      title: '已付款單數',
                      value: paidOrders30d.toString(),
                      icon: Icons.verified,
                    ),
                    _MetricCard(
                      title: '營收（估）',
                      value: _formatMoney(revenue30d),
                      icon: Icons.attach_money,
                      subtitle: '加總 orders.totalAmount / amount / total',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  '提示：若 overview 尚未生成，請按右上角「重新計算」。',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// UI Widgets
// ============================================================

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.computedAt,
    required this.busy,
    required this.onRecompute,
  });

  final DateTime? computedAt;
  final bool busy;
  final Future<void> Function()? onRecompute;

  @override
  Widget build(BuildContext context) {
    final ts = computedAt == null ? '尚未計算' : computedAt!.toLocal().toString();
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.analytics),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '報表概覽',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text('最後更新：$ts', style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: busy ? null : onRecompute,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('重新計算'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final targetWidth = w >= 1100
        ? 320.0
        : (w >= 820 ? 280.0 : double.infinity);

    return SizedBox(
      width: targetWidth,
      child: Card(
        elevation: 0.6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      ),
                    ],
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(message, style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}

// ============================================================
// Helpers（無 cast）
// ============================================================

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? 0;
  return 0;
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? 0;
  return 0;
}

String _formatMoney(double v) {
  // 不引入 intl，避免你其他檔案又出 unused import
  final s = v.toStringAsFixed(0);
  return '\$$s';
}
