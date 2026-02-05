// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../services/wishlist_service.dart';
import '../services/coupon_service.dart';
import '../services/firestore_mock_service.dart';

import 'address_page.dart';
import 'favorites_page.dart';
import 'notifications_page.dart';
import 'orders_page.dart';
import 'support_page.dart';
import 'coupons_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _bg = Color(0xFFF6F7FA);
  static const Color _primary = Colors.blueAccent;
  static const Color _brand = Colors.orangeAccent;

  bool _weekly = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();

    // ✅ 確保收藏 / 優惠券 / 通知初始化（熱重載 / Web 也不會空）
    Future.microtask(() async {
      try {
        await NotificationService.instance.init();
      } catch (_) {}
      try {
        await WishlistService.instance.init();
      } catch (_) {}
      try {
        await CouponService.instance.init();
      } catch (_) {}
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _weekly = prefs.getBool('update_weekly') ?? true;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('update_weekly', _weekly);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  void _openCoupons() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CouponsPage()),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  void _showBadgeInfo(String title, String desc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(desc, style: const TextStyle(fontSize: 15, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 優先用 Provider（若你有包 Provider），沒有也能 fallback 不爆炸
    NotificationService ns;
    WishlistService ws;
    CouponService cs;

    try {
      ns = context.watch<NotificationService>();
    } catch (_) {
      ns = NotificationService.instance;
    }
    try {
      ws = context.watch<WishlistService>();
    } catch (_) {
      ws = WishlistService.instance;
    }
    try {
      cs = context.watch<CouponService>();
    } catch (_) {
      cs = CouponService.instance;
    }

    final int unread = (() {
      try {
        final v = ns.unreadCount;
        if (v is int) return v;
      } catch (_) {}
      return 0;
    })();

    final int wishlistCount = (() {
      try {
        return ws.ids.length;
      } catch (_) {}
      return 0;
    })();

    final int couponCount = (() {
      try {
        final v = cs.availableCount;
        if (v is int) return v;
      } catch (_) {}
      try {
        return cs.available.length;
      } catch (_) {}
      return 0;
    })();

    final int points = (() {
      try {
        return FirestoreMockService.instance.userPoints;
      } catch (_) {}
      return 0;
    })();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('我的', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.6,
        actions: [
          // ✅ 通知 icon + 紅點/數字 badge
          _IconBadgeButton(
            tooltip: '通知中心',
            icon: Icons.notifications_none,
            color: _primary,
            count: unread,
            onPressed: _openNotifications,
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: '設定',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined, color: _primary),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
        child: Column(
          children: [
            _buildProfileHeader(
              points: points,
              wishlistCount: wishlistCount,
              unread: unread,
              couponCount: couponCount,
            ),
            const SizedBox(height: 10),

            // ✅ 快捷功能列
            _buildActionRow(context),

            const SizedBox(height: 12),

            // ✅ 折價券入口卡片
            _buildCouponEntryCard(couponCount),

            const SizedBox(height: 12),

            // ✅ 通知入口卡片（含未讀提示）
            _buildNotificationEntryCard(unread),

            const SizedBox(height: 12),

            // ✅ 設定入口卡片
            _buildSettingsEntryCard(),

            const SizedBox(height: 14),
            _buildUpdateSetting(),
            const SizedBox(height: 14),

            _buildNotificationSection(ns, unread),

            const SizedBox(height: 14),
            _buildAchievements(),
            const SizedBox(height: 26),

            ElevatedButton.icon(
              onPressed: () => _toast('示範：此專案未接登入，先不做登出流程'),
              icon: const Icon(Icons.logout),
              label: const Text('登出'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader({
    required int points,
    required int wishlistCount,
    required int unread,
    required int couponCount,
  }) {
    const userName = '王小明';
    const email = 'osmile_user@gmail.com';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: _primary,
            child: Text(
              '王',
              style: TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  userName,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                const Text(email, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _MiniStat(
                      icon: Icons.local_fire_department_outlined,
                      iconColor: _brand,
                      label: '積分',
                      value: '$points',
                    ),
                    _MiniStat(
                      icon: Icons.favorite,
                      iconColor: Colors.redAccent,
                      label: '收藏',
                      value: '$wishlistCount',
                    ),
                    _MiniStat(
                      icon: Icons.local_offer_outlined,
                      iconColor: _brand,
                      label: '券',
                      value: '$couponCount',
                    ),
                    _MiniStat(
                      icon: Icons.notifications,
                      iconColor: _primary,
                      label: '未讀',
                      value: '$unread',
                      badge: unread > 0,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.receipt_long,
        label: '訂單',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OrdersPage()),
        ),
      ),
      _QuickAction(
        icon: Icons.location_on,
        label: '地址',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddressPage()),
        ),
      ),
      _QuickAction(
        icon: Icons.favorite_border,
        label: '收藏',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FavoritesPage()),
        ),
      ),
      _QuickAction(
        icon: Icons.support_agent,
        label: '客服',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SupportPage()),
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((a) {
          return GestureDetector(
            onTap: a.onTap,
            child: Column(
              children: [
                Icon(a.icon, size: 28, color: _primary),
                const SizedBox(height: 4),
                Text(a.label, style: const TextStyle(fontSize: 13)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCouponEntryCard(int couponCount) {
    return InkWell(
      onTap: _openCoupons,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _brand.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_offer_outlined, color: _brand),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '折價券與優惠券',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '查看可用、已使用與過期的券',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '可用 $couponCount',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationEntryCard(int unread) {
    return InkWell(
      onTap: _openNotifications,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_none, color: _primary),
                ),
                if (unread > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '通知中心',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    unread > 0 ? '你有 $unread 則未讀通知' : '查看所有通知（可篩選、刪除、設為已讀）',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsEntryCard() {
    return InkWell(
      onTap: _openSettings,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.settings_outlined, color: Colors.black87),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '設定',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '通知、震動音效、版本與隱私',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateSetting() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('更新設定',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 10),
          RadioListTile<bool>(
            title: const Text('每週更新'),
            value: true,
            groupValue: _weekly,
            onChanged: (v) {
              setState(() => _weekly = v ?? true);
              _savePrefs();
              _toast('已設定：每週更新');
            },
          ),
          RadioListTile<bool>(
            title: const Text('每月更新'),
            value: false,
            groupValue: _weekly,
            onChanged: (v) {
              setState(() => _weekly = v ?? false);
              _savePrefs();
              _toast('已設定：每月更新');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSection(NotificationService ns, int unread) {
    final hasAny = (() {
      try {
        return ns.notifications.isNotEmpty;
      } catch (_) {
        return false;
      }
    })();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_none, color: _primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '未讀通知：$unread',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(onPressed: _openNotifications, child: const Text('全部')),
              TextButton(
                onPressed: unread == 0
                    ? null
                    : () {
                        try {
                          ns.markAllRead();
                        } catch (_) {}
                        _toast('已全部設為已讀');
                      },
                child: const Text('已讀'),
              ),
              TextButton(
                onPressed: hasAny
                    ? () {
                        try {
                          ns.clearAll();
                        } catch (_) {}
                        _toast('已清空通知');
                      }
                    : null,
                child:
                    const Text('清除', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _openNotifications,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.open_in_new, color: _primary, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '前往通知中心（可篩選、刪除、設為已讀）',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade600),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievements() {
    const badges = <_BadgeData>[
      _BadgeData(
          icon: Icons.local_fire_department,
          label: '熱絡活躍',
          desc: '連續登入 7 天，活躍使用者獎勵'),
      _BadgeData(icon: Icons.emoji_events, label: '活動達人', desc: '完成 3 項平台活動任務'),
      _BadgeData(icon: Icons.favorite, label: '人氣王', desc: '你的貼文獲得 50 個讚'),
      _BadgeData(icon: Icons.directions_run, label: '運動家', desc: '每日步數達標 7 天'),
      _BadgeData(icon: Icons.family_restroom, label: '親子之星', desc: '與家人綁定裝置並互動'),
      _BadgeData(icon: Icons.shield, label: '安心守護', desc: '啟用 SOS 緊急求助功能'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('成就與徽章',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: badges.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemBuilder: (context, i) {
              final b = badges[i];
              return GestureDetector(
                onTap: () => _showBadgeInfo(b.label, b.desc),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(b.icon, color: _brand, size: 28),
                      const SizedBox(height: 8),
                      Text(b.label, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _BadgeData {
  final IconData icon;
  final String label;
  final String desc;
  const _BadgeData({
    required this.icon,
    required this.label,
    required this.desc,
  });
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool badge;

  const _MiniStat({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: 16, color: iconColor),
            if (badge)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
      ],
    );
  }
}

class _IconBadgeButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onPressed;

  const _IconBadgeButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.count,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: color),
          if (count > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
