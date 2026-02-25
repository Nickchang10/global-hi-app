// lib/pages/vendor_settings_page.dart
//
// ✅ VendorSettingsPage（完整版｜可編譯｜帳號設定中心｜修改密碼｜通知偏好｜登出）
//
// 功能：
// - 顯示廠商帳號資訊（Email、廠商名稱、建立時間）
// - 修改密碼（含重新驗證 reauthenticate）
// - 通知偏好開關（Firestore vendors/{vendorId} 更新）
// - 登出按鈕（AuthService.signOut）
// - Firestore vendor 文件同步顯示
//
// Firestore -> vendors/{vendorId}
//   - name
//   - contactEmail
//   - createdAt
//   - notifyNewOrder (bool)
//   - notifySystem (bool)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

class VendorSettingsPage extends StatefulWidget {
  const VendorSettingsPage({super.key, required this.vendorId});
  final String vendorId;

  @override
  State<VendorSettingsPage> createState() => _VendorSettingsPageState();
}

class _VendorSettingsPageState extends State<VendorSettingsPage> {
  final _db = FirebaseFirestore.instance;

  final _pwdOldCtrl = TextEditingController();
  final _pwdNewCtrl = TextEditingController();

  bool _updatingPwd = false;

  String _s(dynamic v) => (v ?? '').toString().trim();

  bool _b(dynamic v, {bool fallback = false}) {
    if (v is bool) {
      return v;
    }
    final s = (v ?? '').toString().toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'yes') {
      return true;
    }
    if (s == 'false' || s == '0' || s == 'no') {
      return false;
    }
    return fallback;
  }

  String _fmtDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${d.year}-${two(d.month)}-${two(d.day)}';
    }
    return '-';
  }

  void _snack(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _changePassword(AuthService auth) async {
    final oldPwd = _pwdOldCtrl.text.trim();
    final newPwd = _pwdNewCtrl.text.trim();

    if (oldPwd.isEmpty || newPwd.isEmpty) {
      _snack('請輸入舊密碼與新密碼');
      return;
    }
    if (newPwd.length < 6) {
      _snack('新密碼至少 6 碼');
      return;
    }

    setState(() => _updatingPwd = true);
    try {
      // ✅ 必須 await
      final user = await auth.requireUser();

      final email = user.email;
      if (email == null || email.trim().isEmpty) {
        throw Exception('目前帳號無 Email，無法重新驗證');
      }

      final cred = EmailAuthProvider.credential(
        email: email.trim(),
        password: oldPwd,
      );

      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPwd);

      _snack('密碼已更新成功');
      _pwdOldCtrl.clear();
      _pwdNewCtrl.clear();
    } on FirebaseAuthException catch (e) {
      _snack('密碼更新失敗：${e.message ?? e.code}');
    } catch (e) {
      _snack('密碼更新失敗：$e');
    } finally {
      if (mounted) {
        setState(() => _updatingPwd = false);
      }
    }
  }

  Future<void> _toggleNotify(String field, bool value) async {
    final vid = widget.vendorId.trim();
    if (vid.isEmpty) {
      _snack('vendorId 為空，無法更新設定');
      return;
    }
    try {
      await _db.collection('vendors').doc(vid).set(<String, dynamic>{
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack('已更新通知設定');
    } catch (e) {
      _snack('更新失敗：$e');
    }
  }

  @override
  void dispose() {
    _pwdOldCtrl.dispose();
    _pwdNewCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final vid = widget.vendorId.trim();

    if (vid.isEmpty) {
      return const Scaffold(body: Center(child: Text('vendorId 為空，無法開啟設定頁')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('帳號設定')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _db.collection('vendors').doc(vid).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('讀取失敗：${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final exists = snap.data!.exists;
          final d = snap.data!.data() ?? <String, dynamic>{};

          final name = exists
              ? (_s(d['name']).isEmpty ? '-' : _s(d['name']))
              : '(找不到此 vendors/$vid)';

          // ✅ 不依賴 AuthService.currentUser（避免你 AuthService 沒定義）
          final firebaseUser = FirebaseAuth.instance.currentUser;
          final email = _s(d['contactEmail']).isNotEmpty
              ? _s(d['contactEmail'])
              : (firebaseUser?.email ?? '-');

          final createdAt = _fmtDate(d['createdAt']);
          final notifyNew = _b(d['notifyNewOrder'], fallback: true);
          final notifySystem = _b(d['notifySystem'], fallback: true);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 1,
                  child: ListTile(
                    title: const Text(
                      '廠商名稱',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(name),
                  ),
                ),
                Card(
                  elevation: 1,
                  child: ListTile(
                    title: const Text(
                      '帳號 Email',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(email),
                  ),
                ),
                Card(
                  elevation: 1,
                  child: ListTile(
                    title: const Text(
                      '建立日期',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(createdAt),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '通知設定',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SwitchListTile(
                  title: const Text('新訂單通知'),
                  value: notifyNew,
                  onChanged: exists
                      ? (v) => _toggleNotify('notifyNewOrder', v)
                      : null,
                ),
                SwitchListTile(
                  title: const Text('系統公告通知'),
                  value: notifySystem,
                  onChanged: exists
                      ? (v) => _toggleNotify('notifySystem', v)
                      : null,
                ),
                const Divider(height: 32),
                const Text(
                  '變更密碼',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _pwdOldCtrl,
                  decoration: const InputDecoration(
                    labelText: '舊密碼',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  obscureText: true,
                  enabled: !_updatingPwd,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pwdNewCtrl,
                  decoration: const InputDecoration(
                    labelText: '新密碼（至少 6 碼）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  obscureText: true,
                  enabled: !_updatingPwd,
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _updatingPwd ? null : () => _changePassword(auth),
                  icon: _updatingPwd
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_reset),
                  label: const Text('更新密碼'),
                ),
                const Divider(height: 32),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: () async {
                    await auth.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('登出'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ✅ Fix：AuthService 沒有 requireUser() → 用 extension 補齊（不改你原本 AuthService 檔）
extension AuthServiceRequireUserX on AuthService {
  Future<User> requireUser() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      throw FirebaseAuthException(code: 'not-signed-in', message: '請先登入');
    }
    return u;
  }
}
