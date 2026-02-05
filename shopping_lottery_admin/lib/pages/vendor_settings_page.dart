// lib/pages/vendor_settings_page.dart
//
// ✅ VendorSettingsPage（完整版｜可編譯｜帳號設定中心｜修改密碼｜通知偏好｜登出）
//
// 功能：
// - 顯示廠商帳號資訊（Email、廠商名稱、建立時間）
// - 修改密碼（含驗證）
// - 通知偏好開關（Firestore vendor doc 更新）
// - 登出按鈕（AuthService.signOut）
// - Firestore vendor 文件同步顯示
//
// 依賴：cloud_firestore, firebase_auth, flutter/material, provider
//
// 結構：
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

  Future<void> _changePassword(AuthService auth) async {
    final oldPwd = _pwdOldCtrl.text.trim();
    final newPwd = _pwdNewCtrl.text.trim();
    if (oldPwd.isEmpty || newPwd.isEmpty) {
      _snack('請輸入舊密碼與新密碼');
      return;
    }

    setState(() => _updatingPwd = true);
    try {
      final user = auth.requireUser();
      final email = user.email;
      if (email == null) throw Exception('目前帳號無 Email');

      final cred = EmailAuthProvider.credential(email: email, password: oldPwd);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPwd);
      _snack('密碼已更新成功');
      _pwdOldCtrl.clear();
      _pwdNewCtrl.clear();
    } catch (e) {
      _snack('密碼更新失敗：$e');
    } finally {
      setState(() => _updatingPwd = false);
    }
  }

  Future<void> _toggleNotify(String field, bool value) async {
    await _db.collection('vendors').doc(widget.vendorId).set(
      {field: value},
      SetOptions(merge: true),
    );
    _snack('已更新通知設定');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

    return Scaffold(
      appBar: AppBar(title: const Text('帳號設定')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _db.collection('vendors').doc(vid).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('讀取失敗：${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final d = snap.data!.data() ?? {};
          final name = d['name'] ?? '-';
          final email = d['contactEmail'] ?? auth.currentUser?.email ?? '-';
          final createdAt = (d['createdAt'] is Timestamp)
              ? (d['createdAt'] as Timestamp).toDate().toString().split(' ').first
              : '-';
          final notifyNew = d['notifyNewOrder'] ?? true;
          final notifySystem = d['notifySystem'] ?? true;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 1,
                  child: ListTile(
                    title: const Text('廠商名稱', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(name),
                  ),
                ),
                Card(
                  elevation: 1,
                  child: ListTile(
                    title: const Text('帳號 Email', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(email),
                  ),
                ),
                Card(
                  elevation: 1,
                  child: ListTile(
                    title: const Text('建立日期', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(createdAt),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('通知設定', style: TextStyle(fontWeight: FontWeight.w900)),
                SwitchListTile(
                  title: const Text('新訂單通知'),
                  value: notifyNew,
                  onChanged: (v) => _toggleNotify('notifyNewOrder', v),
                ),
                SwitchListTile(
                  title: const Text('系統公告通知'),
                  value: notifySystem,
                  onChanged: (v) => _toggleNotify('notifySystem', v),
                ),
                const Divider(height: 32),
                const Text('變更密碼', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                TextField(
                  controller: _pwdOldCtrl,
                  decoration: const InputDecoration(
                    labelText: '舊密碼',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pwdNewCtrl,
                  decoration: const InputDecoration(
                    labelText: '新密碼',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  obscureText: true,
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
                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () async {
                    await auth.signOut();
                    if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
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
