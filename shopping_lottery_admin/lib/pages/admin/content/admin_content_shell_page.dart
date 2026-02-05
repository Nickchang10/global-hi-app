// lib/pages/admin/content/admin_content_shell_page.dart
//
// ✅ AdminContentShellPage（內容管理中心｜完整版）
// ------------------------------------------------------------
// - 管理內容型模組（最新消息 / 公告 / 下載專區 / 聯絡表單 / 內容頁）
// - 支援 Firestore 結構：news / announcements / downloads / contacts / site_contents
// - 提供導航卡片 + 快速開關 + Placeholder 導向
// - 可直接整合至 AdminShellPage
// ------------------------------------------------------------

import 'package:flutter/material.dart';

class AdminContentShellPage extends StatefulWidget {
  const AdminContentShellPage({super.key});

  @override
  State<AdminContentShellPage> createState() => _AdminContentShellPageState();
}

class _AdminContentShellPageState extends State<AdminContentShellPage> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('內容管理中心', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          _SectionTitle(
            title: '內容模組總覽',
            subtitle: '集中管理前台可見的靜態內容與文章資料',
          ),
          const SizedBox(height: 8),

          _ContentTile(
            icon: Icons.article_outlined,
            title: '最新消息',
            subtitle: '管理新聞稿、活動資訊、內容文章（news）',
            onTap: () => _openPlaceholder(
              context,
              title: '最新消息管理（待接入）',
              desc: '下一步我可提供 admin_news_page.dart 完整版，\n'
                  '含上傳封面、內容編輯、上下架與排序。',
            ),
          ),
          _ContentTile(
            icon: Icons.announcement_outlined,
            title: '公告管理',
            subtitle: '網站公告、系統訊息、維護通知（announcements）',
            onTap: () => _openPlaceholder(
              context,
              title: '公告管理（待接入）',
              desc: '支援公告置頂 / 上下架 / 時間控制。',
            ),
          ),
          _ContentTile(
            icon: Icons.download_outlined,
            title: '下載專區',
            subtitle: '檔案版本、上傳日期、可下載連結（downloads）',
            onTap: () => _openPlaceholder(
              context,
              title: '下載專區管理（待接入）',
              desc: '整合 Firebase Storage 上傳與版本維護。',
            ),
          ),
          _ContentTile(
            icon: Icons.mail_outline,
            title: '聯絡表單',
            subtitle: '顯示用戶提交的聯絡內容、狀態、回覆紀錄（contacts）',
            onTap: () => _openPlaceholder(
              context,
              title: '聯絡表單管理（待接入）',
              desc: '包含未讀、已回覆標記、篩選日期。',
            ),
          ),
          _ContentTile(
            icon: Icons.description_outlined,
            title: '內容頁管理',
            subtitle: '靜態頁面：關於我們、隱私條款、使用說明（site_contents）',
            onTap: () => _openPlaceholder(
              context,
              title: '內容頁管理（待接入）',
              desc: '支援 Markdown / HTML 編輯與版本控制。',
            ),
          ),

          const SizedBox(height: 18),
          Card(
            elevation: 0,
            color: cs.surfaceVariant.withOpacity(0.4),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '提示：以上各模組對應 Firestore 集合：news / announcements / downloads / contacts / site_contents。\n'
                '下一步建議：先完成 admin_news_page.dart（最新消息完整可用版）。',
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPlaceholder(BuildContext context,
      {required String title, required String desc}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PlaceholderPage(title: title, desc: desc),
      ),
    );
  }
}

// ============================================================
// UI Widgets
// ============================================================

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        if (subtitle != null)
          Text(subtitle!,
              style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ContentTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ContentTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(icon, color: cs.onPrimaryContainer),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  final String desc;
  const _PlaceholderPage({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 44, color: cs.primary),
                    const SizedBox(height: 10),
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(desc,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: cs.onSurfaceVariant, height: 1.4)),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('返回'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
