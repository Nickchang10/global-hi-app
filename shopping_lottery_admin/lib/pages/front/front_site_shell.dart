// lib/pages/front/front_site_shell.dart
//
// ✅ FrontSiteShell（前台網站主頁框架｜Firebase + Firestore Auto Content）
// ------------------------------------------------------------
// 可與後台共用 Firestore 資料結構 site_contents
// - custom-home: 首頁輪播 + 卡片內容
// - news: 最新消息列表
// - about / services / faq / contact: 靜態頁內容
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../site/site_content_preview_pages.dart';

class FrontSiteShell extends StatefulWidget {
  const FrontSiteShell({super.key});

  @override
  State<FrontSiteShell> createState() => _FrontSiteShellState();
}

class _FrontSiteShellState extends State<FrontSiteShell> {
  int _currentIndex = 0;
  final _pages = const [
    _HomeSection(),
    _NewsSection(),
    _AboutSection(),
    _FAQSection(),
    _ContactSection(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Osmile 官網預覽'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/admin'),
            child: const Text('後台登入', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首頁'),
          BottomNavigationBarItem(icon: Icon(Icons.newspaper_outlined), label: '最新消息'),
          BottomNavigationBarItem(icon: Icon(Icons.apartment_outlined), label: '公司簡介'),
          BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: 'FAQ'),
          BottomNavigationBarItem(icon: Icon(Icons.call_outlined), label: '聯絡我們'),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 首頁輪播
// ------------------------------------------------------------
class _HomeSection extends StatelessWidget {
  const _HomeSection();

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final q = db
        .collection('site_contents')
        .where('category', isEqualTo: 'custom-home')
        .orderBy('updatedAt', descending: true)
        .limit(5);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('尚未建立首頁內容'));
        }
        final images = docs
            .expand((d) => List<String>.from(d['images'] ?? []))
            .where((e) => e.isNotEmpty)
            .toList();

        return ListView(
          children: [
            if (images.isNotEmpty)
              SizedBox(
                height: 220,
                child: PageView.builder(
                  itemCount: images.length,
                  itemBuilder: (_, i) => Image.network(
                    images[i],
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, ev) => ev == null
                        ? child
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('最新內容', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            ...docs.map((d) {
              final data = d.data();
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text((data['title'] ?? '').toString()),
                  subtitle: Text(
                    (data['body'] ?? '').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SiteContentDetailPreviewPage(
                          docId: d.id,
                          pageTitle: (data['title'] ?? '').toString(),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------
// 最新消息
// ------------------------------------------------------------
class _NewsSection extends StatelessWidget {
  const _NewsSection();
  @override
  Widget build(BuildContext context) {
    return const SiteNewsListPreviewPage(
      category: 'news',
      pageTitle: '最新消息',
    );
  }
}

// ------------------------------------------------------------
// 公司簡介
// ------------------------------------------------------------
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return const SiteContentPreviewPage(
      category: 'about',
      pageTitle: '公司簡介',
    );
  }
}

// ------------------------------------------------------------
// FAQ
// ------------------------------------------------------------
class _FAQSection extends StatelessWidget {
  const _FAQSection();

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final q = db
        .collection('site_contents')
        .where('category', isEqualTo: 'faq')
        .orderBy('updatedAt', descending: true)
        .limit(50);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('尚無 FAQ'));
        return ListView(
          children: docs.map((d) {
            final data = d.data();
            return ExpansionTile(
              title: Text((data['title'] ?? '').toString()),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text((data['body'] ?? '').toString()),
                )
              ],
            );
          }).toList(),
        );
      },
    );
  }
}

// ------------------------------------------------------------
// 聯絡我們
// ------------------------------------------------------------
class _ContactSection extends StatelessWidget {
  const _ContactSection();

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final q = db
        .collection('site_contents')
        .where('category', isEqualTo: 'contact')
        .orderBy('updatedAt', descending: true)
        .limit(1);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('尚無聯絡資訊'));
        final data = docs.first.data();
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((data['title'] ?? '').toString(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              SelectableText((data['body'] ?? '').toString(), style: const TextStyle(fontSize: 15)),
            ],
          ),
        );
      },
    );
  }
}
