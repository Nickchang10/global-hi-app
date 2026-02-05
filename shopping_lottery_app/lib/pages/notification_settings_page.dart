import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:osmile_shopping_app/services/notification_service.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final notify = context.watch<NotificationService>();
    final types = notify.enabledTypes;

    return Scaffold(
      appBar: AppBar(title: const Text("通知設定")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("通知類別",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...types.keys.map((type) {
            return SwitchListTile(
              title: Text(_typeName(type)),
              subtitle: Text(_typeDesc(type)),
              value: types[type]!,
              onChanged: (val) => notify.toggleType(type, val),
            );
          }),
        ],
      ),
    );
  }

  String _typeName(String t) {
    switch (t) {
      case "social":
        return "社群通知";
      case "order":
        return "訂單通知";
      case "lottery":
        return "抽獎通知";
      default:
        return "其他";
    }
  }

  String _typeDesc(String t) {
    switch (t) {
      case "social":
        return "好友貼文、留言等社群互動";
      case "order":
        return "購物下單、配送相關提醒";
      case "lottery":
        return "抽獎結果、活動通知";
      default:
        return "";
    }
  }
}
