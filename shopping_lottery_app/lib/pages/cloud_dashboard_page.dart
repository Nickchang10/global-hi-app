// lib/pages/cloud_dashboard_page.dart
//
// ✅ CloudDashboardPage（正式版｜完整版｜可直接編譯）
// ----------------------------------------------------
// 修正：移除不存在的 CloudService 型別（原本造成 non_type_as_type_argument）
// 改用你現有的 services singletons：
// - CloudPushService / AchievementService / AiMarketingService / AiRecommendationService / BadgeService
//
// 需要套件：firebase_auth, cloud_firestore, flutter
// ----------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/achievement_service.dart';
import '../services/ai_marketing_service.dart';
import '../services/ai_recommendation_service.dart';
import '../services/badge_service.dart';
import '../services/cloud_push_service.dart';

class CloudDashboardPage extends StatefulWidget {
  const CloudDashboardPage({super.key});

  @override
  State<CloudDashboardPage> createState() => _CloudDashboardPageState();
}

class _CloudDashboardPageState extends State<CloudDashboardPage> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // ✅ 啟動未讀 badge 監聽
    BadgeService.instance.start();
  }

  User? get _user => FirebaseAuth.instance.currentUser;

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markAllNotificationsRead() async {
    final u = _user;
    if (u == null) return;

    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(u.uid)
        .collection('notifications');

    final snap = await col.where('read', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> _showRecoDialog(List<SimpleProduct> products) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('推薦商品（示範）'),
        content: SizedBox(
          width: 420,
          child: products.isEmpty
              ? const Text('沒有取得推薦（可能 products 集合為空或欄位不一致）')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (_, i) {
                    final p = products[i];
                    final priceText = p.price == null
                        ? ''
                        : '  ${p.price} ${p.currency}';
                    return ListTile(
                      dense: true,
                      title: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${p.category ?? '—'}$priceText'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        // 記錄點擊（可選）
                        await AiRecommendationService.instance.trackClick(
                          placement: 'cloud_dashboard',
                          productId: p.id,
                          data: {'from': 'dialog'},
                        );
                        if (mounted) Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Dashboard'),
        actions: [
          AnimatedBuilder(
            animation: BadgeService.instance,
            builder: (_, __) {
              final count = BadgeService.instance.unreadNotificationsCount;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: count <= 0
                      ? const SizedBox.shrink()
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.redAccent,
                          ),
                          child: Text(
                            '未讀 $count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                ),
              );
            },
          ),
        ],
      ),
      body: u == null ? _needLogin() : _body(u),
    );
  }

  Widget _needLogin() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 52, color: Colors.grey),
            const SizedBox(height: 10),
            const Text(
              '請先登入才能使用 Cloud Dashboard',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamed('/login'),
              child: const Text('前往登入'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(User u) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _header(u),
        const SizedBox(height: 12),

        _sectionTitle('通知中心 / Push'),
        const SizedBox(height: 8),
        _actionCard(
          title: '送一則測試通知給自己',
          subtitle: '寫入 users/{uid}/notifications（供通知中心顯示）',
          icon: Icons.notifications_active_outlined,
          onTap: () => _run(() async {
            await CloudPushService.instance.notifyMe(
              title: '測試通知',
              body: '這是一則測試通知（CloudDashboard）',
              type: 'system',
              data: {'from': 'cloud_dashboard'},
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已送出（已寫入 Firestore 通知中心）')),
            );
          }),
        ),
        _actionCard(
          title: '全部標記為已讀',
          subtitle: '把 read=false 的通知全部改成 read=true',
          icon: Icons.mark_email_read_outlined,
          onTap: () => _run(() async {
            await _markAllNotificationsRead();
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('已標記為已讀')));
          }),
        ),

        const SizedBox(height: 12),
        _sectionTitle('成就 / 點數'),
        const SizedBox(height: 8),
        _actionCard(
          title: '初始化成就文件（ensure docs）',
          subtitle: '建立 users/{uid}/achievements/*',
          icon: Icons.emoji_events_outlined,
          onTap: () => _run(() async {
            await AchievementService.instance.ensureAchievementDocsExist(
              uid: u.uid,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('已初始化成就文件')));
          }),
        ),
        _actionCard(
          title: '模擬：登入成功（first_login）',
          subtitle: '會自動解鎖並加點數（若尚未解鎖）',
          icon: Icons.login_outlined,
          onTap: () => _run(() async {
            await AchievementService.instance.onLoginSuccess(uid: u.uid);
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('已觸發登入成就流程')));
          }),
        ),
        _actionCard(
          title: '模擬：付款成功（首購/累積購買）',
          subtitle: '觸發 first_purchase / purchase_3 / purchase_10 進度',
          icon: Icons.payment_outlined,
          onTap: () => _run(() async {
            await AchievementService.instance.onOrderPaid(uid: u.uid);
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('已觸發付款成就流程')));
          }),
        ),

        const SizedBox(height: 12),
        _sectionTitle('AI 行銷（草稿）'),
        const SizedBox(height: 8),
        _actionCard(
          title: '產生並存一筆行銷草稿（示範）',
          subtitle: 'generateDraft() + saveDraft()',
          icon: Icons.campaign_outlined,
          onTap: () => _run(() async {
            final draft = await AiMarketingService.instance.generateDraft(
              productId: 'demo_product',
              productName: 'Osmile 手錶 ED1000',
              productCategory: '智能穿戴',
              price: 3990,
              currency: 'TWD',
              audience: '親子',
              tone: '可愛',
              goal: '導購',
              channel: 'Line',
              variants: 3,
            );
            final id = await AiMarketingService.instance.saveDraft(draft);

            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('已儲存草稿：$id')));
          }),
        ),

        const SizedBox(height: 12),
        _sectionTitle('AI 推薦'),
        const SizedBox(height: 8),
        _actionCard(
          title: '取得推薦商品（示範）',
          subtitle: 'getRecommendations(limit: 5)',
          icon: Icons.auto_awesome_outlined,
          onTap: () => _run(() async {
            final list = await AiRecommendationService.instance
                .getRecommendations(limit: 5, placement: 'cloud_dashboard');
            await _showRecoDialog(list);
          }),
        ),

        const SizedBox(height: 18),
        if (_busy)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _header(User u) {
    final email = u.email ?? '—';
    final name = u.displayName ?? 'Osmile 會員';

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const CircleAvatar(radius: 24, child: Icon(Icons.cloud_outlined)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(email, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: _busy ? null : onTap,
      ),
    );
  }
}
