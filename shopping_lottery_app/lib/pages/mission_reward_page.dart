// lib/pages/mission_reward_page.dart
// =====================================================
// ✅ MissionRewardPage（健康任務與積分商城｜完整版｜含未登入狀態）
// -----------------------------------------------------
// - 未登入：可瀏覽任務與兌換商品，但「領取/兌換/紀錄」需登入
// - 已登入：可完成每日任務、累積積分、兌換商品
// - 支援 Web / Android / iOS（無平台依賴）
// =====================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

class MissionRewardPage extends StatefulWidget {
  const MissionRewardPage({super.key});

  @override
  State<MissionRewardPage> createState() => _MissionRewardPageState();
}

class _MissionRewardPageState extends State<MissionRewardPage> {
  // ===== Demo state（你之後可以改成接 HealthService / Firestore）=====
  int userPoints = 120; // 初始積分（登入後顯示/可用）
  bool signedToday = false;
  bool stepTaskDone = false;
  bool sleepTaskDone = false;

  final _fmt = NumberFormat('#,###');

  final List<Map<String, dynamic>> _rewards = [
    {
      'name': 'NT\$100 優惠券',
      'points': 200,
      'image':
          'https://images.unsplash.com/photo-1607082349566-187342175e2e?auto=format&fit=crop&w=600&q=80',
    },
    {
      'name': 'Osmile 積分抽獎券',
      'points': 300,
      'image':
          'https://images.unsplash.com/photo-1525182008055-f88b95ff7980?auto=format&fit=crop&w=600&q=80',
    },
    {
      'name': 'Osmile 運動水壺',
      'points': 500,
      'image':
          'https://images.unsplash.com/photo-1579758629938-03607ccdbaba?auto=format&fit=crop&w=600&q=80',
    },
  ];

  // =====================================================
  // ✅ 未登入提示 + 導去登入
  // =====================================================
  bool _ensureLogin({String message = '請先登入以使用此功能'}) {
    if (!mounted) return false;

    final auth = context.read<AuthService>();
    if (auth.loggedIn) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      Navigator.pushNamed(context, '/login');
    });

    return false;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addPoints(int p, String reason) {
    setState(() => userPoints += p);
    _toast("恭喜獲得 +$p 積分（$reason）");
  }

  void _redeem(Map<String, dynamic> reward) {
    if (!_ensureLogin(message: '登入後才能兌換積分商品')) return;

    final cost = reward['points'] as int;
    if (userPoints < cost) {
      _toast("積分不足，無法兌換。");
      return;
    }
    setState(() => userPoints -= cost);
    _toast("已成功兌換：${reward['name']} 🎉");
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final loggedIn = auth.loggedIn;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          "健康任務與積分商城",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.orangeAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_edu_outlined),
            tooltip: "積分記錄",
            onPressed: () {
              if (!_ensureLogin(message: '登入後才能查看積分記錄')) return;
              _toast("顯示積分變化記錄（模板）");
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (!loggedIn) ...[
            _buildGuestBanner(),
            const SizedBox(height: 12),
          ],
          _buildUserSummary(loggedIn: loggedIn),
          const SizedBox(height: 16),
          _buildMissionSection(loggedIn: loggedIn),
          const SizedBox(height: 18),
          _buildRewardSection(loggedIn: loggedIn),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // =====================================================
  // ✅ 未登入提示 Banner（登入 / 註冊）
  // =====================================================
  Widget _buildGuestBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withOpacity(0.18),
            child: const Icon(Icons.person_outline, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('尚未登入',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
                SizedBox(height: 2),
                Text(
                  '登入後可累積積分、完成任務並兌換商品',
                  style: TextStyle(color: Colors.white70, height: 1.2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, '/register'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.65)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('註冊', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF3B82F6),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('登入', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // 使用者積分摘要卡
  // =====================================================
  Widget _buildUserSummary({required bool loggedIn}) {
    final pointsText = loggedIn ? "${_fmt.format(userPoints)} 分" : "登入後顯示";
    final pointsColor =
        loggedIn ? Colors.orangeAccent : Colors.grey.shade600;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.orangeAccent,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "我的積分",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  pointsText,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: pointsColor,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.local_activity_outlined, size: 18),
            label: const Text("兌換紀錄"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: () {
              if (!_ensureLogin(message: '登入後才能查看兌換紀錄')) return;
              _toast("尚未建立兌換紀錄頁（模板）");
            },
          ),
        ],
      ),
    );
  }

  // =====================================================
  // 每日任務卡區
  // =====================================================
  Widget _buildMissionSection({required bool loggedIn}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "🎯 今日任務",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 10),
        _missionCard(
          title: "每日簽到",
          desc: "連續簽到 7 天可獲加倍獎勵",
          icon: Icons.check_circle_outline,
          done: signedToday,
          reward: 20,
          locked: !loggedIn,
          onTap: () {
            if (!_ensureLogin(message: '登入後才能領取任務積分')) return;
            if (signedToday) {
              _toast("今天已簽到！");
              return;
            }
            setState(() => signedToday = true);
            _addPoints(20, "每日簽到");
          },
        ),
        const SizedBox(height: 10),
        _missionCard(
          title: "走滿 5,000 步",
          desc: "每日步數達標即可領取積分",
          icon: Icons.directions_walk_outlined,
          done: stepTaskDone,
          reward: 30,
          locked: !loggedIn,
          onTap: () {
            if (!_ensureLogin(message: '登入後才能領取任務積分')) return;
            if (stepTaskDone) {
              _toast("已完成今日步數任務！");
              return;
            }
            setState(() => stepTaskDone = true);
            _addPoints(30, "步數達標");
          },
        ),
        const SizedBox(height: 10),
        _missionCard(
          title: "睡眠達 7 小時",
          desc: "良好睡眠可獲健康積分",
          icon: Icons.bedtime_outlined,
          done: sleepTaskDone,
          reward: 25,
          locked: !loggedIn,
          onTap: () {
            if (!_ensureLogin(message: '登入後才能領取任務積分')) return;
            if (sleepTaskDone) {
              _toast("已完成今日睡眠任務！");
              return;
            }
            setState(() => sleepTaskDone = true);
            _addPoints(25, "睡眠達標");
          },
        ),
      ],
    );
  }

  Widget _missionCard({
    required String title,
    required String desc,
    required IconData icon,
    required bool done,
    required int reward,
    required bool locked,
    required VoidCallback onTap,
  }) {
    final bg = done
        ? Colors.green.withOpacity(0.08)
        : (locked ? Colors.grey.withOpacity(0.06) : Colors.white);

    final border = done
        ? Colors.green.withOpacity(0.30)
        : Colors.grey.shade200;

    final iconColor = done
        ? Colors.green
        : (locked ? Colors.grey : Colors.orangeAccent);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (locked) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline,
                                  size: 14, color: Colors.grey),
                              SizedBox(width: 4),
                              Text(
                                '需登入',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style:
                        TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: done
                    ? Colors.green.withOpacity(0.10)
                    : Colors.orangeAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded,
                      color: Colors.orangeAccent, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    "+$reward",
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              done
                  ? Icons.check_circle
                  : (locked ? Icons.chevron_right_rounded : Icons.chevron_right_rounded),
              color: done ? Colors.green : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // 積分兌換商城區
  // =====================================================
  Widget _buildRewardSection({required bool loggedIn}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "🎁 積分兌換商城",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _rewards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (_, i) {
            final r = _rewards[i];
            return Stack(
              children: [
                InkWell(
                  onTap: () => _redeem(r),
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16)),
                            child: Image.network(
                              r['image'],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image_outlined,
                                    color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r['name'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.stars_rounded,
                                      color: Colors.orangeAccent, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${r['points']} 分",
                                    style: const TextStyle(
                                      color: Colors.orangeAccent,
                                      fontWeight: FontWeight.w900,
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
                ),

                // ✅ 未登入：加上鎖定提示（不阻擋點擊，點了會導登入）
                if (!loggedIn)
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline, size: 14, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            '登入兌換',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
