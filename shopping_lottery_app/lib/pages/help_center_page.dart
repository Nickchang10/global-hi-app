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
        children: const <Widget>[
          Text(
            '常見問題',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),

          ExpansionTile(
            title: Text('如何重設密碼？'),
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('請至「安全性」頁面點選「變更密碼」即可。'),
              ),
            ],
          ),
          ExpansionTile(
            title: Text('如何追蹤訂單進度？'),
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('在「我的 → 訂單」中點選欲查看的訂單即可追蹤物流。'),
              ),
            ],
          ),
          ExpansionTile(
            title: Text('如何聯絡客服？'),
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('可於此頁下方使用客服信箱或撥打客服專線。'),
              ),
            ],
          ),

          SizedBox(height: 24),
          Text(
            '聯絡方式',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),

          ListTile(
            leading: Icon(Icons.email_outlined),
            title: Text('客服信箱'),
            subtitle: Text('support@osmile.com'),
          ),
          ListTile(
            leading: Icon(Icons.phone),
            title: Text('客服專線'),
            subtitle: Text('02-1234-5678（週一至週五 9:00–18:00）'),
          ),
        ],
      ),
    );
  }
}
