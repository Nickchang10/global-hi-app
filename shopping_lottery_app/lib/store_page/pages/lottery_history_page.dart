import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/shop_scaffold.dart';
import '../router_adapter.dart';

class LotteryHistoryPage extends StatelessWidget {
  const LotteryHistoryPage({super.key, this.lotteryId});

  final String? lotteryId;

  @override
  Widget build(BuildContext context) {
    final allParticipations = context.watch<AppState>().lotteryParticipations;
    final participations = (lotteryId == null || lotteryId!.isEmpty)
        ? allParticipations
        : allParticipations.where((p) => p.lottery.id == lotteryId).toList(growable: false);
    final title = (lotteryId == null || lotteryId!.isEmpty) ? '我的抽獎記錄' : '本活動抽獎記錄';

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
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),

              if (participations.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(Icons.emoji_events_outlined, size: 80, color: Colors.black.withValues(alpha: 0.2)),
                        const SizedBox(height: 12),
                        Text(
                          (lotteryId == null || lotteryId!.isEmpty) ? '尚未參加任何抽獎活動' : '尚無此活動的抽獎記錄',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => context.go('/'),
                          child: const Text('去參加抽獎'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: participations
                      .asMap()
                      .entries
                      .map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ParticipationCard(participation: e.value),
                          ))
                      .toList(growable: false),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipationCard extends StatelessWidget {
  const _ParticipationCard({required this.participation});

  final LotteryParticipation participation;

  @override
  Widget build(BuildContext context) {
    final status = participation.status;

    IconData icon;
    Color color;
    String label;

    switch (status) {
      case LotteryStatus.pending:
        icon = Icons.schedule;
        color = Colors.orange;
        label = '等待開獎';
        break;
      case LotteryStatus.won:
        icon = Icons.check_circle;
        color = Colors.green;
        label = '已中獎';
        break;
      case LotteryStatus.lost:
        icon = Icons.cancel;
        color = Colors.black38;
        label = '未中獎';
        break;
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    participation.lottery.imageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: const Color(0xFFF3F4F6)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(participation.lottery.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('獎品：${participation.lottery.prize}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('參加時間：${formatDateZhTw(participation.participatedAt)}', style: const TextStyle(color: Colors.black45, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color),
                    const SizedBox(width: 4),
                    Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),

          if (participation.shareProofUrl != null && participation.shareProofUrl!.trim().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                color: Color(0xFFF9FAFB),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('分享證明：', style: TextStyle(fontSize: 11, color: Colors.black54)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _launchUrl(participation.shareProofUrl!),
                    child: Text(
                      participation.shareProofUrl!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          if (participation.status == LotteryStatus.pending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                color: Color(0xFFF9FAFB),
              ),
              child: InkWell(
                onTap: () => context.go('/lottery-reveal/${participation.lottery.id}'),
                child: const Text('查看開獎 →', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  static Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
