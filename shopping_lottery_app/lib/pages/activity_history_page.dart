import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:osmile_shopping_app/services/notification_service.dart';
import 'package:osmile_shopping_app/services/firestore_mock_service.dart';

/// 📜 活動紀錄頁（支援分類篩選 + 刪除）
class ActivityHistoryPage extends StatefulWidget {
  const ActivityHistoryPage({super.key});

  @override
  State<ActivityHistoryPage> createState() => _ActivityHistoryPageState();
}

class _ActivityHistoryPageState extends State<ActivityHistoryPage> {
  String _selectedType = "all";

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }

  Color _getColorByType(String? type) {
    switch (type) {
      case "milestone":
        return Colors.orangeAccent;
      case "redeem":
        return Colors.green;
      case "lottery":
        return Colors.purpleAccent;
      case "task":
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconByType(String? type) {
    switch (type) {
      case "milestone":
        return Icons.emoji_events;
      case "redeem":
        return Icons.shopping_bag;
      case "lottery":
        return Icons.casino;
      case "task":
        return Icons.task_alt;
      default:
        return Icons.notifications;
    }
  }

  List<Map<String, dynamic>> _filterNotifications(
      List<Map<String, dynamic>> all) {
    if (_selectedType == "all") return all;
    return all.where((n) => n["type"] == _selectedType).toList();
  }

  void _deleteNotification(Map<String, dynamic> item) {
    setState(() {
      NotificationService.instance.removeNotification(item);
    });
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("清除所有紀錄"),
        content: const Text("確定要刪除所有活動紀錄嗎？此動作無法復原。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          ElevatedButton(
            onPressed: () {
              NotificationService.instance.clearAll();
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("清除"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.watch<FirestoreMockService>();
    final allNotifications = NotificationService.instance.notifications;
    final filtered = _filterNotifications(allNotifications);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "📜 活動紀錄",
          style: GoogleFonts.notoSansTc(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (filtered.isNotEmpty)
            IconButton(
              tooltip: "清除全部紀錄",
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_forever),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // 篩選按鈕列
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterButton("全部", "all", Icons.list_alt, Colors.grey),
                    _buildFilterButton("抽獎", "lottery", Icons.casino, Colors.purple),
                    _buildFilterButton("兌換", "redeem", Icons.shopping_bag, Colors.green),
                    _buildFilterButton("里程碑", "milestone", Icons.emoji_events, Colors.orange),
                    _buildFilterButton("任務", "task", Icons.task_alt, Colors.blue),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            // 紀錄清單
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        "目前沒有紀錄",
                        style: GoogleFonts.notoSansTc(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final n = filtered[index];
                        final color = _getColorByType(n["type"]);
                        final icon = _getIconByType(n["type"]);
                        final time =
                            n["time"] ?? DateTime.now().millisecondsSinceEpoch;

                        return GestureDetector(
                          onLongPress: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("刪除此紀錄？"),
                                content: Text(
                                  n["title"] ?? "確定要刪除這筆紀錄嗎？",
                                  style: const TextStyle(fontSize: 14),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("取消"),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deleteNotification(n);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text("刪除"),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, color: color, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n["title"] ?? "系統通知",
                                        style: GoogleFonts.notoSansTc(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        n["message"] ?? "",
                                        style: GoogleFonts.notoSansTc(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTime(time),
                                        style: GoogleFonts.notoSansTc(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 篩選按鈕樣式
  Widget _buildFilterButton(
      String label, String value, IconData icon, Color color) {
    final bool selected = _selectedType == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? Colors.white : color.withOpacity(0.7)),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.notoSansTc(
                fontSize: 14,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        selected: selected,
        selectedColor: color,
        backgroundColor: Colors.white,
        onSelected: (_) => setState(() => _selectedType = value),
        side: BorderSide(color: color.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
