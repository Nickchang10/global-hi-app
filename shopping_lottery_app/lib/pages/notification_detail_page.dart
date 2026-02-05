import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// 📄 單一通知詳情頁（含分享功能）
class NotificationDetailPage extends StatelessWidget {
  final Map<String, dynamic> notification;

  const NotificationDetailPage({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final time = notification["time"] as DateTime;
    final title = notification["title"] ?? "通知詳情";
    final message = notification["message"] ?? "無內容";
    final source = _detectSource(message);

    return Scaffold(
      appBar: AppBar(
        title: const Text("通知詳情"),
        backgroundColor: const Color(0xFF007BFF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              final shareText = StringBuffer()
                ..writeln("【$title】")
                ..writeln(message)
                ..writeln("")
                ..writeln("來源：$source")
                ..writeln("時間：${_formatTime(time)}");
              Share.share(
                shareText.toString(),
                subject: title.toString(),
              );
            },
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        color: Colors.grey[100],
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 標題
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF007BFF),
                  ),
                ),
                const SizedBox(height: 12),

                // 🔹 時間 + 來源標籤
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(time),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _sourceColor(source).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        source,
                        style: TextStyle(
                          color: _sourceColor(source),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),

                // 🔹 通知內容
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 🔹 底部操作區：返回＋分享
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                      label: const Text("返回"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF007BFF),
                        side: const BorderSide(color: Color(0xFF007BFF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        final shareText = StringBuffer()
                          ..writeln("【$title】")
                          ..writeln(message)
                          ..writeln("")
                          ..writeln("來源：$source")
                          ..writeln("時間：${_formatTime(time)}");
                        Share.share(
                          shareText.toString(),
                          subject: title.toString(),
                        );
                      },
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text("分享"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007BFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🔍 自動判斷來源類型
  String _detectSource(String msg) {
    if (msg.contains("折扣") || msg.contains("優惠")) return "行銷中心";
    if (msg.contains("出貨") || msg.contains("物流")) return "物流部門";
    if (msg.contains("公告") || msg.contains("更新")) return "系統公告";
    return "其他";
  }

  Color _sourceColor(String source) {
    switch (source) {
      case "行銷中心":
        return Colors.blue;
      case "物流部門":
        return Colors.green;
      case "系統公告":
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime t) {
    return "${t.year}/${t.month}/${t.day} "
        "${t.hour.toString().padLeft(2, '0')}:"
        "${t.minute.toString().padLeft(2, '0')}";
  }
}
