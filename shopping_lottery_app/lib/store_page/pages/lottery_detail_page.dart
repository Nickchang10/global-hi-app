import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../router_adapter.dart';
import '../widgets/shop_scaffold.dart';

class LotteryDetailPage extends StatefulWidget {
  const LotteryDetailPage({
    super.key,
    required this.id,
  });

  final String id;

  @override
  State<LotteryDetailPage> createState() => _LotteryDetailPageState();
}

class _LotteryDetailPageState extends State<LotteryDetailPage> {
  bool _showShareInput = false;
  final _shareController = TextEditingController();

  @override
  void dispose() {
    _shareController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lottery = lotteries.where((l) => l.id == widget.id).cast<Lottery?>().firstWhere((e) => e != null, orElse: () => null);
    if (lottery == null) {
      return const ShopScaffold(body: Center(child: Text('抽獎活動不存在')));
    }

    final progress = (lottery.participants / lottery.maxParticipants).clamp(0, 1).toDouble();
    final now = DateTime.now();
    final daysLeft = max(0, (lottery.endDate.difference(now).inHours / 24).ceil());

    return ShopScaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, size: 20),
                label: const Text('返回'),
                style: TextButton.styleFrom(alignment: Alignment.centerLeft),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // banner
                    SizedBox(
                      height: 220,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                          Opacity(
                            opacity: 0.50,
                            child: Image.network(
                              lottery.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text('🎁 抽獎活動', style: TextStyle(color: Colors.black87)),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: Text(
                              lottery.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // prize
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFFBEB), Color(0xFFFFF7ED)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber, width: 2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🏆 獎品', style: TextStyle(color: Colors.black54)),
                                const SizedBox(height: 4),
                                Text(lottery.prize, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text('價值 ${formatTwd(lottery.prizeValue)}', style: const TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),
                          Text(lottery.description, style: const TextStyle(color: Colors.black87)),

                          if (lottery.officialWebsite != null) ...[
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () => _launchUrl(lottery.officialWebsite!),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.open_in_new, color: Colors.blue),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text('查看獎品官方網站', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),
                          // requirement
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('📋 參加條件', style: TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(_requirementText(lottery)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),
                          // progress
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('參加人數', style: TextStyle(color: Colors.black54)),
                              Text('${lottery.participants} / ${lottery.maxParticipants}', style: const TextStyle(color: Colors.black54)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFE5E7EB),
                              valueColor: const AlwaysStoppedAnimation(Color(0xFFDB2777)),
                            ),
                          ),

                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.black54),
                              const SizedBox(width: 8),
                              Text('剩餘 $daysLeft 天', style: const TextStyle(color: Colors.black54)),
                              const SizedBox(width: 8),
                              Text('（截止：${formatDateYmd(lottery.endDate)}）', style: const TextStyle(color: Colors.black45, fontSize: 12)),
                            ],
                          ),

                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => context.go('/store_shop/${lottery.storeId}'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.store_outlined, color: Colors.black54),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('主辦商店', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                        const SizedBox(height: 2),
                                        Text(lottery.store, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          if (_showShareInput && lottery.requirement.type == LotteryRequirementType.share)
                            _ShareProofBox(
                              controller: _shareController,
                              onSubmit: () => _submitShare(context, lottery),
                              onCancel: () => setState(() => _showShareInput = false),
                            )
                          else
                            _ActionButtons(
                              lottery: lottery,
                              onParticipate: () => _handleParticipate(context, lottery),
                            ),

                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => context.go('/store_lottery_history/${lottery.id}'),
                            child: const Text('查看我的抽獎記錄'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _requirementText(Lottery lottery) {
    switch (lottery.requirement.type) {
      case LotteryRequirementType.free:
        return '完全免費，直接參加！';
      case LotteryRequirementType.share:
        return '分享活動到社群媒體即可參加（需提供分享連結證明）';
      case LotteryRequirementType.purchase:
        return '消費滿 ${formatTwd(lottery.requirement.minAmount ?? 0)} 即可參加';
    }
  }

  void _handleParticipate(BuildContext context, Lottery lottery) {
    final appState = context.read<AppState>();

    switch (lottery.requirement.type) {
      case LotteryRequirementType.share:
        setState(() => _showShareInput = true);
        return;
      case LotteryRequirementType.free:
        appState.participateInLottery(
          LotteryParticipation(
            lottery: lottery,
            participatedAt: DateTime.now(),
            status: LotteryStatus.pending,
            announced: false,
          ),
        );
        context.go('/store_lottery_history/${lottery.id}');
        return;
      case LotteryRequirementType.purchase:
        context.go('/search');
        return;
    }
  }

  void _submitShare(BuildContext context, Lottery lottery) {
    final url = _shareController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入分享連結')));
      return;
    }

    context.read<AppState>().participateInLottery(
          LotteryParticipation(
            lottery: lottery,
            participatedAt: DateTime.now(),
            status: LotteryStatus.pending,
            announced: false,
            shareProofUrl: url,
          ),
        );

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已成功參加抽獎！')));
    context.go('/store_lottery_history/${lottery.id}');
  }

  static Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _ShareProofBox extends StatelessWidget {
  const _ShareProofBox({
    required this.controller,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('請提供分享貼文連結', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: '貼上您的分享貼文連結（Facebook、Instagram、Twitter 等）',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onSubmit,
                  child: const Text('確認提交'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onCancel,
                child: const Text('取消'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.lottery,
    required this.onParticipate,
  });

  final Lottery lottery;
  final VoidCallback onParticipate;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();

    switch (lottery.requirement.type) {
      case LotteryRequirementType.share:
        return FilledButton.icon(
          onPressed: onParticipate,
          icon: const Icon(Icons.share),
          label: const Text('分享並參加抽獎'),
          style: FilledButton.styleFrom(backgroundColor: Colors.blue),
        );

      case LotteryRequirementType.free:
        return FilledButton(
          onPressed: onParticipate,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
          child: const Text('立即參加抽獎'),
        );

      case LotteryRequirementType.purchase:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () {
                final minAmount = lottery.requirement.minAmount ?? 0;
                final product = products.firstWhere(
                  (p) => p.price >= minAmount,
                  orElse: () => products.first,
                );
                appState.addToCart(product);
                context.go('/store_checkout');
              },
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('購物參加抽獎'),
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            ),
            const SizedBox(height: 6),
            Text(
              '消費滿 ${formatTwd(lottery.requirement.minAmount ?? 0)} 即可參加',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        );
    }
  }
}
