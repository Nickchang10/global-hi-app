// lib/pages/role_bootstrap_tool_page.dart
//
// RoleBootstrapToolPage（完整版｜可編譯）
// - 開發/測試用角色初始化工具
// - 寫入 users/{uid} 或 roles/{uid}
// - 設定 role: admin/vendor 與 vendorId
//
// 依賴：
// - cloud_firestore
// - firebase_auth
// - provider
// - services/admin_gate.dart (AdminGate, RoleInfo)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';

class RoleBootstrapToolPage extends StatefulWidget {
  const RoleBootstrapToolPage({super.key});

  @override
  State<RoleBootstrapToolPage> createState() => _RoleBootstrapToolPageState();
}

class _RoleBootstrapToolPageState extends State<RoleBootstrapToolPage> {
  final _db = FirebaseFirestore.instance;

  final _targetUidCtrl = TextEditingController();
  final _vendorIdCtrl = TextEditingController();

  bool _loading = false;

  /// 寫入集合選擇：users 或 roles
  String _collection = 'users';

  /// role 選擇：admin / vendor
  String _role = 'admin';

  @override
  void dispose() {
    _targetUidCtrl.dispose();
    _vendorIdCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<RoleInfo?> _getMyRole() async {
    final gate = context.read<AdminGate>();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await gate.ensureAndGetRole(user, forceRefresh: true);
  }

  Future<void> _writeRoleDoc({
    required String uid,
    required String role,
    required String vendorId,
  }) async {
    final doc = _db.collection(_collection).doc(uid);

    await doc.set({
      'role': role.trim(),
      'vendorId': vendorId.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _applyToSelf(String role) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('尚未登入');
      return;
    }
    setState(() => _targetUidCtrl.text = user.uid);
    setState(() => _role = role);
    await _apply();
  }

  Future<void> _apply() async {
    if (kReleaseMode) {
      _snack('此工具已在 Release 模式停用');
      return;
    }

    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      _snack('尚未登入');
      return;
    }

    final targetUid = _targetUidCtrl.text.trim().isEmpty ? me.uid : _targetUidCtrl.text.trim();
    final vendorId = _vendorIdCtrl.text.trim();

    // 基本檢查
    if (targetUid.length < 8) {
      _snack('UID 看起來不正確');
      return;
    }
    if (_role == 'vendor' && vendorId.isEmpty) {
      _snack('vendor 需要 vendorId');
      return;
    }

    setState(() => _loading = true);
    try {
      // 若要限制只有 admin 能改別人：做一個最基本 gate
      //（自己改自己允許；改別人則要求當前使用者是 admin）
      final editingOther = targetUid != me.uid;
      if (editingOther) {
        final myRole = await _getMyRole();
        if (myRole == null || !myRole.isAdmin) {
          _snack('你不是 admin，無法修改其他 UID（請先把自己設成 admin）');
          return;
        }
      }

      await _writeRoleDoc(
        uid: targetUid,
        role: _role,
        vendorId: _role == 'vendor' ? vendorId : '',
      );

      // 刷新 gate cache（讓 dashboard 立即生效）
      if (mounted) {
        context.read<AdminGate>().clearCache();
      }

      _snack('已寫入 $_collection/$targetUid：role=$_role vendorId=${_role == 'vendor' ? vendorId : '(none)'}');
    } catch (e) {
      _snack('寫入失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _readTargetPreview() async {
    final uid = _targetUidCtrl.text.trim();
    if (uid.isEmpty) {
      _snack('請先輸入 UID');
      return;
    }
    try {
      final snap = await _db.collection(_collection).doc(uid).get();
      if (!snap.exists) {
        _snack('找不到文件：$_collection/$uid');
        return;
      }
      final data = snap.data() ?? <String, dynamic>{};
      final role = (data['role'] ?? '').toString();
      final vendorId = (data['vendorId'] ?? '').toString();

      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('預覽：$_collection/$uid', style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text('role: $role'),
                const SizedBox(height: 6),
                Text('vendorId: $vendorId'),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      _snack('讀取失敗：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) {
      return const Scaffold(
        body: Center(
          child: Text('RoleBootstrapToolPage 已在 Release 模式停用'),
        ),
      );
    }

    final me = FirebaseAuth.instance.currentUser;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('角色初始化工具（Dev）'),
        actions: [
          IconButton(
            tooltip: '預覽目標文件',
            onPressed: _loading ? null : _readTargetPreview,
            icon: const Icon(Icons.visibility_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            elevation: 0,
            color: cs.primaryContainer.withOpacity(0.35),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '此頁僅供開發/測試：用來快速寫入 role/vendorId 到 Firestore。\n'
                '建議正式上線前移除路由或用更嚴格的權限控管。',
                style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 當前登入者
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.person_outline),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      me == null ? '尚未登入' : '目前登入 UID：${me.uid}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // collection 選擇
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text('寫入集合：', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _collection,
                    items: const [
                      DropdownMenuItem(value: 'users', child: Text('users/{uid}')),
                      DropdownMenuItem(value: 'roles', child: Text('roles/{uid}')),
                    ],
                    onChanged: _loading ? null : (v) => setState(() => _collection = v ?? 'users'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // target uid
          TextField(
            controller: _targetUidCtrl,
            decoration: const InputDecoration(
              labelText: '目標 UID（留空＝自己）',
              border: OutlineInputBorder(),
            ),
            enabled: !_loading,
          ),
          const SizedBox(height: 12),

          // role
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text('角色：', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _role,
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('admin')),
                      DropdownMenuItem(value: 'vendor', child: Text('vendor')),
                    ],
                    onChanged: _loading ? null : (v) => setState(() => _role = v ?? 'admin'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _role == 'vendor' ? 'vendor 需要 vendorId' : 'admin 不需要 vendorId',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // vendorId
          TextField(
            controller: _vendorIdCtrl,
            decoration: const InputDecoration(
              labelText: 'vendorId（role=vendor 時必填）',
              border: OutlineInputBorder(),
            ),
            enabled: !_loading,
          ),
          const SizedBox(height: 14),

          // quick actions
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _loading ? null : () => _applyToSelf('admin'),
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('把自己設成 admin'),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : () => _applyToSelf('vendor'),
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('把自己設成 vendor'),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // apply
          FilledButton.icon(
            onPressed: _loading ? null : _apply,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: const Text('寫入（Apply）'),
          ),

          const SizedBox(height: 12),
          Text(
            '提示：若你 KPI 查詢出現 “requires an index” 的錯誤，請看我下面提供的索引建議。',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
