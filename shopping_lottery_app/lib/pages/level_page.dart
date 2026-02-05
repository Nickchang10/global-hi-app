import 'package:flutter/material.dart';
import '../services/level_service.dart';

class LevelPage extends StatefulWidget {
  const LevelPage({super.key});

  @override
  State<LevelPage> createState() => _LevelPageState();
}

class _LevelPageState extends State<LevelPage> {
  final levelService = LevelService.instance;

  @override
  void initState() {
    super.initState();
    levelService.init();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: levelService,
      builder: (context, _) {
        final progress = levelService.xp / levelService.nextLevelXP;
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F8),
          appBar: AppBar(
            title: const Text("用戶等級 / VIP 狀態"),
            backgroundColor: Colors.teal,
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  "Level ${levelService.level}",
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  levelService.tier,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 16,
                  backgroundColor: Colors.grey[300],
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(height: 10),
                Text(
                  "XP ${levelService.xp} / ${levelService.nextLevelXP}",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  icon: const Icon(Icons.bolt),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => levelService.addXP(60),
                  label: const Text(
                    "模擬 +60 XP",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                const Spacer(),
                Text(
                  "升級至下一階級即可獲得更多折扣與福利！",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }
}
