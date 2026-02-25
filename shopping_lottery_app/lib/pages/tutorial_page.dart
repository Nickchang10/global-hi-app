// lib/pages/tutorial_page.dart
import 'package:flutter/material.dart';

/// ✅ TutorialPage（新手教學｜完整版｜已修正 withValues alpha 型別）
/// ------------------------------------------------------------
/// - PageView 教學頁
/// - 進度點點 + 下一步/跳過/完成
/// - ✅ withOpacity 全改為 withValues(alpha: double 0~1)
class TutorialPage extends StatefulWidget {
  const TutorialPage({super.key});

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {
  final _pageCtrl = PageController();
  int _index = 0;

  // ✅ withValues(alpha: ) 需要 double?（0.0~1.0）
  double _a(double opacity) => opacity.clamp(0.0, 1.0);

  final List<_TutorialItem> _items = const [
    _TutorialItem(
      title: '歡迎來到 Osmile',
      desc: '這裡會帶你快速了解主要功能：購物、點數任務、抽獎、通知中心。',
      icon: Icons.auto_awesome,
    ),
    _TutorialItem(
      title: '點數任務',
      desc: '完成每日任務累積點數，可用於兌換優惠或參與活動。',
      icon: Icons.stars_outlined,
    ),
    _TutorialItem(
      title: '直播 / 活動',
      desc: '參與直播與限時活動，有機會獲得加碼獎勵與抽獎資格。',
      icon: Icons.live_tv_outlined,
    ),
    _TutorialItem(
      title: '通知中心',
      desc: '訂單、優惠券、系統公告都會在這裡提醒你，不漏接重要訊息。',
      icon: Icons.notifications_outlined,
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_index >= _items.length - 1) {
      _finish();
      return;
    }
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _skip() => _finish();

  void _finish() {
    // 你也可以改成 pushReplacementNamed('/home')
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushReplacementNamed('/'); // fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _items.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('新手教學'),
        actions: [TextButton(onPressed: _skip, child: const Text('跳過'))],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: _items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _page(context, _items[i]),
            ),
          ),
          _dots(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _skip,
                    child: const Text('略過'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _goNext,
                    child: Text(isLast ? '完成' : '下一步'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _page(BuildContext context, _TutorialItem item) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      // ✅ withOpacity → withValues(alpha: double 0~1)
                      color: primary.withValues(alpha: _a(0.10)),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: primary.withValues(alpha: _a(0.18)),
                      ),
                    ),
                    child: Icon(item.icon, size: 44, color: primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.desc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      height: 1.6,
                      color: Colors.black.withValues(alpha: _a(0.72)),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: _a(0.08)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: _a(0.06)),
                      ),
                    ),
                    child: Text(
                      '提示：你可以隨時在「我的」或「設定」重新查看教學。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: _a(0.65)),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_items.length, (i) {
        final active = i == _index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? Colors.blueAccent
                : Colors.blueAccent.withValues(alpha: _a(0.25)),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

class _TutorialItem {
  final String title;
  final String desc;
  final IconData icon;

  const _TutorialItem({
    required this.title,
    required this.desc,
    required this.icon,
  });
}
