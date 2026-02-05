import 'dart:math';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';

// Providers
import '../providers/notification_provider.dart';
import '../providers/friend_provider.dart';

// Pages
import 'notification_page.dart';
import 'points_store_page.dart';
import 'lucky_bag_event_page.dart';
import 'leaderboard_page.dart';
import 'friend_leaderboard_page.dart';
import 'send_points_page.dart';

// Widgets
import '../widgets/coin_reward_popup.dart';

class EventPlazaPage extends StatefulWidget {
  const EventPlazaPage({super.key});

  @override
  State<EventPlazaPage> createState() => _EventPlazaPageState();
}

class _EventPlazaPageState extends State<EventPlazaPage>
    with SingleTickerProviderStateMixin {
  int myPoints = 350;
  int signInStreak = 0;
  bool hasSignedInToday = false;
  late AnimationController _controller;

  double get todayProgress => hasSignedInToday ? 1.0 : 0.6;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _signInToday() {
    if (hasSignedInToday) return;

    setState(() {
      hasSignedInToday = true;
      signInStreak += 1;
      // 每日 +20，第7天 +100 積分
      if (signInStreak % 7 == 0) {
        myPoints += 100;
      } else {
        myPoints += 20;
      }
    });

    _controller.forward(from: 0);

    String message;
    if (signInStreak % 7 == 0) {
      message = "🎉 已連續簽到 7 天！獲得『限時福袋 +100 積分』！";
    } else {
      final remain = 7 - (signInStreak % 7);
      message = "已連續簽到 $signInStreak 天 🎯 再簽 $remain 天可領福袋 🎁";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CoinRewardPopup(
        points: signInStreak % 7 == 0 ? 100 : 20,
        message: message,
      ),
    );
  }

  void _openPage(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final notify = Provider.of<NotificationProvider>(context);
    final friends = Provider.of<FriendProvider>(context).friends;

    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      appBar: AppBar(
        title: const Text("🎡 活動廣場 Event Plaza"),
        backgroundColor: Colors.pinkAccent,
        centerTitle: true,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () => _openPage(const NotificationPage()),
              ),
              if (notify.unreadCount > 0)
                Positioned(
                  right: 10,
                  top: 10,
                  child: CircleAvatar(
                    radius: 6,
                    backgroundColor: Colors.yellowAccent,
                    child: Text(
                      notify.unreadCount.toString(),
                      style:
                          const TextStyle(fontSize: 9, color: Colors.black87),
                    ),
                  ),
                ),
            ],
          )
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildStreakBoard(),
              const SizedBox(height: 20),
              _buildGridButtons(context),
              const SizedBox(height: 20),
              _buildFriendSummary(friends),
            ],
          ),

          // ✨ 金幣動畫（簽到時觸發）
          if (_controller.isAnimating)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  children: List.generate(12, (i) {
                    final random = Random(i);
                    final dx =
                        random.nextDouble() * MediaQuery.of(context).size.width;
                    final dy =
                        _controller.value * 500 * (0.5 + random.nextDouble());
                    return Positioned(
                      left: dx,
                      top: dy,
                      child: Opacity(
                        opacity: 1 - _controller.value,
                        child: const Icon(Icons.monetization_on,
                            color: Colors.yellowAccent, size: 26),
                      ),
                    );
                  }),
                );
              },
            ),
        ],
      ),
    );
  }

  /// 💰 積分與簽到頭部
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.pinkAccent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.savings, color: Colors.white, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("我的積分",
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text("$myPoints 分",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _signInToday,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hasSignedInToday ? Colors.grey : Colors.orangeAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  hasSignedInToday ? "已簽到" : "簽到領積分",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearPercentIndicator(
            lineHeight: 10.0,
            percent: todayProgress,
            backgroundColor: Colors.white24,
            progressColor: Colors.yellowAccent,
            animation: true,
            barRadius: const Radius.circular(8),
          ),
          const SizedBox(height: 8),
          Text(
            hasSignedInToday
                ? "今日簽到完成 ✅"
                : "再簽 ${7 - (signInStreak % 7)} 天可領福袋 🎁",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// 🗓️ 七天簽到進度板
  Widget _buildStreakBoard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Text("📅 本週簽到進度",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final day = i + 1;
              final signed = day <= (signInStreak % 7);
              final isReward = day == 7;
              return Column(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        signed ? Colors.pinkAccent : Colors.grey.shade300,
                    child: isReward
                        ? const Icon(Icons.card_giftcard,
                            color: Colors.white, size: 20)
                        : Text(
                            "Day\n$day",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isReward ? "福袋" : signed ? "✔️" : "",
                    style: TextStyle(
                        fontSize: 11,
                        color: isReward
                            ? Colors.orangeAccent
                            : signed
                                ? Colors.pinkAccent
                                : Colors.grey),
                  )
                ],
              );
            }),
          )
        ],
      ),
    );
  }

  /// 🎯 主要活動功能卡
  Widget _buildGridButtons(BuildContext context) {
    final List<Map<String, dynamic>> cards = [
      {
        "title": "積分商城",
        "icon": Icons.store,
        "color": Colors.blueAccent,
        "page": const PointsStorePage()
      },
      {
        "title": "限時福袋",
        "icon": Icons.card_giftcard,
        "color": Colors.orangeAccent,
        "page": LuckyBagEventPage(
          currentPoints: myPoints,
          onPointsUpdate: (add) => setState(() => myPoints += add),
        )
      },
      {
        "title": "排行榜",
        "icon": Icons.emoji_events,
        "color": Colors.purpleAccent,
        "page": const LeaderboardPage(),
      },
      {
        "title": "好友排行",
        "icon": Icons.people_alt,
        "color": Colors.teal,
        "page": const FriendLeaderboardPage(),
      },
      {
        "title": "積分互贈",
        "icon": Icons.favorite,
        "color": Colors.redAccent,
        "page": const SendPointsPage(),
      },
    ];

    return GridView.builder(
      itemCount: cards.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, i) {
        final c = cards[i];
        return InkWell(
          onTap: () => _openPage(c["page"]),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: c["color"],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: c["color"].withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(c["icon"], size: 50, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  c["title"],
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 👥 好友積分摘要
  Widget _buildFriendSummary(List friends) {
    if (friends.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("👥 好友積分狀況",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          ...friends.take(3).map((f) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(f.name,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text("${f.points} 分",
                      style: const TextStyle(color: Colors.pinkAccent)),
                ],
              ),
            );
          })
        ],
      ),
    );
  }
}
