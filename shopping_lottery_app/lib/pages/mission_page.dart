import 'package:flutter/material.dart';
import '../services/mission_service.dart';

class MissionPage extends StatefulWidget {
  const MissionPage({super.key});

  @override
  State<MissionPage> createState() => _MissionPageState();
}

class _MissionPageState extends State<MissionPage> {
  final missionService = MissionService.instance;

  @override
  void initState() {
    super.initState();
    missionService.init();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: missionService,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text("每日任務與寶箱"),
            backgroundColor: Colors.teal,
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: missionService.missions.length,
                    itemBuilder: (context, index) {
                      final mission = missionService.missions[index];
                      final done = mission["done"] as bool;

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: Icon(
                            done
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: done ? Colors.green : Colors.grey,
                          ),
                          title: Text(
                            mission["title"],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          trailing: Text(
                            "+${mission["rewardXP"]} XP",
                            style: const TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: done
                              ? null
                              : () => missionService
                                  .completeMission(mission["id"]),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: missionService.allMissionsCompleted &&
                          !missionService.chestOpened
                      ? () async {
                          await missionService.openChest();
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              title: const Text("🎁 寶箱開啟成功！"),
                              content: const Text("恭喜您獲得額外 100 XP！"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("OK"),
                                ),
                              ],
                            ),
                          );
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: missionService.allMissionsCompleted
                          ? Colors.amber[600]
                          : Colors.grey[400],
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        if (missionService.allMissionsCompleted)
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.6),
                            blurRadius: 10,
                            spreadRadius: 3,
                          ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      missionService.chestOpened
                          ? "✅ 今日寶箱已開啟"
                          : missionService.allMissionsCompleted
                              ? "🎁 點擊開啟寶箱！"
                              : "完成所有任務以開啟寶箱",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
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
