import 'package:flutter/material.dart';

class LotteryTabPage extends StatelessWidget {
  const LotteryTabPage({super.key});

  void _safeNav(BuildContext context, String routeName) {
    try {
      Navigator.of(context).pushNamed(routeName);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('尚未設定路由：$routeName')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('抽獎'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_outlined, size: 56, color: Colors.orangeAccent),
              const SizedBox(height: 12),
              const Text('抽獎頁（Tab）已對應完成 ✅', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 6),
              const Text('你可把這裡替換成你原本的 LotteryPage。\n目前先提供可編譯版本，確保底導可正常切換。', textAlign: TextAlign.center),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => _safeNav(context, '/lottery/draw'),
                child: const Text('去抽獎動畫頁 /lottery/draw（若你有設定）'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
