// lib/pages/front/front_site_shell_rwd.dart
//
// ✅ FrontSiteShellRWD（正式版網站結構 + RWD + Firestore 自動同步）
// ------------------------------------------------------------
// 結構：AppBar / Drawer / Body / Footer
// 資料來源：site_contents
//   - custom-home：首頁
//   - news：最新消息
//   - about：公司簡介
//   - faq：FAQ
//   - contact：聯絡我們
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../site/site_content_preview_pages.dart';

class FrontSiteShellRWD extends StatefulWidget {
  const FrontSiteShellRWD({super.key});

  @override
  State<FrontSiteShellRWD> createState() => _FrontSiteShellRWDState();
}

class _FrontSiteShellRWDState extends State<FrontSiteShellRWD> {
  int _selectedIndex = 0;
  final _sections = const [
    _FrontHomeSection(),
    _FrontNewsSection(),
    _FrontAboutSection(),
    _FrontFAQSection(),
    _FrontContactSection(),
  ];

  final _titles = const ['首頁', '最新消息', '公司簡介', 'FAQ', '聯絡我們'];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 32, errorBuilder: (_, __, ___) => const Icon(Icons.watch)),
            const SizedBox(width: 8),
            const Text('Osmile 官網'),
            const Spacer(),
            if (isWide)
              Row(
                children: List.generate(_titles.length, (i) {
                  final active = i == _selectedIndex;
                  return TextButton(
                    onPressed: () => setState(() => _selectedIndex = i),
                    child: Text(
                      _titles[i],
                      style: TextStyle(
                        color: active ? Colors.amberAccent : Colors.white,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
      drawer: isWide
          ? null
          : Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const DrawerHeader(
                    decoration: BoxDecoration(color: Colors.blue),
                    child: Text('Osmile 導覽選單', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                  ...List.generate(_titles.length, (i) {
                    return ListTile(
                      leading: Icon(
                        [Icons.home, Icons.newspaper, Icons.apartment, Icons.help, Icons.call][i],
                      ),
                      title: Text(_titles[i]),
                      selected: _selectedIndex == i,
                      onTap: () {
                        setState(() => _selectedIndex = i);
                        Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ),
            ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _sections[_selectedIndex],
      ),
      bottomNavigationBar: isWide ? null : _FooterSection(),
    );
  }
}

// ------------------------------------------------------------
// 首頁：custom-home
// ------------------------------------------------------------
class _FrontHomeSection extends StatelessWidget {
  const _FrontHomeSection();

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
        final data = docs.first.data();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (images.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: PageView.builder(
                    itemCount: images.length,
                    itemBuilder: (_, i) => Image.network(images[i], fit: BoxFit.cover),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              (data['title'] ?? '').toString(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text((data['body'] ?? '').toString(), style: const TextStyle(fontSize: 16, height: 1.5)),
            const SizedBox(height: 30),
            const _FooterSection(),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------
// 最新消息
// ------------------------------------------------------------
class _FrontNewsSection extends StatelessWidget {
  const _FrontNewsSection();

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
class _FrontAboutSection extends StatelessWidget {
  const _FrontAboutSection();

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
class _FrontFAQSection extends StatelessWidget {
  const _FrontFAQSection();

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
          padding: const EdgeInsets.all(16),
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
class _FrontContactSection extends StatelessWidget {
  const _FrontContactSection();

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
              const SizedBox(height: 20),
              const _FooterSection(),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------
// Footer 區（共用）
// ------------------------------------------------------------
class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('site_contents')
          .where('category', isEqualTo: 'contact')
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        String contactText = '© ${DateTime.now().year} Osmile. All rights reserved.';
        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          final d = snap.data!.docs.first.data();
          contactText += '\n${(d['body'] ?? '').toString()}';
        }
        return Container(
          width: double.infinity,
          color: Colors.grey.shade100,
          padding: const EdgeInsets.all(20),
          child: Text(
            contactText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
          ),
        );
      },
    );
  }
}
