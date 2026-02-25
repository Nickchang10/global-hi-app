// lib/pages/interaction_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Uint8List / Clipboard
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osmile_shopping_app/services/notification_service.dart';

// ======================================================
// ✅ InteractionPage（動態 / 好友 / 活動）完整版（推播整合版）
// - Web 友善：不使用 dart:io
// - 功能全開：發文(含選圖)、按讚、留言、標籤、好友新增、好友搜尋、活動遊戲化
// - 修正：PageController not attached（只在活動Tab啟動輪播 + hasClients 防呆）
// - 修正：_FriendsRow 橫向小卡 RenderFlex overflow（縮排 + FittedBox）
// - 修正：demo posts 使用 const comments 導致 add() 失敗（改為可變 List）
// - ✅ 整合 NotificationService：重要行為推播到「我的」紅點/通知中心
// - ✅ 修正：withOpacity deprecated → 改用 withValues(alpha: x)
// - ✅ 修正：curly_braces_in_flow_control_structures（所有 if 單行改成 block）
// ======================================================

class InteractionPage extends StatefulWidget {
  const InteractionPage({super.key});

  @override
  State<InteractionPage> createState() => _InteractionPageState();
}

class _InteractionPageState extends State<InteractionPage>
    with SingleTickerProviderStateMixin {
  // ===== Theme tokens =====
  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _brand = Colors.orangeAccent;
  static const Color _primary = Colors.blueAccent;

  // ===== Tabs =====
  late final TabController _tab;
  int _tabIndex = 0;

  // ===== Persistence keys =====
  static const String _kPrefsFriends = 'interaction_friends_v2';
  static const String _kPrefsRequests = 'interaction_friend_requests_v2';
  static const String _kPrefsInviteCode = 'interaction_my_invite_code_v2';
  static const String _kPrefsDaily = 'interaction_daily_v2';

  // ===== Friend system =====
  final List<_Friend> _friends = []; // includes "我"
  final List<_FriendRequest> _requests = [];
  String _friendSearch = '';

  // ===== Feed =====
  final List<String> _tags = const [
    '#Osmile',
    '#今日步數',
    '#親子互動',
    '#長輩關懷',
    '#健康打卡',
  ];
  final List<_Leader> _leaders = [
    _Leader(name: '用戶 1', score: 120),
    _Leader(name: '用戶 2', score: 87),
    _Leader(name: '用戶 3', score: 65),
  ];
  final List<_Post> _posts = [];

  // ===== Activity / Gamification =====
  final ConfettiController _confetti = ConfettiController(
    duration: const Duration(milliseconds: 1400),
  );

  int _points = 120;
  int _streakDays = 2;

  // daily mission
  final int _todayGoal = 5;
  int _todayDone = 2;
  bool _signedToday = false;

  // poll
  String? _pollAnswer;

  // activity list
  String _selectedActivityCategory = '全部';

  final PageController _bannerController = PageController(
    viewportFraction: 0.92,
  );
  int _bannerIndex = 0;
  Timer? _bannerTimer;

  final List<_BannerItem> _banners = const [
    _BannerItem(
      title: '限時任務挑戰賽',
      subtitle: '7 天活躍挑戰，累積點數換徽章',
      imageUrl:
          'https://images.unsplash.com/photo-1520975958225-8d0f6c9a4b0b?auto=format&fit=crop&w=1200&q=80',
      tag: '任務',
    ),
    _BannerItem(
      title: '親子互動日',
      subtitle: '一起完成 3 次親子任務，獲得「親子之星」',
      imageUrl:
          'https://images.unsplash.com/photo-1605296867304-46d5465a13f1?auto=format&fit=crop&w=1200&q=80',
      tag: '親子',
    ),
    _BannerItem(
      title: '健走活動',
      subtitle: '每日 5,000 步，完成可抽好禮',
      imageUrl:
          'https://images.unsplash.com/photo-1599058917212-d750089bc07f?auto=format&fit=crop&w=1200&q=80',
      tag: '健康',
    ),
  ];

  final List<_ActivityEvent> _events = [
    _ActivityEvent(
      id: 'ev_walk',
      category: '健康挑戰',
      title: 'Osmile 健走活動',
      subtitle: '12/20 - 12/31 完成每日 5,000 步可抽好禮！',
      imageUrl:
          'https://images.unsplash.com/photo-1599058917212-d750089bc07f?auto=format&fit=crop&w=1200&q=80',
      joined: false,
      progress: 0.15,
      rewardPoints: 30,
    ),
    _ActivityEvent(
      id: 'ev_family',
      category: '親子互動',
      title: '親子運動任務',
      subtitle: '與孩子一起完成 3 次任務即可得獎章！',
      imageUrl:
          'https://images.unsplash.com/photo-1605296867304-46d5465a13f1?auto=format&fit=crop&w=1200&q=80',
      joined: true,
      progress: 0.60,
      rewardPoints: 25,
    ),
    _ActivityEvent(
      id: 'ev_sos',
      category: 'Osmile 功能',
      title: 'SOS 安心設定挑戰',
      subtitle: '完成「聯絡人設定 + 測試通知」即可領取點數。',
      imageUrl:
          'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?auto=format&fit=crop&w=1200&q=80',
      joined: false,
      progress: 0.00,
      rewardPoints: 40,
    ),
  ];

  // ===== Image picker (compose) =====
  final ImagePicker _picker = ImagePicker();
  Uint8List? _pendingImageBytes;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);

    _tab.addListener(() {
      if (_tab.indexIsChanging) {
        return;
      }
      final idx = _tab.index;
      if (idx == _tabIndex) {
        return;
      }

      setState(() => _tabIndex = idx);

      // ✅ 只在活動頁啟動 banner 自動輪播，離開就停止，修正 PageController not attached
      if (_tabIndex == 2) {
        _startBannerAuto();
      } else {
        _stopBannerAuto();
      }
    });

    _seedInitialData();
    _loadPersisted();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_tabIndex == 2) {
        _startBannerAuto();
      }
    });
  }

  @override
  void dispose() {
    _stopBannerAuto();
    _bannerController.dispose();
    _confetti.dispose();
    _tab.dispose();
    super.dispose();
  }

  // ======================================================
  // Notification helper
  // ======================================================

  NotificationService _ns() {
    try {
      return context.read<NotificationService>();
    } catch (_) {
      return NotificationService.instance;
    }
  }

  void _pushNotif({
    required String type,
    required String title,
    required String message,
    IconData? icon,
  }) {
    try {
      _ns().addNotification(
        type: type,
        title: title,
        message: message,
        icon: icon,
      );
    } catch (_) {
      // ignore
    }
  }

  // ======================================================
  // Data seed / persistence
  // ======================================================

  void _seedInitialData() {
    _friends.addAll(const [
      _Friend(
        id: 'me',
        name: '我',
        initials: '我',
        colorValue: 0xFF1976D2,
        online: true,
      ),
      _Friend(
        id: 'f_alice',
        name: 'Alice',
        initials: 'A',
        colorValue: 0xFFFF9800,
        online: true,
      ),
      _Friend(
        id: 'f_bob',
        name: 'Bob',
        initials: 'B',
        colorValue: 0xFF1E88E5,
        online: false,
      ),
      _Friend(
        id: 'f_carol',
        name: 'Carol',
        initials: 'C',
        colorValue: 0xFFE91E63,
        online: true,
      ),
      _Friend(
        id: 'f_david',
        name: 'David',
        initials: 'D',
        colorValue: 0xFFFFC107,
        online: false,
      ),
      _Friend(
        id: 'f_emma',
        name: 'Emma',
        initials: 'E',
        colorValue: 0xFFFF5722,
        online: true,
      ),
    ]);

    // ✅ demo posts：comments 必須是可變 List（不能 const），否則留言 add() 會爆
    _posts.addAll([
      _Post(
        id: 'p1',
        user: '用戶 1',
        time: '1 小時前',
        content: '今天跑步 5 公里，超有成就感！',
        tags: const ['#今日步數', '#健康打卡'],
        imageUrl:
            'https://images.unsplash.com/photo-1554284126-aa88f22d8b74?auto=format&fit=crop&w=1200&q=70',
        likes: 120,
        liked: false,
        comments: [
          const _Comment(user: 'Alice', text: '太棒了！我也要開始跑步！'),
          const _Comment(user: 'David', text: '堅持最重要！'),
        ],
      ),
      _Post(
        id: 'p2',
        user: '用戶 2',
        time: '3 小時前',
        content: '今天幫爸媽設定了 SOS 聯絡人，安心很多。',
        tags: const ['#Osmile', '#長輩關懷'],
        imageUrl:
            'https://images.unsplash.com/photo-1520975958225-8d0f6c9a4b0b?auto=format&fit=crop&w=1200&q=70',
        likes: 87,
        liked: false,
        comments: [const _Comment(user: 'Emma', text: '很實用的功能！')],
      ),
    ]);
  }

  Future<void> _loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // invite code
      final code = prefs.getString(_kPrefsInviteCode);
      if (code == null || code.trim().isEmpty) {
        final newCode = _genInviteCode();
        await prefs.setString(_kPrefsInviteCode, newCode);
      }

      // friends
      final friendsJson = prefs.getString(_kPrefsFriends);
      if (friendsJson != null && friendsJson.trim().isNotEmpty) {
        final raw = jsonDecode(friendsJson);
        if (raw is List) {
          final loaded = raw
              .whereType<Map>()
              .map((m) => _Friend.fromJson(m.cast<String, dynamic>()))
              .toList();

          final hasMe = loaded.any((f) => f.id == 'me');
          if (!hasMe) {
            loaded.insert(
              0,
              const _Friend(
                id: 'me',
                name: '我',
                initials: '我',
                colorValue: 0xFF1976D2,
                online: true,
              ),
            );
          }

          if (mounted) {
            setState(() {
              _friends
                ..clear()
                ..addAll(loaded);
            });
          }
        }
      }

      // requests
      final reqJson = prefs.getString(_kPrefsRequests);
      if (reqJson != null && reqJson.trim().isNotEmpty) {
        final raw = jsonDecode(reqJson);
        if (raw is List) {
          final loaded = raw
              .whereType<Map>()
              .map((m) => _FriendRequest.fromJson(m.cast<String, dynamic>()))
              .toList();
          if (mounted) {
            setState(() {
              _requests
                ..clear()
                ..addAll(loaded);
            });
          }
        }
      } else {
        // default: demo request
        if (mounted) {
          setState(() {
            _requests.add(
              _FriendRequest(
                id: 'req_demo',
                fromName: 'Ken',
                fromInitials: 'K',
                fromColorValue: 0xFF7E57C2,
                message: '一起參加健走活動嗎？',
                createdAt: DateTime.now().subtract(const Duration(hours: 6)),
              ),
            );
          });
        }
        await _persistRequests();
      }

      // daily
      final dailyJson = prefs.getString(_kPrefsDaily);
      if (dailyJson != null && dailyJson.trim().isNotEmpty) {
        final m = jsonDecode(dailyJson);
        if (m is Map) {
          final map = m.cast<String, dynamic>();
          final date = (map['date'] ?? '').toString();
          final today = _yyyyMmDd(DateTime.now());
          if (date == today) {
            if (mounted) {
              setState(() {
                _signedToday = (map['signedToday'] == true);
                _todayDone = (map['todayDone'] is int)
                    ? map['todayDone'] as int
                    : _todayDone;
                _points = (map['points'] is int)
                    ? map['points'] as int
                    : _points;
                _streakDays = (map['streakDays'] is int)
                    ? map['streakDays'] as int
                    : _streakDays;
                _pollAnswer = map['pollAnswer']?.toString();
              });
            }
          }
        }
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _persistFriends() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _friends.map((f) => f.toJson()).toList();
      await prefs.setString(_kPrefsFriends, jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _persistRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _requests.map((r) => r.toJson()).toList();
      await prefs.setString(_kPrefsRequests, jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _persistDaily() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final m = {
        'date': _yyyyMmDd(DateTime.now()),
        'signedToday': _signedToday,
        'todayDone': _todayDone,
        'points': _points,
        'streakDays': _streakDays,
        'pollAnswer': _pollAnswer,
      };
      await prefs.setString(_kPrefsDaily, jsonEncode(m));
    } catch (_) {}
  }

  // ======================================================
  // Helpers / actions
  // ======================================================

  void _toast(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _yyyyMmDd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _genInviteCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<String> _getInviteCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kPrefsInviteCode);
    if (code != null && code.trim().isNotEmpty) {
      return code.trim();
    }
    final newCode = _genInviteCode();
    await prefs.setString(_kPrefsInviteCode, newCode);
    return newCode;
  }

  // ======================================================
  // Compose post (feed)
  // ======================================================

  Future<void> _pickImageForCompose() async {
    try {
      final x = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (x == null) {
        return;
      }
      final bytes = await x.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() => _pendingImageBytes = bytes);
    } catch (e) {
      _toast('選圖失敗：$e');
    }
  }

  void _openComposeSheet() {
    final contentCtrl = TextEditingController();
    final tagCtrl = TextEditingController(text: '#Osmile');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        final inset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + inset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '新增貼文',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_pendingImageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    _pendingImageBytes!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: contentCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '想分享什麼？（示範）',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tagCtrl,
                decoration: InputDecoration(
                  hintText: '#標籤（用逗號分隔）',
                  prefixIcon: const Icon(Icons.tag),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _pickImageForCompose();
                        if (mounted) {
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('選擇圖片'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: _primary.withValues(alpha: 0.35),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final text = contentCtrl.text.trim();
                        final tags = tagCtrl.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();

                        if (text.isEmpty && _pendingImageBytes == null) {
                          _toast('請輸入內容或選擇圖片');
                          return;
                        }

                        setState(() {
                          _posts.insert(
                            0,
                            _Post(
                              id: 'p_${DateTime.now().millisecondsSinceEpoch}',
                              user: '我',
                              time: '剛剛',
                              content: text.isEmpty ? '（圖片分享）' : text,
                              tags: tags.isEmpty ? const ['#Osmile'] : tags,
                              imageBytes: _pendingImageBytes,
                              imageUrl: null,
                              likes: 0,
                              liked: false,
                              comments: <_Comment>[],
                            ),
                          );
                          _pendingImageBytes = null;
                        });

                        Navigator.pop(context);
                        _toast('已發佈（示範）');
                        _pushNotif(
                          type: 'system',
                          title: '貼文已發佈',
                          message: '你的動態已成功發布。',
                          icon: Icons.dynamic_feed_outlined,
                        );
                      },
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('發佈'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      // 關閉時清掉暫存圖片，避免下次殘留
      if (mounted) {
        setState(() => _pendingImageBytes = null);
      }
    });
  }

  // ======================================================
  // Tag sheet
  // ======================================================

  void _openTagSheet(String tag) {
    final filtered = _posts.where((p) => p.tags.contains(tag)).toList();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '查看 $tag 相關貼文（示範）',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              if (filtered.isEmpty)
                Text('目前沒有相關貼文', style: TextStyle(color: Colors.grey.shade600))
              else
                ...filtered.take(6).map((p) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: _primary.withValues(alpha: 0.12),
                      foregroundColor: _primary,
                      child: Text(
                        p.user.isNotEmpty ? p.user[0] : '?',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    title: Text(
                      p.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('${p.user} · ${p.time}'),
                    onTap: () {
                      Navigator.pop(context);
                      _toast('已定位到貼文（示範）');
                    },
                  );
                }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _toast('查看更多 $tag（示範）');
                  },
                  icon: const Icon(Icons.search_outlined),
                  label: const Text('查看更多'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ======================================================
  // Friend system (add / accept / search)
  // ======================================================

  void _openAddFriendSheet() async {
    final code = await _getInviteCode();
    if (!mounted) {
      return;
    }

    final inputCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        final inset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + inset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '新增好友',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // My invite code
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _primary.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.qr_code_2_rounded,
                      color: _primary.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '我的邀請碼',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            code,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (mounted) {
                          _toast('已複製邀請碼');
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: _primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Text('複製'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Input invite code
              TextField(
                controller: inputCtrl,
                decoration: InputDecoration(
                  hintText: '輸入對方邀請碼（示範）',
                  prefixIcon: const Icon(Icons.person_add_alt_1_outlined),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final v = inputCtrl.text.trim().toUpperCase();
                        if (v.isEmpty) {
                          _toast('請輸入邀請碼');
                          return;
                        }
                        setState(() {
                          _requests.insert(
                            0,
                            _FriendRequest(
                              id: 'req_${DateTime.now().millisecondsSinceEpoch}',
                              fromName: '邀請碼 $v',
                              fromInitials: '☆',
                              fromColorValue: 0xFF26A69A,
                              message: '想加你為好友（示範）',
                              createdAt: DateTime.now(),
                            ),
                          );
                        });
                        _persistRequests();
                        Navigator.pop(context);
                        _toast('已送出 / 收到好友邀請（示範）');
                        _pushNotif(
                          type: 'system',
                          title: '收到好友邀請',
                          message: '有一筆新的好友邀請（示範）。',
                          icon: Icons.group_add_outlined,
                        );
                      },
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('送出邀請'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: _primary.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final sug = _Friend(
                          id: 'f_${DateTime.now().millisecondsSinceEpoch}',
                          name: '新朋友',
                          initials: '新',
                          colorValue: 0xFF7E57C2,
                          online: true,
                        );
                        setState(() {
                          if (_friends.every((x) => x.id != sug.id)) {
                            _friends.add(sug);
                          }
                        });
                        _persistFriends();
                        Navigator.pop(context);
                        _toast('已加入好友（示範）');
                        _pushNotif(
                          type: 'system',
                          title: '好友已新增',
                          message: '你已新增一位好友：${sug.name}',
                          icon: Icons.person_add_alt_1,
                        );
                      },
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('一鍵加入'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '你可能認識',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FriendChip(
                    name: 'Mina',
                    initials: 'M',
                    color: const Color(0xFFEF5350),
                    onAdd: () {
                      _acceptFriendDirect(
                        const _Friend(
                          id: 'f_mina',
                          name: 'Mina',
                          initials: 'M',
                          colorValue: 0xFFEF5350,
                          online: true,
                        ),
                      );
                      Navigator.pop(context);
                    },
                  ),
                  _FriendChip(
                    name: 'Leo',
                    initials: 'L',
                    color: const Color(0xFF42A5F5),
                    onAdd: () {
                      _acceptFriendDirect(
                        const _Friend(
                          id: 'f_leo',
                          name: 'Leo',
                          initials: 'L',
                          colorValue: 0xFF42A5F5,
                          online: false,
                        ),
                      );
                      Navigator.pop(context);
                    },
                  ),
                  _FriendChip(
                    name: 'Nina',
                    initials: 'N',
                    color: const Color(0xFF66BB6A),
                    onAdd: () {
                      _acceptFriendDirect(
                        const _Friend(
                          id: 'f_nina',
                          name: 'Nina',
                          initials: 'N',
                          colorValue: 0xFF66BB6A,
                          online: true,
                        ),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 14),
            ],
          ),
        );
      },
    );
  }

  void _acceptFriendDirect(_Friend f) {
    setState(() {
      if (_friends.any((x) => x.id == f.id)) {
        return;
      }
      _friends.add(f);
    });
    _persistFriends();
    _toast('已加入好友：${f.name}');
    _pushNotif(
      type: 'system',
      title: '好友已新增',
      message: '你已加入好友：${f.name}',
      icon: Icons.person_add_alt_1,
    );
  }

  void _acceptRequest(_FriendRequest r) {
    final friend = _Friend(
      id: 'f_${r.id}',
      name: r.fromName,
      initials: r.fromInitials,
      colorValue: r.fromColorValue,
      online: true,
    );
    setState(() {
      _requests.removeWhere((x) => x.id == r.id);
      if (_friends.every((x) => x.id != friend.id)) {
        _friends.add(friend);
      }
    });
    _persistFriends();
    _persistRequests();
    _toast('已接受好友邀請：${r.fromName}');
    _pushNotif(
      type: 'system',
      title: '好友邀請已接受',
      message: '你已新增好友：${r.fromName}',
      icon: Icons.verified_outlined,
    );
  }

  void _declineRequest(_FriendRequest r) {
    setState(() => _requests.removeWhere((x) => x.id == r.id));
    _persistRequests();
    _toast('已拒絕（示範）');
    _pushNotif(
      type: 'system',
      title: '已拒絕好友邀請',
      message: '你已拒絕：${r.fromName}',
      icon: Icons.person_remove_outlined,
    );
  }

  void _openFriendDetail(_Friend f) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        final color = Color(f.colorValue);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: color.withValues(alpha: 0.18),
                    foregroundColor: color,
                    child: Text(
                      f.initials,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          f.online ? '在線中' : '離線中',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _toast('已釘選 ${f.name}（示範）');
                      _pushNotif(
                        type: 'system',
                        title: '好友已釘選',
                        message: '你已釘選：${f.name}',
                        icon: Icons.push_pin_outlined,
                      );
                    },
                    icon: const Icon(Icons.push_pin_outlined),
                    tooltip: '釘選',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _toast('開啟與 ${f.name} 的聊天（示範）');
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('發訊息'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _friends.removeWhere((x) => x.id == f.id);
                        });
                        _persistFriends();
                        _toast('已移除好友（示範）');
                        _pushNotif(
                          type: 'system',
                          title: '好友已移除',
                          message: '你已移除：${f.name}',
                          icon: Icons.person_remove_outlined,
                        );
                      },
                      icon: const Icon(Icons.person_remove_outlined),
                      label: const Text('移除'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(
                          color: Colors.redAccent.withValues(alpha: 0.35),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ======================================================
  // Activity
  // ======================================================

  void _stopBannerAuto() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
  }

  void _startBannerAuto() {
    _stopBannerAuto();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) {
        return;
      }
      if (_tabIndex != 2) {
        return; // ✅ 非活動頁不輪播
      }
      if (!_bannerController.hasClients) {
        return; // ✅ 修正 PageController not attached
      }
      if (_banners.isEmpty) {
        return;
      }

      final next = (_bannerIndex + 1) % _banners.length;
      setState(() => _bannerIndex = next);

      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOut,
      );
    });
  }

  void _playReward({
    required int points,
    String? toast,
    String? notifTitle,
    String? notifMsg,
  }) {
    setState(() {
      _points += points;
    });
    _confetti.play();
    _persistDaily();
    if (toast != null) {
      _toast(toast);
    }

    if (notifTitle != null && notifMsg != null) {
      _pushNotif(
        type: 'lottery',
        title: notifTitle,
        message: notifMsg,
        icon: Icons.star_outline,
      );
    }
  }

  void _signToday() {
    if (_signedToday) {
      _toast('今天已簽到');
      return;
    }
    setState(() {
      _signedToday = true;
      _streakDays = (_streakDays + 1).clamp(1, 9999);
    });
    _persistDaily();
    _playReward(
      points: 15,
      toast: '簽到成功 +15 點',
      notifTitle: '簽到成功',
      notifMsg: '你已簽到並獲得 +15 點（示範）',
    );
  }

  void _advanceTodayChallenge() {
    setState(() {
      _todayDone = (_todayDone + 1).clamp(0, _todayGoal);
    });
    _persistDaily();

    if (_todayDone >= _todayGoal) {
      _playReward(
        points: 20,
        toast: '完成今日挑戰 +20 點',
        notifTitle: '今日挑戰完成',
        notifMsg: '恭喜完成今日互動挑戰，獲得 +20 點（示範）',
      );
    } else {
      _toast('挑戰進度 +1（示範）');
      _pushNotif(
        type: 'system',
        title: '挑戰進度更新',
        message: '今日互動挑戰進度：$_todayDone / $_todayGoal',
        icon: Icons.insights_outlined,
      );
    }
  }

  void _openEventDetail(_ActivityEvent e) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        final inset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + inset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  e.imageUrl,
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 170,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  e.subtitle,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '進度',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const Spacer(),
                        Text(
                          '${(e.progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: e.progress.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        color: _brand,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '完成可獲得 +${e.rewardPoints} 點',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _toast('已加入行事曆（示範）');
                        _pushNotif(
                          type: 'system',
                          title: '活動提醒已設定',
                          message: '已為「${e.title}」設定提醒（示範）',
                          icon: Icons.event_available_outlined,
                        );
                      },
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('提醒我'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: BorderSide(
                          color: _primary.withValues(alpha: 0.35),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        bool justJoined = false;
                        bool justCompleted = false;

                        setState(() {
                          if (!e.joined) {
                            justJoined = true;
                            e.joined = true;
                            e.progress = max(e.progress, 0.05);
                          } else {
                            e.progress = (e.progress + 0.20).clamp(0.0, 1.0);
                            if (e.progress >= 1.0) {
                              justCompleted = true;
                            }
                          }
                        });
                        _persistDaily();
                        Navigator.pop(context);

                        if (justCompleted) {
                          _playReward(
                            points: e.rewardPoints,
                            toast: '任務完成 +${e.rewardPoints} 點',
                            notifTitle: '活動任務完成',
                            notifMsg:
                                '「${e.title}」完成，獲得 +${e.rewardPoints} 點（示範）',
                          );
                        } else {
                          _toast(justJoined ? '報名成功（示範）' : '已打卡（示範）');
                          _confetti.play();

                          _pushNotif(
                            type: 'system',
                            title: justJoined ? '活動已報名' : '活動已打卡',
                            message: justJoined
                                ? '你已報名「${e.title}」（示範）'
                                : '你在「${e.title}」完成一次打卡（示範）',
                            icon: justJoined
                                ? Icons.how_to_reg_rounded
                                : Icons.flag_rounded,
                          );
                        }
                      },
                      icon: Icon(
                        e.joined
                            ? Icons.flag_rounded
                            : Icons.how_to_reg_rounded,
                      ),
                      label: Text(e.joined ? '打卡' : '立即報名'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: e.joined ? _primary : _brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ======================================================
  // UI
  // ======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('互動', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.8,
        bottom: TabBar(
          controller: _tab,
          labelColor: _brand,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: _brand,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.dynamic_feed_outlined), text: '動態'),
            Tab(icon: Icon(Icons.group_outlined), text: '好友'),
            Tab(icon: Icon(Icons.emoji_events_outlined), text: '活動'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tab,
            children: [
              _buildFeedTab(),
              _buildFriendsTab(),
              _buildActivityTab(),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 18,
              gravity: 0.18,
              colors: const [
                Colors.orange,
                Colors.blueAccent,
                Colors.greenAccent,
                Colors.pinkAccent,
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'interaction_fab',
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        onPressed: () {
          if (_tabIndex == 0) {
            _openComposeSheet();
          } else if (_tabIndex == 1) {
            _openAddFriendSheet();
          } else {
            _toast('建立活動（示範）');
            _pushNotif(
              type: 'system',
              title: '建立活動（示範）',
              message: '此功能可在下一步串接後端/Firestore。',
              icon: Icons.emoji_events_outlined,
            );
          }
        },
        child: Icon(
          _tabIndex == 0
              ? Icons.add
              : (_tabIndex == 1 ? Icons.person_add_alt_1 : Icons.emoji_events),
        ),
      ),
    );
  }

  // ---------------------------
  // Tab 1: Feed
  // ---------------------------
  Widget _buildFeedTab() {
    final progress = (_todayGoal == 0)
        ? 0.0
        : (_todayDone / _todayGoal).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      children: [
        _PointsHeader(
          points: _points,
          streakDays: _streakDays,
          onSign: _signToday,
          signedToday: _signedToday,
        ),
        const SizedBox(height: 12),

        _TodayChallengeCard(
          done: _todayDone,
          goal: _todayGoal,
          progress: progress,
          onTap: _advanceTodayChallenge,
        ),
        const SizedBox(height: 12),

        _PollCard(
          value: _pollAnswer,
          onSelect: (v) {
            setState(() => _pollAnswer = v);
            _persistDaily();
            _toast('已送出回答：$v（示範）');
            _playReward(
              points: 5,
              toast: '回答小調查 +5 點',
              notifTitle: '小調查完成',
              notifMsg: '你完成了今日小調查，獲得 +5 點（示範）',
            );
          },
        ),
        const SizedBox(height: 12),

        _FriendsRow(
          friends: _friends.take(8).toList(),
          onTapFriend: (f) => _openFriendDetail(f),
          onTapAdd: _openAddFriendSheet,
        ),
        const SizedBox(height: 10),

        _TagRow(tags: _tags, onTap: _openTagSheet),
        const SizedBox(height: 12),

        _LeaderboardCard(leaders: _leaders),
        const SizedBox(height: 12),

        for (final p in _posts) ...[
          _PostCard(
            post: p,
            brand: _brand,
            primary: _primary,
            onTapTag: _openTagSheet,
            onLike: () {
              setState(() {
                p.liked = !p.liked;
                p.likes += p.liked ? 1 : -1;
              });
              if (p.liked) {
                _playReward(
                  points: 1,
                  notifTitle: '互動獎勵',
                  notifMsg: '你按讚獲得 +1 點（示範）',
                );
                _pushNotif(
                  type: 'system',
                  title: '你按了一個讚',
                  message: '互動已記錄（示範）',
                  icon: Icons.favorite_rounded,
                );
              }
            },
            onAddComment: (text) {
              setState(() => p.comments.add(_Comment(user: '我', text: text)));
              _playReward(
                points: 2,
                toast: '留言 +2 點',
                notifTitle: '互動獎勵',
                notifMsg: '你留言獲得 +2 點（示範）',
              );
              _pushNotif(
                type: 'system',
                title: '留言已送出',
                message: '你的留言已發布（示範）',
                icon: Icons.mode_comment_outlined,
              );
            },
            onShare: () {
              _toast('已分享（示範）');
              _pushNotif(
                type: 'system',
                title: '已分享動態',
                message: '分享成功（示範）',
                icon: Icons.ios_share_rounded,
              );
            },
            onMore: () => _toast('更多操作（示範）'),
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 70),
      ],
    );
  }

  // ---------------------------
  // Tab 2: Friends
  // ---------------------------
  Widget _buildFriendsTab() {
    final list = _friends.where((f) => f.id != 'me').toList();

    final filtered = _friendSearch.trim().isEmpty
        ? list
        : list
              .where(
                (f) => f.name.toLowerCase().contains(
                  _friendSearch.trim().toLowerCase(),
                ),
              )
              .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _friendSearch = v),
                decoration: InputDecoration(
                  hintText: '搜尋好友…',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: _openAddFriendSheet,
              style: IconButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.person_add_alt_1),
              tooltip: '新增好友',
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_requests.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '好友邀請',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                for (final r in _requests.take(5)) ...[
                  _FriendRequestTile(
                    req: r,
                    onAccept: () => _acceptRequest(r),
                    onDecline: () => _declineRequest(r),
                  ),
                  if (r != _requests.take(5).last) const Divider(height: 18),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (filtered.isEmpty)
          _EmptyHint(
            icon: Icons.group_off_outlined,
            title: '找不到好友',
            subtitle: '試試看換關鍵字或新增好友。',
            buttonText: '新增好友',
            onPressed: _openAddFriendSheet,
          )
        else
          ...filtered.map((f) {
            final c = Color(f.colorValue);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ListTile(
                onTap: () => _openFriendDetail(f),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: c.withValues(alpha: 0.16),
                      foregroundColor: c,
                      child: Text(
                        f.initials,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: f.online ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Text(
                  f.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  f.online ? '在線中' : '離線中',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                trailing: ElevatedButton(
                  onPressed: () => _toast('開啟與 ${f.name} 的聊天（示範）'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('發訊息'),
                ),
              ),
            );
          }),

        const SizedBox(height: 70),
      ],
    );
  }

  // ---------------------------
  // Tab 3: Activity (fun)
  // ---------------------------
  Widget _buildActivityTab() {
    const categories = ['全部', '健康挑戰', '親子互動', 'Osmile 功能'];
    final filtered = _selectedActivityCategory == '全部'
        ? _events
        : _events
              .where((e) => e.category == _selectedActivityCategory)
              .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _brand.withValues(alpha: 0.18),
                _primary.withValues(alpha: 0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.emoji_events_rounded, color: _brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '活動中心',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '玩任務、拿點數、換徽章（示範）',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$_points',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '點數',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _bannerIndex = i),
            itemBuilder: (_, i) => _BannerCard(
              item: _banners[i],
              onTap: () => _toast('開啟活動：${_banners[i].title}（示範）'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _banners.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _bannerIndex ? 18 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == _bannerIndex ? _brand : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: categories.map((c) {
            final selected = _selectedActivityCategory == c;
            return ChoiceChip(
              showCheckmark: false,
              selected: selected,
              onSelected: (_) => setState(() => _selectedActivityCategory = c),
              selectedColor: _brand,
              backgroundColor: Colors.white,
              side: BorderSide(color: selected ? _brand : Colors.grey.shade200),
              label: Text(
                c,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        if (filtered.isEmpty)
          _EmptyHint(
            icon: Icons.event_busy_outlined,
            title: '目前沒有符合的活動',
            subtitle: '換個分類看看，或等下一波活動。',
            buttonText: '重設分類',
            onPressed: () => setState(() => _selectedActivityCategory = '全部'),
          )
        else
          ...filtered.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ActivityCard(
                event: e,
                brand: _brand,
                primary: _primary,
                onTap: () => _openEventDetail(e),
                onJoinOrCheck: () {
                  bool justJoined = false;
                  bool completed = false;

                  setState(() {
                    if (!e.joined) {
                      justJoined = true;
                      e.joined = true;
                      e.progress = max(e.progress, 0.05);
                    } else {
                      e.progress = (e.progress + 0.20).clamp(0.0, 1.0);
                      if (e.progress >= 1.0) {
                        completed = true;
                      }
                    }
                  });

                  if (justJoined) {
                    _playReward(
                      points: 3,
                      toast: '報名 +3 點',
                      notifTitle: '活動報名成功',
                      notifMsg: '你已報名「${e.title}」，獲得 +3 點（示範）',
                    );
                  } else if (completed) {
                    _playReward(
                      points: e.rewardPoints,
                      toast: '任務完成 +${e.rewardPoints} 點',
                      notifTitle: '活動任務完成',
                      notifMsg: '「${e.title}」完成，獲得 +${e.rewardPoints} 點（示範）',
                    );
                  } else {
                    _playReward(
                      points: 2,
                      toast: '打卡 +2 點',
                      notifTitle: '活動打卡',
                      notifMsg: '你在「${e.title}」完成一次打卡，獲得 +2 點（示範）',
                    );
                  }

                  _persistDaily();
                },
              ),
            );
          }),

        const SizedBox(height: 70),
      ],
    );
  }
}

// ======================================================================
// Widgets (UI components)
// ======================================================================

class _PointsHeader extends StatelessWidget {
  final int points;
  final int streakDays;
  final bool signedToday;
  final VoidCallback onSign;

  const _PointsHeader({
    required this.points,
    required this.streakDays,
    required this.signedToday,
    required this.onSign,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.orangeAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '連續 $streakDays 天活躍',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '累積點數：$points',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: signedToday ? null : onSign,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              signedToday ? '已簽到' : '簽到',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayChallengeCard extends StatelessWidget {
  final int done;
  final int goal;
  final double progress;
  final VoidCallback onTap;

  const _TodayChallengeCard({
    required this.done,
    required this.goal,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orangeAccent.withValues(alpha: 0.12),
            Colors.blueAccent.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              color: Colors.orangeAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今日互動挑戰',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '按讚 + 留言累積進度，達成可領點數（示範）',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: progress,
                    backgroundColor: Colors.white,
                    color: Colors.orangeAccent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '進度：$done / $goal',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              '去挑戰',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onSelect;

  const _PollCard({required this.value, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    Widget chip(String t) {
      final selected = value == t;
      return ChoiceChip(
        showCheckmark: false,
        selected: selected,
        onSelected: (_) => onSelect(t),
        label: Text(
          t,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
        selectedColor: Colors.orangeAccent,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected ? Colors.orangeAccent : Colors.grey.shade200,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('今日小調查', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            '你今天有跟 Osmile 手錶互動了嗎？',
            style: TextStyle(color: Colors.grey.shade700, height: 1.2),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [chip('有，已記錄運動'), chip('等一下準備運動'), chip('今天先休息一下')],
          ),
          const SizedBox(height: 8),
          Text(
            value == null ? '我的回答：尚未作答' : '我的回答：$value',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ✅ 修正溢位：縮小卡片 + mainAxisSize.min + FittedBox(scaleDown)
class _FriendsRow extends StatelessWidget {
  final List<_Friend> friends;
  final ValueChanged<_Friend> onTapFriend;
  final VoidCallback onTapAdd;

  const _FriendsRow({
    required this.friends,
    required this.onTapFriend,
    required this.onTapAdd,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: friends.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          Widget nameText(String text) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
            );
          }

          if (i == 0) {
            return InkWell(
              onTap: onTapAdd,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 76,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.orangeAccent.withValues(
                        alpha: 0.16,
                      ),
                      foregroundColor: Colors.orangeAccent,
                      child: const Icon(Icons.person_add_alt_1, size: 20),
                    ),
                    const SizedBox(height: 4),
                    nameText('加好友'),
                  ],
                ),
              ),
            );
          }

          final f = friends[i - 1];
          final c = Color(f.colorValue);

          return InkWell(
            onTap: () => onTapFriend(f),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 76,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: c.withValues(alpha: 0.18),
                        foregroundColor: c,
                        child: Text(
                          f.initials,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: f.online ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  nameText(f.name),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  final List<String> tags;
  final ValueChanged<String> onTap;

  const _TagRow({required this.tags, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tags.map((t) {
        return InkWell(
          onTap: () => onTap(t),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              t,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  final List<_Leader> leaders;

  const _LeaderboardCard({required this.leaders});

  @override
  Widget build(BuildContext context) {
    final maxScore = leaders.isEmpty
        ? 1
        : leaders.map((e) => e.score).reduce((a, b) => a > b ? a : b);

    Widget row(_Leader l, int rank) {
      final percent = (l.score / maxScore).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '$rank',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const Icon(
              Icons.local_fire_department,
              color: Colors.orangeAccent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  color: Colors.orangeAccent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${l.score}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('人氣排行榜', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            '本週互動熱度（示範）',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          for (int i = 0; i < leaders.length; i++) row(leaders[i], i + 1),
        ],
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final _Post post;
  final Color brand;
  final Color primary;
  final ValueChanged<String> onTapTag;
  final VoidCallback onLike;
  final ValueChanged<String> onAddComment;
  final VoidCallback onShare;
  final VoidCallback onMore;

  const _PostCard({
    required this.post,
    required this.brand,
    required this.primary,
    required this.onTapTag,
    required this.onLike,
    required this.onAddComment,
    required this.onShare,
    required this.onMore,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _showComments = false;
  final TextEditingController _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Widget _imgFallback() => Container(
    height: 190,
    color: Colors.grey.shade200,
    alignment: Alignment.center,
    child: const Icon(
      Icons.broken_image_outlined,
      color: Colors.grey,
      size: 42,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = widget.post;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: widget.primary.withValues(alpha: 0.12),
              foregroundColor: widget.primary,
              child: Text(
                p.user.isNotEmpty ? p.user[0] : '?',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            title: Text(
              p.user,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              p.time,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            trailing: IconButton(
              onPressed: widget.onMore,
              icon: const Icon(Icons.more_horiz),
              tooltip: '更多',
            ),
          ),

          if (p.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: p.tags.map((t) {
                  return InkWell(
                    onTap: () => widget.onTapTag(t),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          if (p.imageBytes != null)
            Image.memory(
              p.imageBytes!,
              height: 190,
              width: double.infinity,
              fit: BoxFit.cover,
            )
          else if (p.imageUrl != null && p.imageUrl!.isNotEmpty)
            Image.network(
              p.imageUrl!,
              height: 190,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _imgFallback(),
            )
          else
            _imgFallback(),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Text(p.content, style: const TextStyle(height: 1.35)),
          ),

          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: widget.onLike,
                  icon: Icon(
                    p.liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: p.liked ? Colors.redAccent : Colors.grey.shade700,
                  ),
                  label: Text(
                    '${p.likes}',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _showComments = !_showComments);
                  },
                  icon: Icon(
                    Icons.mode_comment_outlined,
                    color: Colors.grey.shade700,
                  ),
                  label: Text(
                    '${p.comments.length}',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onShare,
                  icon: Icon(
                    Icons.ios_share_rounded,
                    color: Colors.grey.shade700,
                  ),
                  tooltip: '分享',
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _showComments = true);
                  },
                  icon: Icon(Icons.add_comment_outlined, color: widget.brand),
                  tooltip: '留言',
                ),
              ],
            ),
          ),

          if (_showComments) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                children: [
                  if (p.comments.isEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '目前沒有留言，來當第一個吧。',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  else
                    ...p.comments.map((c) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: widget.primary.withValues(
                                alpha: 0.12,
                              ),
                              foregroundColor: widget.primary,
                              child: Text(
                                c.user.isNotEmpty ? c.user[0] : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      color: Colors.grey.shade900,
                                      height: 1.3,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '${c.user}  ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      TextSpan(text: c.text),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          decoration: InputDecoration(
                            hintText: '輸入留言…',
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          final text = _commentCtrl.text.trim();
                          if (text.isEmpty) {
                            return;
                          }
                          widget.onAddComment(text);
                          _commentCtrl.clear();
                          setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '送出',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FriendRequestTile extends StatelessWidget {
  final _FriendRequest req;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _FriendRequestTile({
    required this.req,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final c = Color(req.fromColorValue);
    final timeText = _relativeTime(req.createdAt);

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: c.withValues(alpha: 0.16),
          foregroundColor: c,
          child: Text(
            req.fromInitials,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                req.fromName,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                req.message,
                style: TextStyle(color: Colors.grey.shade700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                timeText,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onDecline,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.35)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text('拒絕'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onAccept,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            '接受',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) {
      return '${max(1, diff.inMinutes)} 分鐘前';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} 小時前';
    }
    return '${diff.inDays} 天前';
  }
}

class _FriendChip extends StatelessWidget {
  final String name;
  final String initials;
  final Color color;
  final VoidCallback onAdd;

  const _FriendChip({
    required this.name,
    required this.initials,
    required this.color,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.16),
            foregroundColor: color,
            child: Text(
              initials,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '加入',
          ),
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final _BannerItem item;
  final VoidCallback onTap;

  const _BannerCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          image: DecorationImage(
            image: NetworkImage(item.imageUrl),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.30),
              BlendMode.darken,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    item.tag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final _ActivityEvent event;
  final Color brand;
  final Color primary;
  final VoidCallback onTap;
  final VoidCallback onJoinOrCheck;

  const _ActivityCard({
    required this.event,
    required this.brand,
    required this.primary,
    required this.onTap,
    required this.onJoinOrCheck,
  });

  @override
  Widget build(BuildContext context) {
    final btnColor = event.joined ? primary : brand;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: Image.network(
                event.imageUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 150,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.grey,
                    size: 40,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.subtitle,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: event.progress.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            color: brand,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(event.progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          '完成 +${event.rewardPoints} 點',
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: onJoinOrCheck,
                        icon: Icon(
                          event.joined
                              ? Icons.flag_rounded
                              : Icons.how_to_reg_rounded,
                        ),
                        label: Text(
                          event.joined ? '打卡' : '報名',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: btnColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
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
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Models
// ======================================================================

class _Friend {
  final String id;
  final String name;
  final String initials;
  final int colorValue;
  final bool online;

  const _Friend({
    required this.id,
    required this.name,
    required this.initials,
    required this.colorValue,
    required this.online,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'initials': initials,
    'colorValue': colorValue,
    'online': online,
  };

  factory _Friend.fromJson(Map<String, dynamic> m) => _Friend(
    id: (m['id'] ?? '').toString(),
    name: (m['name'] ?? '').toString(),
    initials: (m['initials'] ?? '').toString(),
    colorValue: (m['colorValue'] is int)
        ? (m['colorValue'] as int)
        : 0xFF1976D2,
    online: m['online'] == true,
  );
}

class _FriendRequest {
  final String id;
  final String fromName;
  final String fromInitials;
  final int fromColorValue;
  final String message;
  final DateTime createdAt;

  _FriendRequest({
    required this.id,
    required this.fromName,
    required this.fromInitials,
    required this.fromColorValue,
    required this.message,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromName': fromName,
    'fromInitials': fromInitials,
    'fromColorValue': fromColorValue,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
  };

  factory _FriendRequest.fromJson(Map<String, dynamic> m) => _FriendRequest(
    id: (m['id'] ?? '').toString(),
    fromName: (m['fromName'] ?? '').toString(),
    fromInitials: (m['fromInitials'] ?? '').toString(),
    fromColorValue: (m['fromColorValue'] is int)
        ? (m['fromColorValue'] as int)
        : 0xFF7E57C2,
    message: (m['message'] ?? '').toString(),
    createdAt:
        DateTime.tryParse((m['createdAt'] ?? '').toString()) ?? DateTime.now(),
  );
}

class _Leader {
  final String name;
  final int score;

  _Leader({required this.name, required this.score});
}

class _Comment {
  final String user;
  final String text;

  const _Comment({required this.user, required this.text});
}

class _Post {
  final String id;
  final String user;
  final String time;
  final String content;

  final List<String> tags;

  final String? imageUrl; // network
  final Uint8List? imageBytes; // local bytes (web-friendly)

  int likes;
  bool liked;
  final List<_Comment> comments;

  _Post({
    required this.id,
    required this.user,
    required this.time,
    required this.content,
    required this.tags,
    required this.likes,
    required this.comments,
    this.imageUrl,
    this.imageBytes,
    this.liked = false,
  });
}

class _BannerItem {
  final String title;
  final String subtitle;
  final String imageUrl;
  final String tag;

  const _BannerItem({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.tag,
  });
}

class _ActivityEvent {
  final String id;
  final String category;
  final String title;
  final String subtitle;
  final String imageUrl;

  bool joined;
  double progress;
  final int rewardPoints;

  _ActivityEvent({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.joined,
    required this.progress,
    required this.rewardPoints,
  });
}
