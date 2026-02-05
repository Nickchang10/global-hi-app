// lib/pages/card_management_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/card_service.dart';

class CardManagementPage extends StatefulWidget {
  const CardManagementPage({super.key});
  @override
  State<CardManagementPage> createState() => _CardManagementPageState();
}

class _CardManagementPageState extends State<CardManagementPage> {
  @override
  Widget build(BuildContext context) {
    final cardService = context.watch<CardService>();
    final cards = cardService.cards;

    return Scaffold(
      appBar: AppBar(
        title: const Text('管理已儲存卡片'),
        actions: [
          if (cards.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '清除全部',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('清除所有卡片'),
                    content: const Text('確定要移除所有已儲存卡片嗎？此操作無法復原。'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
                      ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('確定')),
                    ],
                  ),
                );
                if (ok == true) {
                  await CardService.instance.clearAll();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清除所有卡片')));
                }
              },
            ),
        ],
      ),
      body: cards.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.credit_card_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('目前沒有儲存任何卡片', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('在付款時勾選「儲存此卡」即可儲存'),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: cards.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, i) {
                final c = cards[i];
                return ListTile(
                  leading: _brandWidgetForLabel(c.label),
                  title: Text(c.label + (c.isDefault ? ' （預設）' : '')),
                  subtitle: Text('到期 ${c.expiry}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      tooltip: '設為預設',
                      onPressed: c.isDefault
                          ? null
                          : () async {
                              await CardService.instance.setDefaultCard(c.id);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已設定為預設卡')));
                            },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('刪除卡片'),
                            content: Text('確定要刪除 ${c.label} 嗎？'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
                              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('刪除')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await CardService.instance.removeCard(c.id);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除卡片')));
                        }
                      },
                    ),
                  ]),
                  onTap: () {
                    showDialog(context: context, builder: (ctx) {
                      return AlertDialog(
                        title: Text(c.label),
                        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('卡片最後四碼：${c.last4}'),
                          const SizedBox(height: 6),
                          Text('到期：${c.expiry}'),
                          const SizedBox(height: 6),
                          Text('Token：${c.token}'),
                          const SizedBox(height: 12),
                          if (!c.isDefault) ElevatedButton(onPressed: () async {
                            await CardService.instance.setDefaultCard(c.id);
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已設定為預設卡')));
                          }, child: const Text('設為預設卡')),
                        ]),
                        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('關閉'))],
                      );
                    });
                  },
                );
              },
            ),
    );
  }

  Widget _brandWidgetForLabel(String label) {
    final l = label.toLowerCase();
    String asset;
    if (l.contains('visa')) {
      asset = 'assets/brands/visa.svg';
    } else if (l.contains('master')) {
      asset = 'assets/brands/mastercard.svg';
    } else if (l.contains('amex') || l.contains('american')) {
      asset = 'assets/brands/amex.svg';
    } else {
      asset = 'assets/brands/card.svg';
    }

    // 如果沒有 svg，fallback to icon
    return SizedBox(width: 40, height: 28, child: SvgPicture.asset(asset, fit: BoxFit.contain, placeholderBuilder: (_) => const Icon(Icons.credit_card)));
  }
}
