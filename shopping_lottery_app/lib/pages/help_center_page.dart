// lib/pages/help_center_page.dart
import 'package:flutter/material.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('客服中心')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('常見問題', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ExpansionTile(
            title: const Text('如何重設密碼？'),
            children: const [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('請至「安全性」頁面點選「變更密碼」即可。'),
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('如何追蹤訂單進度？'),
            children: const [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('在「我的 → 訂單」中點選欲查看的訂單即可追蹤物流。'),
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('如何聯絡客服？'),
            children: const [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('可於此頁下方使用客服信箱或撥打客服專線。'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('聯絡方式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('客服信箱'),
            subtitle: const Text('support@osmile.com'),
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('客服專線'),
            subtitle: const Text('02-1234-5678（週一至週五 9:00–18:00）'),
          ),
        ],
      ),
    );
  }
}
