import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final List<Map<String, dynamic>> friends = [
    {
      'name': 'Alice',
      'status': '在線中',
      'online': true,
      'points': 320,
      'streak': 7,
      'avatarColor': Colors.orangeAccent,
    },
    {
      'name': 'Bob',
      'status': '離線中',
      'online': false,
      'points': 270,
      'streak': 3,
      'avatarColor': Colors.blueAccent,
    },
    {
      'name': 'Carol',
      'status': '在線中',
      'online': true,
      'points': 400,
      'streak': 12,
      'avatarColor': Colors.pinkAccent,
    },
    {
      'name': 'David',
      'status': '離線中',
      'online': false,
      'points': 180,
      'streak': 5,
      'avatarColor': Colors.amber,
    },
    {
      'name': 'Emma',
      'status': '在線中',
      'online': true,
      'points': 350,
      'streak': 9,
      'avatarColor': Colors.deepOrangeAccent,
    },
    {
      'name': 'Ken',
      'status': '在線中',
      'online': true,
      'points': 410,
      'streak': 14,
      'avatarColor': Colors.deepPurpleAccent,
    },
  ];

  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff9fafb),
      appBar: AppBar(
        title: const Text('好友中心'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.8,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orangeAccent,
        child: const Icon(Icons.person_add_alt_1),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('新增好友功能開發中...')),
          );
        },
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 10),
              _buildStoriesRow(),
              const SizedBox(height: 10),
              _buildLeaderboard(),
              const SizedBox(height: 12),
              Expanded(child: _buildFriendList()),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 25,
              gravity: 0.3,
              colors: const [
                Colors.orangeAccent,
                Colors.amber,
                Colors.pinkAccent,
                Colors.blueAccent,
                Colors.green
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =======================================================
  // 搜尋列
  // =======================================================
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜尋好友...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.orangeAccent,
            child: const Icon(Icons.group_add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // =======================================================
  // 好友故事圈
  // =======================================================
  Widget _buildStoriesRow() {
    return SizedBox(
      height: 95,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (_, i) {
          final f = friends[i];
          return Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          f['online']
                              ? Colors.orangeAccent
                              : Colors.grey.shade400,
                          f['online']
                              ? Colors.amber
                              : Colors.grey.shade300,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: f['avatarColor'].withOpacity(0.15),
                      child: Text(
                        f['name'][0],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ),
                  if (f['online'])
                    const Positioned(
                      right: 2,
                      bottom: 2,
                      child: CircleAvatar(
                        radius: 5,
                        backgroundColor: Colors.green,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                f['name'],
                style: const TextStyle(fontSize: 12),
              ),
            ],
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: friends.length,
      ),
    );
  }

  // =======================================================
  // 好友排行榜
  // =======================================================
  Widget _buildLeaderboard() {
    final sorted = [...friends];
    sorted.sort((a, b) => b['points'].compareTo(a['points']));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔥 本週好友排行榜',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          ...List.generate(3, (i) {
            final f = sorted[i];
            final icon = i == 0
                ? Icons.emoji_events
                : i == 1
                    ? Icons.military_tech
                    : Icons.workspace_premium;
            final color = i == 0
                ? Colors.amber
                : i == 1
                    ? Colors.grey
                    : Colors.brown;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon, color: color),
              title: Text(f['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text('${f['points']} pts',
                  style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w600)),
            );
          }),
        ],
      ),
    );
  }

  // =======================================================
  // 好友清單
  // =======================================================
  Widget _buildFriendList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: friends.length,
      itemBuilder: (_, i) {
        final f = friends[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            leading: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: f['avatarColor'].withOpacity(0.15),
                  child: Text(f['name'][0],
                      style: GoogleFonts.notoSansTc(
                          fontWeight: FontWeight.bold,
                          color: f['avatarColor'])),
                ),
                if (f['online'])
                  const Positioned(
                    bottom: 2,
                    right: 2,
                    child: CircleAvatar(
                      radius: 5,
                      backgroundColor: Colors.green,
                    ),
                  ),
              ],
            ),
            title: Text(f['name'],
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(
              children: [
                Text(f['status'],
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(width: 6),
                const Icon(Icons.local_fire_department,
                    color: Colors.orangeAccent, size: 14),
                Text('${f['streak']} 天',
                    style: const TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.w600)),
              ],
            ),
            trailing: ElevatedButton(
              onPressed: () => _openChat(f),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: const Text('發訊息'),
            ),
            onTap: () => _showFriendDetail(f),
          ),
        );
      },
    );
  }

  // =======================================================
  // 好友詳情彈窗
  // =======================================================
  void _showFriendDetail(Map<String, dynamic> f) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: f['avatarColor'].withOpacity(0.15),
              child: Text(f['name'][0],
                  style: TextStyle(
                      color: f['avatarColor'],
                      fontSize: 26,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            Text(f['name'],
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            Text(f['status'],
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionButton(Icons.chat, '聊天', Colors.blue,
                    onTap: () => _openChat(f)),
                _actionButton(Icons.directions_run, '挑戰', Colors.green,
                    onTap: () => _startChallenge(f)),
                _actionButton(Icons.favorite, '鼓勵', Colors.pinkAccent,
                    onTap: () => _sendEncouragement(f)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color,
      {required VoidCallback onTap}) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: CircleAvatar(
            radius: 28,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _openChat(Map<String, dynamic> f) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatPage(friend: f)),
    );
  }

  void _sendEncouragement(Map<String, dynamic> f) {
    Navigator.pop(context);
    _confetti.play();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('已送出鼓勵給 ${f['name']}！'),
      backgroundColor: Colors.green,
    ));
  }

  void _startChallenge(Map<String, dynamic> f) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('已向 ${f['name']} 發出挑戰邀請！'),
      backgroundColor: Colors.orangeAccent,
    ));
  }
}

// =======================================================
// 模擬聊天頁面
// =======================================================
class ChatPage extends StatelessWidget {
  final Map<String, dynamic> friend;
  const ChatPage({super.key, required this.friend});

  @override
  Widget build(BuildContext context) {
    final messages = [
      {'from': 'me', 'text': '嗨 ${friend['name']}！今天運動了嗎？'},
      {'from': 'friend', 'text': '有呀～剛跑完 5 公里！'},
      {'from': 'me', 'text': '太棒了，保持下去！🔥'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(friend['name']),
        backgroundColor: Colors.white,
        elevation: 0.8,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final m = messages[i];
                final isMe = m['from'] == 'me';
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.blueAccent.withOpacity(0.85)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      m['text']!,
                      style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: '輸入訊息...',
                      contentPadding: const EdgeInsets.all(8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.send, color: Colors.blueAccent))
              ],
            ),
          )
        ],
      ),
    );
  }
}
