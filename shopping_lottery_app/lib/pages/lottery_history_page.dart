// lib/pages/lottery_history_page.dart
import 'package:flutter/material.dart';
import '../services/lottery_history_service.dart';
import 'package:intl/intl.dart';

class LotteryHistoryPage extends StatelessWidget {
  const LotteryHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final history = LotteryHistoryService.instance.records;
    final formatter = DateFormat('yyyy/MM/dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('抽獎紀錄'),
        centerTitle: true,
      ),
      body: history.isEmpty
          ? const Center(child: Text('尚無抽獎紀錄，快來試試手氣吧！'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, i) {
                final item = history[i];
                return ListTile(
                  leading: Icon(
                    item['type'] == 'points'
                        ? Icons.star
                        : (item['type'] == 'coupon'
                            ? Icons.local_activity
                            : Icons.casino),
                    color: Colors.orangeAccent,
                  ),
                  title: Text(item['result']),
                  subtitle: Text(formatter.format(item['time'])),
                  trailing: Text(
                    item['type'] == 'coupon'
                        ? '折扣 NT\$${item['value']}'
                        : (item['type'] == 'points'
                            ? '+${item['value']} 積分'
                            : ''),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                );
              },
            ),
    );
  }
}
