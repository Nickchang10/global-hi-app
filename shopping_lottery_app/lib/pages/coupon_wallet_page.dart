import 'package:flutter/material.dart';
import '../services/firestore_mock_service.dart';

class CouponWalletPage extends StatefulWidget {
  const CouponWalletPage({super.key});

  @override
  State<CouponWalletPage> createState() => _CouponWalletPageState();
}

class _CouponWalletPageState extends State<CouponWalletPage> {
  @override
  Widget build(BuildContext context) {
    final coupons = FirestoreMockService.instance.userCoupons;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      appBar: AppBar(
        title: const Text("我的優惠券"),
        backgroundColor: const Color(0xFF007BFF),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: coupons.length,
        itemBuilder: (context, i) {
          final c = coupons[i];
          final bool used = c["used"] ?? false;
          final bool expired = c["expired"] ?? false;

          Color cardColor;
          if (used) {
            cardColor = Colors.grey.shade300;
          } else if (expired) {
            cardColor = Colors.red.shade100;
          } else {
            cardColor = Colors.white;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.local_offer, color: Color(0xFF007BFF)),
              title: Text(
                c["title"],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: used || expired ? Colors.grey : Colors.black,
                ),
              ),
              subtitle: Text(
                c["desc"],
                style: TextStyle(
                  color: used || expired ? Colors.grey : Colors.black87,
                ),
              ),
              trailing: Text(
                used
                    ? "已使用"
                    : expired
                        ? "已過期"
                        : "可使用",
                style: TextStyle(
                  color: used
                      ? Colors.grey
                      : expired
                          ? Colors.red
                          : const Color(0xFF007BFF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
