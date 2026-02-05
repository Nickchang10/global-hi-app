// lib/pages/faq_page.dart
//
// ✅ FaqPage（/faq｜最終可編譯版）
// ------------------------------------------------------------
// - 讀取 Firestore：site_contents/faq
// - 欄位：title, content
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  static const String routeName = '/faq';

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('site_contents').doc('faq');

    return Scaffold(
      appBar: AppBar(title: const Text('常見問題')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _Body(title: '常見問題', content: '讀取失敗：${snap.error}');
          }

          final data = snap.data?.data();
          final title = (data?['title'] ?? '常見問題').toString().trim();
          final content = (data?['content'] ??
                  '你可以在 Firestore 的 site_contents/faq 設定 title、content 來更新內容。')
              .toString();

          return _Body(title: title.isEmpty ? '常見問題' : title, content: content);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final String title;
  final String content;

  const _Body({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(content, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
