// lib/pages/admin/content/admin_content_hub_page.dart
//
// ✅ AdminContentHubPage（公告/內容管理｜正式入口｜可編譯）
// ------------------------------------------------------------
// - 提供入口：最新消息（news）/ 公告（announcements）/ FAQ（faqs）/ 頁面內容（site_contents）
// - 全部用 Named Routes（避免 creation_with_non_type）
// - 不依賴 service，FireStore 由各頁自行處理
//

import 'package:flutter/material.dart';
import '../../../layouts/scaffold_with_drawer.dart';

class AdminContentHubPage extends StatelessWidget {
  const AdminContentHubPage({super.key});

  static const String routeName = '/admin-content';

  @override
  Widget build(BuildContext context) {
    final items = <_Entry>[
      const _Entry(
        title: '最新消息',
        subtitle: 'news：新增/編輯/上下架',
        icon: Icons.newspaper_outlined,
        route: '/admin-content/news',
      ),
      const _Entry(
        title: '公告',
        subtitle: 'announcements：新增/編輯/上下架',
        icon: Icons.announcement_outlined,
        route: '/admin-content/announcements',
      ),
      const _Entry(
        title: 'FAQ',
        subtitle: 'faqs：問答管理/啟用/排序',
        icon: Icons.quiz_outlined,
        route: '/admin-content/faqs',
      ),
      const _Entry(
        title: '頁面內容',
        subtitle: 'site_contents：About/Terms/Privacy',
        icon: Icons.article_outlined,
        route: '/admin-content/pages',
      ),
    ];

    return ScaffoldWithDrawer(
      title: '公告 / 內容管理',
      currentRoute: routeName,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(context),
          const SizedBox(height: 12),
          _grid(context, items),
          const SizedBox(height: 16),
          _tips(context),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.announcement_outlined, color: cs.primary, size: 28),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '公告 / 內容管理',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text('管理最新消息、公告、FAQ、與靜態頁面內容'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(BuildContext context, List<_Entry> items) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final crossAxisCount = w >= 980 ? 4 : (w >= 680 ? 3 : 2);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (_, i) => _EntryCard(entry: items[i]),
        );
      },
    );
  }

  Widget _tips(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('小提醒', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              '• 內容頁全部使用 Firestore collections：news / announcements / faqs / site_contents',
            ),
            Text('• 若列表顯示空，先確認 Firestore 規則與該 collection 是否存在資料'),
            Text('• 本模組不做複合查詢（避免索引地獄），搜尋為本地過濾'),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final _Entry entry;
  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pushNamed(context, entry.route),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(entry.icon, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _Entry {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  const _Entry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });
}
