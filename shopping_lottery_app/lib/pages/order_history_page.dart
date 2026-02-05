import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:osmile_shopping_app/services/firestore_mock_service.dart';

/// 🧾 Osmile 訂單紀錄頁面
///
/// 功能：
/// ✅ 顯示歷史訂單
/// ✅ 展開顯示商品清單與金額
/// ✅ 可點擊展開詳細內容
class OrderHistoryPage extends StatelessWidget {
  const OrderHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.watch<FirestoreMockService>();
    final orders = firestore.orderHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text("📦 我的訂單紀錄"),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: orders.isEmpty
          ? const Center(
              child: Text(
                "尚無訂單紀錄 🧾",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              itemBuilder: (_, i) {
                final o = orders[i];
                final time = DateFormat("yyyy/MM/dd HH:mm").format(o["time"]);
                final total = o["total"];
                final items = o["items"] as List<dynamic>;

                return ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: const Icon(Icons.receipt_long_rounded,
                      color: Colors.blueAccent),
                  title: Text("訂單編號：#${o["id"]}"),
                  subtitle: Text("建立時間：$time"),
                  childrenPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    Column(
                      children: items
                          .map((p) => ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.asset(
                                    p["image"],
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.watch, size: 30),
                                  ),
                                ),
                                title: Text(p["name"]),
                                subtitle:
                                    Text("NT\$${p["price"]}  x${p["qty"]}"),
                              ))
                          .toList(),
                    ),
                    const Divider(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding:
                            const EdgeInsets.only(right: 16, bottom: 10, top: 4),
                        child: Text(
                          "總金額：NT\$${total.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
