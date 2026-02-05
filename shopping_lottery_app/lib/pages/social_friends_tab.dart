// lib/pages/social_friends_tab.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'chat_page.dart';

class SocialFriendsTab extends StatefulWidget {
  final String currentUser;
  const SocialFriendsTab({super.key, required this.currentUser});

  @override
  State<SocialFriendsTab> createState() => _SocialFriendsTabState();
}

class _SocialFriendsTabState extends State<SocialFriendsTab>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  /// 好友資料：可以之後接後端 API 換成真實資料
  final List<Map<String, dynamic>> _friends = [
    {
      'name': 'Alice',
      'online': true,
      'lastSeen': '剛剛上線',
      'interests': <String>['跑步', '攝影'],
      'posts': 23,
    },
    {
      'name': 'Bob',
      'online': false,
      'lastSeen': '30 分鐘前',
      'interests': <String>['音樂', '露營'],
      'posts': 12,
    },
    {
      'name': 'Carol',
      'online': true,
      'lastSeen': '2 分鐘前',
      'interests': <String>['健身', '旅遊'],
      'posts': 34,
    },
    {
      'name': 'David',
      'online': false,
      'lastSeen': '1 小時前',
      'interests': <String>['科技', '閱讀'],
      'posts': 19,
    },
    {
      'name': 'Emma',
      'online': true,
      'lastSeen': '剛剛上線',
      'interests': <String>['舞蹈', '咖啡'],
      'posts': 42,
    },
  ];

  Timer? _timer;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _simulateOnline();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  /// 模擬好友在線 / 離線狀態變化
  void _simulateOnline() {
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      setState(() {
        for (final f in _friends) {
          f['online'] = Random().nextBool();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 依搜尋字串過濾好友
  List<Map<String, dynamic>> get _filteredFriends {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _friends;
    return _friends
        .where((f) =>
            (f['name'] as String).toLowerCase().contains(query))
        .toList();
  }

  /// 單一好友卡片（頭像 + 在線點 + 標籤 + 聊天／語音）
  Widget _buildFriendCard(Map<String, dynamic> f, int index) {
    final String name = f['name'] as String;
    final bool online = f['online'] as bool;
    final String lastSeen = f['lastSeen'] as String;
    final List<String> interests =
        (f['interests'] as List).map((e) => e.toString()).toList();

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animController,
        curve: Interval(
          _friends.isEmpty ? 0 : index / _friends.length,
          1,
          curve: Curves.easeOut,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.orange,
                child: Text(
                  name[0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: online ? Colors.green : Colors.grey,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontSize: 13)),
          Text(
            lastSeen,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline,
                    color: Colors.blueAccent),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        currentUser: widget.currentUser,
                        friendName: name,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.mic_none, color: Colors.redAccent),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('與 $name 語音通話中（示意）'),
                    ),
                  );
                },
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: interests
                .map(
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      i,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 推薦好友區塊
  Widget _buildRecommendedSection() {
    final List<Map<String, dynamic>> rec = [
      {'name': 'Fiona', 'mutual': 2},
      {'name': 'George', 'mutual': 1},
      {'name': 'Hank', 'mutual': 3},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text(
          '推薦好友',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        ...rec.map(
          (n) {
            final String name = n['name'] as String;
            final int mutual = n['mutual'] as int;
            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(name),
                subtitle: Text('$mutual 位共同好友'),
                trailing: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已追蹤 $name（示意）')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blueAccent,
                    side: const BorderSide(color: Colors.blueAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('追蹤'),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> onlineFriends =
        _filteredFriends.where((f) => f['online'] as bool).toList();
    final List<Map<String, dynamic>> offlineFriends =
        _filteredFriends.where((f) => !(f['online'] as bool)).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 搜尋列
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '搜尋好友...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),

        // 在線好友
        const Text(
          '在線好友',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (onlineFriends.isEmpty)
          const Text(
            '目前沒有在線好友',
            style: TextStyle(color: Colors.grey),
          )
        else
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: onlineFriends
                .asMap()
                .entries
                .map((e) => _buildFriendCard(e.value, e.key))
                .toList(),
          ),

        const SizedBox(height: 20),

        // 離線好友
        const Text(
          '離線好友',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (offlineFriends.isEmpty)
          const Text(
            '太棒了，所有好友都在線上！',
            style: TextStyle(color: Colors.grey),
          )
        else
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: offlineFriends
                .asMap()
                .entries
                .map((e) => _buildFriendCard(e.value, e.key))
                .toList(),
          ),

        const SizedBox(height: 24),

        // 推薦好友
        _buildRecommendedSection(),
      ],
    );
  }
}
