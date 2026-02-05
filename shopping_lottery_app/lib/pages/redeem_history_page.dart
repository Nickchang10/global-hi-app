import 'package:flutter/material.dart';

class RedeemHistoryPage extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const RedeemHistoryPage({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📜 兌換紀錄"),
        centerTitle: true,
        backgroundColor: Colors.pinkAccent,
      ),
      backgroundColor: Colors.grey[100],
      body: history.isEmpty
          ? const Center(
              child: Text("目前還沒有兌換紀錄哦～",
                  style: TextStyle(color: Colors.grey, fontSize: 15)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (_, i) {
                final item = history[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(item["image"],
                          width: 60, height: 60, fit: BoxFit.cover),
                    ),
                    title: Text(item["title"],
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      "${item["date"]}\n花費：${item["points"]} 積分",
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}
