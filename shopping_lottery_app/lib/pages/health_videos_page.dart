import 'package:flutter/material.dart';

class HealthVideosPage extends StatelessWidget {
  const HealthVideosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> videos = [
      {
        'title': 'Osmile S5 教學：血氧監測',
        'thumb': 'https://images.unsplash.com/photo-1519824145371-296894a0daa9?auto=format&fit=crop&w=900&q=80',
        'duration': '02:10'
      },
      {
        'title': '每日三分鐘伸展運動',
        'thumb': 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?auto=format&fit=crop&w=900&q=80',
        'duration': '03:05'
      }
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('健康影片'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: videos.length,
        itemBuilder: (_, i) {
          final v = videos[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(v['thumb']!, width: 80, fit: BoxFit.cover),
              ),
              title: Text(v['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('時長：${v['duration']}'),
              trailing: const Icon(Icons.play_circle_fill, color: Colors.blueAccent),
              onTap: () => ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('播放影片：${v['title']}'))),
            ),
          );
        },
      ),
    );
  }
}
