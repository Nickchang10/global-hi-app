// lib/pages/lottery_rules_page.dart
//
// ✅ LotteryRulesPage（抽獎規則｜可編譯完整版）
// ------------------------------------------------------------
// - 顯示抽獎規則、注意事項、常見問題
// - 無任何多餘未使用變數（修正 unused_local_variable: titleStyle）
// - 可直接 Navigator.push 進來使用
//
// ✅ 修正：withOpacity deprecated → 改用 withValues(alpha: ...)

import 'package:flutter/material.dart';

class LotteryRulesPage extends StatelessWidget {
  const LotteryRulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ 修正點：titleStyle 真的用上（避免 unused_local_variable）
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900);

    final sectionTitleStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900);

    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(height: 1.5);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(title: const Text('抽獎規則')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _heroCard(titleStyle, bodyStyle),
          const SizedBox(height: 12),

          _sectionCard(
            title: '如何獲得抽獎券？',
            titleStyle: sectionTitleStyle,
            bodyStyle: bodyStyle,
            bullets: const [
              '完成每日任務可獲得抽獎券（依活動設定）。',
              '直播下單、活動加碼可能會額外贈送抽獎券（依公告為準）。',
              '部分活動需要先登入帳號才會記錄抽獎資格。',
            ],
          ),

          const SizedBox(height: 12),
          _sectionCard(
            title: '抽獎流程說明',
            titleStyle: sectionTitleStyle,
            bodyStyle: bodyStyle,
            bullets: const [
              '活動期間內累積抽獎券數量。',
              '抽獎日由系統進行抽獎並公告結果（示範頁面不含真實抽獎）。',
              '中獎者可於「我的獎勵 / 我的優惠券」查看領取方式。',
            ],
          ),

          const SizedBox(height: 12),
          _sectionCard(
            title: '注意事項',
            titleStyle: sectionTitleStyle,
            bodyStyle: bodyStyle,
            bullets: const [
              '抽獎券為活動資格憑證，不可轉讓、不可折現。',
              '若發現異常行為（洗券、作弊等），官方有權取消資格。',
              '獎品內容、數量、領取方式以活動公告為準。',
              '系統示範頁：內容僅用於 App 功能展示。',
            ],
          ),

          const SizedBox(height: 12),
          _faqCard(sectionTitleStyle, bodyStyle),

          const SizedBox(height: 24),
          Text(
            '若你要把這頁接到 Firestore 活動規則（例如後台可改內容），我也可以幫你改成可讀取 site_contents / campaigns 的版本。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _heroCard(TextStyle? titleStyle, TextStyle? bodyStyle) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                // ✅ 修正：withOpacity -> withValues
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.emoji_events_outlined,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('活動抽獎規則', style: titleStyle),
                  const SizedBox(height: 8),
                  Text('此頁提供抽獎券取得方式、抽獎流程與注意事項。實際規則請以官方公告為準。', style: bodyStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required TextStyle? titleStyle,
    required TextStyle? bodyStyle,
    required List<String> bullets,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: titleStyle),
            const SizedBox(height: 10),
            ...bullets.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 6, color: Colors.black54),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t, style: bodyStyle)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _faqCard(TextStyle? titleStyle, TextStyle? bodyStyle) {
    final faqs = <Map<String, String>>[
      {'q': '抽獎券會過期嗎？', 'a': '一般以活動期間為準，活動結束後未使用的抽獎券可能失效（依公告）。'},
      {'q': '我沒登入也能參加嗎？', 'a': '建議登入，避免抽獎券無法記錄到帳號中。'},
      {'q': '中獎後要去哪裡領？', 'a': '可在「我的獎勵 / 我的優惠券」查看中獎與領取方式（依獎品類型不同）。'},
    ];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('常見問題', style: titleStyle),
            const SizedBox(height: 10),
            ...faqs.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Q：${f['q']}',
                      style: titleStyle?.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text('A：${f['a']}', style: bodyStyle),
                    const Divider(height: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
