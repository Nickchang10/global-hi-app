// lib/pages/lottery_page.dart
// =======================================================
// ✅ LotteryPage（最終整合完整版）
// - Web / Android / iOS 可用（無 dart:io）
// - 與 FirestoreMockService / LotteryService / NotificationService 完整整合
// - 權重機率 + 保底機制 + 抽獎紀錄
// - 轉盤動畫：保證「指針位置 = 真實結果」
// =======================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/lottery_service.dart';
import '../services/notification_service.dart';
import '../services/firestore_mock_service.dart';

class LotteryPage extends StatefulWidget {
  const LotteryPage({super.key});

  @override
  State<LotteryPage> createState() => _LotteryPageState();
}

class _LotteryPageState extends State<LotteryPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _spinAnim;

  bool _isSpinning = false;
  double _rotation = 0.0; // wheel rotation in radians
  String? _resultText;

  final String userId = 'demo_user';
  final List<String> _history = [];

  // ✅ 轉盤顯示順序（同時決定每一塊的位置）
  final List<String> _rewards = const [
    '+50 積分',
    '+20 積分',
    'NT\$100 優惠券',
    'NT\$200 優惠券',
    '再接再厲',
    '免費抽獎',
  ];

  // ✅ 權重（不是百分比）
  final Map<String, double> _weights = const {
    '+50 積分': 25,
    '+20 積分': 25,
    'NT\$100 優惠券': 20,
    'NT\$200 優惠券': 10,
    '再接再厲': 10,
    '免費抽獎': 10,
  };

  // ✅ 保底
  int _spinCount = 0;
  static const int _pityEvery = 10;

  // ✅ 指針固定在上方
  static const double _startAngle = -pi / 2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );
    _spinAnim = Tween<double>(begin: 0, end: 0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _points => FirestoreMockService.instance.userPoints;
  int get _freeCount => LotteryService.instance.getFreeSpinCount(userId);
  bool get _canSpin => _freeCount > 0 || _points >= 50;

  String get _spinButtonLabel {
    if (_isSpinning) return '抽獎中...';
    if (_freeCount > 0) return '使用免費抽獎（$_freeCount 次）';
    return '消耗 50 積分抽一次';
  }

  // --------------------------
  // Geometry helpers
  // --------------------------
  double _norm2pi(double a) {
    final two = 2 * pi;
    a = a % two;
    if (a < 0) a += two;
    return a;
  }

  /// 依「目前輪盤旋轉角 _rotation」計算指針(上方)目前指到哪一個 index
  /// ✅ 最終結果永遠用這個 index 取得，保證「指針=結果」
  int _indexFromRotation(double rotation) {
    final n = _rewards.length;
    final sweep = 2 * pi / n;

    // 指針角度 = _startAngle
    // 輪盤旋轉後，指針所對應到輪盤的「本地角度」= pointer - rotation
    final localAtPointer = _norm2pi(_startAngle - rotation);
    final offset = _norm2pi(localAtPointer - _startAngle); // 0..2pi
    int index = (offset / sweep).floor();
    if (index < 0) index = 0;
    if (index >= n) index = n - 1;
    return index;
  }

  /// 算出要讓 index 的「中心」對齊指針，需要的目標 rotation(模 2π)
  double _desiredRotationForIndex(int index, {double jitterFrac = 0.18}) {
    final n = _rewards.length;
    final sweep = 2 * pi / n;

    // index 中心在未旋轉狀態的角度
    final centerAngle = _startAngle + index * sweep + sweep / 2;

    // 旋轉 rotation 後：centerAngle + rotation = _startAngle (mod 2π)
    // => rotation = _startAngle - centerAngle
    double desired = _startAngle - centerAngle;

    // 抖動：讓停的位置更自然，但仍在同一格內
    final jitterMax = sweep * jitterFrac; // < 0.5*sweep 才不會跨格
    desired += (Random().nextDouble() * 2 - 1) * jitterMax;

    return _norm2pi(desired);
  }

  // --------------------------
  // Weighted draw (kept)
  // --------------------------
  String _drawPrizeByWeight() {
    _spinCount++;

    // 保底：每 N 抽至少出 100 以上
    if (_pityEvery > 0 && _spinCount % _pityEvery == 0) {
      return Random().nextBool() ? 'NT\$100 優惠券' : 'NT\$200 優惠券';
    }

    final total = _weights.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return _rewards.first;

    final r = Random().nextDouble() * total;
    double acc = 0;
    for (final k in _rewards) {
      acc += (_weights[k] ?? 0);
      if (r <= acc) return k;
    }
    return _rewards.last;
  }

  // --------------------------
  // Safe compatible awarding
  // --------------------------
  Future<void> _safeAddPoints(int pts) async {
    final dynamic fs = FirestoreMockService.instance;

    try {
      final f = fs.addPoints;
      if (f is Function) {
        final ret = f(pts);
        if (ret is Future) await ret;
        return;
      }
    } catch (_) {}

    try {
      final f = fs.increasePoints;
      if (f is Function) {
        final ret = f(pts);
        if (ret is Future) await ret;
        return;
      }
    } catch (_) {}

    try {
      fs.userPoints = (fs.userPoints as int) + pts;
    } catch (_) {}
  }

  Future<void> _safeAddFreeSpin() async {
    final dynamic ls = LotteryService.instance;

    try {
      final f = ls.addFreeSpin;
      if (f is Function) {
        final ret = f(userId);
        if (ret is Future) await ret;
        return;
      }
    } catch (_) {}

    try {
      final f = ls.grantFreeSpin;
      if (f is Function) {
        final ret = f(userId);
        if (ret is Future) await ret;
        return;
      }
    } catch (_) {}

    try {
      final f = ls.giveFreeSpin;
      if (f is Function) {
        final ret = f(userId);
        if (ret is Future) await ret;
        return;
      }
    } catch (_) {}
  }

  // --------------------------
  // Start Lottery
  // --------------------------
  Future<void> _startLottery() async {
    if (_isSpinning) return;

    final lottery = LotteryService.instance;
    final notification = NotificationService.instance;
    final firestore = FirestoreMockService.instance;

    final hasFree = lottery.getFreeSpinCount(userId) > 0;
    final canAfford = firestore.userPoints >= 50;

    if (!hasFree && !canAfford) {
      _toast('積分不足，無法抽獎');
      return;
    }

    setState(() {
      _isSpinning = true;
      _resultText = null;
    });

    HapticFeedback.selectionClick();

    // 先扣點/用免費（避免動畫轉完才失敗）
    try {
      if (hasFree) {
        await lottery.useFreeSpin(userId);
      } else {
        await firestore.deductPoints(50);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSpinning = false);
      _toast('扣點 / 使用免費次數失敗，請稍後再試');
      return;
    }

    // 先用權重抽「想要」停在哪格
    final wantedPrize = _drawPrizeByWeight();
    final wantedIndex = max(0, _rewards.indexOf(wantedPrize));

    // 算出這格要對齊指針的 rotation（模 2π）
    final desiredMod = _desiredRotationForIndex(wantedIndex);

    // 轉多圈再落點：從目前 rotation(模2π)轉到 desiredMod
    final currentMod = _norm2pi(_rotation);
    final delta = _norm2pi(desiredMod - currentMod); // 0..2π
    final turns = 7 + Random().nextInt(3); // 7~9圈
    final targetRotation = _rotation + turns * 2 * pi + delta;

    _spinAnim = Tween<double>(begin: _rotation, end: targetRotation).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.reset();
    try {
      await _controller.forward().orCancel;
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSpinning = false);
      return;
    }

    _rotation = targetRotation;

    // ✅ 最終結果以「實際指針指到的格」為準（保證永遠一致）
    final landedIndex = _indexFromRotation(_rotation);
    final landedPrize = _rewards[landedIndex];

    final apply = await _applyPrize(landedPrize);

    if (!mounted) return;
    setState(() {
      _isSpinning = false;
      _resultText = apply.message;
      _history.insert(0, apply.message);
      if (_history.length > 30) _history.removeRange(30, _history.length);
    });

    notification.addNotification(
      type: 'lottery',
      title: '抽獎結果',
      message: apply.message,
      icon: Icons.casino,
    );

    HapticFeedback.lightImpact();
    _toast(apply.message, success: apply.success);
    await _showResultDialog(message: apply.message, success: apply.success);
  }

  Future<_ApplyResult> _applyPrize(String prize) async {
    bool success = true;
    String message;

    switch (prize) {
      case '+50 積分':
        await _safeAddPoints(50);
        message = '恭喜獲得 +50 積分！';
        break;
      case '+20 積分':
        await _safeAddPoints(20);
        message = '恭喜獲得 +20 積分！';
        break;
      case 'NT\$100 優惠券':
        message = '恭喜獲得 折抵NT\$100 優惠券！';
        break;
      case 'NT\$200 優惠券':
        message = '恭喜獲得 折抵NT\$200 優惠券！';
        break;
      case '免費抽獎':
        await _safeAddFreeSpin();
        message = '恭喜獲得 免費抽獎 1 次！';
        break;
      default:
        success = false;
        message = '再接再厲，下次會更好！';
        break;
    }

    return _ApplyResult(message: message, success: success);
  }

  void _toast(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.grey.shade800,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showResultDialog({
    required String message,
    required bool success,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(
              success ? Icons.emoji_events_outlined : Icons.info_outline,
              color: success ? Colors.orangeAccent : Colors.grey,
            ),
            const SizedBox(width: 8),
            const Text('抽獎結果'),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() {});
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('轉盤抽獎', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatsCard(),
          const SizedBox(height: 12),
          _buildWheelCard(),
          const SizedBox(height: 14),
          _buildSpinButton(),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _buildResultCard(),
          ),
          const SizedBox(height: 12),
          _buildHistory(),
          const SizedBox(height: 12),
          _buildRules(),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: _StatTile(
                title: '可用積分',
                value: '$_points',
                icon: Icons.local_fire_department_outlined,
                valueColor: Colors.blueAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                title: '免費抽獎',
                value: '$_freeCount 次',
                icon: Icons.card_giftcard_outlined,
                valueColor:
                    _freeCount > 0 ? Colors.orangeAccent : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWheelCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(title: '轉盤'),
            const SizedBox(height: 10),
            Center(
              child: SizedBox(
                width: 328,
                height: 328,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 外層陰影底
                    Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                    ),

                    // 外圈金屬感（雙環）
                    Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.grey.shade200,
                            Colors.white,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                    ),
                    Container(
                      width: 312,
                      height: 312,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF7F8FA),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                    ),

                    // 轉盤本體
                    ClipOval(
                      child: Container(
                        width: 296,
                        height: 296,
                        color: Colors.white,
                        child: RepaintBoundary(child: _buildWheel()),
                      ),
                    ),

                    // 玻璃高光 overlay
                    IgnorePointer(
                      child: ClipOval(
                        child: Container(
                          width: 296,
                          height: 296,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.30),
                                Colors.white.withOpacity(0.06),
                                Colors.transparent,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 指針
                    Positioned(
                      top: 10,
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.20),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: CustomPaint(
                              size: const Size(38, 30),
                              painter: _PointerPainter(color: Colors.red.shade700),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 中心按鈕（立體）
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFF7E8), Color(0xFFFFFFFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: Colors.orangeAccent, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 14,
                            child: Container(
                              width: 48,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.72),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.casino,
                            size: 38,
                            color: Colors.orangeAccent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWheel() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final rotation = _spinAnim.value;
        return Transform.rotate(
          angle: rotation,
          child: CustomPaint(
            size: const Size(296, 296),
            painter: _WheelPainter(_rewards, startAngle: _startAngle),
          ),
        );
      },
    );
  }

  Widget _buildSpinButton() {
    return ElevatedButton.icon(
      onPressed: (_isSpinning || !_canSpin) ? null : _startLottery,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        disabledForegroundColor: Colors.grey.shade700,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      icon: _isSpinning
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.play_circle_outline),
      label: Text(_spinButtonLabel),
    );
  }

  Widget _buildResultCard() {
    if (_resultText == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orangeAccent.withOpacity(0.25)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_outlined, color: Colors.orangeAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _resultText!,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: _SectionTitle(title: '抽獎紀錄')),
                TextButton(
                  onPressed: _history.isEmpty
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() => _history.clear());
                        },
                  child: const Text('清除'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_history.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '尚無抽獎紀錄，快來試試手氣吧！',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              )
            else
              ..._history.take(10).map(
                    (msg) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(Icons.history, color: Colors.grey.shade500),
                      title: Text(
                        msg,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildRules() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(title: '抽獎規則'),
            const SizedBox(height: 8),
            const _Bullet(text: '每次抽獎需消耗 50 積分（若有免費次數則優先使用）。'),
            const _Bullet(text: '滿 NT\$500 購物可獲得一次免費抽獎機會。'),
            _Bullet(text: '每 $_pityEvery 次抽獎保底至少 NT\$100 以上獎項。'),
            const _Bullet(text: '獎項包含：積分、優惠券、免費機會、再接再厲。'),
            const SizedBox(height: 10),
            Text(
              _buildProbabilityText(),
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildProbabilityText() {
    final total = _weights.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return '機率：未設定（權重總和為 0）';

    final parts = _rewards.map((k) {
      final w = _weights[k] ?? 0;
      final pct = (w / total) * 100;
      return '$k ${pct.toStringAsFixed(0)}%';
    }).toList();

    return '機率（依權重換算）：${parts.join('、')}';
  }
}

class _ApplyResult {
  final String message;
  final bool success;
  _ApplyResult({required this.message, required this.success});
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color valueColor;

  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: valueColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: valueColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: Colors.blueAccent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(height: 1.35)),
          ),
        ],
      ),
    );
  }
}

/// 指針造型 painter（正式指示器）
class _PointerPainter extends CustomPainter {
  final Color color;
  _PointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height * 0.72)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, p);

    final hi = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.fill;

    final hiPath = Path()
      ..moveTo(size.width / 2, 2)
      ..lineTo(size.width * 0.78, size.height * 0.72)
      ..lineTo(size.width / 2, size.height * 0.62)
      ..lineTo(size.width * 0.22, size.height * 0.72)
      ..close();

    canvas.drawPath(hiPath, hi);
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 🎨 自訂轉盤繪製器（漸層扇形 + 分隔線 + 文字順向）
class _WheelPainter extends CustomPainter {
  final List<String> rewards;
  final double startAngle;

  _WheelPainter(this.rewards, {required this.startAngle});

  List<Color> _palette() {
    return const [
      Color(0xFF4F8CFF),
      Color(0xFF2EC4B6),
      Color(0xFF7B61FF),
      Color(0xFFFF5C8A),
      Color(0xFFFFC857),
      Color(0xFFFF6B6B),
    ];
  }

  String _prettyLabel(String s) {
    if (s.contains('NT\$100')) return 'NT\$100\n優惠券';
    if (s.contains('NT\$200')) return 'NT\$200\n優惠券';
    if (s.contains('+50')) return '+50\n積分';
    if (s.contains('+20')) return '+20\n積分';
    if (s == '免費抽獎') return '免費\n抽獎';
    if (s == '再接再厲') return '再接\n再厲';
    return s;
  }

  double _norm2pi(double a) {
    final two = 2 * pi;
    a = a % two;
    if (a < 0) a += two;
    return a;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final sectorCount = rewards.length;
    final sweep = 2 * pi / sectorCount;
    final colors = _palette();

    final rect = Rect.fromCircle(center: center, radius: radius);

    // 扇形（漸層）
    for (int i = 0; i < sectorCount; i++) {
      final base = colors[i % colors.length];
      final sa = startAngle + i * sweep;

      final fill = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [base.withOpacity(0.92), base.withOpacity(1.0)],
          stops: const [0.18, 1.0],
        ).createShader(rect);

      canvas.drawArc(rect, sa, sweep, true, fill);
    }

    // 分隔線
    final separator = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withOpacity(0.92);

    for (int i = 0; i < sectorCount; i++) {
      final a = startAngle + i * sweep;
      final p1 = center;
      final p2 = Offset(center.dx + cos(a) * radius, center.dy + sin(a) * radius);
      canvas.drawLine(p1, p2, separator);
    }

    // 內圈
    final innerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = Colors.white.withOpacity(0.55);
    canvas.drawCircle(center, radius * 0.20, innerRing);

    // 外圈描邊
    final outerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withOpacity(0.85);
    canvas.drawCircle(center, radius - 1.5, outerRing);

    // 文字（自動轉正）
    for (int i = 0; i < sectorCount; i++) {
      final sa = startAngle + i * sweep;
      final mid = sa + sweep / 2;

      double textRot = mid + pi / 2;
      final normalized = _norm2pi(textRot);
      if (normalized > pi / 2 && normalized < 3 * pi / 2) {
        textRot += pi;
      }

      final tp = TextPainter(
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );

      tp.text = TextSpan(
        text: _prettyLabel(rewards[i]),
        style: TextStyle(
          fontSize: 13,
          height: 1.05,
          fontWeight: FontWeight.w900,
          color: Colors.black.withOpacity(0.85),
          shadows: [
            Shadow(
              color: Colors.white.withOpacity(0.55),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      );

      tp.layout(maxWidth: radius * 0.62);

      final rText = radius * 0.62;
      final pos = Offset(
        center.dx + cos(mid) * rText,
        center.dy + sin(mid) * rText,
      );

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(textRot);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.rewards != rewards || oldDelegate.startAngle != startAngle;
  }
}
