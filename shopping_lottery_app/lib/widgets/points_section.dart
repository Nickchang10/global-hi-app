import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/points_provider.dart';
import '../pages/points_store_page.dart';

/// 💰 積分任務專區
class PointsSection extends StatelessWidget {
  const PointsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final points = Provider.of<PointsProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("💎 積分任務",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),

            _buildTaskButton(
              context,
              icon: Icons.check_circle,
              title: "每日簽到",
              points: "+10",
              completed: points.signedInToday,
              onTap: () {
                if (points.signedInToday) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("今天已簽到過囉 ✅")));
                } else {
                  points.dailySignIn();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("簽到成功！獲得 +10 積分 🎉")));
                }
              },
            ),
            _buildTaskButton(
              context,
              icon: Icons.share,
              title: "分享商品",
              points: "+5",
              onTap: () {
                points.shareProduct();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("感謝分享！獲得 +5 積分 💕")));
              },
            ),
            _buildTaskButton(
              context,
              icon: Icons.comment,
              title: "留言互動",
              points: "+3",
              onTap: () {
                points.commentAction();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("留言成功！獲得 +3 積分 ✨")));
              },
            ),

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("目前積分：${points.points}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton.icon(
                  icon: const Icon(Icons.store, color: Colors.pinkAccent),
                  label: const Text("積分商城",
                      style: TextStyle(color: Colors.pinkAccent)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PointsStorePage()),
                    );
                  },
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskButton(BuildContext context,
      {required IconData icon,
      required String title,
      required String points,
      required VoidCallback onTap,
      bool completed = false}) {
    return ListTile(
      leading: Icon(icon,
          color: completed ? Colors.grey : Colors.pinkAccent, size: 28),
      title: Text(title),
      trailing: completed
          ? const Icon(Icons.check, color: Colors.green)
          : ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: Text(points,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
    );
  }
}
