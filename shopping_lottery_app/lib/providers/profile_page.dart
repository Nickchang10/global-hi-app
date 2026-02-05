import 'package:flutter/material.dart';
import 'order_history_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("我的帳號")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundImage: NetworkImage("https://picsum.photos/200"),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text("Osmile 會員",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.receipt_long, color: Color(0xFF007BFF)),
            title: const Text("我的訂單"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrderHistoryPage()),
              );
            },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.settings, color: Colors.grey),
            title: Text("設定"),
          ),
          const ListTile(
            leading: Icon(Icons.help_outline, color: Colors.grey),
            title: Text("幫助中心"),
          ),
        ],
      ),
    );
  }
}
