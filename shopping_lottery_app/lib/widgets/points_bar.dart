import 'package:flutter/material.dart';

/// 用於顯示會員積分資訊與簽到提示的橫條
class PointsBar extends StatelessWidget {
  final String userName;
  final int points;
  final VoidCallback? onSignIn;

  const PointsBar({
    super.key,
    required this.userName,
    required this.points,
    this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("嗨，$userName 👋",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text("記得每日簽到可得 10 積分",
                  style: TextStyle(color: Colors.black54)),
            ],
          ),
          ElevatedButton(
            onPressed: onSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007BFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text("積分：$points"),
          ),
        ],
      ),
    );
  }
}
