// lib/pages/tasks_page.dart
import 'package:flutter/material.dart';
import 'lottery_widgets.dart';
import 'leaderboard_page.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});
  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  int points = 0;

  void _addPoints(int value) {
    setState(() => points += value);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('獲得 $value 積分！')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('任務與排行榜'), backgroundColor: Colors.blue),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          DailyMissionSection(onAddPoints: _addPoints),
          SignInSection(onSigned: _addPoints),
          const LeaderboardSection(), // 可換成 LeaderboardPage() 若你要獨立顯示
          const ShareSection(),
        ],
      ),
    );
  }
}
