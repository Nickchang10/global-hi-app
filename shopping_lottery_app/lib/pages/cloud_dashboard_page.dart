import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cloud_service.dart';

/// ☁️ 雲端管理主頁面
class CloudDashboardPage extends StatelessWidget {
  const CloudDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cloud = Provider.of<CloudService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("☁️ 雲端儲存模擬中心"),
        backgroundColor: const Color(0xFF007BFF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: "切換伺服器",
            onPressed: cloud.switchServer,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF007BFF),
        onPressed: () async {
          final filename = "file_${DateTime.now().millisecondsSinceEpoch}.png";
          await cloud.uploadFile(filename);
        },
        child: const Icon(Icons.cloud_upload),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("目前伺服器節點：${cloud.activeServer}",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text("伺服器狀態：${cloud.serverStatus()["uptime"]}"),
            const SizedBox(height: 12),
            const Divider(),
            const Text("📂 已上傳檔案：",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: cloud.files.isEmpty
                  ? const Center(child: Text("尚無檔案"))
                  : ListView.builder(
                      itemCount: cloud.files.length,
                      itemBuilder: (_, i) {
                        final f = cloud.files[i];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.insert_drive_file,
                                color: Color(0xFF007BFF)),
                            title: Text(f["name"]),
                            subtitle: Text(
                                "伺服器: ${f["server"]}\n時間: ${f["time"].toString().substring(0, 19)}"),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  cloud.deleteFile(f["name"]),
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
}
