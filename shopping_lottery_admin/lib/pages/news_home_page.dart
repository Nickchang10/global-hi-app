import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'news_page.dart';
import 'news_detail_page.dart';

class NewsHomePage extends StatelessWidget {
  const NewsHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Osmile 最新消息')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔥 熱門消息',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildHotNewsSection(context),
            const SizedBox(height: 20),
            const Text('📰 最新消息分類',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildCategoryButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHotNewsSection(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('news')
        .where('isActive', isEqualTo: true)
        .where('isHot', isEqualTo: true)
        .orderBy('date', descending: true)
        .limit(5);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Text('目前沒有熱門消息');
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.local_fire_department, color: Colors.red),
                title: Text(data['title'] ?? ''),
                subtitle: Text('${data['category']}｜${data['date']}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NewsDetailPage(id: doc.id, data: data),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCategoryButtons(BuildContext context) {
    final categories = ['最新消息', '活動公告', '媒體報導'];
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: categories.map((cat) {
        return OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NewsPage(initialCategory: cat),
              ),
            );
          },
          icon: const Icon(Icons.label_outline),
          label: Text(cat),
        );
      }).toList(),
    );
  }
}
