import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:osmile_shopping_app/pages/home_page.dart';

/// 🎯 訂單結果頁：顯示成功 / 處理中 / 失敗動畫
class ResultPage extends StatelessWidget {
  final bool success;
  final String title;
  final String message;
  final String? orderId;

  const ResultPage({
    super.key,
    required this.success,
    required this.title,
    required this.message,
    this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    final animationAsset = success
        ? "assets/animations/success.json"
        : "assets/animations/error.json";

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                animationAsset,
                width: 220,
                repeat: !success,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: success ? Colors.blueAccent : Colors.redAccent,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
              if (orderId != null) ...[
                const SizedBox(height: 8),
                Text(
                  "訂單編號：# $orderId",
                  style: const TextStyle(color: Colors.black45),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.home_outlined),
                label: const Text("返回首頁"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomePage()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
