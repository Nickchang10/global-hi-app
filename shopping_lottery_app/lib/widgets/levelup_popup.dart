import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// 🎉 成就卡彈窗（升級動畫）
class LevelUpPopup extends StatelessWidget {
  final String rank;
  final Color color;

  const LevelUpPopup({super.key, required this.rank, required this.color});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Lottie.asset(
            'assets/animations/levelup.json',
            repeat: false,
            height: 280,
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10)
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium, color: color, size: 60),
                const SizedBox(height: 12),
                Text(
                  "升級成功！",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: color),
                ),
                const SizedBox(height: 8),
                Text(
                  "恭喜你成為：$rank",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 10)),
                  child: const Text("太棒了！"),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
