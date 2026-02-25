import 'package:flutter/material.dart';

/// ✅ OnboardingPage（新手引導｜修改後完整版）
/// ------------------------------------------------------------
/// 修正重點：
/// - ✅ 完全移除 AppNotification 型別依賴（避免 non_type_as_type_argument）
/// - ✅ 純 Flutter PageView + 指示點
/// - ✅ 完成後導向 /login（你可依專案改成 /home）
/// ------------------------------------------------------------
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;

  final List<_OnboardSlide> _slides = const [
    _OnboardSlide(
      icon: Icons.shopping_bag_outlined,
      title: 'Osmile 購物與活動',
      desc: '一次整合商城、抽獎、優惠券、任務與積分，讓你買得划算、玩得開心。',
    ),
    _OnboardSlide(
      icon: Icons.local_activity_outlined,
      title: '任務積分與徽章',
      desc: '完成每日任務拿積分，收集徽章，解鎖更多回饋與活動資格。',
    ),
    _OnboardSlide(
      icon: Icons.notifications_outlined,
      title: '通知中心',
      desc: '訂單、活動、優惠券與系統消息集中管理，不再漏接重要訊息。',
    ),
    _OnboardSlide(
      icon: Icons.sos_outlined,
      title: 'SOS 求助與守護',
      desc: '關鍵時刻一鍵求助，守護家人安全（需依裝置/權限設定）。',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _slides.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _skip() => _finish();

  void _finish() {
    // ✅ 這裡只做導航，不依賴任何通知/模型/服務，避免再引入型別錯誤
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login'); // 你要改 /home 也可以
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  TextButton(onPressed: _skip, child: const Text('略過')),
                  const Spacer(),
                  Text(
                    '${_index + 1}/${_slides.length}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),

            // pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _slideView(_slides[i]),
              ),
            ),

            // dots + actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Column(
                children: [
                  _dots(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _skip,
                          child: const Text('先逛逛'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: isLast ? _finish : _next,
                          child: Text(isLast ? '開始使用' : '下一步'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slideView(_OnboardSlide s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(s.icon, size: 64, color: Colors.blueGrey),
                  const SizedBox(height: 14),
                  Text(
                    s.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.desc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Colors.black87,
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
      children: List.generate(_slides.length, (i) {
        final active = i == _index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? Colors.blueGrey : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _OnboardSlide {
  final IconData icon;
  final String title;
  final String desc;

  const _OnboardSlide({
    required this.icon,
    required this.title,
    required this.desc,
  });
}
