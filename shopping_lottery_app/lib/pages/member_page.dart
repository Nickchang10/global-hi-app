// lib/pages/member_page.dart
// =====================================================
// ✅ MemberPage（會員中心完整版｜可編譯通過｜Web/Android/iOS）
// -----------------------------------------------------
// ✅ 對齊你新版 service 介面：
// - AuthService：initialized / loggedIn / name / phone / level / updateProfile
//              loginWithPhone(phone,{smsCode}) -> String?
//              registerWithPhone(name,phone,{smsCode}) -> String?
//              logout()
// - NotificationService：unreadCount
// - HealthService：points / battery / online / lastSource / lastUpdated / steps / sleepHours / heartRate / bp
// - BluetoothService：isConnected / deviceName
// - CartService：items
// - WishlistService：items
// - SOSService：active / triggerSOS(reason) / cancelSOS
//
// ✅ 本頁已內建未登入 GuestView（即使 main.dart 已分流也不怕）
// ✅ 手機登入/註冊 BottomSheet：含驗證碼兩步流程
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/wishlist_service.dart';
import '../services/notification_service.dart';
import '../services/bluetooth_service.dart';
import '../services/health_service.dart';
import '../services/sos_service.dart';

class MemberPage extends StatefulWidget {
  const MemberPage({super.key});

  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {
  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _brand = Color(0xFF3B82F6);

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

  void _safeNav(String route, {Object? arguments}) {
    try {
      Navigator.of(context).pushNamed(route, arguments: arguments);
    } catch (_) {
      _toast('尚未設定路由：$route');
    }
  }

  String _hhmm(DateTime? t) {
    if (t == null) return '—';
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _logout() async {
    final auth = AuthService.instance;

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('登出'),
            content: const Text('確定要登出目前帳號嗎？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('登出'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    await auth.logout();
    if (!mounted) return;
    _toast('已登出');
  }

  // =====================================================
  // ✅ 手機登入 BottomSheet（兩步：送碼 -> 輸碼）
  // =====================================================
  Future<void> _showLoginSheet() async {
    final auth = AuthService.instance;
    final phone = TextEditingController(text: auth.phone == '09xx-xxx-xxx' ? '' : auth.phone);
    final code = TextEditingController();

    bool codeSent = false;
    bool loading = false;

    try {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) {
          final bottom = MediaQuery.of(context).viewInsets.bottom;

          return StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> handlePrimary() async {
                if (loading) return;

                final p = phone.text.trim();
                if (p.isEmpty) {
                  _toast('請輸入手機號碼');
                  return;
                }

                setSheetState(() => loading = true);
                try {
                  if (!codeSent) {
                    // step 1: send code
                    final err = await auth.loginWithPhone(p);
                    if (err != null) {
                      _toast(err);
                      return;
                    }
                    setSheetState(() => codeSent = true);
                    _toast('驗證碼已發送，請輸入簡訊驗證碼');
                    return;
                  } else {
                    // step 2: verify code
                    final sms = code.text.trim();
                    if (sms.isEmpty) {
                      _toast('請輸入驗證碼');
                      return;
                    }
                    final err = await auth.loginWithPhone(p, smsCode: sms);
                    if (err != null) {
                      _toast(err);
                      return;
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context, true);
                  }
                } finally {
                  if (context.mounted) setSheetState(() => loading = false);
                }
              }

              return _AuthBottomSheetShell(
                title: '登入（手機）',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: '手機號碼',
                        hintText: '例如：0912xxxxxx',
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (codeSent) ...[
                      TextField(
                        controller: code,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '驗證碼',
                          hintText: '輸入簡訊驗證碼',
                          filled: true,
                          fillColor: const Color(0xFFF7F8FA),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: loading ? null : () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('取消', style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: loading ? null : handlePrimary,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brand,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    codeSent ? '確認登入' : '取得驗證碼',
                                    style: const TextStyle(fontWeight: FontWeight.w900),
                                  ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 14 + bottom * 0.05),

                    _AuthHintRow(
                      leftText: '還沒有帳號？',
                      actionText: '立即註冊',
                      onTap: () async {
                        if (!context.mounted) return;
                        Navigator.pop(context, false);
                        await Future<void>.delayed(const Duration(milliseconds: 120));
                        if (mounted) await _showRegisterSheet();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      if (ok == true && mounted) {
        _toast('登入成功');
      }
    } finally {
      phone.dispose();
      code.dispose();
    }
  }

  // =====================================================
  // ✅ 手機註冊 BottomSheet（兩步：送碼 -> 輸碼）
  // =====================================================
  Future<void> _showRegisterSheet() async {
    final auth = AuthService.instance;

    final name = TextEditingController(text: auth.name == 'Osmile 會員' ? '' : auth.name);
    final phone = TextEditingController(text: auth.phone == '09xx-xxx-xxx' ? '' : auth.phone);
    final code = TextEditingController();

    String level = auth.level.isEmpty ? '一般會員' : auth.level;
    bool codeSent = false;
    bool loading = false;

    try {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) {
          final bottom = MediaQuery.of(context).viewInsets.bottom;

          return StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> handlePrimary() async {
                if (loading) return;

                final n = name.text.trim();
                final p = phone.text.trim();

                if (n.isEmpty) {
                  _toast('請輸入姓名');
                  return;
                }
                if (p.isEmpty) {
                  _toast('請輸入手機號碼');
                  return;
                }

                setSheetState(() => loading = true);
                try {
                  if (!codeSent) {
                    // step 1: send code
                    final err = await auth.registerWithPhone(name: n, phone: p);
                    if (err != null) {
                      _toast(err);
                      return;
                    }
                    setSheetState(() => codeSent = true);
                    _toast('驗證碼已發送，請輸入簡訊驗證碼');
                    return;
                  } else {
                    // step 2: verify code
                    final sms = code.text.trim();
                    if (sms.isEmpty) {
                      _toast('請輸入驗證碼');
                      return;
                    }

                    final err = await auth.registerWithPhone(name: n, phone: p, smsCode: sms);
                    if (err != null) {
                      _toast(err);
                      return;
                    }

                    // ✅ 註冊成功後寫入 level（可選）
                    await auth.updateProfile(level: level);

                    if (!context.mounted) return;
                    Navigator.pop(context, true);
                  }
                } finally {
                  if (context.mounted) setSheetState(() => loading = false);
                }
              }

              return _AuthBottomSheetShell(
                title: '註冊（手機）',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: '姓名',
                        hintText: '請輸入暱稱或姓名',
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: '手機號碼',
                        hintText: '例如：0912xxxxxx',
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: level,
                      items: const [
                        DropdownMenuItem(value: '一般會員', child: Text('一般會員')),
                        DropdownMenuItem(value: '銀卡會員', child: Text('銀卡會員')),
                        DropdownMenuItem(value: '金卡會員', child: Text('金卡會員')),
                        DropdownMenuItem(value: 'VIP', child: Text('VIP')),
                      ],
                      onChanged: (v) => setSheetState(() => level = v ?? '一般會員'),
                      decoration: InputDecoration(
                        labelText: '會員等級（可後續修改）',
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (codeSent) ...[
                      TextField(
                        controller: code,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '驗證碼',
                          hintText: '輸入簡訊驗證碼',
                          filled: true,
                          fillColor: const Color(0xFFF7F8FA),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: loading ? null : () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('取消', style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: loading ? null : handlePrimary,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brand,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    codeSent ? '確認註冊' : '取得驗證碼',
                                    style: const TextStyle(fontWeight: FontWeight.w900),
                                  ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 14 + bottom * 0.05),

                    _AuthHintRow(
                      leftText: '已經有帳號？',
                      actionText: '直接登入',
                      onTap: () async {
                        if (!context.mounted) return;
                        Navigator.pop(context, false);
                        await Future<void>.delayed(const Duration(milliseconds: 120));
                        if (mounted) await _showLoginSheet();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      if (ok == true && mounted) {
        _toast('註冊成功');
      }
    } finally {
      name.dispose();
      phone.dispose();
      code.dispose();
    }
  }

  // =====================================================
  // ✅ 編輯會員資料
  // =====================================================
  Future<void> _editProfile() async {
    final auth = AuthService.instance;
    if (!auth.loggedIn) {
      await _showLoginSheet();
      return;
    }

    final updated = await showModalBottomSheet<_ProfileData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        initial: _ProfileData(
          name: auth.name,
          phone: auth.phone,
          level: auth.level,
        ),
      ),
    );

    if (updated != null) {
      await auth.updateProfile(
        name: updated.name,
        phone: updated.phone,
        level: updated.level,
      );
      if (!mounted) return;
      _toast('已更新會員資料');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    // ✅ 初始化中
    if (!auth.initialized) {
      return const Scaffold(
        backgroundColor: _bg,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    // ✅ 未登入：GuestView
    if (!auth.loggedIn) {
      return _GuestView(
        onLogin: _showLoginSheet,
        onRegister: _showRegisterSheet,
        onBrowseShop: () => _safeNav('/shop'),
      );
    }

    // ✅ 已登入：再 watch 其他服務
    final cart = context.watch<CartService>();
    final wish = context.watch<WishlistService>();
    final noti = context.watch<NotificationService>();
    final ble = context.watch<BluetoothService>();
    final health = context.watch<HealthService>();
    final sos = context.watch<SOSService>();

    final unread = noti.unreadCount;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future<void>.delayed(const Duration(milliseconds: 250));
            if (mounted) _toast('已刷新');
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
            children: [
              _MemberHeaderCard(
                name: auth.name,
                phone: auth.phone,
                level: auth.level,
                points: health.points,
                loggedIn: true,
                onEdit: _editProfile,
                onLogin: _showLoginSheet,
                onLogout: _logout,
              ),
              const SizedBox(height: 12),

              _SectionTitle(
                title: '快捷入口',
                actionText: '查看通知',
                onAction: () => _safeNav('/notifications'),
              ),
              const SizedBox(height: 8),
              _QuickGrid(
                items: [
                  _QuickItem(
                    icon: Icons.receipt_long_outlined,
                    label: '我的訂單',
                    badge: null,
                    onTap: () => _safeNav('/orders'),
                  ),
                  _QuickItem(
                    icon: Icons.local_offer_outlined,
                    label: '優惠券',
                    badge: null,
                    onTap: () => _safeNav('/coupons'),
                  ),
                  _QuickItem(
                    icon: Icons.favorite_border,
                    label: '收藏',
                    badge: wish.items.length == 0 ? null : wish.items.length.toString(),
                    onTap: () => _safeNav('/wishlist'),
                  ),
                  _QuickItem(
                    icon: Icons.shopping_cart_outlined,
                    label: '購物車',
                    badge: cart.items.length == 0 ? null : cart.items.length.toString(),
                    onTap: () => _safeNav('/cart'),
                  ),
                  _QuickItem(
                    icon: Icons.notifications_none_rounded,
                    label: '通知',
                    badge: unread == 0 ? null : unread.toString(),
                    onTap: () => _safeNav('/notifications'),
                  ),
                  _QuickItem(
                    icon: Icons.support_agent_outlined,
                    label: '客服',
                    badge: null,
                    onTap: () => _safeNav('/support'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _SectionTitle(
                title: '裝置狀態',
                actionText: '前往配對',
                onAction: () => _safeNav('/device'),
              ),
              const SizedBox(height: 8),
              _DeviceStatusCard(
                isConnected: ble.isConnected,
                deviceName: ble.deviceName ?? '未連線',
                battery: health.battery,
                onConnect: () => _safeNav('/device'),
              ),
              const SizedBox(height: 12),

              _SectionTitle(
                title: '健康摘要',
                actionText: '進入健康',
                onAction: () => _safeNav('/health'),
              ),
              const SizedBox(height: 8),
              _HealthSummaryCard(
                online: health.online,
                lastSource: health.lastSource,
                lastUpdated: health.lastUpdated,
                steps: health.steps,
                sleepHours: health.sleepHours,
                heartRate: health.heartRate,
                bp: health.bp,
                timeText: _hhmm(health.lastUpdated),
                onOpenHealth: () => _safeNav('/health'),
              ),
              const SizedBox(height: 12),

              _SectionTitle(
                title: '安全功能',
                actionText: '即時追蹤',
                onAction: () => _safeNav('/tracking'),
              ),
              const SizedBox(height: 8),
              _SOSCard(
                active: sos.active,
                onPrimary: () async {
                  try {
                    if (!sos.active) {
                      await sos.triggerSOS(reason: '會員頁 SOS');
                      _toast('已發出 SOS 警報');
                    } else {
                      await sos.cancelSOS();
                      _toast('已取消 SOS');
                    }
                  } catch (e) {
                    _toast('操作失敗：$e');
                  }
                },
                onSecondary: () => _safeNav('/tracking'),
              ),
              const SizedBox(height: 12),

              const _SectionTitle(title: '更多', actionText: '', onAction: _noop),
              const SizedBox(height: 8),
              _SettingList(
                loggedIn: true,
                onTap: (key) async {
                  switch (key) {
                    case 'logout':
                      await _logout();
                      break;
                    case 'profile':
                      await _editProfile();
                      break;
                    case 'address':
                      _safeNav('/addresses');
                      break;
                    case 'payment':
                      _safeNav('/payment_methods');
                      break;
                    case 'faq':
                      _safeNav('/faq');
                      break;
                    case 'about':
                      _safeNav('/about');
                      break;
                    default:
                      _toast('功能開發中：$key');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _noop() {}

// =====================================================
// ✅ 未登入 GuestView
// =====================================================
class _GuestView extends StatelessWidget {
  static const Color _brand = Color(0xFF3B82F6);

  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onBrowseShop;

  const _GuestView({
    required this.onLogin,
    required this.onRegister,
    required this.onBrowseShop,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
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
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.22)),
                    ),
                    child: const Icon(Icons.person_outline, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '未登入',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '登入後可同步健康資料、查看通知、享受完整會員福利。',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: const [
                Expanded(
                  child: _GuestBenefitCard(
                    icon: Icons.notifications_active_outlined,
                    title: '通知管理',
                    subtitle: '付款/訂單/抽獎\n即時提醒',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _GuestBenefitCard(
                    icon: Icons.monitor_heart_outlined,
                    title: '健康同步',
                    subtitle: '步數/睡眠/心率\n隨時掌握',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: const [
                Expanded(
                  child: _GuestBenefitCard(
                    icon: Icons.sos_outlined,
                    title: 'SOS 求助',
                    subtitle: '緊急狀況\n快速啟動',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _GuestBenefitCard(
                    icon: Icons.local_offer_outlined,
                    title: '優惠/積分',
                    subtitle: '活動優惠\n積分回饋',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('登入', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: onRegister,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _brand,
                  side: BorderSide(color: _brand.withOpacity(0.35)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('註冊新帳號', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onBrowseShop,
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('先逛逛商城'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestBenefitCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _GuestBenefitCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 106,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF3B82F6).withOpacity(0.10),
            child: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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

// =====================================================
// BottomSheet UI helpers
// =====================================================
class _AuthBottomSheetShell extends StatelessWidget {
  final String title;
  final Widget child;

  const _AuthBottomSheetShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 14 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AuthHintRow extends StatelessWidget {
  final String leftText;
  final String actionText;
  final VoidCallback onTap;

  const _AuthHintRow({
    required this.leftText,
    required this.actionText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(leftText,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(width: 6),
        InkWell(
          onTap: onTap,
          child: Text(
            actionText,
            style: const TextStyle(
              color: Color(0xFF3B82F6),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================
// Profile data model (for edit sheet)
// =====================================================
class _ProfileData {
  final String name;
  final String phone;
  final String level;

  const _ProfileData({
    required this.name,
    required this.phone,
    required this.level,
  });
}

// =====================================================
// UI widgets
// =====================================================
class _SectionTitle extends StatelessWidget {
  final String title;
  final String actionText;
  final VoidCallback onAction;

  const _SectionTitle({
    required this.title,
    required this.actionText,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ),
        if (actionText.trim().isNotEmpty)
          TextButton(onPressed: onAction, child: Text(actionText)),
      ],
    );
  }
}

class _MemberHeaderCard extends StatelessWidget {
  final String name;
  final String phone;
  final String level;
  final int points;
  final bool loggedIn;

  final VoidCallback onEdit;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  const _MemberHeaderCard({
    required this.name,
    required this.phone,
    required this.level,
    required this.points,
    required this.loggedIn,
    required this.onEdit,
    required this.onLogin,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
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
            radius: 26,
            backgroundColor: Colors.white.withOpacity(0.18),
            child: const Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: onEdit,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('編輯', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                phone,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(text: level),
                  _Pill(text: '積分 $points'),
                  _ActionPill(
                    text: loggedIn ? '登出' : '登入',
                    onTap: loggedIn ? onLogout : onLogin,
                  ),
                ],
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _ActionPill({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _QuickItem {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  _QuickItem({
    required this.icon,
    required this.label,
    required this.badge,
    required this.onTap,
  });
}

class _QuickGrid extends StatelessWidget {
  final List<_QuickItem> items;
  const _QuickGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (_, i) {
        final it = items[i];
        return InkWell(
          onTap: it.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(it.icon, color: const Color(0xFF3B82F6), size: 26),
                    const SizedBox(height: 8),
                    Text(it.label,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  ],
                ),
                if (it.badge != null && it.badge!.trim().isNotEmpty && it.badge != '0')
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        it.badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DeviceStatusCard extends StatelessWidget {
  final bool isConnected;
  final String deviceName;
  final int battery;
  final VoidCallback onConnect;

  const _DeviceStatusCard({
    required this.isConnected,
    required this.deviceName,
    required this.battery,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = isConnected ? Colors.green : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: badgeColor.withOpacity(0.12),
            child: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: badgeColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(deviceName, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  isConnected ? '已連線 • 電量 $battery%' : '未連線',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('配對', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _HealthSummaryCard extends StatelessWidget {
  final bool online;
  final String lastSource;
  final DateTime? lastUpdated;
  final int steps;
  final double sleepHours;
  final int heartRate;
  final String bp;
  final VoidCallback onOpenHealth;
  final String timeText;

  const _HealthSummaryCard({
    required this.online,
    required this.lastSource,
    required this.lastUpdated,
    required this.steps,
    required this.sleepHours,
    required this.heartRate,
    required this.bp,
    required this.onOpenHealth,
    required this.timeText,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpenHealth,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: (online ? Colors.green : Colors.grey).withOpacity(0.12),
                  child: Icon(
                    online ? Icons.check_circle_outline : Icons.sync_problem_outlined,
                    color: online ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(online ? '同步中' : '未同步', style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('來源：$lastSource • 更新：$timeText',
                        style: TextStyle(color: Colors.grey.shade700)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _MetricTile(icon: Icons.directions_walk, label: '步數', value: '$steps')),
                const SizedBox(width: 10),
                Expanded(
                    child: _MetricTile(
                        icon: Icons.bedtime_outlined,
                        label: '睡眠',
                        value: '${sleepHours.toStringAsFixed(1)} h')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _MetricTile(icon: Icons.favorite_border, label: '心率', value: '$heartRate bpm')),
                const SizedBox(width: 10),
                Expanded(child: _MetricTile(icon: Icons.monitor_heart_outlined, label: '血壓', value: bp)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF3B82F6).withOpacity(0.12),
            child: Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _SOSCard extends StatelessWidget {
  final bool active;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const _SOSCard({
    required this.active,
    required this.onPrimary,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: (active ? Colors.redAccent : Colors.orangeAccent).withOpacity(0.12),
                child: Icon(active ? Icons.sos : Icons.sos_outlined,
                    color: active ? Colors.redAccent : Colors.orangeAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('SOS 求助', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(active ? '目前：已啟動' : '目前：未啟動', style: TextStyle(color: Colors.grey.shade700)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPrimary,
                  icon: Icon(active ? Icons.close_rounded : Icons.sos_outlined),
                  label: Text(active ? '取消 SOS' : '啟動 SOS', style: const TextStyle(fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: active ? Colors.grey : Colors.redAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSecondary,
                  icon: const Icon(Icons.my_location_outlined),
                  label: const Text('即時追蹤', style: TextStyle(fontWeight: FontWeight.w900)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingList extends StatelessWidget {
  final bool loggedIn;
  final void Function(String key) onTap;

  const _SettingList({required this.loggedIn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _SettingTile(icon: Icons.person_outline, title: '個人資料', onTap: () => onTap('profile')),
          _SettingTile(icon: Icons.location_on_outlined, title: '收件地址', onTap: () => onTap('address')),
          _SettingTile(icon: Icons.credit_card_outlined, title: '付款方式', onTap: () => onTap('payment')),
          _SettingTile(icon: Icons.help_outline, title: '常見問題', onTap: () => onTap('faq')),
          if (loggedIn) _SettingTile(icon: Icons.logout, title: '登出', onTap: () => onTap('logout')),
          _SettingTile(
            icon: Icons.info_outline,
            title: '關於 Osmile',
            onTap: () => onTap('about'),
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool showDivider;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Icon(icon, color: const Color(0xFF3B82F6)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ),
        if (showDivider) Divider(height: 1, color: Colors.grey.shade200),
      ],
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final _ProfileData initial;
  const _EditProfileSheet({required this.initial});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  String _level = '一般會員';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name);
    _phone = TextEditingController(text: widget.initial.phone);
    _level = widget.initial.level.isEmpty ? '一般會員' : widget.initial.level;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 14 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(999)),
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('編輯會員資料', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: '姓名',
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: '手機',
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _level,
            items: const [
              DropdownMenuItem(value: '一般會員', child: Text('一般會員')),
              DropdownMenuItem(value: '銀卡會員', child: Text('銀卡會員')),
              DropdownMenuItem(value: '金卡會員', child: Text('金卡會員')),
              DropdownMenuItem(value: 'VIP', child: Text('VIP')),
            ],
            onChanged: (v) => setState(() => _level = v ?? '一般會員'),
            decoration: InputDecoration(
              labelText: '會員等級',
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('取消', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      _ProfileData(
                        name: _name.text.trim().isEmpty ? 'Osmile 會員' : _name.text.trim(),
                        phone: _phone.text.trim().isEmpty ? '09xx-xxx-xxx' : _phone.text.trim(),
                        level: _level,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('儲存', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
