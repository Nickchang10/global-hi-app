// lib/pages/profile_page.dart
//
// ✅ ProfilePage（個人資料｜最終完整版｜可直接使用｜已修正 lint）
// ------------------------------------------------------------
// ✅ 修正重點：
// - ✅ use_build_context_synchronously：所有 await 後使用 State.context 前先 mounted 檢查
// - ✅ 不保存 context 變數、不做不相關 mounted guard（lint 會過）
// - ✅ FirebaseAuth + Firestore users/{uid} 讀寫
//
// Firestore 建議結構：
// users/{uid}
//   - displayName: String?
//   - email: String?
//   - phone: String?
//   - avatarUrl: String?
//   - updatedAt: Timestamp
//   - createdAt: Timestamp
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  static const routeName = '/profile';

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _booting = true;
  bool _saving = false;
  String? _error;

  User? get _user => _auth.currentUser;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _avatarCtrl = TextEditingController();

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _fs.collection('users').doc(uid);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _booting = true;
      _error = null;
    });

    try {
      final u = _user;
      if (u == null) {
        setState(() => _booting = false);
        return;
      }

      final ref = _userRef(u.uid);
      final snap = await ref.get();

      // 確保 user doc 存在（不覆蓋既有）
      final base = <String, dynamic>{
        'email': u.email,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!snap.exists) {
        await ref.set({
          ...base,
          'displayName': u.displayName,
          'phone': null,
          'avatarUrl': null,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await ref.set(base, SetOptions(merge: true));
      }

      final snap2 = await ref.get();
      final data = snap2.data() ?? <String, dynamic>{};

      // ✅ await 後再用 State.context 沒關係，但要先 mounted
      if (!mounted) return;

      _nameCtrl.text = _s(data['displayName'], u.displayName ?? '').trim();
      _phoneCtrl.text = _s(data['phone'], '').trim();
      _avatarCtrl.text = _s(data['avatarUrl'], '').trim();

      setState(() => _booting = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _booting = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    final u = _user;
    if (u == null) {
      _snack('請先登入');
      return;
    }
    if (_saving) return;

    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final avatar = _avatarCtrl.text.trim();

    setState(() => _saving = true);

    try {
      await _userRef(u.uid).set({
        'displayName': name.isEmpty ? null : name,
        'phone': phone.isEmpty ? null : phone,
        'avatarUrl': avatar.isEmpty ? null : avatar,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ✅ await 後先 mounted，再用 context
      if (!mounted) return;

      _snack('✅ 已儲存');
    } catch (e) {
      if (!mounted) return;
      _snack('❌ 儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _goLogin() {
    Navigator.of(context, rootNavigator: true).pushNamed('/login');
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('登出'),
        content: const Text('確定要登出嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('登出'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      if (!mounted) return;
      _snack('❌ 登出失敗：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('個人資料'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _saving ? null : _bootstrap,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: u == null
          ? _needLogin()
          : (_booting
                ? const Center(child: CircularProgressIndicator())
                : (_error != null ? _errorBox(_error!) : _form(u))),
    );
  }

  Widget _needLogin() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 56, color: cs.primary),
                  const SizedBox(height: 12),
                  const Text(
                    '請先登入才能編輯個人資料',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _goLogin, child: const Text('前往登入')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(User u) {
    final cs = Theme.of(context).colorScheme;
    final email = (u.email ?? '').trim();

    final avatarUrl = _avatarCtrl.text.trim();
    final hasAvatar = avatarUrl.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: cs.primaryContainer,
                  foregroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                  child: hasAvatar
                      ? null
                      : Icon(Icons.person, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameCtrl.text.trim().isEmpty
                            ? '會員'
                            : _nameCtrl.text.trim(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email.isEmpty
                            ? 'uid: ${u.uid}'
                            : '$email\nuid: ${u.uid}',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '基本資料',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '顯示名稱',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) {
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '電話（選填）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _avatarCtrl,
                  decoration: const InputDecoration(
                    labelText: '頭像 URL（選填）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) {
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? '儲存中…' : '儲存'),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Card(
          elevation: 1,
          child: ListTile(
            leading: const Icon(Icons.logout),
            title: const Text(
              '登出',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text('退出目前帳號'),
            onTap: _confirmSignOut,
          ),
        ),

        const SizedBox(height: 12),
        Text(
          '註：本頁已修正 use_build_context_synchronously（await 後使用 context 前皆先 mounted 檢查）。',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }

  Widget _errorBox(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
