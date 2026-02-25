// lib/pages/member_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth/auth_service.dart' as app_auth;

class MemberPage extends StatefulWidget {
  const MemberPage({super.key});

  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _initedUserDoc = false;

  User? get _user => _auth.currentUser;
  String get _uid => _user?.uid ?? '';

  DocumentReference<Map<String, dynamic>> _userRef() =>
      _db.collection('users').doc(_uid);

  DocumentReference<Map<String, dynamic>> _adminRef() =>
      _db.collection('admins').doc(_uid);

  @override
  void initState() {
    super.initState();
    _ensureUserDoc();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _copy(String label, String value) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    _toast('已複製 $label');
  }

  Future<void> _signOut() async {
    try {
      await app_auth.AuthService.instance.signOut();
    } catch (e) {
      _toast('登出失敗：$e');
    }
  }

  void _go(String route, {Object? args}) {
    try {
      Navigator.of(context).pushNamed(route, arguments: args);
    } catch (_) {
      _toast('尚未設定路由：$route');
    }
  }

  Future<void> _ensureUserDoc() async {
    final u = _user;
    if (u == null) return;
    if (_initedUserDoc) return;

    try {
      final ref = _db.collection('users').doc(u.uid);
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'displayName': (u.displayName ?? '').toString(),
          'phone': '',
          'prefs': {
            'notifyOrder': true,
            'notifyLottery': true,
            'notifyMarketing': false,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // ignore
    } finally {
      _initedUserDoc = true;
    }
  }

  Future<void> _sendVerifyEmail() async {
    final u = _user;
    if (u == null) return;

    final email = (u.email ?? '').trim();
    if (email.isEmpty) {
      _toast('此帳號沒有 Email');
      return;
    }
    if (u.emailVerified) {
      _toast('Email 已驗證');
      return;
    }
    try {
      await u.sendEmailVerification();
      _toast('已寄出驗證信：$email');
    } catch (e) {
      _toast('寄送失敗：$e');
    }
  }

  void _showAccountSheet({
    required String email,
    required String uid,
    required bool emailVerified,
    required String role,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 8),
                  const Text(
                    '帳號資訊',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const Spacer(),
                  _RolePill(text: role),
                ],
              ),
              const SizedBox(height: 12),
              _KVRow(
                label: 'Email',
                value: email.isEmpty ? '（無）' : email,
                onCopy: email.isEmpty ? null : () => _copy('Email', email),
              ),
              const SizedBox(height: 8),
              _KVRow(
                label: 'UID',
                value: uid,
                onCopy: uid.isEmpty ? null : () => _copy('UID', uid),
              ),
              const SizedBox(height: 8),
              _KVRow(
                label: '狀態',
                value: emailVerified ? 'Email 已驗證' : 'Email 未驗證',
                trailing: (!emailVerified && email.isNotEmpty)
                    ? TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _sendVerifyEmail();
                        },
                        child: const Text('寄驗證信'),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _go('/settings/security');
                  },
                  icon: const Icon(Icons.security_outlined),
                  label: const Text('帳號與安全'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    if (u == null) return const Scaffold(body: Center(child: Text('請先登入')));

    final email = u.email ?? '';
    final uid = u.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userRef().snapshots(),
      builder: (context, snap) {
        final udoc = snap.data?.data() ?? <String, dynamic>{};

        final displayName =
            (udoc['displayName'] ?? u.displayName ?? '')
                .toString()
                .trim()
                .isEmpty
            ? '（未設定）'
            : (udoc['displayName'] ?? u.displayName).toString();

        final phone = (udoc['phone'] ?? '').toString().trim().isEmpty
            ? '（未設定）'
            : (udoc['phone'] ?? '').toString();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _adminRef().snapshots(),
          builder: (context, adminSnap) {
            final isAdmin = adminSnap.data?.exists == true;
            final role = isAdmin ? 'admin' : 'user';

            return Scaffold(
              appBar: AppBar(
                title: const Text('會員中心'),
                actions: [
                  IconButton(
                    tooltip: '登出',
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.06,
                            ),
                            child: const Icon(Icons.person_outline),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _RolePill(text: role),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  email.isEmpty ? '（無 Email）' : email,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '電話：$phone',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _go('/settings/profile'),
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const Text('基本資料'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _showAccountSheet(
                                          email: email,
                                          uid: uid,
                                          emailVerified: u.emailVerified,
                                          role: role,
                                        ),
                                        icon: const Icon(Icons.info_outline),
                                        label: const Text('帳號資訊'),
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

                  const SizedBox(height: 14),

                  _SectionTitle('快捷功能'),
                  const SizedBox(height: 8),
                  _QuickGrid(
                    items: [
                      _QuickItem(
                        icon: Icons.receipt_long_outlined,
                        label: '我的訂單',
                        onTap: () => _go('/orders'),
                      ),
                      _QuickItem(
                        icon: Icons.location_on_outlined,
                        label: '地址簿',
                        onTap: () => _go('/addresses'),
                      ),
                      _QuickItem(
                        icon: Icons.stars_outlined,
                        label: '積分',
                        onTap: () => _go('/points'),
                      ),
                      _QuickItem(
                        icon: Icons.card_giftcard_outlined,
                        label: '抽獎',
                        onTap: () => _go('/lotterys'),
                      ),
                      _QuickItem(
                        icon: Icons.discount_outlined,
                        label: '優惠券',
                        onTap: () => _go('/coupons'),
                      ),
                      // ✅ 修正：通知快捷鍵改到「通知設定」，避免 /notifications 路由不存在
                      _QuickItem(
                        icon: Icons.notifications_none_outlined,
                        label: '通知設定',
                        onTap: () => _go('/settings/notifications'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  _SectionTitle('設定'),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.manage_accounts_outlined),
                          title: const Text('基本資料'),
                          subtitle: const Text('顯示名稱、電話'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _go('/settings/profile'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.local_shipping_outlined),
                          title: const Text('收件資訊'),
                          subtitle: const Text('預設收件人、電話、地址'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _go('/settings/shipping'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.notifications_active_outlined,
                          ),
                          title: const Text('通知設定'),
                          subtitle: const Text('訂單 / 抽獎 / 行銷'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _go('/settings/notifications'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.security_outlined),
                          title: const Text('帳號與安全'),
                          subtitle: Text(
                            u.emailVerified
                                ? 'Email 已驗證'
                                : 'Email 未驗證 / 重設密碼 / 刪除帳號',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _go('/settings/security'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  if (snap.hasError)
                    Text(
                      '讀取會員資料失敗：${snap.error}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ====== UI ======

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String text;
  const _RolePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Text(
        text.isEmpty ? 'user' : text,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _KVRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;
  final Widget? trailing;

  const _KVRow({
    required this.label,
    required this.value,
    this.onCopy,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            '$label：',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) trailing!,
        if (onCopy != null)
          IconButton(
            tooltip: '複製',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
      ],
    );
  }
}

class _QuickItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickItem({
    required this.icon,
    required this.label,
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
        childAspectRatio: 1.35,
      ),
      itemBuilder: (_, i) {
        final it = items[i];
        return InkWell(
          onTap: it.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(it.icon),
                const SizedBox(height: 6),
                Text(
                  it.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
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
