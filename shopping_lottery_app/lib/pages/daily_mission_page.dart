import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:osmile_shopping_app/services/firestore_mock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🎯 每日任務中心（模擬版）
///
/// ✅ 自動重置每日任務
/// ✅ 完成任務可獲積分 + 動畫特效
/// ✅ 觸發升級邏輯（連動成就系統）
class DailyMissionPage extends StatefulWidget {
  const DailyMissionPage({super.key});

  @override
  State<DailyMissionPage> createState() => _DailyMissionPageState();
}

class _DailyMissionPageState extends State<DailyMissionPage> {
  final Map<String, bool> _missions = {
    "login": false,
    "post": false,
    "lottery": false,
    "share": false,
    "social": false,
  };

  final Map<String, int> _rewards = {
    "login": 10,
    "post": 20,
    "lottery": 15,
    "share": 10,
    "social": 10,
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  /// 📅 載入今日任務（每天自動重置）
  Future<void> _loadMissions() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = prefs.getString('mission_date');

    if (lastDate != today) {
      // 重置新的一天
      await prefs.setString('mission_date', today);
      for (var key in _missions.keys) {
        prefs.remove('mission_$key');
      }
    }

    for (var key in _missions.keys) {
      _missions[key] = prefs.getBool('mission_$key') ?? false;
    }

    setState(() => _isLoading = false);
  }

  /// 🎉 完成任務 + 加積分
  Future<void> _completeMission(String key) async {
    if (_missions[key] == true) return;
    final prefs = await SharedPreferences.getInstance();
    final firestore = FirestoreMockService.instance;

    setState(() => _missions[key] = true);
    await prefs.setBool('mission_$key', true);

    // 增加積分
    firestore.addPoints(_rewards[key]!);

    // 動畫提示
    _showSuccessAnimation(context, key, _rewards[key]!);
  }

  /// ✨ 動畫提示
  void _showSuccessAnimation(BuildContext context, String key, int reward) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 12)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/animations/levelup.json',
                repeat: false,
                height: 120,
              ),
              const SizedBox(height: 16),
              Text(
                "任務完成 🎯",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "獲得 +$reward 積分！",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text("太棒了！"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.watch<FirestoreMockService>();
    final points = firestore.userPoints;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("🎯 每日任務中心"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMissions,
            tooltip: "重新整理",
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFf7f9fb), Color(0xFFe6f1ff)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.stars, color: Colors.amber, size: 36),
                title: const Text("目前積分"),
                subtitle: Text("$points"),
              ),
            ),
            const SizedBox(height: 20),
            ..._missions.keys.map((key) => _buildMissionCard(
                context, key, _missions[key]!, _rewards[key]!)),
          ],
        ),
      ),
    );
  }

  /// 🧩 單個任務卡片
  Widget _buildMissionCard(
      BuildContext context, String key, bool done, int reward) {
    final missionTitles = {
      "login": "每日登入",
      "post": "發佈貼文",
      "lottery": "參加抽獎",
      "share": "分享活動",
      "social": "社群互動",
    };

    final missionIcons = {
      "login": Icons.login,
      "post": Icons.edit_note,
      "lottery": Icons.casino,
      "share": Icons.share,
      "social": Icons.people_alt,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: done ? 6 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(missionIcons[key],
            color: done ? Colors.green : Colors.blueAccent, size: 36),
        title: Text(
          missionTitles[key]!,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: done ? Colors.grey : Colors.black),
        ),
        subtitle: Text(done ? "已完成任務 🎉" : "獎勵 +$reward 積分"),
        trailing: done
            ? const Icon(Icons.check_circle, color: Colors.green)
            : ElevatedButton(
                onPressed: () => _completeMission(key),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text("完成"),
              ),
      ),
    );
  }
}
