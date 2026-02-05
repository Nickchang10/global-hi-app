import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeaderboardRewardHistoryPage extends StatefulWidget {
  const LeaderboardRewardHistoryPage({super.key});

  @override
  State<LeaderboardRewardHistoryPage> createState() =>
      _LeaderboardRewardHistoryPageState();
}

class _LeaderboardRewardHistoryPageState
    extends State<LeaderboardRewardHistoryPage> {
  List<Map<String, dynamic>> _rewardHistory = [];

  @override
  void initState() {
    super.initState();
    _loadRewardHistory();
  }

  Future<void> _loadRewardHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final storedData = prefs.getStringList('rewardHistory') ?? [];
    setState(() {
      _rewardHistory = storedData.map((e) {
        final parts = e.split('|');
        return {
          "date": parts[0],
          "event": parts[1],
          "points": int.tryParse(parts[2]) ?? 0,
        };
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "🏆 獎勵紀錄",
          style: GoogleFonts.notoSansTc(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _rewardHistory.isEmpty
          ? const Center(
              child: Text(
                "目前沒有獎勵紀錄 😅",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rewardHistory.length,
              itemBuilder: (context, index) {
                final item = _rewardHistory[index];
                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.card_giftcard,
                        color: Colors.amber, size: 36),
                    title: Text(
                      item["event"],
                      style: GoogleFonts.notoSansTc(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      item["date"],
                      style: GoogleFonts.notoSansTc(color: Colors.grey[600]),
                    ),
                    trailing: Text(
                      "+${item["points"]} 分",
                      style: GoogleFonts.notoSansTc(
                        color: Colors.blueAccent,
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
