// lib/pages/community_hub_page.dart
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import 'product_detail_page.dart';

class CommunityHubPage extends StatefulWidget {
  const CommunityHubPage({super.key});

  @override
  State<CommunityHubPage> createState() => _CommunityHubPageState();
}

class _CommunityHubPageState extends State<CommunityHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Live demo data
  final List<Map<String, dynamic>> _liveSeed = [
    {
      'id': 'l1',
      'title': 'Osmile 新品直播',
      'host': 'Alice',
      'start': null,
      'timeLabel': '今晚 19:30',
      'category': '新品',
      'image': 'https://picsum.photos/seed/live1/1200/600',
      'isLive': true,
      'reminded': false,
      'viewers': 1250,
      'favorited': false,
      'hostFollowed': false,
      'featured': true,
    },
    {
      'id': 'l2',
      'title': '健身穿搭 & 測評',
      'host': 'Bob',
      'start': DateTime.now().add(const Duration(hours: 20)),
      'timeLabel': '明晚 20:00',
      'category': '運動',
      'image': 'https://picsum.photos/seed/live2/1200/600',
      'isLive': false,
      'reminded': false,
      'viewers': 0,
      'favorited': false,
      'hostFollowed': false,
      'featured': false,
    },
  ];
  late List<Map<String, dynamic>> _liveItems;
  final Map<String, ValueNotifier<List<Map<String, dynamic>>>> _liveChatNotifiers =
      {};

  Timer? _tickTimer;
  late ScrollController _liveScrollController;
  bool _isLoadingMore = false;
  final Random _rand = Random();

  // Community
  String _searchQuery = '';
  String _sortMode = '最新';
  String _selectedFilter = '全部';
  final List<String> _postFilters = ['全部', '官方', '朋友'];

  // Shop / Posts / Stories / Friends demo
  final List<Map<String, dynamic>> _shopItems = [
    {
      'id': 'p1',
      'name': 'Osmile S5 智慧手錶',
      'price': 2990,
      'image': 'https://picsum.photos/seed/prod1/600/400',
      'seller': 'Osmile 官方'
    },
    {
      'id': 'p2',
      'name': '運動藍牙耳機',
      'price': 1280,
      'image': 'https://picsum.photos/seed/prod2/600/400',
      'seller': '電子小舖'
    },
    {
      'id': 'p3',
      'name': '專業慢跑鞋',
      'price': 2590,
      'image': 'https://picsum.photos/seed/prod3/600/400',
      'seller': '運動達人'
    },
  ];

  final List<Map<String, dynamic>> _posts = [
    {
      'id': 1001,
      'author': '小明',
      'avatarColor': Colors.orange,
      'timeLabel': '昨天',
      'tag': '開箱',
      'content': '剛收到 Osmile S5，睡眠偵測真的超準 🔥',
      'image': 'https://picsum.photos/seed/post2/900/500',
      'imageBytes': null,
      'likes': 64,
      'comments': [
        {'user': 'David', 'text': '真的不錯，我也買一隻！'},
      ],
      'liked': false,
      'followed': false,
      'bookmarked': false,
      '_expanded': false,
      'product': {
        'id': 'p1',
        'name': 'Osmile S5 智慧手錶',
        'price': 2990,
        'image': 'https://picsum.photos/seed/prod1/600/400',
        'seller': 'Osmile 官方'
      }
    },
    {
      'id': 1002,
      'author': 'Osmile 官方',
      'avatarColor': Colors.blue,
      'timeLabel': '3 小時前',
      'tag': '公告',
      'content': '本週直播下單享 95 折，抽獎券加倍送，記得開啟小鈴鐺避免錯過～',
      'image': 'https://picsum.photos/seed/post1/900/500',
      'imageBytes': null,
      'likes': 128,
      'comments': [
        {'user': '小美', 'text': '超棒！'},
      ],
      'liked': false,
      'followed': true,
      'bookmarked': false,
      '_expanded': false,
    },
  ];

  final List<Map<String, dynamic>> _stories = [
    {'name': '小美', 'color': Colors.purple},
    {'name': 'David', 'color': Colors.blue},
    {'name': '阿宏', 'color': Colors.teal},
    {'name': '小明', 'color': Colors.orange},
    {'name': 'Osmile', 'color': Colors.indigo},
  ];

  final List<Map<String, dynamic>> _friends = [
    {'name': '小美', 'status': '正在看直播', 'online': true, 'avatarColor': Colors.purple},
    {'name': 'David', 'status': '剛買了 Osmile S5', 'online': true, 'avatarColor': Colors.blue},
    {'name': '阿宏', 'status': '上次抽獎中大獎 🎁', 'online': false, 'avatarColor': Colors.teal},
  ];

  // friends UI
  final TextEditingController _friendsSearchController = TextEditingController();
  String _friendViewFilter = '全部';
  final List<String> _friendViewFilters = ['全部', '在線', '最近', '建議'];

  List<Map<String, dynamic>> _friendRequests = [
    {'name': '小艾', 'avatarColor': Colors.pink, 'message': '想加你為好友', 'time': '1 小時前'}
  ];

  List<Map<String, dynamic>> _suggestedFriends = [
    {'name': '小華', 'avatarColor': Colors.teal, 'reason': '追蹤了相同商店'},
    {'name': '小王', 'avatarColor': Colors.green, 'reason': '你們有共同好友 David'}
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
    _friendsSearchController.addListener(() => setState(() {}));

    _liveItems = List<Map<String, dynamic>>.from(_liveSeed);
    for (var l in _liveItems) {
      final id = (l['id'] as Object?)?.toString() ?? '';
      _liveChatNotifiers[id] = ValueNotifier<List<Map<String, dynamic>>>([
        {'user': l['host'], 'text': '大家好，歡迎來到直播！'},
        {'user': '小美', 'text': '期待今天的優惠～'},
      ]);
    }

    _liveScrollController = ScrollController()..addListener(_onLiveScroll);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _liveScrollController.removeListener(_onLiveScroll);
    _liveScrollController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _friendsSearchController.dispose();
    for (var v in _liveChatNotifiers.values) v.dispose();
    super.dispose();
  }

  // ---------- helpers ----------
  void _onLiveScroll() {
    if (_liveScrollController.position.pixels >=
            _liveScrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore) {
      _loadMoreLives();
    }
  }

  Future<void> _loadMoreLives() async {
    _isLoadingMore = true;
    await Future.delayed(const Duration(milliseconds: 700));
    final base = _liveItems.length;
    final newItems = List<Map<String, dynamic>>.generate(5, (i) {
      final id = 'gen-${base + i}';
      final isLive = _rand.nextBool() && _rand.nextInt(3) == 0;
      final host = 'Host${base + i}';
      final startTime = DateTime.now().add(Duration(minutes: 30 + _rand.nextInt(300)));
      return {
        'id': id,
        'title': '更多直播 #${base + i + 1}',
        'host': host,
        'start': isLive ? null : startTime,
        'timeLabel': isLive ? '直播中' : '預定 ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}',
        'category': ['新品', '運動', '3C'][_rand.nextInt(3)],
        'image': 'https://picsum.photos/seed/gen${base + i}/1200/600',
        'isLive': isLive,
        'reminded': false,
        'viewers': isLive ? 100 + _rand.nextInt(2000) : 0,
        'favorited': false,
        'hostFollowed': false,
        'featured': false,
      };
    });
    setState(() {
      _liveItems.addAll(newItems);
      for (var n in newItems) {
        final nid = (n['id'] as Object?)?.toString() ?? '';
        _liveChatNotifiers[nid] = ValueNotifier<List<Map<String, dynamic>>>([
          {'user': n['host'], 'text': 'Hi，我是 ${n['host']}，準備中...'},
        ]);
      }
    });
    _isLoadingMore = false;
  }

  void _onTick() {
    final now = DateTime.now();
    bool changed = false;
    for (var live in _liveItems) {
      final id = (live['id'] as Object?)?.toString() ?? '';
      final start = live['start'] as DateTime?;
      if (start != null && start.isBefore(now) && live['isLive'] != true) {
        live['isLive'] = true;
        live['viewers'] = 200 + _rand.nextInt(3000);
        changed = true;
      }
      if (live['isLive'] == true) {
        final int viewers = live['viewers'] as int;
        final delta = (_rand.nextInt(21) - 10);
        live['viewers'] = max(0, viewers + delta);
        changed = true;
        if (_rand.nextDouble() < 0.35) {
          final user = ['小美', 'David', '阿宏', 'Tom', '小紅', '小明'][_rand.nextInt(6)];
          final texts = [
            '好精彩！',
            '折扣是多少？',
            '主持人介紹一下功能',
            '有人知道型號嗎？',
            '直播連線好穩！',
            '我剛下單～'
          ];
          final text = texts[_rand.nextInt(texts.length)];
          final v = _liveChatNotifiers[id];
          if (v != null) {
            final newList = List<Map<String, dynamic>>.from(v.value);
            newList.add({'user': user, 'text': text});
            if (newList.length > 200) newList.removeRange(0, newList.length - 200);
            v.value = newList;
          }
        }
      }
    }
    if (changed && mounted) setState(() {});
  }

  String _viewerLabel(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
    return v.toString();
  }

  String _formatTimeLabel(Map<String, dynamic> live) {
    if (live['isLive'] == true) return '直播中';
    final start = live['start'] as DateTime?;
    if (start == null) return live['timeLabel'] ?? '';
    final now = DateTime.now();
    if (start.isBefore(now)) return live['timeLabel'] ?? '';
    final diff = start.difference(now);
    if (diff.inHours > 24) {
      return '${start.month}/${start.day} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    } else if (diff.inHours >= 1) {
      return '剩 ${diff.inHours} 小時';
    } else {
      return '剩 ${diff.inMinutes} 分鐘';
    }
  }

  List<Map<String, dynamic>> _getFilteredPosts() {
    final q = _searchQuery.toLowerCase();
    final list = _posts.where((p) {
      if (_selectedFilter == '官方' && p['author'] != 'Osmile 官方') return false;
      if (_selectedFilter == '朋友' && p['followed'] != true) return false;
      if (q.isEmpty) return true;
      if ((p['author'] as String).toLowerCase().contains(q)) return true;
      if ((p['content'] as String).toLowerCase().contains(q)) return true;
      if ((p['tag'] as String).toLowerCase().contains(q)) return true;
      if (p.containsKey('product') &&
          (p['product']['name'] as String).toLowerCase().contains(q)) {
        return true;
      }
      return false;
    }).toList();

    if (_sortMode == '熱門') {
      list.sort((a, b) => (b['likes'] as int).compareTo(a['likes'] as int));
    } else {
      list.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    }
    return list;
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final notifier = context.read<NotificationService>();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('互動中心'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: '直播'), Tab(text: '社群'), Tab(text: '好友')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLiveTab(notifier),
          _buildCommunityTab(notifier),
          _buildFriendsTab(notifier),
        ],
      ),
      floatingActionButton: (_tabController.index == 1)
          ? FloatingActionButton.extended(
              backgroundColor: Colors.orangeAccent,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('發佈貼文'),
              onPressed: () => _openPostComposer(context, notifier),
            )
          : null,
    );
  }

  // ---------------- Live tab UI ----------------
  Widget _buildLiveTab(NotificationService notifier) {
    List<Map<String, dynamic>> list = List.from(_liveItems);
    if (_sortMode == '熱門') {
      list.sort((a, b) => (b['viewers'] as int).compareTo(a['viewers'] as int));
    } else {
      list.sort((a, b) {
        final fa = (a['featured'] == true) ? 1 : 0;
        final fb = (b['featured'] == true) ? 1 : 0;
        return fb - fa;
      });
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 400));
        setState(() {});
      },
      child: ListView(
        controller: _liveScrollController,
        padding: const EdgeInsets.all(12),
        children: [
          Row(children: [
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration:
                    BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.search, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(hintText: '搜尋直播主或標題', border: InputBorder.none, isDense: true),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 1),
              onPressed: () {
                setState(() {
                  _sortMode = _sortMode == '最新' ? '熱門' : (_sortMode == '熱門' ? '即將' : '最新');
                });
              },
              icon: const Icon(Icons.sort, size: 18),
              label: Text(_sortMode),
            ),
          ]),
          const SizedBox(height: 12),

          if (list.where((l) => l['featured'] == true).isNotEmpty)
            SizedBox(
              height: 180,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                scrollDirection: Axis.horizontal,
                itemCount: list.where((l) => l['featured'] == true).length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, idx) {
                  final featured = list.where((l) => l['featured'] == true).toList()[idx];
                  final fid = (featured['id'] as Object?)?.toString() ?? '';
                  return GestureDetector(
                    onTap: () {
                      if (featured['isLive'] == true) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LivePlayerPage(
                              liveId: fid,
                              title: featured['title'] as String,
                              host: featured['host'] as String,
                              image: featured['image'] as String,
                              chatNotifier: _liveChatNotifiers[fid]!,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${featured['title']} 即將於 ${featured['timeLabel']} 開播（示範）')));
                      }
                    },
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      clipBehavior: Clip.antiAlias,
                      elevation: 3,
                      child: Stack(children: [
                        Image.network(featured['image'] as String, width: 320, height: 180, fit: BoxFit.cover),
                        Positioned(
                          left: 12,
                          bottom: 12,
                          right: 12,
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)), child: Text(featured['category'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12))),
                                const SizedBox(height: 6),
                                Text(featured['title'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  CircleAvatar(radius: 10, backgroundColor: Colors.white, child: Text((featured['host'] as String).substring(0, 1))),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text('主持人：${featured['host']} · ${_formatTimeLabel(featured)}', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                ]),
                              ]),
                            ),
                            if (featured['isLive'] == true)
                              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.fiber_manual_record, color: Colors.white, size: 12), const SizedBox(width: 6), Text('${_viewerLabel(featured['viewers'] as int)}', style: const TextStyle(color: Colors.white))])),
                          ]),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 14),

          ...list.map((live) {
            final isLive = live['isLive'] == true;
            final id = (live['id'] as Object?)?.toString() ?? '';
            final chatNotifier = _liveChatNotifiers[id]!;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              elevation: 2,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Stack(children: [
                  Image.network(live['image'] as String, width: double.infinity, height: 180, fit: BoxFit.cover),
                  Positioned(left: 12, top: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isLive ? Colors.redAccent : Colors.orangeAccent, borderRadius: BorderRadius.circular(20)), child: Text(isLive ? '直播中' : '即將開播', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)))),
                  Positioned(right: 12, top: 12, child: Row(children: [
                    IconButton(icon: Icon((live['favorited'] == true) ? Icons.favorite : Icons.favorite_border, color: Colors.pink), onPressed: () => setState(() => live['favorited'] = !(live['favorited'] == true))),
                    IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () {
                      Clipboard.setData(ClipboardData(text: '來看看：${live['title']}'));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製直播分享文字（示範）')));
                    }),
                  ])),
                ]),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(live['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        Row(children: [
                          CircleAvatar(radius: 12, backgroundColor: Colors.white, child: Text((live['host'] as String).substring(0, 1))),
                          const SizedBox(width: 8),
                          Expanded(child: Text('主持人：${live['host']} · ${_formatTimeLabel(live)}', style: const TextStyle(color: Colors.grey))),
                        ]),
                      ]),
                    ),
                    Column(children: [
                      Text('${live['category']}', style: const TextStyle(color: Colors.blueAccent)),
                      const SizedBox(height: 6),
                      if (isLive)
                        Row(children: [const Icon(Icons.remove_red_eye, size: 18, color: Colors.grey), const SizedBox(width: 6), Text(_viewerLabel(live['viewers'] as int))])
                      else
                        IconButton(
                          icon: Icon(live['reminded'] == true ? Icons.notifications_active : Icons.notifications_none,
                              color: live['reminded'] == true ? Colors.blue : Colors.grey),
                          onPressed: () {
                            if (live['reminded'] == true) return;
                            setState(() => live['reminded'] = true);
                            context.read<NotificationService>().addNotification(type: '互動', title: '直播提醒', message: '${live['title']} 將於 ${live['timeLabel']} 開始');
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已設定提醒：${live['title']}')));
                          },
                        ),
                    ])
                  ]),
                ),

                // small chat preview
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                        child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                          valueListenable: chatNotifier,
                          builder: (_, value, __) {
                            final preview = value.length <= 2 ? value : value.sublist(max(0, value.length - 2));
                            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: preview.map((m) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${m['user']}: ${m['text']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))).toList());
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => LivePlayerPage(
                            liveId: id,
                            title: live['title'] as String,
                            host: live['host'] as String,
                            image: live['image'] as String,
                            chatNotifier: chatNotifier,
                          )));
                        },
                        icon: Icon(isLive ? Icons.play_circle_fill : Icons.play_arrow),
                        label: Text(isLive ? '立即觀看' : (live['reminded'] == true ? '已提醒' : '提醒我')),
                      ),
                      const SizedBox(height: 6),
                      TextButton(onPressed: () {
                        setState(() => live['hostFollowed'] = !(live['hostFollowed'] == true));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text((live['hostFollowed'] == true) ? '已追蹤 ${live['host']}' : '取消追蹤 ${live['host']}')));
                      }, child: Text(live['hostFollowed'] == true ? '已追蹤' : '追蹤主持人'))
                    ])
                  ]),
                ),
              ]),
            );
          }).toList(),

          if (_isLoadingMore) ...[
            const SizedBox(height: 8),
            Center(child: CircularProgressIndicator.adaptive()),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  // ---------------- Community tab UI ----------------
  Widget _buildCommunityTab(NotificationService notifier) {
    final posts = _getFilteredPosts();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            padding: const EdgeInsets.all(12),
            decoration:
                BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.03), blurRadius: 6)]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: const Color(0xFFF6F7F9), borderRadius: BorderRadius.circular(22)),
                    child: Row(children: [
                      const Icon(Icons.search, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: _searchController, decoration: const InputDecoration(hintText: '搜尋作者、內容或標籤', border: InputBorder.none, isDense: true))),
                      if (_searchQuery.isNotEmpty) GestureDetector(onTap: () => setState(() => _searchController.clear()), child: const Icon(Icons.close, size: 18, color: Colors.grey)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 1,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _sortMode = _sortMode == '最新' ? '熱門' : '最新'),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Row(children: [const Icon(Icons.filter_list, size: 18, color: Colors.grey), const SizedBox(width: 6), Text(_sortMode)])),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: _postFilters.length,
                  itemBuilder: (_, i) {
                    final label = _postFilters[i];
                    final active = _selectedFilter == label;
                    return ChoiceChip(
                      label: Text(label),
                      selected: active,
                      onSelected: (_) => setState(() => _selectedFilter = label),
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(color: active ? Colors.white : Colors.black87, fontWeight: active ? FontWeight.bold : FontWeight.normal),
                      backgroundColor: const Color(0xFFF3F4F6),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),

        // stories
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration:
                BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.02), blurRadius: 6)]),
            child: SizedBox(
              height: 92,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                scrollDirection: Axis.horizontal,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemCount: _stories.length,
                itemBuilder: (_, i) {
                  final s = _stories[i];
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    GestureDetector(
                      onTap: () => _openStoryViewer(context, s),
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.pink.shade400, Colors.orange.shade400]), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.06), blurRadius: 6)]),
                        child: Padding(
                          padding: const EdgeInsets.all(3.5),
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: CircleAvatar(backgroundColor: s['color'] as Color, child: Text((s['name'] as String).substring(0, 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(width: 72, child: Text(s['name'], textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                  ]);
                },
              ),
            ),
          ),
        ),

        // product carousel
        SliverToBoxAdapter(
          child: SizedBox(
            height: 120,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: _shopItems.length,
              itemBuilder: (_, i) {
                final p = _shopItems[i];
                return SizedBox(
                  width: 220,
                  child: LayoutBuilder(builder: (context, constraints) {
                    final maxH = constraints.maxHeight > 0 ? constraints.maxHeight : 120.0;
                    final imageH = (maxH * 0.45).clamp(40.0, 72.0);
                    final bottomAvailable = maxH - imageH;
                    return Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: imageH, width: double.infinity, child: Image.network(p['image'] as String, fit: BoxFit.cover)),
                          SizedBox(
                            height: bottomAvailable,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(p['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                  ),
                                  Row(children: [
                                    Text('NT\$${p['price']}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                    const Spacer(),
                                    SizedBox(
                                      height: 28,
                                      child: ElevatedButton(onPressed: () => _openProductDetail(context, p), style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)), child: const Text('購買', style: TextStyle(fontSize: 12))),
                                    ),
                                  ]),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),

        // posts list
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final post = _getFilteredPosts()[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _postCard(post, context.read<NotificationService>()),
              );
            },
            childCount: _getFilteredPosts().length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _postCard(Map<String, dynamic> post, NotificationService notifier) {
    post['_expanded'] ??= false;
    post['bookmarked'] ??= false;

    final List<Map<String, dynamic>> commentsList = List<Map<String, dynamic>>.from(post['comments'] as List<dynamic>);
    final preview = commentsList.length > 2 ? commentsList.sublist(0, 2) : commentsList;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            GestureDetector(
              onTap: () => _openUserProfileSheet(context, post['author'] as String, post['avatarColor'] as Color),
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.05), blurRadius: 4)]),
                child: CircleAvatar(backgroundColor: post['avatarColor'] as Color, radius: 22, child: Text((post['author'] as String).substring(0, 1), style: const TextStyle(color: Colors.white, fontSize: 18))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Text(post['author'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(width: 8),
                  if (post['tag'] != null)
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)), child: Text(post['tag'] as String, style: const TextStyle(color: Colors.blue, fontSize: 11))),
                  const SizedBox(width: 6),
                  if (post['author'] == 'Osmile 官方')
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)), child: const Text('商店', style: TextStyle(color: Colors.green, fontSize: 11))),
                ]),
                const SizedBox(height: 4),
                Text(post['timeLabel'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
            TextButton(
              onPressed: () {
                setState(() => post['followed'] = !(post['followed'] == true));
                if (post['followed'] == true) {
                  notifier.addNotification(type: '互動', title: '已追蹤 ${post['author']}', message: '將提醒他的貼文與直播');
                }
              },
              child: Text((post['followed'] == true) ? '已追蹤' : '追蹤', style: TextStyle(color: (post['followed'] == true) ? Colors.grey : Colors.blue)),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'bookmark') {
                  setState(() => post['bookmarked'] = !(post['bookmarked'] == true));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(post['bookmarked'] == true ? '已加入收藏' : '已從收藏移除')));
                } else if (v == 'share') {
                  await Clipboard.setData(ClipboardData(text: post['content'] as String));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製分享內容')));
                } else if (v == 'edit' && post['author'] == '我') {
                  _openCreateOrEditPostSheet(context, notifier, post: post);
                } else if (v == 'delete' && post['author'] == '我') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('刪除貼文'),
                      content: const Text('確定要刪除此貼文？'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    setState(() => _posts.removeWhere((p) => p['id'] == post['id']));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('貼文已刪除')));
                  }
                } else if (v == 'view_shop') {
                  _openShopPage(context, post['author'] as String);
                } else if (v == 'report') {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已回報，感謝回饋')));
                }
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                PopupMenuItem(value: 'bookmark', child: Text((post['bookmarked'] == true) ? '取消收藏' : '加入收藏')),
                const PopupMenuItem(value: 'share', child: Text('分享')),
                if (post['author'] == '我') const PopupMenuItem(value: 'edit', child: Text('編輯')),
                if (post['author'] == '我') const PopupMenuItem(value: 'delete', child: Text('刪除')),
                const PopupMenuItem(value: 'view_shop', child: Text('查看商店')),
                if (post['author'] != '我') const PopupMenuItem(value: 'report', child: Text('回報')),
              ],
            ),
          ]),
        ),

        if ((post['content'] as String).isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(post['content'] as String, maxLines: post['_expanded'] ? null : 3, overflow: post['_expanded'] ? TextOverflow.visible : TextOverflow.ellipsis, style: const TextStyle(height: 1.45)),
              if ((post['content'] as String).length > 80)
                GestureDetector(onTap: () => setState(() => post['_expanded'] = !(post['_expanded'] as bool)), child: Padding(padding: const EdgeInsets.only(top: 6.0), child: Text(post['_expanded'] ? '收合內容' : '顯示更多', style: const TextStyle(color: Colors.blueAccent)))),
            ]),
          ),

        if (post['imageBytes'] != null)
          Padding(padding: const EdgeInsets.all(12), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(post['imageBytes'] as Uint8List, width: double.infinity, height: 220, fit: BoxFit.cover)))
        else if ((post['image'] as String).isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityPostDetailPage(post: Map<String, dynamic>.from(post), onLikeToggle: () => _toggleLike(post)))),
              child: Hero(tag: 'post-image-${post['id']}', child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(post['image'] as String, width: double.infinity, height: 220, fit: BoxFit.cover))),
            ),
          ),

        if (post.containsKey('product') && post['product'] != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(post['product']['image'] as String, width: 86, height: 86, fit: BoxFit.cover)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(post['product']['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('NT\$${post['product']['price']}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(children: [
                    ElevatedButton(onPressed: () => _openProductDetail(context, post['product']), style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent), child: const Text('查看/購買')),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: () => _addToCart(post['product']), child: const Text('加入購物車')),
                  ]),
                ])),
              ]),
            ),
          ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            InkWell(onTap: () => _toggleLike(post), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: Row(children: [
              Icon((post['liked'] == true) ? Icons.favorite : Icons.favorite_border, size: 20, color: (post['liked'] == true) ? Colors.pink : Colors.grey[700]),
              const SizedBox(width: 6),
              Text('${post['likes'] ?? 0}', style: TextStyle(color: (post['liked'] == true) ? Colors.pink : Colors.grey[700])),
            ]))),
            const SizedBox(width: 10),
            InkWell(onTap: () => _openCommentSheet(context, context.read<NotificationService>(), post), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: Row(children: [
              const Icon(Icons.mode_comment_outlined, size: 20, color: Colors.grey),
              const SizedBox(width: 6),
              Text('${(post['comments'] as List).length}', style: const TextStyle(color: Colors.grey)),
            ]))),
            const Spacer(),
            if (preview.isNotEmpty)
              Row(children: preview.take(3).map((c) => Padding(padding: const EdgeInsets.only(left: 6.0), child: CircleAvatar(radius: 10, backgroundColor: Colors.grey.shade200, child: Text((c['user'] as String).substring(0, 1), style: const TextStyle(fontSize: 10))))).toList()),
            IconButton(onPressed: () {
              setState(() => post['bookmarked'] = !(post['bookmarked'] == true));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text((post['bookmarked'] == true) ? '已加入收藏' : '已從收藏移除')));
            }, icon: Icon((post['bookmarked'] == true) ? Icons.bookmark : Icons.bookmark_border, color: Colors.grey[700])),
            IconButton(icon: const Icon(Icons.share_outlined, color: Colors.grey), onPressed: () async {
              await Clipboard.setData(ClipboardData(text: post['content'] as String));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製分享內容')));
            }),
          ]),
        ),

        if (preview.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              for (var c in preview)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(radius: 12, child: Text((c['user'] as String).substring(0, 1), style: const TextStyle(fontSize: 12))),
                  const SizedBox(width: 8),
                  Expanded(child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87), children: [TextSpan(text: '${c['user']}: ', style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: c['text'])]))),
                ])),
              if ((post['comments'] as List).length > 2)
                Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityPostDetailPage(post: Map<String, dynamic>.from(post), onLikeToggle: () => _toggleLike(post)))), child: const Text('查看全部留言', style: TextStyle(color: Colors.blueAccent)))),
            ]),
          ),
      ]),
    );
  }

  // ---------------- Post composer simplified ----------------
  Future<void> _openPostComposer(BuildContext ctx, NotificationService notifier) async {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) {
        return Padding(
          padding: EdgeInsets.only(left: 12, right: 12, top: 12, bottom: MediaQuery.of(c).viewInsets.bottom + 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [const Text('發佈', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(c))]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _composerActionButton(Icons.camera_alt, '限動', () {
                Navigator.pop(c);
                _openCreateStorySheet(ctx, notifier);
              }),
              _composerActionButton(Icons.post_add, '貼文', () {
                Navigator.pop(c);
                _openCreateOrEditPostSheet(ctx, notifier);
              }),
              _composerActionButton(Icons.video_call, '影片', () {
                Navigator.pop(c);
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('影片上傳（示範）')));
              }),
              _composerActionButton(Icons.videocam, '開直播', () {
                Navigator.pop(c);
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('進入開播流程（示範）')));
              }),
            ]),
            const SizedBox(height: 12),
            const Text('或選擇快速發佈貼文'),
            const SizedBox(height: 8),
            ElevatedButton.icon(onPressed: () { Navigator.pop(c); _openCreateOrEditPostSheet(ctx, notifier); }, icon: const Icon(Icons.edit), label: const Text('建立貼文')),
            const SizedBox(height: 18),
          ]),
        );
      },
    );
  }

  Widget _composerActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(children: [
        CircleAvatar(radius: 26, backgroundColor: Colors.orangeAccent.shade100, child: Icon(icon, color: Colors.white)),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]),
    );
  }

  // ---------------- Story creator ----------------
  Future<void> _openCreateStorySheet(BuildContext ctx, NotificationService notifier) async {
    final picker = ImagePicker();
    Uint8List? picked;
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) {
        return StatefulBuilder(builder: (c2, setS) {
          return Padding(
            padding: EdgeInsets.only(left: 12, right: 12, bottom: MediaQuery.of(c2).viewInsets.bottom + 12, top: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [const Text('上傳限動', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(c2))]),
              const SizedBox(height: 8),
              if (picked != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(picked!, height: 220, width: double.infinity, fit: BoxFit.cover)),
              const SizedBox(height: 8),
              Row(children: [
                TextButton.icon(onPressed: () async {
                  try {
                    final XFile? f = await picker.pickImage(source: ImageSource.gallery, maxWidth: 2000);
                    if (f != null) {
                      final b = await f.readAsBytes();
                      setS(() => picked = b);
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('選擇圖片失敗：$e')));
                  }
                }, icon: const Icon(Icons.photo_library), label: const Text('選擇圖片')),
                const SizedBox(width: 8),
                if (picked != null) TextButton(onPressed: () => setS(() => picked = null), child: const Text('移除')),
              ]),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () {
                if (picked == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('請先選擇圖片')));
                  return;
                }
                setState(() => _stories.insert(0, {'name': '我', 'color': Colors.purple}));
                notifier.addNotification(type: '互動', title: '限動已上傳', message: '你的限動已上傳（示範）');
                Navigator.pop(c2);
              }, child: const Text('上傳限動')),
              const SizedBox(height: 12),
            ]),
          );
        });
      },
    );
  }

  // ---------------- Friends tab UI ----------------
  Widget _buildFriendsTab(NotificationService notifier) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 400));
        setState(() {});
      },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(children: [
            const Icon(Icons.people_alt_rounded, color: Colors.blueAccent),
            const SizedBox(width: 8),
            const Expanded(child: Text('好友動態', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            Stack(alignment: Alignment.topRight, children: [
              IconButton(icon: const Icon(Icons.person_add), onPressed: () => _openFriendRequestsSheet()),
              if (_friendRequests.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('${_friendRequests.length}', style: const TextStyle(color: Colors.white, fontSize: 10))),
                ),
            ]),
            const SizedBox(width: 4),
            IconButton(icon: const Icon(Icons.person_search), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('搜尋用戶（示範）')))),
          ]),
          const SizedBox(height: 12),

          // search + filter
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: const Color(0xFFF6F7F9), borderRadius: BorderRadius.circular(22)),
                    child: Row(children: [
                      const Icon(Icons.search, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: _friendsSearchController, decoration: const InputDecoration(hintText: '搜尋好友或狀態', border: InputBorder.none, isDense: true))),
                      if (_friendsSearchController.text.isNotEmpty) GestureDetector(onTap: () => setState(() => _friendsSearchController.clear()), child: const Icon(Icons.close, size: 18, color: Colors.grey)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 1,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      final cur = _friendViewFilter;
                      final idx = _friendViewFilters.indexOf(cur);
                      final next = _friendViewFilters[(idx + 1) % _friendViewFilters.length];
                      setState(() => _friendViewFilter = next);
                    },
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Row(children: [const Icon(Icons.filter_list, size: 18, color: Colors.grey), const SizedBox(width: 6), Text(_friendViewFilter)])),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _friendViewFilters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final label = _friendViewFilters[i];
                    final active = _friendViewFilter == label;
                    return ChoiceChip(
                      label: Text(label),
                      selected: active,
                      onSelected: (_) => setState(() => _friendViewFilter = label),
                      selectedColor: Colors.blueAccent,
                      labelStyle: TextStyle(color: active ? Colors.white : Colors.black87),
                      backgroundColor: const Color(0xFFF3F4F6),
                    );
                  },
                ),
              ),
            ]),
          ),

          const SizedBox(height: 12),

          // friend requests
          if (_friendRequests.isNotEmpty)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('好友請求', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (var req in _friendRequests)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(backgroundColor: req['avatarColor'] as Color, child: Text((req['name'] as String).substring(0, 1))),
                      title: Text(req['name'] as String),
                      subtitle: Text(req['message'] as String),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        TextButton(onPressed: () => _acceptFriendRequest(req), child: const Text('接受')),
                        TextButton(onPressed: () => _declineFriendRequest(req), child: const Text('拒絕')),
                      ]),
                    ),
                ]),
              ),
            ),

          const SizedBox(height: 8),

          // filtered friend lists + suggested
          Builder(builder: (ctx) {
            final q = _friendsSearchController.text.trim().toLowerCase();
            List<Map<String, dynamic>> filtered = List<Map<String, dynamic>>.from(_friends);

            if (_friendViewFilter == '在線') filtered = filtered.where((f) => f['online'] == true).toList();
            else if (_friendViewFilter == '最近') filtered = filtered.where((f) => f['online'] == true || (f['status'] as String).contains('剛') || (f['status'] as String).contains('上次') || (f['status'] as String).contains('昨天')).toList();

            if (q.isNotEmpty) {
              filtered = filtered.where((f) {
                final name = (f['name'] as String).toLowerCase();
                final status = (f['status'] as String).toLowerCase();
                return name.contains(q) || status.contains(q);
              }).toList();
            }

            filtered.sort((a, b) {
              final ao = a['online'] == true ? 1 : 0;
              final bo = b['online'] == true ? 1 : 0;
              return bo - ao;
            });

            final online = filtered.where((f) => f['online'] == true).toList();
            final recent = filtered.where((f) => f['online'] != true && ((f['status'] as String).contains('剛') || (f['status'] as String).contains('上次') || (f['status'] as String).contains('昨天'))).toList();
            final others = filtered.where((f) => !online.contains(f) && !recent.contains(f)).toList();

            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (online.isNotEmpty) ...[
                const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('在線中', style: TextStyle(fontWeight: FontWeight.bold))),
                for (var f in online) _friendTile(f, notifier),
                const SizedBox(height: 8),
              ],
              if (recent.isNotEmpty) ...[
                const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('最近互動', style: TextStyle(fontWeight: FontWeight.bold))),
                for (var f in recent) _friendTile(f, notifier),
                const SizedBox(height: 8),
              ],
              if (others.isNotEmpty) ...[
                const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('其他好友', style: TextStyle(fontWeight: FontWeight.bold))),
                for (var f in others) _friendTile(f, notifier),
                const SizedBox(height: 8),
              ],
              const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('建議好友', style: TextStyle(fontWeight: FontWeight.bold))),
              Column(children: _suggestedFriends.map((s) {
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: s['avatarColor'] as Color, child: Text((s['name'] as String).substring(0, 1))),
                    title: Text(s['name'] as String),
                    subtitle: Text(s['reason'] as String),
                    trailing: ElevatedButton(onPressed: () => _addSuggestedFriend(s), child: const Text('加好友')),
                  ),
                );
              }).toList()),
              const SizedBox(height: 24),

              Row(children: [
                Expanded(child: ElevatedButton.icon(onPressed: () => _createGroupChat(), icon: const Icon(Icons.group), label: const Text('建立群組聊天'))),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(onPressed: () => _inviteFriends(), icon: const Icon(Icons.person_add_alt), label: const Text('邀請好友'))),
              ]),
            ]);
          }),
        ],
      ),
    );
  }

  Widget _friendTile(Map<String, dynamic> f, NotificationService notifier) {
    final online = f['online'] == true;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(children: [
          CircleAvatar(backgroundColor: f['avatarColor'] as Color, child: Text((f['name'] as String).substring(0, 1), style: const TextStyle(color: Colors.white))),
          if (online)
            Positioned(right: -2, bottom: -2, child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2))))),
        ]),
        title: Text(f['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(f['status'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: SizedBox(width: 140, child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.message, color: Colors.blue), onPressed: () => _startChatWith(f, notifier)),
          IconButton(icon: const Icon(Icons.videocam, color: Colors.grey), onPressed: () => _startVideoCall(f)),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'profile') _viewFriendProfile(f);
              if (v == 'remove') _removeFriendConfirm(f);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Text('檢視個人資料')),
              PopupMenuItem(value: 'remove', child: Text('移除好友')),
            ],
          ),
        ])),
      ),
    );
  }

  // ---------------- Friend actions (implemented) ----------------

  void _acceptFriendRequest(Map<String, dynamic> req) {
    setState(() {
      _friendRequests.remove(req);
      _friends.insert(0, {'name': req['name'], 'status': '剛成為好友', 'online': false, 'avatarColor': req['avatarColor']});
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已接受 ${req['name']} 的好友請求')));
  }

  void _declineFriendRequest(Map<String, dynamic> req) {
    setState(() => _friendRequests.remove(req));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已拒絕 ${req['name']} 的好友請求')));
  }

  void _addSuggestedFriend(Map<String, dynamic> s) {
    setState(() {
      _suggestedFriends.remove(s);
      _friends.insert(0, {'name': s['name'], 'status': '你們有共同朋友', 'online': false, 'avatarColor': s['avatarColor']});
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已送出好友邀請給 ${s['name']}（示範）')));
  }

  void _startChatWith(Map<String, dynamic> f, NotificationService notifier) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DemoChatPage(partner: f['name'] as String)));
  }

  void _startVideoCall(Map<String, dynamic> f) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('視訊通話：${f['name']}（示範）')));
  }

  void _viewFriendProfile(Map<String, dynamic> f) {
    _openUserProfileSheet(context, f['name'] as String, f['avatarColor'] as Color);
  }

  void _removeFriendConfirm(Map<String, dynamic> f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('移除好友'),
        content: Text('確定要移除 ${f['name']} 嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('移除')),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _friends.removeWhere((x) => x['name'] == f['name']));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${f['name']} 已移除')));
    }
  }

  // ---------------- Friend sheets: create group / invite / requests ----------------

  void _createGroupChat() {
    final TextEditingController _groupNameCtrl = TextEditingController();
    final Map<String, bool> selected = {};
    final TextEditingController _searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setS) {
          final q = _searchCtrl.text.trim().toLowerCase();
          final List<Map<String, dynamic>> candidates = q.isEmpty
              ? List<Map<String, dynamic>>.from(_friends)
              : _friends.where((f) {
                  final name = (f['name'] as String).toLowerCase();
                  final status = (f['status'] as String).toLowerCase();
                  return name.contains(q) || status.contains(q);
                }).toList();

          final selectedList = selected.keys.toList();
          return Padding(
            padding: EdgeInsets.only(left: 12, right: 12, bottom: MediaQuery.of(ctx2).viewInsets.bottom + 12, top: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [const Text('建立群組聊天', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx2))]),
              const SizedBox(height: 8),
              TextField(controller: _groupNameCtrl, decoration: const InputDecoration(labelText: '群組名稱', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    const SizedBox(width: 8),
                    ...selectedList.map((name) {
                      final friend = _friends.firstWhere((f) => f['name'] == name, orElse: () => {});
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Chip(
                          avatar: CircleAvatar(backgroundColor: friend['avatarColor'] as Color? ?? Colors.grey, child: Text((name as String).substring(0, 1))),
                          label: Text(name),
                          deleteIcon: const Icon(Icons.close),
                          onDeleted: () => setS(() => selected.remove(name)),
                        ),
                      );
                    }),
                    if (selectedList.isEmpty) const Padding(padding: EdgeInsets.only(left: 8.0), child: Text('尚未選取成員')),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.02), blurRadius: 4)]),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: TextField(controller: _searchCtrl, decoration: const InputDecoration(hintText: '搜尋好友', border: InputBorder.none, isDense: true))),
                    IconButton(icon: const Icon(Icons.search), onPressed: () => setS(() {})),
                  ]),
                  const Divider(),
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      itemCount: candidates.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx3, i) {
                        final f = candidates[i];
                        final checked = selected[f['name']] == true;
                        return ListTile(
                          leading: CircleAvatar(backgroundColor: f['avatarColor'] as Color, child: Text((f['name'] as String).substring(0, 1))),
                          title: Text(f['name'] as String),
                          subtitle: Text(f['status'] as String),
                          trailing: Checkbox(value: checked, onChanged: (v) => setS(() => v == true ? selected[f['name']] = true : selected.remove(f['name']))),
                          onTap: () => setS(() => selected[f['name']] = !(selected[f['name']] == true)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: ElevatedButton(
                      onPressed: (selected.isEmpty || _groupNameCtrl.text.trim().isEmpty) ? null : () {
                        final groupName = _groupNameCtrl.text.trim();
                        final members = selected.keys.toList();
                        members.insert(0, '我');
                        Navigator.pop(ctx2);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatPage(groupName: groupName, members: members)));
                      },
                      child: const Text('建立群組並進入聊天'),
                    )),
                  ]),
                ]),
              ),
            ]),
          );
        });
      },
    );
  }

  void _inviteFriends() {
    final Map<String, bool> invited = {};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setS) {
          return Padding(
            padding: EdgeInsets.only(left: 12, right: 12, bottom: MediaQuery.of(ctx2).viewInsets.bottom + 12, top: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [const Text('邀請好友', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx2))]),
              const SizedBox(height: 8),
              const Text('分享邀請連結給好友或直接從好友列表發送邀請'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () {
                  final link = 'https://osmile.app/invite?code=ABC123';
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('邀請連結已複製（示範）')));
                }, icon: const Icon(Icons.link), label: const Text('複製邀請連結'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: () {
                  final link = 'https://osmile.app/invite?code=ABC123';
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('透過系統分享介面（可自行實作）'))); 
                }, icon: const Icon(Icons.share), label: const Text('系統分享'))),
              ]),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text('從好友發送邀請', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 260,
                child: ListView.separated(
                  itemCount: _friends.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx3, i) {
                    final f = _friends[i];
                    final isInv = invited[f['name']] == true;
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: f['avatarColor'] as Color, child: Text((f['name'] as String).substring(0, 1))),
                      title: Text(f['name'] as String),
                      subtitle: Text(f['status'] as String),
                      trailing: isInv
                          ? ElevatedButton(onPressed: null, child: const Text('已邀請'))
                          : TextButton(onPressed: () {
                              setS(() => invited[f['name']] = true);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已邀請 ${f['name']}（示範）')));
                            }, child: const Text('邀請')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () {
                Navigator.pop(ctx2);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('邀請已送出（示範）')));
              }, child: const Text('完成並關閉')),
            ]),
          );
        });
      },
    );
  }

  void _openFriendRequestsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [const Text('好友請求', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
            if (_friendRequests.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('目前沒有好友請求')),
            for (var req in _friendRequests)
              ListTile(
                leading: CircleAvatar(backgroundColor: req['avatarColor'] as Color, child: Text((req['name'] as String).substring(0, 1))),
                title: Text(req['name'] as String),
                subtitle: Text(req['message'] as String),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () { _acceptFriendRequest(req); Navigator.pop(ctx); }),
                  IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () { _declineFriendRequest(req); Navigator.pop(ctx); }),
                ]),
              ),
          ]),
        );
      },
    );
  }

  // ---------------- user profile / shop / product ----------------

  void _openUserProfileSheet(BuildContext ctx, String name, Color color) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              CircleAvatar(backgroundColor: color, radius: 28, child: Text(name.substring(0, 1), style: const TextStyle(color: Colors.white, fontSize: 18))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), const Text('關注：120 ・ 追蹤者：3.4k', style: TextStyle(color: Colors.grey))])),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: ElevatedButton(onPressed: () { Navigator.pop(c); ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('已追蹤 $name'))); }, child: const Text('追蹤'))),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () { Navigator.pop(c); ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('開啟與 $name 的私訊（示範）'))); }, child: const Text('私訊')),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              ElevatedButton.icon(onPressed: () { Navigator.pop(c); _openShopPage(ctx, name); }, icon: const Icon(Icons.store), label: const Text('查看商店')),
              OutlinedButton.icon(onPressed: () { Navigator.pop(c); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('檢舉/回報（示範）'))); }, icon: const Icon(Icons.flag_outlined), label: const Text('檢舉')),
            ]),
            const SizedBox(height: 12),
          ]),
        );
      },
    );
  }

  void _openShopPage(BuildContext ctx, String shopName) {
    Navigator.push(ctx, MaterialPageRoute(builder: (_) {
      final items = _shopItems.where((s) => s['seller'] == shopName || shopName == 'Osmile 官方').toList();
      final showItems = items.isNotEmpty ? items : _shopItems;
      return Scaffold(
        appBar: AppBar(title: Text('$shopName 商店')),
        body: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: showItems.length,
          itemBuilder: (_, idx) {
            final item = showItems[idx];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(item['image'] as String, width: 64, height: 64, fit: BoxFit.cover)),
                title: Text(item['name'] as String),
                subtitle: Text('NT\$${item['price']}', style: const TextStyle(color: Colors.orange)),
                trailing: ElevatedButton(onPressed: () => _openProductDetail(ctx, item), child: const Text('購買')),
              ),
            );
          },
        ),
      );
    }));
  }

  void _openProductDetail(BuildContext ctx, Map<String, dynamic> product) {
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)));
  }

  void _addToCart(Map<String, dynamic> product) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已加入購物車：${product['name'] ?? product['title'] ?? ''}（示範）')));
  }

  void _toggleLike(Map<String, dynamic> post) {
    setState(() {
      final curLiked = post['liked'] == true;
      post['liked'] = !curLiked;
      final rawLikes = post['likes'];
      int likes = 0;
      if (rawLikes is int) likes = rawLikes;
      else if (rawLikes is String) likes = int.tryParse(rawLikes) ?? 0;
      else if (rawLikes is num) likes = rawLikes.toInt();
      post['likes'] = max(0, likes + ((post['liked'] == true) ? 1 : -1));
    });
  }

  Future<void> _openCommentSheet(BuildContext context, NotificationService notifier, Map post) async {
    final controller = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, top: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('留言', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(hintText: '輸入留言...', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: ElevatedButton(onPressed: () {
                if (controller.text.trim().isEmpty) return;
                setState(() {
                  (post['comments'] as List).add({'user': '我', 'text': controller.text.trim()});
                });
                Navigator.pop(ctx);
                context.read<NotificationService>().addNotification(type: '互動', title: '留言已送出', message: '你對 ${post['author']} 的貼文留言成功');
              }, child: const Text('送出'))),
            ]),
          ]),
        );
      },
    );
  }

  // ---------------- Create / Edit post ----------------
  Future<void> _openCreateOrEditPostSheet(BuildContext context, NotificationService notifier, {Map<String, dynamic>? post}) async {
    final controller = TextEditingController(text: post != null ? post['content'] as String : '');
    List<Uint8List>? pickedImages = post != null && post['imageBytes'] != null ? [post['imageBytes'] as Uint8List] : null;
    Map<String, dynamic>? taggedProduct = post != null ? post['product'] as Map<String, dynamic>? : null;
    String tag = post != null ? (post['tag'] ?? '生活') as String : '生活';
    final picker = ImagePicker();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, top: 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(post == null ? '發佈貼文' : '編輯貼文', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: tag,
                decoration: const InputDecoration(labelText: '分類', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: '開箱', child: Text('開箱')),
                  DropdownMenuItem(value: '運動', child: Text('運動')),
                  DropdownMenuItem(value: '生活', child: Text('生活')),
                  DropdownMenuItem(value: '問題', child: Text('問題')),
                ],
                onChanged: (v) => setModalState(() => tag = v ?? tag),
              ),
              const SizedBox(height: 10),
              TextField(controller: controller, maxLines: 4, decoration: const InputDecoration(hintText: '分享你的想法...', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              if ((pickedImages ?? []).isNotEmpty)
                SizedBox(
                  height: 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: (pickedImages ?? []).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(pickedImages![i], height: 140, width: 220, fit: BoxFit.cover)),
                  ),
                ),
              const SizedBox(height: 8),
              Row(children: [
                TextButton.icon(onPressed: () async {
                  try {
                    final XFile? picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1800);
                    if (picked != null) {
                      final bytes = await picked.readAsBytes();
                      setModalState(() => pickedImages = (pickedImages ?? [])..add(bytes));
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('選圖片失敗：$e')));
                  }
                }, icon: const Icon(Icons.photo_library), label: const Text('選擇圖片')),
                const SizedBox(width: 8),
                if ((pickedImages ?? []).isNotEmpty) TextButton(onPressed: () => setModalState(() => pickedImages = null), child: const Text('移除')),
                const Spacer(),
                TextButton.icon(onPressed: () {
                  Navigator.pop(ctx);
                  _openTagProductSheet(ctx, (p) {
                    setState(() => taggedProduct = p);
                  });
                }, icon: const Icon(Icons.local_offer), label: const Text('標註商品')),
              ]),
              const SizedBox(height: 12),
              if (taggedProduct != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Row(children: [ ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(taggedProduct!['image'] as String, width: 72, height: 72, fit: BoxFit.cover)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(taggedProduct!['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)), Text('NT\$${taggedProduct!['price']}', style: const TextStyle(color: Colors.orange)) ])), TextButton(onPressed: () => setModalState(() => taggedProduct = null), child: const Text('移除')) ])),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: ElevatedButton(onPressed: () {
                  if (controller.text.trim().isEmpty && (pickedImages == null || pickedImages!.isEmpty) && taggedProduct == null) return;
                  if (post == null) {
                    setState(() {
                      _posts.insert(0, {
                        'id': DateTime.now().millisecondsSinceEpoch,
                        'author': '我',
                        'avatarColor': Colors.purple,
                        'timeLabel': '剛剛',
                        'tag': tag,
                        'content': controller.text.trim(),
                        'image': '',
                        'imageBytes': (pickedImages != null && pickedImages!.isNotEmpty) ? pickedImages!.first : null,
                        'likes': 0,
                        'comments': [],
                        'liked': false,
                        'followed': true,
                        'bookmarked': false,
                        '_expanded': false,
                        'product': taggedProduct
                      });
                    });
                    notifier.addNotification(type: '互動', title: '貼文已發佈', message: '你的貼文已成功上傳！');
                    Navigator.pop(ctx);
                  } else {
                    setState(() {
                      post['content'] = controller.text.trim();
                      post['imageBytes'] = (pickedImages != null && pickedImages!.isNotEmpty) ? pickedImages!.first : null;
                      post['tag'] = tag;
                      post['product'] = taggedProduct;
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('貼文已更新')));
                  }
                }, child: Text(post == null ? '發佈' : '儲存'))),
              ]),
              const SizedBox(height: 12),
            ]),
          );
        });
      },
    );
  }

  void _openTagProductSheet(BuildContext ctx, void Function(Map<String, dynamic>) onSelected) {
    showModalBottomSheet(context: ctx, builder: (c) {
      return Padding(padding: const EdgeInsets.all(12.0), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [ const Text('標註商品', style: TextStyle(fontWeight: FontWeight.bold)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(c)) ]),
        const SizedBox(height: 8),
        ..._shopItems.map((product) {
          return ListTile(
            leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(product['image'] as String, width: 36, height: 36, fit: BoxFit.cover)),
            title: Text(product['name'] as String),
            subtitle: Text('NT\$${product['price']}'),
            trailing: TextButton(onPressed: () {
              Navigator.pop(c);
              onSelected(product);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已標註商品：${product['name']}（示範）')));
            }, child: const Text('選取')),
          );
        }).toList(),
        const SizedBox(height: 8),
      ]));
    });
  }

  // ---------------- Story viewer ----------------
  void _openStoryViewer(BuildContext context, Map<String, dynamic> story) {
    Navigator.push(context, PageRouteBuilder(opaque: false, pageBuilder: (_, __, ___) {
      return Scaffold(
        backgroundColor: Colors.black87,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Row(children: [
            CircleAvatar(backgroundColor: (story['color'] as Color?) ?? Colors.grey, radius: 16, child: Text(((story['name'] as String?) ?? '').isNotEmpty ? (story['name'] as String)[0] : '', style: const TextStyle(color: Colors.white))),
            const SizedBox(width: 8),
            Expanded(child: Text((story['name'] as String?) ?? '', style: const TextStyle(color: Colors.white, fontSize: 16), overflow: TextOverflow.ellipsis)),
          ]),
          actions: [
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
          ],
        ),
        body: SafeArea(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Column(children: [
              Expanded(child: Container(width: double.infinity, color: (story['color'] as Color?) ?? Colors.black, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${story['name']} 的限時動態', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0), child: Text('此處為示範限時動態內容，點擊可關閉。', style: TextStyle(color: Colors.white.withOpacity(0.9)), textAlign: TextAlign.center)),
              ]))),

              Container(
                color: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.message, color: Colors.white70), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('回覆限動（示範）')))),
                  IconButton(icon: const Icon(Icons.share, color: Colors.white70), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('分享限動（示範）')))),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('關閉', style: TextStyle(color: Colors.white70))),
                ]),
              ),
            ]),
          ),
        ),
      );
    }, transitionsBuilder: (_, animation, __, child) {
      final offset = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(animation);
      return FadeTransition(opacity: animation, child: SlideTransition(position: offset, child: child));
    }));
  }
}

// ---------------- LivePlayerPage ----------------
class LivePlayerPage extends StatefulWidget {
  final String liveId;
  final String title;
  final String host;
  final String image;
  final ValueNotifier<List<Map<String, dynamic>>> chatNotifier;

  const LivePlayerPage({
    super.key,
    required this.liveId,
    required this.title,
    required this.host,
    required this.image,
    required this.chatNotifier,
  });

  @override
  State<LivePlayerPage> createState() => _LivePlayerPageState();
}

class _LivePlayerPageState extends State<LivePlayerPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  bool _barrageOn = true;

  @override
  void initState() {
    super.initState();
    widget.chatNotifier.addListener(_onChatUpdate);
  }

  void _onChatUpdate() {
    if (_chatScroll.hasClients) {
      Future.delayed(const Duration(milliseconds: 80), () {
        if (_chatScroll.hasClients) _chatScroll.jumpTo(_chatScroll.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    widget.chatNotifier.removeListener(_onChatUpdate);
    _inputController.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    final v = widget.chatNotifier;
    final newList = List<Map<String, dynamic>>.from(v.value);
    newList.add({'user': '我', 'text': text.trim()});
    if (newList.length > 300) newList.removeRange(0, newList.length - 300);
    v.value = newList;
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(icon: Icon(_barrageOn ? Icons.stream : Icons.stream_outlined), onPressed: () => setState(() => _barrageOn = !_barrageOn), tooltip: '彈幕'),
        ],
      ),
      body: Column(children: [
        Stack(children: [
          SizedBox(height: 220, width: double.infinity, child: Image.network(widget.image, fit: BoxFit.cover)),
          Positioned(left: 12, bottom: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.live_tv, color: Colors.redAccent, size: 16), const SizedBox(width: 8), Text('主持人：${widget.host}', style: const TextStyle(color: Colors.white))]))),
          if (_barrageOn)
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: widget.chatNotifier,
                  builder: (_, chats, __) {
                    final last = chats.length <= 5 ? chats : chats.sublist(max(0, chats.length - 5));
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: last.reversed.map((m) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                              child: Text('${m['user']}: ${m['text']}', style: const TextStyle(color: Colors.white)),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            color: Colors.grey.shade50,
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: widget.chatNotifier,
              builder: (_, chats, __) {
                return ListView.builder(
                  controller: _chatScroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: chats.length,
                  itemBuilder: (_, i) {
                    final m = chats[i];
                    final isMe = m['user'] == '我';
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: isMe ? Colors.blue.shade100 : Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${m['user']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700)),
                          const SizedBox(height: 6),
                          Text('${m['text']}')
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Expanded(child: TextField(controller: _inputController, decoration: const InputDecoration(hintText: '寫下你的留言...', border: InputBorder.none))),
            IconButton(icon: const Icon(Icons.send, color: Colors.blue), onPressed: () => _sendMessage(_inputController.text)),
          ]),
        ),
      ]),
    );
  }
}

// ---------------- Post detail page ----------------
class CommunityPostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLikeToggle;

  const CommunityPostDetailPage({super.key, required this.post, required this.onLikeToggle});

  @override
  State<CommunityPostDetailPage> createState() => _CommunityPostDetailPageState();
}

class _CommunityPostDetailPageState extends State<CommunityPostDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  late int _likes;
  late bool _liked;
  late List<Map<String, dynamic>> _comments;

  @override
  void initState() {
    super.initState();

    final p = widget.post;

    _likes = 0;
    if (p.containsKey('likes')) {
      final v = p['likes'];
      if (v is int) _likes = v;
      else if (v is String) _likes = int.tryParse(v) ?? 0;
      else if (v is num) _likes = v.toInt();
    }

    _liked = (p['liked'] == true);

    final rawComments = p['comments'];
    if (rawComments is List) {
      _comments = rawComments.map<Map<String, dynamic>>((c) {
        if (c is Map<String, dynamic>) return c;
        if (c is Map) return Map<String, dynamic>.from(c);
        return {'user': '${c}', 'text': ''};
      }).toList();
    } else {
      _comments = <Map<String, dynamic>>[];
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      _liked = !_liked;
      _likes = max(0, _likes + (_liked ? 1 : -1));
    });

    widget.post['liked'] = _liked;
    widget.post['likes'] = _likes;

    try {
      widget.onLikeToggle();
    } catch (_) {}
  }

  void _addComment(String text) {
    if (text.trim().isEmpty) return;
    final comment = {'user': '我', 'text': text.trim()};
    setState(() {
      _comments.add(comment);
    });
    widget.post['comments'] = _comments;
    _commentController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('留言已送出（示範）')));
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final author = post['author'] ?? '';
    final avatarColor = post['avatarColor'] as Color? ?? Colors.grey;
    final timeLabel = post['timeLabel'] ?? '';
    final content = post['content'] ?? '';
    final hasImageBytes = post['imageBytes'] != null;
    final imageUrl = (post['image'] is String) ? post['image'] as String : '';

    return Scaffold(
      appBar: AppBar(title: const Text('貼文內容')),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                CircleAvatar(backgroundColor: avatarColor, radius: 20, child: Text((author as String).isNotEmpty ? author[0] : '?', style: const TextStyle(color: Colors.white))),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(author as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(timeLabel as String, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              ]),
              const SizedBox(height: 12),
              Text(content as String),
              const SizedBox(height: 10),
              if (hasImageBytes)
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(post['imageBytes'] as Uint8List, fit: BoxFit.cover))
              else if (imageUrl.isNotEmpty)
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(imageUrl, fit: BoxFit.cover)),
              const SizedBox(height: 10),
              Row(children: [IconButton(onPressed: _toggleLike, icon: Icon(_liked ? Icons.favorite : Icons.favorite_border, color: _liked ? Colors.pink : Colors.grey[700])), Text('$_likes 個讚')]),
              const Divider(),
              const Text('留言', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_comments.isEmpty) ...[
                const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('目前尚無留言', style: TextStyle(color: Colors.black54))),
              ] else ...[
                for (var c in _comments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CircleAvatar(radius: 14, child: Text(((c['user'] as String?) ?? '').isNotEmpty ? (c['user'] as String)[0] : '?')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black87),
                            children: [
                              TextSpan(text: '${c['user']} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: '${c['text']}'),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.03), blurRadius: 4)]),
          child: Row(children: [
            Expanded(child: TextField(controller: _commentController, decoration: const InputDecoration(hintText: '寫下你的留言...', border: InputBorder.none), minLines: 1, maxLines: 3)),
            IconButton(icon: const Icon(Icons.send, color: Colors.blue), onPressed: () => _addComment(_commentController.text)),
          ]),
        ),
      ]),
    );
  }
}

// ---------------- GroupChatPage ----------------
class GroupChatPage extends StatefulWidget {
  final String groupName;
  final List<String> members;

  const GroupChatPage({super.key, required this.groupName, required this.members});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final List<Map<String, String>> _msgs = [
    {'user': '小美', 'text': '嗨大家好！'},
    {'user': '我', 'text': '哈囉！'},
  ];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _sc = ScrollController();

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    setState(() => _msgs.add({'user': '我', 'text': t}));
    _ctrl.clear();
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_sc.hasClients) _sc.jumpTo(_sc.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.groupName), Text('${widget.members.length} 位成員', style: const TextStyle(fontSize: 12, color: Colors.white70))]),
        actions: [IconButton(icon: const Icon(Icons.info_outline), onPressed: () => showModalBottomSheet(context: context, builder: (_) => Padding(padding: const EdgeInsets.all(12), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('群組成員', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Wrap(spacing: 8, children: widget.members.map((m) => Chip(label: Text(m))).toList()), const SizedBox(height: 12)]))))],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _sc,
            padding: const EdgeInsets.all(12),
            itemCount: _msgs.length,
            itemBuilder: (ctx, i) {
              final m = _msgs[i];
              final isMe = m['user'] == '我';
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: isMe ? Colors.blue.shade100 : Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m['user']!, style: const TextStyle(fontSize: 12, color: Colors.black54)), const SizedBox(height: 6), Text(m['text']!)]),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.white,
          child: Row(children: [
            Expanded(child: TextField(controller: _ctrl, decoration: const InputDecoration(hintText: '寫訊息...', border: InputBorder.none))),
            IconButton(icon: const Icon(Icons.send, color: Colors.blue), onPressed: _send),
          ]),
        ),
      ]),
    );
  }
}

// ---------------- DemoChatPage ----------------
class DemoChatPage extends StatefulWidget {
  final String partner;
  const DemoChatPage({super.key, required this.partner});

  @override
  State<DemoChatPage> createState() => _DemoChatPageState();
}

class _DemoChatPageState extends State<DemoChatPage> {
  final List<Map<String, String>> _msgs = [
    {'user': '對方', 'text': '嗨！'},
    {'user': '我', 'text': '哈囉'},
  ];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _sc = ScrollController();

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    setState(() => _msgs.add({'user': '我', 'text': t}));
    _ctrl.clear();
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_sc.hasClients) _sc.jumpTo(_sc.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('與 ${widget.partner} 的聊天')),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _sc,
            padding: const EdgeInsets.all(12),
            itemCount: _msgs.length,
            itemBuilder: (ctx, i) {
              final m = _msgs[i];
              final isMe = m['user'] == '我';
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: isMe ? Colors.blue.shade100 : Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m['user']!, style: const TextStyle(fontSize: 12, color: Colors.black54)), const SizedBox(height: 6), Text(m['text']!)]),
                ),
              );
            },
          ),
        ),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), color: Colors.white, child: Row(children: [Expanded(child: TextField(controller: _ctrl, decoration: const InputDecoration(hintText: '寫訊息...', border: InputBorder.none))), IconButton(icon: const Icon(Icons.send, color: Colors.blue), onPressed: _send)])),
      ]),
    );
  }
}
