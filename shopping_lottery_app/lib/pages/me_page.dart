// lib/pages/me_page.dart
// =====================================================
// ✅ MePage（我的頁｜功能全開完整版）
// -----------------------------------------------------
// - 快捷入口：我的訂單 / 優惠券 / 收藏 / 購物車 / 通知 / 客服（全部可點）
// - Badge：收藏數、未讀通知數（自動顯示）
// - 裝置狀態：前往配對
// - 健康摘要：步數/睡眠/心率/血壓（可點進健康頁）
// - 安全功能：SOS（可點進 SOS 頁）
// - 個人資料：編輯、登出、積分顯示（SharedPreferences + FirestoreMockService 兼容）
// - 導頁採「優先 pushNamed，沒有 route 時提示」避免你專案檔名不同導致編譯炸裂
// =====================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/cart_service.dart';
import '../services/wishlist_service.dart';
import '../services/notification_service.dart';
import '../services/firestore_mock_service.dart';

class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  static const Color _bg = Color(0xFFF4F6F9);
  static const Color _brand = Colors.blueAccent;

  static const String _prefsProfileKey = 'os_me_profile_v1';
  static const String _prefsHealthKey = 'os_health_summary_v1';

  String _name = 'Demo';
  String _phone = '09xx-xxx-xxx';
  int _points = 0;

  bool _deviceConnected = false;

  // health summary
  int _steps = 1904;
  double _sleepHours = 7.7;
  int _hr = 84;
  String _bp = '112/76';
  DateTime? _lastSyncAt;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    await _loadProfile();
    await _loadPoints();
    await _loadHealth();
    await _loadDeviceStatus();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsProfileKey);
      if (raw == null) return;
      final m = jsonDecode(raw);
      if (m is Map) {
        final mm = Map<String, dynamic>.from(m);
        _name = (mm['name'] ?? _name).toString();
        _phone = (mm['phone'] ?? _phone).toString();
      }
    } catch (_) {}
  }

  Future<void> _saveProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsProfileKey,
        jsonEncode({'name': _name, 'phone': _phone}),
      );
    } catch (_) {}
  }

  Future<void> _loadPoints() async {
    // 兼容 FirestoreMockService（若你有 points API 就讀；沒有就用本地）
    int local = _points;
    try {
      await FirestoreMockService.instance.init();
      final dyn = FirestoreMockService.instance as dynamic;

      // 嘗試：getPoints()
      try {
        final v = await dyn.getPoints();
        if (v is num) local = v.toInt();
      } catch (_) {}

      // 嘗試：points / userPoints 欄位
      try {
        final v = dyn.points;
        if (v is num) local = v.toInt();
      } catch (_) {}
      try {
        final v = dyn.userPoints;
        if (v is num) local = v.toInt();
      } catch (_) {}
    } catch (_) {}

    _points = local;
  }

  Future<void> _loadHealth() async {
    // 有健康 service 就接，沒有就用本地 prefs + 預設 demo
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsHealthKey);
      if (raw != null) {
        final m = jsonDecode(raw);
        if (m is Map) {
          final mm = Map<String, dynamic>.from(m);
          _steps = _toInt(mm['steps'], fallback: _steps);
          _sleepHours = _toDouble(mm['sleepHours'], fallback: _sleepHours);
          _hr = _toInt(mm['hr'], fallback: _hr);
          _bp = (mm['bp'] ?? _bp).toString();
          final ts = _toInt(mm['lastSyncAt'], fallback: 0);
          _lastSyncAt = ts > 0 ? DateTime.fromMillisecondsSinceEpoch(ts) : _lastSyncAt;
        }
      }
    } catch (_) {}

    // 嘗試從 FirestoreMockService 讀（如果你有 health snapshot）
    try {
      await FirestoreMockService.instance.init();
      final dyn = FirestoreMockService.instance as dynamic;

      try {
        final snap = await dyn.getHealthSummary();
        if (snap is Map) {
          final mm = Map<String, dynamic>.from(snap);
          _steps = _toInt(mm['steps'], fallback: _steps);
          _sleepHours = _toDouble(mm['sleepHours'], fallback: _sleepHours);
          _hr = _toInt(mm['hr'], fallback: _hr);
          _bp = (mm['bp'] ?? _bp).toString();
          final ts = _toInt(mm['lastSyncAt'], fallback: 0);
          _lastSyncAt = ts > 0 ? DateTime.fromMillisecondsSinceEpoch(ts) : _lastSyncAt;
        }
      } catch (_) {}
    } catch (_) {}

    _lastSyncAt ??= DateTime.now();
  }

  Future<void> _loadDeviceStatus() async {
    // 若你有裝置 service，這裡可替換；目前用 mock（未連線）
    // 也嘗試從 FirestoreMockService 讀 connected
    bool connected = false;
    try {
      final dyn = FirestoreMockService.instance as dynamic;
      try {
        final v = dyn.isDeviceConnected;
        if (v is bool) connected = v;
      } catch (_) {}
      try {
        final v = await dyn.getDeviceConnected();
        if (v is bool) connected = v;
      } catch (_) {}
    } catch (_) {}

    _deviceConnected = connected;
  }

  int _cartCount(dynamic cartItems) {
    // 兼容 items 可能是 List<Map> 或 List<CartItem>
    if (cartItems is! List) return 0;
    int sum = 0;
    for (final it in cartItems) {
      if (it is Map) {
        sum += _toInt(it['qty'] ?? it['quantity'], fallback: 1).clamp(1, 999);
      } else {
        try {
          final any = it as dynamic;
          sum += _toInt(any.qty ?? any.quantity ?? any.count, fallback: 1).clamp(1, 999);
        } catch (_) {
          sum += 1;
        }
      }
    }
    return sum;
  }

  int _wishlistCount(WishlistService ws) {
    // 兼容不同命名
    try {
      final list = (ws as dynamic).items;
      if (list is List) return list.length;
    } catch (_) {}
    try {
      final list = (ws as dynamic).wishlist;
      if (list is List) return list.length;
    } catch (_) {}
    return 0;
  }

  int _unreadNotiCount() {
    // 兼容 NotificationService 不同欄位
    final ns = NotificationService.instance;
    try {
      final v = (ns as dynamic).unreadCount;
      if (v is num) return v.toInt();
    } catch (_) {}
    try {
      final list = (ns as dynamic).notifications;
      if (list is List) {
        // 若每筆有 read:false
        final unread = list.where((e) {
          try {
            final m = e as dynamic;
            return (m['read'] == false) || (m.read == false);
          } catch (_) {
            return false;
          }
        }).length;
        return unread;
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _openNamed(String routeName) async {
    try {
      if (!mounted) return;
      await Navigator.pushNamed(context, routeName);
    } catch (e) {
      _toast('尚未設定路由：$routeName\n請在 main.dart routes 加上對應頁面');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _editProfile() async {
    final nameCtl = TextEditingController(text: _name);
    final phoneCtl = TextEditingController(text: _phone);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              const Text('編輯個人資料',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(
                  labelText: '姓名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtl,
                decoration: const InputDecoration(
                  labelText: '手機',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _name = nameCtl.text.trim().isEmpty ? _name : nameCtl.text.trim();
                      _phone = phoneCtl.text.trim().isEmpty ? _phone : phoneCtl.text.trim();
                    });
                    await _saveProfile();
                    if (mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('儲存', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    // 若你有 AuthService，這裡可串 logout；目前先回首頁（或 pop 到 root）
    try {
      Navigator.popUntil(context, (r) => r.isFirst);
      _toast('已登出（示範）');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final wishlist = context.watch<WishlistService>();

    final cartItems = cart.items;
    final cartCount = _cartCount(cartItems);
    final favCount = _wishlistCount(wishlist);
    final unread = _unreadNotiCount();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _bootstrap,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            children: [
              _buildHeader(),
              const SizedBox(height: 14),

              _sectionTitle(
                title: '快捷入口',
                trailing: TextButton(
                  onPressed: () => _openNamed('/notifications'),
                  child: const Text('查看通知'),
                ),
              ),
              const SizedBox(height: 10),
              _buildQuickGrid(
                cartCount: cartCount,
                favCount: favCount,
                unread: unread,
              ),

              const SizedBox(height: 14),
              _sectionTitle(
                title: '裝置狀態',
                trailing: TextButton(
                  onPressed: () => _openNamed('/pairing'),
                  child: const Text('前往配對'),
                ),
              ),
              const SizedBox(height: 10),
              _buildDeviceCard(),

              const SizedBox(height: 14),
              _sectionTitle(
                title: '健康摘要',
                trailing: TextButton(
                  onPressed: () => _openNamed('/health'),
                  child: const Text('進入健康'),
                ),
              ),
              const SizedBox(height: 10),
              _buildHealthCard(),

              const SizedBox(height: 14),
              _sectionTitle(
                title: '安全功能',
                trailing: TextButton(
                  onPressed: () => _openNamed('/safety'),
                  child: const Text('即時追蹤'),
                ),
              ),
              const SizedBox(height: 10),
              _buildSafetyCard(),

              const SizedBox(height: 12),
              if (_loading)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Center(
                    child: Text(
                      '載入中…',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _brand,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white.withOpacity(0.22),
            child: const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _phone,
                style: TextStyle(color: Colors.white.withOpacity(0.95)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill('一般會員'),
                  _pill('積分 $_points'),
                  InkWell(
                    onTap: _logout,
                    child: Text(
                      '登出',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ]),
          ),
          TextButton(
            onPressed: _editProfile,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('編輯', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }

  Widget _sectionTitle({required String title, required Widget trailing}) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
        trailing,
      ],
    );
  }

  Widget _buildQuickGrid({required int cartCount, required int favCount, required int unread}) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: [
        _QuickEntry(
          icon: Icons.receipt_long_outlined,
          label: '我的訂單',
          onTap: () => _openNamed('/orders'),
        ),
        _QuickEntry(
          icon: Icons.local_offer_outlined,
          label: '優惠券',
          onTap: () => _openNamed('/coupons'),
        ),
        _QuickEntry(
          icon: Icons.favorite_border,
          label: '收藏',
          badge: favCount,
          onTap: () => _openNamed('/wishlist'),
        ),
        _QuickEntry(
          icon: Icons.shopping_cart_outlined,
          label: '購物車',
          badge: cartCount,
          onTap: () => _openNamed('/cart'),
        ),
        _QuickEntry(
          icon: Icons.notifications_none,
          label: '通知',
          badge: unread,
          onTap: () => _openNamed('/notifications'),
        ),
        _QuickEntry(
          icon: Icons.support_agent_outlined,
          label: '客服',
          onTap: () => _openNamed('/support'),
        ),
      ],
    );
  }

  Widget _buildDeviceCard() {
    final title = _deviceConnected ? '已連線' : '未連線';
    final sub = _deviceConnected ? '裝置已配對並可同步資料' : '未連線';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade100,
            child: Icon(
              _deviceConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: _deviceConnected ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(sub, style: TextStyle(color: Colors.grey.shade600)),
            ]),
          ),
          SizedBox(
            height: 34,
            child: ElevatedButton(
              onPressed: () => _openNamed('/pairing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text('配對', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCard() {
    final t = _lastSyncAt;
    final syncText = t == null
        ? '來源：模擬 · 更新：—'
        : '來源：模擬 · 更新：${_two(t.hour)}:${_two(t.minute)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green),
              const SizedBox(width: 8),
              const Text('同步中', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(width: 10),
              Expanded(child: Text(syncText, style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
              IconButton(
                tooltip: '重新整理',
                onPressed: () async {
                  await _loadHealth();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _Metric(icon: Icons.directions_walk, label: '步數', value: '$_steps')),
              const SizedBox(width: 10),
              Expanded(child: _Metric(icon: Icons.bedtime_outlined, label: '睡眠', value: '${_sleepHours.toStringAsFixed(1)} h')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _Metric(icon: Icons.favorite_border, label: '心率', value: '$_hr bpm')),
              const SizedBox(width: 10),
              Expanded(child: _Metric(icon: Icons.monitor_heart_outlined, label: '血壓', value: _bp)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.orange.withOpacity(0.12),
            child: const Text('SOS', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SOS 求助', style: TextStyle(fontWeight: FontWeight.w900)),
              SizedBox(height: 3),
              Text('目前：未啟動', style: TextStyle(color: Colors.grey)),
            ]),
          ),
          SizedBox(
            height: 34,
            child: OutlinedButton(
              onPressed: () => _openNamed('/sos'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orangeAccent,
                side: BorderSide(color: Colors.orangeAccent.withOpacity(0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text('查看', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  int _toInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? fallback;
  }

  double _toDouble(dynamic v, {double fallback = 0}) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}') ?? fallback;
  }
}

class _QuickEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badge;
  final VoidCallback onTap;

  const _QuickEntry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.blueAccent),
                  const SizedBox(height: 10),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            if (badge > 0)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Metric({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            child: Icon(icon, size: 18, color: Colors.blueGrey),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
