import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:osmile_shopping_app/services/firestore_mock_service.dart';

class DailyCheckInPage extends StatefulWidget {
  const DailyCheckInPage({super.key});

  @override
  State<DailyCheckInPage> createState() => _DailyCheckInPageState();
}

class _DailyCheckInPageState extends State<DailyCheckInPage> {
  DateTime _now = DateTime.now();
  Set<String> _checkedDates = {};
  bool _todayChecked = false;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadCheckInData();
  }

  Future<void> _loadCheckInData() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('checkinDays') ?? [];
    final today = _dateKey(_now);
    final lastCheck = prefs.getString('lastCheckinDate');

    // 🔁 計算連續天數
    int streak = prefs.getInt('checkinStreak') ?? 0;
    if (lastCheck != null) {
      final lastDate = DateTime.parse(lastCheck);
      if (_now.difference(lastDate).inDays == 1) {
        streak++;
      } else if (_now.difference(lastDate).inDays > 1) {
        streak = 0; // 中斷連續
      }
    }

    setState(() {
      _checkedDates = list.toSet();
      _todayChecked = _checkedDates.contains(today);
      _streak = streak;
    });
  }

  Future<void> _checkInToday(BuildContext context) async {
    if (_todayChecked) return;

    final firestore = context.read<FirestoreMockService>();
    final prefs = await SharedPreferences.getInstance();

    final today = _dateKey(_now);
    _checkedDates.add(today);
    _todayChecked = true;

    // 🎁 每次簽到獎勵
    firestore.addPoints(10);

    // 🔥 連續簽到額外獎勵
    final lastCheck = prefs.getString('lastCheckinDate');
    if (lastCheck != null) {
      final lastDate = DateTime.parse(lastCheck);
      if (_now.difference(lastDate).inDays == 1) {
        _streak = (_streak + 1).clamp(1, 10);
      } else {
        _streak = 1;
      }
    } else {
      _streak = 1;
    }

    if (_streak % 10 == 0) {
      firestore.addPoints(200);
      _showRewardDialog(context, "🎉 連續簽到 $_streak 天！", "額外獎勵 200 積分 💎");
    } else {
      _showRewardDialog(context, "✅ 今日簽到成功！", "獲得 10 積分 💎");
    }

    await prefs.setStringList('checkinDays', _checkedDates.toList());
    await prefs.setString('lastCheckinDate', today);
    await prefs.setInt('checkinStreak', _streak);

    setState(() {});
  }

  void _showRewardDialog(BuildContext context, String title, String msg) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "checkin",
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 70),
              const SizedBox(height: 12),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("太棒了！",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              )
            ],
          ),
        ),
      ),
      transitionBuilder: (_, anim, __, child) =>
          ScaleTransition(scale: anim, child: child),
    );
  }

  String _dateKey(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateUtils.getDaysInMonth(_now.year, _now.month); // 當月天數
    final firstDay = DateTime(_now.year, _now.month, 1);
    final startWeekday = firstDay.weekday; // 星期幾開始
    final firestore = context.watch<FirestoreMockService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("📅 每日簽到"),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(firestore.userPoints),
            const SizedBox(height: 20),
            Center(
              child: Text(
                "${_now.year} 年 ${_now.month} 月",
                style: GoogleFonts.notoSansTc(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            _buildCalendar(startWeekday, daysInMonth),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _todayChecked
                  ? null
                  : () => _checkInToday(context),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _todayChecked ? Colors.grey : Colors.blueAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: Text(
                _todayChecked ? "今日已簽到 ✅" : "簽到拿 10 積分 💎",
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "🔥 連續簽到：$_streak 天",
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int points) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        children: [
          const Text("每日簽到日曆",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("💎 目前積分：$points",
              style: const TextStyle(color: Colors.blueAccent, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildCalendar(int startWeekday, int daysInMonth) {
    final todayKey = _dateKey(_now);
    List<Widget> cells = [];

    for (int i = 1; i < startWeekday; i++) {
      cells.add(Container()); // 前面空格
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final dateKey = _dateKey(DateTime(_now.year, _now.month, day));
      final checked = _checkedDates.contains(dateKey);
      final isToday = dateKey == todayKey;

      cells.add(AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: checked
              ? Colors.greenAccent
              : isToday
                  ? Colors.yellow.shade300
                  : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            if (checked)
              BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
          ],
        ),
        child: Center(
          child: Text(
            "$day",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: checked
                  ? Colors.white
                  : isToday
                      ? Colors.redAccent
                      : Colors.black87,
            ),
          ),
        ),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
  }
}
