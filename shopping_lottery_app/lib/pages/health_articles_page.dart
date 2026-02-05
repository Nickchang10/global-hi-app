import 'package:flutter/material.dart';

class HealthArticlesPage extends StatelessWidget {
  const HealthArticlesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> articles = [
      {
        'title': '冬季如何預防感冒',
        'desc': '保持睡眠、補水與維生素 C 攝取。',
        'image': 'https://images.unsplash.com/photo-1473773508845-188df298d2d1?auto=format&fit=crop&w=900&q=80'
      },
      {
        'title': '長者健康：每天走路的好處',
        'desc': '促進血液循環與心肺健康。',
        'image': 'https://images.unsplash.com/photo-1520975958225-7d63de373ca7?auto=format&fit=crop&w=900&q=80'
      }
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('健康文章'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: articles.length,
        itemBuilder: (_, i) {
          final a = articles[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: InkWell(
              onTap: () => ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('閱讀：${a['title']}'))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: Image.network(a['image']!, width: double.infinity, height: 160, fit: BoxFit.cover),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a['title']!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text(a['desc']!, style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
