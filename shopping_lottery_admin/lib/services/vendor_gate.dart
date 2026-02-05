// lib/services/vendor_gate.dart
//
// ✅ VendorGate（最終完整版｜可編譯｜Vendor Only｜角色/綁定檢查｜自動導入 VendorShellPage）
//
// 功能：
// - 檢查 FirebaseAuth 是否登入
// - 讀取 users/{uid} 文件（檢查 vendorId / role / disabled 狀態）
// - 確保 vendorId 已綁定且合法
// - 補 vendorName（users.vendorName 或 vendors/{vendorId}.name）
// - 通過驗證 → 進入 VendorShellPage(vendorId, vendorName)
// - 錯誤時 → 顯示原因、可複製 UID / Email、支援重試與登出
//
// 依賴：
// - firebase_auth
// - cloud_firestore
// - flutter/material.dart
// - flutter/services.dart
// - pages/vendor_shell_page.dart
//
// 使用方式：
// 在 main_vendor.dart routes: { '/vendor': (_) => const VendorGate() }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pages/vendor_shell_page.dart';

class VendorGate extends StatefulWidget {
  const VendorGate({super.key});

  @override
  State<VendorGate> createState() => _VendorGateState();
}

class _VendorGateState extends State<VendorGate> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;
  String? _vendorId;
  String? _vendorName;

  String _s(dynamic v) => (v ?? '').toString().trim();
  bool _isTrue(dynamic v) => v == true;

  Future<void> _snack(String msg) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _copy(String text, {String done = '已複製'}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    await _snack(done);
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _vendorId = null;
      _vendorName = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('尚未登入，無法進入廠商後台');
      }

      final uDoc = await _db.collection('users').doc(user.uid).get();
      final uData = uDoc.data();

      if (uData == null) {
        throw Exception('找不到 users/${user.uid}，請確認使用者資料是否建立。');
      }

      if (_isTrue(uData['disabled'])) {
        throw Exception('此帳號已停用（users/${user.uid}.disabled = true）');
      }

      final vid = _s(uData['vendorId']);
      if (vid.isEmpty) {
        throw Exception('此帳號尚未綁定 vendorId，請由主後台設定 users/${user.uid}.vendorId');
      }

      // 角色檢查（可選）
      final role = _s(uData['role']).toLowerCase();
      final roles = (uData['roles'] is List) ? List.from(uData['roles']) : <dynamic>[];
      final rolesLower = roles.map((e) => _s(e).toLowerCase()).toList();
      final isVendorFlag = _isTrue(uData['isVendor']);
      final hasAnyRoleField = role.isNotEmpty || rolesLower.isNotEmpty || uData.containsKey('isVendor');

      if (hasAnyRoleField) {
        final okVendorRole = isVendorFlag || role == 'vendor' || rolesLower.contains('vendor');
        if (!okVendorRole) {
          throw Exception('此帳號無 Vendor 權限（role=$role / roles=${rolesLower.join(",")} / isVendor=$isVendorFlag）');
        }
      }

      // 取得 vendorName
      String? vn;
      final vnUser = _s(uData['vendorName']);
      if (vnUser.isNotEmpty) {
        vn = vnUser;
      } else {
        final vDoc = await _db.collection('vendors').doc(vid).get();
        final vData = vDoc.data();
        if (vData == null) {
          throw Exception('找不到 vendors/$vid 文件，請確認主後台已建立該廠商。');
        }
        final vnVendor = _s(vData['name']);
        if (vnVendor.isNotEmpty) vn = vnVendor;
      }

      if (!mounted) return;
      setState(() {
        _vendorId = vid;
        _vendorName = vn;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
    } catch (e) {
      await _snack('登出失敗：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      final user = _auth.currentUser;
      return Scaffold(
        appBar: AppBar(
          title: const Text('VendorGate'),
          actions: [
            IconButton(
              tooltip: '重試',
              onPressed: _bootstrap,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('無法進入廠商後台', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      const SizedBox(height: 10),
                      Text(_error!, style: TextStyle(color: cs.error)),
                      const SizedBox(height: 14),
                      if (user != null) ...[
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _copy(user.uid, done: '已複製 uid'),
                              icon: const Icon(Icons.copy),
                              label: const Text('複製 uid'),
                            ),
                            if (user.email != null)
                              OutlinedButton.icon(
                                onPressed: () => _copy(user.email!, done: '已複製 email'),
                                icon: const Icon(Icons.email_outlined),
                                label: const Text('複製 email'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('uid：${user.uid}\nemail：${user.email ?? "-"}',
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                        const SizedBox(height: 10),
                      ],
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: _bootstrap,
                            icon: const Icon(Icons.refresh),
                            label: const Text('重試'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _signOut,
                            icon: const Icon(Icons.logout),
                            label: const Text('登出'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false),
                            child: const Text('回首頁'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '常見原因：\n'
                        '1) users/{uid} 不存在\n'
                        '2) users/{uid}.vendorId 未綁定\n'
                        '3) vendors/{vendorId} 不存在\n'
                        '4) 角色欄位不是 vendor\n'
                        '5) Firestore rules 阻擋讀取\n',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final vid = (_vendorId ?? '').trim();
    if (vid.isEmpty) {
      return const Scaffold(body: Center(child: Text('vendorId 不可為空')));
    }

    return VendorShellPage(
      vendorId: vid,
      vendorName: (_vendorName ?? '').trim().isEmpty ? null : (_vendorName ?? '').trim(),
    );
  }
}
