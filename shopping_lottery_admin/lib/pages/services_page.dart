// lib/pages/services_page.dart
//
// ✅ ServicesPage（最終完整版｜可編譯｜移除 unused arguments 參數｜withOpacity → withValues(alpha:)）
// ------------------------------------------------------------
// - 支援搜尋
// - 卡片式入口
// - 不再使用 Color.withOpacity（deprecated）
//   改用 Color.withValues(alpha: 0~255)

import 'package:flutter/material.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _s(String v) => v.trim().toLowerCase();

  void _clearSearch() {
    _searchCtrl.clear();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = _s(_searchCtrl.text);

    final items = <_ServiceItem>[
      const _ServiceItem(
        title: '公告管理',
        subtitle: 'announcements collection（新增/編輯/上下架/置頂）',
        icon: Icons.campaign_outlined,
        routeName: '/announcements',
      ),
      const _ServiceItem(
        title: '訂單管理',
        subtitle: 'orders 列表與狀態更新',
        icon: Icons.receipt_long_outlined,
        routeName: '/orders',
      ),
      const _ServiceItem(
        title: '新聞內容',
        subtitle: 'site_contents category=news',
        icon: Icons.newspaper_outlined,
        routeName: '/news',
      ),
      const _ServiceItem(
        title: '前台官網預覽',
        subtitle: 'FrontSiteShell（site_contents）',
        icon: Icons.public_outlined,
        routeName: '/front_site',
      ),
    ];

    final filtered = items.where((it) {
      if (q.isEmpty) return true;
      return _s(it.title).contains(q) || _s(it.subtitle).contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('服務中心'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋服務/功能…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  tooltip: '清除',
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.clear),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      '沒有符合的項目',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ServiceCard(item: filtered[i]),
                  ),
          ),
        ],
      ),
      backgroundColor: cs.surface,
    );
  }
}

class _ServiceItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String routeName;

  const _ServiceItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.routeName,
  });
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.item});
  final _ServiceItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ✅ withOpacity(0.10) -> alpha ≈ 26
    final bg = cs.primary.withValues(alpha: 26);

    // ✅ withOpacity(0.14) -> alpha ≈ 36
    final iconBg = cs.primary.withValues(alpha: 36);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pushNamed(context, item.routeName);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Icon(item.icon, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
