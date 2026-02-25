import 'package:flutter/material.dart';

class VideosPage extends StatelessWidget {
  const VideosPage({super.key});

  static final List<Map<String, String>> kVideos = [
    {
      'title': '如何使用 Osmile S5 監測血氧',
      'duration': '02:10',
      // 換成你的 YouTube 影片
      'url': 'https://www.youtube.com/watch?v=XXXXXXXXXXX',
    },
    {
      'title': '每日三分鐘伸展，提升循環',
      'duration': '03:05',
      'url': 'https://www.youtube.com/watch?v=YYYYYYYYYYY',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('健康影片')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: kVideos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final v = kVideos[i];
          final title = v['title'] ?? '影片';
          final duration = v['duration'] ?? '';
          final url = v['url'] ?? '';

          return Card(
            child: ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: duration.isEmpty ? null : Text('片長：$duration'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(
                  context,
                ).pushNamed('/video', arguments: {'title': title, 'url': url});
              },
            ),
          );
        },
      ),
    );
  }
}
