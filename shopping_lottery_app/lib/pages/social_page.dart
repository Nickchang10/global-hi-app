// lib/pages/social_page.dart
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import 'social_friends_tab.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ConfettiController _confetti;

  bool _todayMissionDone = false;
  String _surveyAnswer = '尚未作答';

  final List<Map<String, dynamic>> _stories = [
    {'name': '我', 'unread': true},
    {'name': 'Alice', 'unread': true},
    {'name': 'Bob', 'unread': false},
    {'name': 'Carol', 'unread': true},
    {'name': 'David', 'unread': true},
    {'name': 'Emma', 'unread': false},
  ];

  final List<Map<String, dynamic>> _posts = [
    {
      'user': '用戶 1',
      'time': '1 小時前',
      'image': 'https://picsum.photos/seed/social1/800/500',
      'likes': 120,
      'content': '示範貼文：Osmile S5 開箱！',
      'liked': false,
      'comments': [
        {'user': 'Alice', 'text': '太酷了！'},
        {'user': 'Bob', 'text': '我也想試！'},
      ],
    },
    {
      'user': '用戶 2',
      'time': '5 小時前',
      'image': 'https://picsum.photos/seed/social2/800/500',
      'likes': 87,
      'content': '今天去郊外走走，順便測試手錶 GPS～',
      'liked': true,
      'comments': [],
    },
  ];

  List<Map<String, dynamic>> get _topPosts {
    final sorted = List<Map<String, dynamic>>.from(_posts);
    sorted.sort((a, b) => (b['likes'] as int).compareTo(a['likes'] as int));
    return sorted.take(3).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _confetti.dispose();
    super.dispose();
  }

  // ------------------- 貼文互動邏輯 -------------------

  void _toggleLike(Map<String, dynamic> post) {
    setState(() {
      post['liked'] = !(post['liked'] as bool);
      post['likes'] += (post['liked'] as bool) ? 1 : -1;
    });
  }

  void _addComment(Map<String, dynamic> post) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('留言', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '輸入留言內容...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                setState(() {
                  (post['comments'] as List).add({'user': '我', 'text': text});
                });
                Navigator.pop(context);
              },
              child: const Text('送出'),
            ),
          ],
        ),
      ),
    );
  }

  void _addNewPost() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('新增貼文', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '分享你今天與 Osmile 的故事...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                setState(() {
                  _posts.insert(0, {
                    'user': '我',
                    'time': '剛剛',
                    'image':
                        'https://picsum.photos/seed/${Random().nextInt(1000)}/800/500',
                    'likes': 0,
                    'content': text,
                    'liked': false,
                    'comments': <Map<String, dynamic>>[],
                  });
                });
                Navigator.pop(context);
                _confetti.play();
              },
              child: const Text('發佈'),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------- UI: 動態分頁 -------------------

  Widget _buildDailyMissionCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFFFFF7E6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.orange,
              child: Icon(Icons.emoji_events, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今日互動挑戰',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '按 5 個讚 + 留一則留言，晚上可獲得小驚喜徽章！',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                setState(() => _todayMissionDone = true);
                _confetti.play();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _todayMissionDone
                    ? Colors.grey
                    : Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: Text(_todayMissionDone ? '已完成' : '去挑戰'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurveyCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.poll_outlined, size: 18),
                SizedBox(width: 6),
                Text(
                  '今日小調查',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('你今天有跟 Osmile 手錶互動了嗎？', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildSurveyChip('有，已記錄運動'),
                _buildSurveyChip('等一下準備要運動'),
                _buildSurveyChip('今天先休息一下'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text(
                  '我的回答：',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(_surveyAnswer, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurveyChip(String label) {
    final selected = _surveyAnswer == label;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => setState(() => _surveyAnswer = label),
      selectedColor: Colors.orange.shade100,
    );
  }

  Widget _buildStoriesRow() {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final story = _stories[index];
          final bool isMe = story['name'] == '我';
          final bool unread = (story['unread'] as bool?) ?? false;

          return GestureDetector(
            onTap: () {
              setState(() => story['unread'] = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('查看 ${story['name']} 的一天（示意）')),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: unread
                        ? const LinearGradient(
                            colors: [Colors.orange, Colors.pink],
                          )
                        : null,
                    border: unread
                        ? null
                        : Border.all(color: Colors.grey, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: isMe ? Colors.blueAccent : Colors.orange,
                    child: isMe
                        ? const Icon(Icons.add, color: Colors.white)
                        : Text(
                            (story['name'] as String)[0],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(story['name'], style: const TextStyle(fontSize: 11)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHashtagRow() {
    const tags = ['#Osmile', '#今日步數', '#親子互動', '#長輩關懷', '#健康打卡'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tags
            .map(
              (t) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(t),
                  onPressed: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('查看 $t 相關貼文（示意）')));
                  },
                  backgroundColor: Colors.grey.shade100,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildRankingSection() {
    final top = _topPosts;
    if (top.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        const Text('🏆 人氣排行榜', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...top.map(
          (p) => ListTile(
            dense: true,
            leading: const Icon(
              Icons.local_fire_department,
              color: Colors.orange,
            ),
            title: Text(p['user']),
            subtitle: Text('讚數：${p['likes']}'),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicTab() {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildDailyMissionCard(),
            const SizedBox(height: 8),
            _buildSurveyCard(),
            const SizedBox(height: 12),
            _buildStoriesRow(),
            const SizedBox(height: 8),
            _buildHashtagRow(),
            const SizedBox(height: 12),
            _buildRankingSection(),
            const SizedBox(height: 8),
            ..._posts.map(
              (p) => _PostCard(
                post: p,
                onLike: () => _toggleLike(p),
                onComment: () => _addComment(p),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirection: pi / 2,
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            maxBlastForce: 20,
            minBlastForce: 5,
            gravity: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTab() {
    final activities = [
      {
        'title': '每日登入獎勵',
        'desc': '簽到可得 5 積分與抽獎券！',
        'icon': Icons.calendar_today,
        'color': Colors.blueAccent,
      },
      {
        'title': '好友互動挑戰',
        'desc': '今日按讚 + 留言 5 次可領徽章！',
        'icon': Icons.emoji_events_outlined,
        'color': Colors.orangeAccent,
      },
      {
        'title': '社群任務：Osmile 一起動起來！',
        'desc': '上傳運動照片可抽神秘禮物 🎁',
        'icon': Icons.fitness_center,
        'color': Colors.green,
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: activities
          .map(
            (a) => Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: a['color'] as Color,
                  child: Icon(a['icon'] as IconData, color: Colors.white),
                ),
                title: Text(
                  a['title'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(a['desc'] as String),
                trailing: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: a['color'] as Color,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('前往'),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('互動'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.dynamic_feed_outlined), text: '動態'),
            Tab(icon: Icon(Icons.people_alt_outlined), text: '好友'),
            Tab(icon: Icon(Icons.emoji_events_outlined), text: '活動'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDynamicTab(),
          const SocialFriendsTab(currentUser: '我'),
          _buildActivityTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewPost,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ------------------- 貼文卡片元件 -------------------

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final VoidCallback onComment;

  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE0ECFF),
                child: Text('用'),
              ),
              title: Text(post['user']),
              subtitle: Text(post['time']),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(post['image'], fit: BoxFit.cover),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    (post['liked'] as bool)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: (post['liked'] as bool) ? Colors.red : null,
                  ),
                  onPressed: onLike,
                ),
                IconButton(
                  icon: const Icon(Icons.mode_comment_outlined),
                  onPressed: onComment,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                '${post['likes']} 個讚',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(post['content']),
            ),
            if ((post['comments'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (post['comments'] as List)
                      .map((c) => Text('${c['user']}: ${c['text']}'))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
