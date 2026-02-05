// lib/pages/lottery_debug_page.dart

import 'package:flutter/material.dart';
import 'package:osmile_shopping_app/services/notification_service.dart';

/// 🎰 抽獎測試頁
/// 可模擬中獎或失敗，觸發通知與積分獎勵
class LotteryDebugPage extends StatelessWidget {
  const LotteryDebugPage({super.key});

  void _simulate(BuildContext context, {required bool win}) {
    final notify = NotificationService.instance;
    if (win) {
      notify.addNotification(
        title: "🎉 抽獎中獎！",
        message: "恭喜獲得 50 積分與折價券！",
        type: "lottery",
        target: "lottery",
      );
    } else {
      notify.addNotification(
        title: "😢 抽獎未中",
        message: "下次再接再厲吧！",
        type: "lottery",
        target: "lottery",
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(win ? "中獎通知已送出！" : "未中獎通知已送出")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🎰 抽獎測試工具"),
        backgroundColor: Colors.purpleAccent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "模擬抽獎結果",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.emoji_events),
                label: const Text("模擬中獎"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent),
                onPressed: () => _simulate(context, win: true),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.sentiment_dissatisfied),
                label: const Text("模擬未中獎"),
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                onPressed: () => _simulate(context, win: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
