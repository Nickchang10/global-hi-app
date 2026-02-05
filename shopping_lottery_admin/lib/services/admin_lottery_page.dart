// lib/pages/admin_lottery_page.dart
//
// ✅ AdminLotteryPage（最終完整版）
// ------------------------------------------------------------
// 功能：
// - 顯示所有已付款訂單（可抽獎）
// - 抽獎按鈕（呼叫 LotteryService.drawOnce）
// - 顯示抽獎結果（中獎/未中獎）
// - 自動發送通知（由 LotteryService 控制）
// - 可搜尋訂單ID / UID
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/lottery_service.dart';
import '../services/notification_service.dart';

class AdminLotteryPage extends StatefulWidget {
  const AdminLotteryPage({super.key});

  @override
  State<AdminLotteryPage> createState() => _AdminLotteryPageState();
}

class _AdminLotteryPageState extends State<AdminLotteryPage> {
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matches(Map<String, dynamic> data) {
    if (_query.trim().isEmpty) return true;
    final q = _query.toLowerCase();
    return (data['id'] ?? '').toString().toLowerCase().contains(q) ||
        (data['buyerUid'] ?? '').toString().toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final lotterySvc = LotteryService(
      notificationService: context.read<NotificationService>(),
    );

    final db = FirebaseFirestore.instance;
    final ordersRef = db.collection('orders');

    return Scaffold(
      appBar: AppBar(
        title: const Text('抽獎管理'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋 訂單ID / UID',
                border: const OutlineInputBorder(),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ordersRef
                    .orderBy('createdAt', descending: true)
                    .limit(100)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Text('讀取訂單失敗：${snap.error}'),
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs.where((d) {
                    final data = d.data();
                    return _matches({
                      'id': d.id,
                      'buyerUid': data['buyerUid'] ?? '',
                    });
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(child: Text('目前沒有符合的訂單'));
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final doc = docs[i];
                      final data = doc.data();
                      final id = doc.id;
                      final uid =
                          (data['buyerUid'] ?? '').toString().trim();
                      final lottery =
                          (data['lottery'] ?? {}) as Map<String, dynamic>;
                      final drawn = lottery['drawn'] == true;
                      final prizeName =
                          (lottery['prizeName'] ?? '').toString().trim();
                      final status =
                          (lottery['status'] ?? '').toString().trim();

                      final cs = Theme.of(context).colorScheme;
                      final isWon = status == 'won';
                      final chipColor = isWon
                          ? cs.primary
                          : (drawn ? cs.onSurfaceVariant : Colors.grey);

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: chipColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: chipColor.withOpacity(0.3)),
                          ),
                          child: Icon(
                            drawn
                                ? (isWon
                                    ? Icons.emoji_events
                                    : Icons.sentiment_dissatisfied)
                                : Icons.help_outline,
                            color: chipColor,
                          ),
                        ),
                        title: Text('訂單 $id'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('UID：$uid', style: const TextStyle(fontSize: 12)),
                            if (drawn)
                              Text(
                                isWon
                                    ? '中獎：$prizeName'
                                    : '未中獎（銘謝惠顧）',
                                style: TextStyle(
                                  color: isWon ? cs.primary : cs.outline,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        trailing: ElevatedButton.icon(
                          icon: const Icon(Icons.casino),
                          label: Text(drawn ? '重抽' : '抽獎'),
                          onPressed: () async {
                            await _handleDraw(
                              context,
                              lotterySvc,
                              orderId: id,
                              alreadyDrawn: drawn,
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDraw(
    BuildContext context,
    LotteryService lotterySvc, {
    required String orderId,
    required bool alreadyDrawn,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(alreadyDrawn ? '重抽確認' : '抽獎確認'),
        content: Text(alreadyDrawn
            ? '此訂單已抽過，確定要重新抽獎嗎？（將覆蓋原紀錄）'
            : '確定要為訂單 $orderId 執行抽獎嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('抽獎進行中...')),
    );

    try {
      final result = await lotterySvc.drawOnce(orderId);
      if (!mounted) return;

      final msg = result.status == 'won'
          ? '恭喜中獎：「${result.prizeName}」'
          : '未中獎，銘謝惠顧！';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('抽獎失敗：$e')));
    }
  }
}
