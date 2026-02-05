import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:osmile_shopping_app/services/firestore_mock_service.dart';
import 'package:osmile_shopping_app/services/notification_service.dart';

/// 🎯 任務中心頁面（MissionCenterPage）
///
/// 功能：
/// ✅ 顯示每日、每週、限時任務清單  
/// ✅ 任務可點擊「領取獎勵」  
/// ✅ 自動加積分並推播提示  
/// ✅ 支援任務完成狀態與進度條
class MissionCenterPage extends StatefulWidget {
  const MissionCenterPage({super.key});

  @override
  State<MissionCenterPage> createState() => _MissionCenterPageState();
}

class _MissionCenterPageState extends State<MissionCenterPage> {
  late List<Map<String, dynamic>> _dailyMissions;
  late List<Map<String, dynamic>> _weeklyMissions;
  late List<Map<String, dynamic>> _eventMissions;

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  /// 🔧 模擬任務資料
  void _loadMissions() {
    _dailyMissions = [
      {
        "title": "每日登入",
        "desc": "每天登入一次可獲得 10 積分",
        "points": 10,
        "progress": 1.0,
        "done": false,
      },
      {
        "title": "瀏覽首頁",
        "desc": "瀏覽首頁商品 3 次",
        "points": 15,
        "progress": 0.7,
        "done": false,
      },
      {
        "title": "分享社群貼文",
        "desc": "將任一貼文分享至好友",
        "points": 20,
        "progress": 0.3,
        "done": false,
      },
    ];

    _weeklyMissions = [
      {
        "title": "完成 3 次抽獎",
        "desc": "連續抽獎 3 次即可獲得 50 積分",
        "points": 50,
        "progress": 0.6,
        "done": false,
      },
      {
        "title": "累計登入 7 天",
        "desc": "連續登入一週可獲得 100 積分",
        "points": 100,
        "progress": 0.4,
        "done": false,
      },
    ];

    _eventMissions = [
      {
        "title": "🎄 聖誕活動特別任務",
        "desc": "完成聖誕限時挑戰可獲得 200 積分",
        "points": 200,
        "progress": 0.8,
        "done": false,
      },
    ];
  }

  /// 🎁 領取任務獎勵
  void _claimMission(Map<String, dynamic> mission) {
    if (mission["done"] == true) return;

    final firestore = FirestoreMockService.instance;
    final notify = NotificationService.instance;

    firestore.addPoints(mission["points"]);
    notify.addNotification(
      title: "任務完成 🎉",
      message: "你完成了「${mission["title"]}」，獲得 ${mission["points"]} 積分！",
      type: "mission",
    );

    setState(() {
      mission["done"] = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("✅ ${mission["title"]} 完成！+${mission["points"]} 積分"),
      backgroundColor: Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.watch<FirestoreMockService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("🎯 任務中心"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF6F8FB),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(firestore.points),
          const SizedBox(height: 16),
          _buildMissionGroup("📅 每日任務", _dailyMissions),
          const SizedBox(height: 16),
          _buildMissionGroup("📆 每週任務", _weeklyMissions),
          const SizedBox(height: 16),
          _buildMissionGroup("🎉 限時活動任務", _eventMissions),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// 🏅 頁面頂部積分區
  Widget _buildHeader(int points) {
    return Card(
      color: Colors.blueAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const Icon(Icons.flag_circle, color: Colors.white, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                "目前積分：$points",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20))),
              icon: const Icon(Icons.refresh),
              label: const Text("刷新"),
              onPressed: () {
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 📋 任務分類區塊
  Widget _buildMissionGroup(String title, List<Map<String, dynamic>> missions) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...missions.map((m) => _buildMissionTile(m)).toList(),
          ],
        ),
      ),
    );
  }

  /// 🎯 單一任務卡片
  Widget _buildMissionTile(Map<String, dynamic> mission) {
    final done = mission["done"] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: done ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: done ? Colors.green : Colors.grey.shade300, width: 1),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: done ? Colors.green : Colors.blueAccent,
          child: Icon(done ? Icons.check : Icons.flag,
              color: Colors.white, size: 20),
        ),
        title: Text(
          mission["title"],
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: done ? Colors.green : Colors.black87),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mission["desc"],
                style: const TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: mission["progress"],
              color: done ? Colors.green : Colors.blueAccent,
              backgroundColor: Colors.grey.shade200,
              minHeight: 6,
            ),
          ],
        ),
        trailing: done
            ? const Text("已完成 🎉",
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => _claimMission(mission),
                child: const Text("領取"),
              ),
      ),
    );
  }
}
