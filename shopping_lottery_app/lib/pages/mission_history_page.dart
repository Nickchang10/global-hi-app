import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 📜 任務積分紀錄頁（MissionHistoryPage）
///
/// 功能：
/// ✅ 顯示所有任務完成與積分變化紀錄  
/// ✅ 支援搜尋與排序  
/// ✅ 可視化任務來源（每日 / 每週 / 活動 / 其他）  
class MissionHistoryPage extends StatefulWidget {
  const MissionHistoryPage({super.key});

  @override
  State<MissionHistoryPage> createState() => _MissionHistoryPageState();
}

class _MissionHistoryPageState extends State<MissionHistoryPage> {
  List<Map<String, dynamic>> _history = [];
  String _filterKeyword = "";

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList("point_history") ?? [];
    final parsed = data
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList()
      ..sort((a, b) =>
          DateTime.parse(b["time"]).compareTo(DateTime.parse(a["time"])));
    setState(() => _history = parsed);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterKeyword.isEmpty
        ? _history
        : _history
            .where((h) =>
                h["source"].toString().contains(_filterKeyword) ||
                h["note"].toString().contains(_filterKeyword))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("📜 任務積分紀錄"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF6F8FB),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "搜尋任務名稱 / 來源...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _filterKeyword = v.trim()),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      "目前沒有任務紀錄",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildHistoryItem(filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> h) {
    final int value = h["value"];
    final bool isGain = value >= 0;
    final String type = h["source"] ?? "任務";
    final String note = h["note"] ?? "";
    final String time = h["time"] ?? "";

    Color badgeColor;
    IconData badgeIcon;
    switch (type) {
      case "每日任務":
      case "任務":
        badgeColor = Colors.blueAccent;
        badgeIcon = Icons.check_circle;
        break;
      case "每週任務":
        badgeColor = Colors.purpleAccent;
        badgeIcon = Icons.calendar_today;
        break;
      case "活動":
        badgeColor = Colors.orangeAccent;
        badgeIcon = Icons.local_fire_department;
        break;
      default:
        badgeColor = Colors.grey;
        badgeIcon = Icons.task_alt;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: badgeColor,
          child: Icon(badgeIcon, color: Colors.white),
        ),
        title: Text(note.isNotEmpty ? note : "未知任務"),
        subtitle: Text(
          "$type｜$time",
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: Text(
          (isGain ? "+" : "") + value.toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isGain ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }
}
