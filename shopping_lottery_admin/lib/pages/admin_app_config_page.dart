// lib/pages/admin_app_config_page.dart
//
// ✅ AdminAppConfigPage（完整版・功能加強版）
//
// 目標：提供「系統設定 / 參數管理」的後台頁面（Admin 可編輯、Vendor/一般使用者可只讀）
//
// 功能：
// - 即時讀取 Firestore app_config/main
// - Admin：編輯常用設定（維護模式、客服資訊、公告 Banner、結帳/物流/付款、Feature Flags）
// - Admin：匯出 JSON（顯示 / 複製到剪貼簿）
// - Admin：匯入 JSON（貼上後驗證並寫入）
// - Admin：重置為預設（套用預設 + 可立即儲存）
// - 寫入時附帶：updatedAt / updatedByUid / updatedByEmail
// - （選用）寫入 history 子集合：app_config/main/history（失敗不阻斷）
//
// Firestore 建議結構：
// - app_config/main
//   - maintenanceMode: bool
//   - maintenanceMessage: String
//   - support: { email, phone, lineId, hours }
//   - banner: { enabled, text, linkUrl }
//   - checkout: { currency, taxRate, minOrderAmount, enableCoupons, enableLottery }
//   - shipping: { enabled, flatFee, freeThreshold, providers: [String] }
//   - payment: { creditCard, atm, cod, webhookEnabled }
//   - featureFlags: { key: bool, ... }
//   - updatedAt, updatedByUid, updatedByEmail
//
// 依賴：
// - cloud_firestore
// - firebase_auth
// - provider
// - services/admin_gate.dart
// - services/auth_service.dart
//
// Route：/app_config

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';
import '../services/auth_service.dart';

class AdminAppConfigPage extends StatefulWidget {
  const AdminAppConfigPage({super.key});

  @override
  State<AdminAppConfigPage> createState() => _AdminAppConfigPageState();
}

class _AdminAppConfigPageState extends State<AdminAppConfigPage> {
  final _db = FirebaseFirestore.instance;

  Future<RoleInfo>? _roleFuture;
  String? _lastUid;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('app_config').doc('main');

  Map<String, dynamic>? _draft; // 本地草稿（可編輯）
  bool _dirty = false; // 是否有未儲存修改
  bool _saving = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  Map<String, dynamic> _map(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  List<String> _stringList(dynamic v) {
    if (v is List) {
      return v
          .map((e) => (e ?? '').toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  num _toNum(dynamic v, {num fallback = 0}) {
    if (v is num) return v;
    return num.tryParse((v ?? '').toString().trim()) ?? fallback;
  }

  bool _toBool(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    final s = (v ?? '').toString().trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return fallback;
  }

  Map<String, dynamic> _defaults() {
    return <String, dynamic>{
      'maintenanceMode': false,
      'maintenanceMessage': '系統維護中，請稍後再試。',
      'support': {
        'email': 'support@osmile.com',
        'phone': '',
        'lineId': '',
        'hours': '週一至週五 09:00-18:00',
      },
      'banner': {
        'enabled': false,
        'text': '歡迎使用 Osmile！',
        'linkUrl': '',
      },
      'checkout': {
        'currency': 'TWD',
        'taxRate': 0,
        'minOrderAmount': 0,
        'enableCoupons': true,
        'enableLottery': true,
      },
      'shipping': {
        'enabled': true,
        'flatFee': 80,
        'freeThreshold': 1200,
        'providers': ['blackcat', 'post'],
      },
      'payment': {
        'creditCard': true,
        'atm': true,
        'cod': false,
        'webhookEnabled': true,
      },
      'featureFlags': <String, dynamic>{
        'enableSos': true,
        'enableVoiceAssistant': true,
        'enableVendorPortal': true,
      },
    };
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    // 寬鬆相容：缺欄位補預設、型別不對就轉成可用型別
    final d = _defaults();

    final maintenanceMode =
        _toBool(raw['maintenanceMode'], fallback: _toBool(d['maintenanceMode']));
    final maintenanceMessage = _s(raw['maintenanceMessage']).isEmpty
        ? _s(d['maintenanceMessage'])
        : _s(raw['maintenanceMessage']);

    final support = {..._map(d['support']), ..._map(raw['support'])};
    final banner = {..._map(d['banner']), ..._map(raw['banner'])};
    final checkout = {..._map(d['checkout']), ..._map(raw['checkout'])};
    final shipping = {..._map(d['shipping']), ..._map(raw['shipping'])};
    final payment = {..._map(d['payment']), ..._map(raw['payment'])};

    // providers
    shipping['providers'] = _stringList(shipping['providers']).isEmpty
        ? _stringList(_map(d['shipping'])['providers'])
        : _stringList(shipping['providers']);

    // numbers
    checkout['taxRate'] =
        _toNum(checkout['taxRate'], fallback: _toNum(_map(d['checkout'])['taxRate']));
    checkout['minOrderAmount'] = _toNum(checkout['minOrderAmount'],
        fallback: _toNum(_map(d['checkout'])['minOrderAmount']));
    shipping['flatFee'] =
        _toNum(shipping['flatFee'], fallback: _toNum(_map(d['shipping'])['flatFee']));
    shipping['freeThreshold'] = _toNum(shipping['freeThreshold'],
        fallback: _toNum(_map(d['shipping'])['freeThreshold']));

    // bools
    banner['enabled'] = _toBool(banner['enabled'], fallback: false);
    checkout['enableCoupons'] = _toBool(checkout['enableCoupons'], fallback: true);
    checkout['enableLottery'] = _toBool(checkout['enableLottery'], fallback: true);
    shipping['enabled'] = _toBool(shipping['enabled'], fallback: true);

    payment['creditCard'] = _toBool(payment['creditCard'], fallback: true);
    payment['atm'] = _toBool(payment['atm'], fallback: true);
    payment['cod'] = _toBool(payment['cod'], fallback: false);
    payment['webhookEnabled'] = _toBool(payment['webhookEnabled'], fallback: true);

    // feature flags: 保留預設 key + 合併外部 key
    final featureFlagsRaw = _map(raw['featureFlags']);
    final featureFlagsDefault = _map(d['featureFlags']);
    final featureFlags = <String, dynamic>{...featureFlagsDefault};

    for (final e in featureFlagsRaw.entries) {
      featureFlags[e.key] =
          _toBool(e.value, fallback: _toBool(featureFlagsDefault[e.key]));
    }

    // 若 raw 有新增 key（不在預設中），也收進來
    for (final e in featureFlagsRaw.entries) {
      if (!featureFlags.containsKey(e.key)) {
        featureFlags[e.key] = _toBool(e.value, fallback: false);
      }
    }

    return <String, dynamic>{
      'maintenanceMode': maintenanceMode,
      'maintenanceMessage': maintenanceMessage,
      'support': support,
      'banner': banner,
      'checkout': checkout,
      'shipping': shipping,
      'payment': payment,
      'featureFlags': featureFlags,
    };
  }

  dynamic _getPath(Map<String, dynamic> root, List<String> path) {
    dynamic cur = root;
    for (final k in path) {
      if (cur is Map) {
        cur = cur[k];
      } else {
        return null;
      }
    }
    return cur;
  }

  void _setPath(Map<String, dynamic> root, List<String> path, dynamic value) {
    if (path.isEmpty) return;
    Map<String, dynamic> cur = root;
    for (int i = 0; i < path.length - 1; i++) {
      final k = path[i];
      final next = cur[k];
      if (next is Map<String, dynamic>) {
        cur = next;
      } else if (next is Map) {
        cur[k] = next.cast<String, dynamic>();
        cur = cur[k] as Map<String, dynamic>;
      } else {
        cur[k] = <String, dynamic>{};
        cur = cur[k] as Map<String, dynamic>;
      }
    }
    cur[path.last] = value;
  }

  Future<void> _writeConfig({
    required Map<String, dynamic> data,
    required User user,
  }) async {
    final payload = <String, dynamic>{
      ..._normalize(data),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': user.uid,
      'updatedByEmail': user.email ?? '',
    };

    await _ref.set(payload, SetOptions(merge: true));

    // 選用：寫 history（失敗不阻斷）
    try {
      await _ref.collection('history').add({
        ...payload,
        'snapshotAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // ignore
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('確定')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _copyJson(Map<String, dynamic> config) async {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(config);
    await Clipboard.setData(ClipboardData(text: jsonStr));
    _snack('已複製 JSON 到剪貼簿');
  }

  Future<void> _showJsonDialog(Map<String, dynamic> config) async {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(config);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('匯出 JSON'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: SelectableText(jsonStr),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: jsonStr));
              if (context.mounted) Navigator.pop(context);
              _snack('已複製 JSON 到剪貼簿');
            },
            child: const Text('複製'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
        ],
      ),
    );
  }

  Future<void> _importJson({
    required Map<String, dynamic> current,
    required User user,
  }) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('匯入 JSON（會覆蓋/合併 main 設定）'),
        content: SizedBox(
          width: 760,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '請貼上 JSON（根節點需為 object）。\n'
                '系統會做基本驗證與 normalize，並寫入 app_config/main。',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                maxLines: 14,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '{\n  "maintenanceMode": false,\n  ...\n}',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('匯入')),
        ],
      ),
    );

    if (ok != true) return;

    final raw = ctrl.text.trim();
    if (raw.isEmpty) {
      _snack('JSON 不可空白');
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _snack('JSON 根節點需為 object（{}）');
        return;
      }
      final map = decoded.cast<String, dynamic>();

      setState(() => _saving = true);
      await _writeConfig(data: map, user: user);
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _draft = _normalize(map);
      });
      _snack('已匯入並寫入設定');
    } catch (e) {
      _snack('匯入失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetToDefault({
    required User user,
    required bool saveImmediately,
  }) async {
    final ok = await _confirm('重置為預設', '確定要套用預設值？${saveImmediately ? "並立即儲存到 Firestore。" : ""}');
    if (!ok) return;

    final def = _defaults();
    setState(() {
      _draft = _normalize(def);
      _dirty = true;
    });

    if (!saveImmediately) {
      _snack('已套用預設（尚未儲存）');
      return;
    }

    setState(() => _saving = true);
    try {
      await _writeConfig(data: def, user: user);
      if (!mounted) return;
      setState(() => _dirty = false);
      _snack('已重置並儲存');
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save({
    required User user,
    required Map<String, dynamic> draft,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _writeConfig(data: draft, user: user);
      if (!mounted) return;
      setState(() => _dirty = false);
      _snack('已儲存設定');
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // -------------------------
  // Editing helpers (Dialogs)
  // -------------------------

  Future<void> _editString({
    required bool canEdit,
    required String title,
    required String description,
    required List<String> path,
    required String currentValue,
  }) async {
    if (!canEdit) return;
    final ctrl = TextEditingController(text: currentValue);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (description.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(description, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ),
              TextField(
                controller: ctrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('套用')),
        ],
      ),
    );

    if (ok != true) return;
    final v = ctrl.text.trim();

    setState(() {
      final d = _draft ??= _normalize(_defaults());
      _setPath(d, path, v);
      _dirty = true;
    });
  }

  Future<void> _editNum({
    required bool canEdit,
    required String title,
    required String description,
    required List<String> path,
    required num currentValue,
    num? min,
    num? max,
  }) async {
    if (!canEdit) return;
    final ctrl = TextEditingController(text: currentValue.toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (description.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(description, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  isDense: true,
                  helperText: [
                    if (min != null) '最小 $min',
                    if (max != null) '最大 $max',
                  ].where((s) => s.trim().isNotEmpty).join(' · '),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('套用')),
        ],
      ),
    );

    if (ok != true) return;

    final parsed = num.tryParse(ctrl.text.trim());
    if (parsed == null) {
      _snack('請輸入正確數字');
      return;
    }
    if (min != null && parsed < min) {
      _snack('不可小於 $min');
      return;
    }
    if (max != null && parsed > max) {
      _snack('不可大於 $max');
      return;
    }

    setState(() {
      final d = _draft ??= _normalize(_defaults());
      _setPath(d, path, parsed);
      _dirty = true;
    });
  }

  Future<void> _editStringList({
    required bool canEdit,
    required String title,
    required String description,
    required List<String> path,
    required List<String> currentValue,
  }) async {
    if (!canEdit) return;
    final ctrl = TextEditingController(text: currentValue.join(', '));

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (description.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(description, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ),
              TextField(
                controller: ctrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: '用逗號分隔，例如：blackcat, post, hct',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('套用')),
        ],
      ),
    );

    if (ok != true) return;

    final list = ctrl.text
        .split(',')
        .map((e) => e.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() {
      final d = _draft ??= _normalize(_defaults());
      _setPath(d, path, list);
      _dirty = true;
    });
  }

  Future<void> _editFeatureFlags({
    required bool canEdit,
    required Map<String, dynamic> currentFlags,
  }) async {
    if (!canEdit) return;

    // 轉成可編輯的 local map（String->bool）
    final local = <String, bool>{
      for (final e in currentFlags.entries) e.key: _toBool(e.value, fallback: false),
    };

    final newKeyCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Feature Flags'),
          content: SizedBox(
            width: 720,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '管理功能開關（前端可透過 app_config/main.featureFlags 讀取）。\n'
                  '注意：key 建議使用英文 camelCase。',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: newKeyCtrl,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          labelText: '新增 key',
                          hintText: '例如 enableNewCheckout',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () {
                        final k = newKeyCtrl.text.trim();
                        if (k.isEmpty) return;
                        if (local.containsKey(k)) return;
                        setStateDialog(() {
                          local[k] = false;
                          newKeyCtrl.clear();
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('新增'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 360),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.35)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: local.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final key = local.keys.toList()..sort();
                      final k = key[i];
                      final v = local[k] ?? false;
                      return ListTile(
                        title: Text(k, style: const TextStyle(fontWeight: FontWeight.w800)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: v,
                              onChanged: (nv) => setStateDialog(() => local[k] = nv),
                            ),
                            IconButton(
                              tooltip: '刪除 key',
                              onPressed: () => setStateDialog(() => local.remove(k)),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                // 套用到 draft
                setState(() {
                  final d = _draft ??= _normalize(_defaults());
                  _setPath(d, ['featureFlags'], <String, dynamic>{
                    for (final e in local.entries) e.key: e.value,
                  });
                  _dirty = true;
                });
                Navigator.pop(ctx);
              },
              child: const Text('套用'),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------
  // UI
  // -------------------------

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget _tile({
    required bool canEdit,
    required String title,
    required String subtitle,
    required VoidCallback? onEdit,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle.isEmpty ? '-' : subtitle),
      trailing: trailing ??
          (canEdit
              ? IconButton(
                  tooltip: '編輯',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                )
              : null),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();
    final authSvc = context.read<AuthService>();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;

        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (user == null) {
          return const Scaffold(body: Center(child: Text('請先登入')));
        }

        if (_roleFuture == null || _lastUid != user.uid) {
          _lastUid = user.uid;
          _roleFuture = gate.ensureAndGetRole(user, forceRefresh: false);
        }

        return FutureBuilder<RoleInfo>(
          future: _roleFuture,
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (roleSnap.hasError) {
              return _SimpleErrorPage(
                title: '讀取角色失敗',
                message: '${roleSnap.error}',
                onRetry: () => setState(() {
                  gate.clearCache();
                  _roleFuture = gate.ensureAndGetRole(user, forceRefresh: true);
                }),
                onLogout: () async {
                  gate.clearCache();
                  await authSvc.signOut();
                  if (!context.mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                },
              );
            }

            final role = (roleSnap.data?.role ?? 'unknown').toString().trim().toLowerCase();
            final isAdmin = role == 'admin';
            final canEdit = isAdmin;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _ref.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Scaffold(
                    appBar: AppBar(
                      title: const Text('App 設定'),
                      centerTitle: true,
                      actions: [
                        IconButton(
                          tooltip: '登出',
                          icon: const Icon(Icons.logout),
                          onPressed: () async {
                            gate.clearCache();
                            await authSvc.signOut();
                            if (!context.mounted) return;
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                        ),
                      ],
                    ),
                    body: Center(
                      child: Text(
                        '讀取 app_config 失敗：${snap.error}',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snap.hasData) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }

                final data = snap.data!.data() ?? <String, dynamic>{};
                final normalized = _normalize(data);

                // 若使用者尚未開始修改（_dirty=false），就用遠端資料刷新 draft
                if (_draft == null || !_dirty) {
                  _draft = Map<String, dynamic>.from(normalized);
                }

                final draft = _draft ?? Map<String, dynamic>.from(normalized);

                // 取出各段
                final maintenanceMode = _toBool(draft['maintenanceMode'], fallback: false);
                final maintenanceMessage = _s(draft['maintenanceMessage']);

                final support = _map(draft['support']);
                final banner = _map(draft['banner']);
                final checkout = _map(draft['checkout']);
                final shipping = _map(draft['shipping']);
                final payment = _map(draft['payment']);
                final featureFlags = _map(draft['featureFlags']);

                final updatedBy = _s(data['updatedByEmail']);
                final updatedAt = data['updatedAt'];

                String updatedAtText = '-';
                try {
                  if (updatedAt != null && (updatedAt as dynamic).toDate is Function) {
                    final dt = (updatedAt as dynamic).toDate() as DateTime;
                    String two(int n) => n.toString().padLeft(2, '0');
                    updatedAtText =
                        '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
                  }
                } catch (_) {}

                return Scaffold(
                  appBar: AppBar(
                    title: const Text('App 設定'),
                    centerTitle: true,
                    actions: [
                      if (_dirty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.35)),
                                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.25),
                              ),
                              child: const Text('未儲存', style: TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: '匯出 JSON（顯示）',
                        onPressed: () => _showJsonDialog(draft),
                        icon: const Icon(Icons.code),
                      ),
                      IconButton(
                        tooltip: '複製 JSON',
                        onPressed: () => _copyJson(draft),
                        icon: const Icon(Icons.copy),
                      ),
                      IconButton(
                        tooltip: '匯入 JSON（Admin）',
                        onPressed: canEdit ? () => _importJson(current: draft, user: user) : null,
                        icon: const Icon(Icons.upload_file),
                      ),
                      IconButton(
                        tooltip: '重置預設（Admin）',
                        onPressed: canEdit
                            ? () => _resetToDefault(user: user, saveImmediately: false)
                            : null,
                        icon: const Icon(Icons.restart_alt),
                      ),
                      IconButton(
                        tooltip: '儲存（Admin）',
                        onPressed: canEdit && _dirty && !_saving ? () => _save(user: user, draft: draft) : null,
                        icon: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                      ),
                      IconButton(
                        tooltip: '登出',
                        icon: const Icon(Icons.logout),
                        onPressed: () async {
                          gate.clearCache();
                          await authSvc.signOut();
                          if (!context.mounted) return;
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                  body: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                canEdit ? '你目前是 Admin（可編輯）' : '你目前是 $role（只讀）',
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              Text('最後更新：$updatedAtText ${updatedBy.isEmpty ? "" : "· $updatedBy"}',
                                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
                              const SizedBox(height: 10),
                              if (canEdit)
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: !_dirty
                                            ? null
                                            : () async {
                                                final ok = await _confirm('放棄未儲存修改', '確定要放棄本地修改並重新載入遠端設定？');
                                                if (!ok) return;
                                                setState(() {
                                                  _dirty = false;
                                                  _draft = Map<String, dynamic>.from(normalized);
                                                });
                                                _snack('已放棄修改並重新載入');
                                              },
                                        icon: const Icon(Icons.undo),
                                        label: const Text('放棄修改'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: !_dirty || _saving ? null : () => _save(user: user, draft: draft),
                                        icon: const Icon(Icons.save),
                                        label: const Text('儲存變更'),
                                      ),
                                    ),
                                  ],
                                ),
                              if (canEdit) ...[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _saving
                                      ? null
                                      : () => _resetToDefault(user: user, saveImmediately: true),
                                  icon: const Icon(Icons.warning_amber_rounded),
                                  label: const Text('重置預設並立即儲存（高風險）'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // -----------------
                      // Maintenance
                      // -----------------
                      _sectionHeader('維護模式'),
                      Card(
                        elevation: 0,
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('maintenanceMode', style: TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: const Text('開啟後前端可顯示維護中提示並限制操作'),
                              value: maintenanceMode,
                              onChanged: canEdit
                                  ? (v) => setState(() {
                                        final d = _draft ??= _normalize(_defaults());
                                        d['maintenanceMode'] = v;
                                        _dirty = true;
                                      })
                                  : null,
                            ),
                            const Divider(height: 1),
                            _tile(
                              canEdit: canEdit,
                              title: 'maintenanceMessage',
                              subtitle: maintenanceMessage,
                              onEdit: () => _editString(
                                canEdit: canEdit,
                                title: 'maintenanceMessage',
                                description: '維護模式顯示文字（前端可顯示）。',
                                path: const ['maintenanceMessage'],
                                currentValue: maintenanceMessage,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // -----------------
                      // Support
                      // -----------------
                      _sectionHeader('客服資訊 support'),
                      Card(
                        elevation: 0,
                        child: Column(
                          children: [
                            _tile(
                              canEdit: canEdit,
                              title: 'support.email',
                              subtitle: _s(support['email']),
                              onEdit: () => _editString(
                                canEdit: canEdit,
                                title: 'support.email',
                                description: '客服信箱',
                                path: const ['support', 'email'],
                                currentValue: _s(support['email']),
                              ),
                            ),
                            const Divider(height: 1),
                            _tile(
                              canEdit: canEdit,
                              title: 'support.phone',
                              subtitle: _s(support['phone']),
                              onEdit: () => _editString(
                                canEdit: canEdit,
                                title: 'support.phone',
                                description: '客服電話（可留空）',
                                path: const ['support', 'phone'],
                                currentValue: _s(support['phone']),
                              ),
                            ),
                            const Divider(height: 1),
                            _tile(
                              canEdit: canEdit,
                              title: 'support.lineId',
                              subtitle: _s(support['lineId']),
                              onEdit: () => _editString(
                                canEdit: canEdit,
                                title: 'support.lineId',
                                description: 'LINE ID（可留空）',
                                path: const ['support', 'lineId'],
                                currentValue: _s(support['lineId']),
                              ),
                            ),
                            const Divider(height: 1),
                            _tile(
                              canEdit: canEdit,
                              title: 'support.hours',
                              subtitle: _s(support['hours']),
                              onEdit: () => _editString(
                                canEdit: canEdit,
                                title: 'support.hours',
                                description: '客服時間（例如：週一至週五 09:00-18:00）',
                                path: const ['support', 'hours'],
                                currentValue: _s(support['hours']),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // -----------------
                      // Banner
                      // -----------------
                      _sectionHeader('公告 Banner'),
                      Card(
                        elevation: 0,
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('banner.enabled', style: TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: const Text('前端可用此開關顯示/隱藏首頁 banner'),
                              value: _toBool(banner['enabled'], fallback: false),
                              onChanged: canEdit
                                  ? (v) => setState(() {
                                        final d = _draft ??= _normalize(_defaults());
                                        _setPath(d, const ['banner', 'enabled'], v);
                                        _dirty = true;
                                      })
                                  : null,
                            ),
                            const Divider(height: 1),
                            _tile(
                              canEdit: canEdit,
                              title: 'banner.text',
                              subtitle: _s(banner['text']),
                              onEdit: () => _editString(
                                canEdit: canEdit,
                                title: 'banner.text',
                                description: 'Banner 文字內容',
                                path: const ['banner', 'text'],
                                currentValue: _s(banner['text']),
                              ),
                            ),
                            const Divider(height: 1),
                            _tile(
                              canEdit: canEdit,
                              title: 'banner.linkUrl',
                              subtitle: _s(banner['linkUrl']),
                              onEdit: () => _editString(
                                canEdit: canEdit,
                                title: 'banner.linkUrl',
                                description: 'Banner 點擊連結（可留空）',
                                path: const ['banner', 'linkUrl'],
                                currentValue: _s(banner['linkUrl']),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // -----------------
                      // Checkout
                      // -----------------
                      _sectionHeader('結帳 checkout'),
                      Card(
                        elevation: 0,
                        child: Column(
                          children: [
                            _tile(
                              canEdit: canEdit,
                              title: 'checkout.currency',
                              subtitle: _s(checkout['currency']),
                              onEdit: () => _editString(
                                canEdit: canEdit,
                                title: 'checkout.currency',
                                description: '幣別代碼（例如：TWD / USD）',
                                path: const ['checkout', 'currency'],
                                currentValue: _s(checkout['currency']),
                              ),
                            ),
                            const Divider(height: 1),
                            _tile(
                              canEdit: canEdit,
                              title: 'checkout.taxRate',
                              subtitle: _toNum(checkout['taxRate']).toString(),
                              onEdit: () => _editNum(
                                canEdit: canEdit,
                                title: 'checkout.taxRate',
                                description: '稅率（例如 0.05 表示 5%）；若不用稅，填 0',
                                path: const ['checkout', 'taxRate'],
                                currentValue: _toNum(checkout['taxRate']),
                                min: 0,
                              ),
                            ),
                            const Divider(height: 1),
                            _tile(
                              canEdit: canEdit,
                              title: 'checkout.minOrderAmount',
                              subtitle: _toNum(checkout['minOrderAmount']).toString(),
                              onEdit: () => _editNum(
                                canEdit: canEdit,
                                title: 'checkout.minOrderAmount',
                                description: '最低下單金額（未達可在前端提示或禁用結帳）',
                                path: const ['checkout', 'minOrderAmount'],
                                currentValue: _toNum(checkout['minOrderAmount']),
                                min: 0,
                              ),
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: const Text('checkout.enableCoupons', style: TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: const Text('啟用優惠券/折扣流程'),
                              value: _toBool(checkout['enableCoupons'], fallback: true),
                              onChanged: canEdit
                                  ? (v) => setState(() {
                                        final d = _draft ??= _normalize(_defaults());
                                        _setPath(d, const ['checkout', 'enableCoupons'], v);
                                        _dirty = true;
                                      })
                                  : null,
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: const Text('checkout.enableLottery', style: TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: const Text('啟用抽獎/轉盤流程（付款後）'),
                              value: _toBool(checkout['enableLottery'], fallback: true),
                              onChanged: canEdit
                                  ? (v) => setState(() {
                                        final d = _draft ??= _normalize(_defaults());
                                        _setPath(d, const ['checkout', 'enableLottery'], v);
                                        _dirty = true;
                                      })
                                  : null,
                            ),
                          ],
                        ),
                      ),

                      // -----------------
                      // Shipping
                      // -----------------
                      _sectionHeader('物流 shipping'),
                      Card(
                        elevation: 0,
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('shipping.enabled', style: TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: const Text('是否啟用物流計算/配送選項'),
                              value: _toBool(shipping['enabled'], fallback: true),
                              onChanged: canEdit
                                  ? (v) => setState(() {
                                        final d = _draft ??= _normalize(_defaults());
                                        _setPath(d, const ['shipping', 'enabled'], v);
                                        _dirty = true;
                                      })
                                  : null,
                            ),
                            const Divider(height: 1),
                            _tile(
                              canEdit: canEdit,
                              title: 'shipping.flatFee',
                              subtitle: _toNum(shipping['flatFee']).toString(),
                              onEdit: () => _editNum(
                                canEdit: canEdit,
                                title: 'shipping.flatFee',
                                description: '運費固定金額',
                                path: const ['shipping', 'flatFee'],
                                currentValue: _toNum(shipping['flatFee']),
                                min: 0,
                              ),
                            ),
                            const Divider(height: 1),
                            _tile(
                              canEdit: canEdit,
                              title: 'shipping.freeThreshold',
                              subtitle: _toNum(shipping['freeThreshold']).toString(),
                              onEdit: () => _editNum(
                                canEdit: canEdit,
                                title: 'shipping.freeThreshold',
                                description: '滿額免運門檻（若不用免運可填 0）',
                                path: const ['shipping', 'freeThreshold'],
                                currentValue: _toNum(shipping['freeThreshold']),
                                min: 0,
                              ),
                            ),
                            const Divider(height: 1),
                            _tile(
                              canEdit: canEdit,
                              title: 'shipping.providers',
                              subtitle: _stringList(shipping['providers']).join(', '),
                              onEdit: () => _editStringList(
                                canEdit: canEdit,
                                title: 'shipping.providers',
                                description: '物流供應商代碼列表（逗號分隔）',
                                path: const ['shipping', 'providers'],
                                currentValue: _stringList(shipping['providers']),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // -----------------
                      // Payment
                      // -----------------
                      _sectionHeader('付款 payment'),
                      Card(
                        elevation: 0,
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('payment.creditCard', style: TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: const Text('信用卡付款'),
                              value: _toBool(payment['creditCard'], fallback: true),
                              onChanged: canEdit
                                  ? (v) => setState(() {
                                        final d = _draft ??= _normalize(_defaults());
                                        _setPath(d, const ['payment', 'creditCard'], v);
                                        _dirty = true;
                                      })
                                  : null,
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: const Text('payment.atm', style: TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: const Text('ATM 轉帳'),
                              value: _toBool(payment['atm'], fallback: true),
                              onChanged: canEdit
                                  ? (v) => setState(() {
                                        final d = _draft ??= _normalize(_defaults());
                                        _setPath(d, const ['payment', 'atm'], v);
                                        _dirty = true;
                                      })
                                  : null,
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: const Text('payment.cod', style: TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: const Text('貨到付款（COD）'),
                              value: _toBool(payment['cod'], fallback: false),
                              onChanged: canEdit
                                  ? (v) => setState(() {
                                        final d = _draft ??= _normalize(_defaults());
                                        _setPath(d, const ['payment', 'cod'], v);
                                        _dirty = true;
                                      })
                                  : null,
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: const Text('payment.webhookEnabled', style: TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: const Text('是否啟用 webhook（支付回調）'),
                              value: _toBool(payment['webhookEnabled'], fallback: true),
                              onChanged: canEdit
                                  ? (v) => setState(() {
                                        final d = _draft ??= _normalize(_defaults());
                                        _setPath(d, const ['payment', 'webhookEnabled'], v);
                                        _dirty = true;
                                      })
                                  : null,
                            ),
                          ],
                        ),
                      ),

                      // -----------------
                      // Feature Flags
                      // -----------------
                      _sectionHeader('Feature Flags'),
                      Card(
                        elevation: 0,
                        child: Column(
                          children: [
                            ListTile(
                              title: const Text('featureFlags', style: TextStyle(fontWeight: FontWeight.w900)),
                              subtitle: Text(
                                featureFlags.isEmpty
                                    ? '（空）'
                                    : '共 ${featureFlags.length} 個 key（點擊管理）',
                              ),
                              trailing: canEdit
                                  ? FilledButton.icon(
                                      onPressed: () => _editFeatureFlags(
                                        canEdit: canEdit,
                                        currentFlags: featureFlags,
                                      ),
                                      icon: const Icon(Icons.tune),
                                      label: const Text('管理'),
                                    )
                                  : null,
                              onTap: canEdit
                                  ? () => _editFeatureFlags(
                                        canEdit: canEdit,
                                        currentFlags: featureFlags,
                                      )
                                  : null,
                            ),
                            const Divider(height: 1),
                            if (featureFlags.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('目前沒有 feature flags'),
                              )
                            else
                              ...(() {
                                final keys = featureFlags.keys.toList()..sort();
                                return keys.map((k) {
                                  final v = _toBool(featureFlags[k], fallback: false);
                                  return Column(
                                    children: [
                                      SwitchListTile(
                                        title: Text(k, style: const TextStyle(fontWeight: FontWeight.w800)),
                                        subtitle: Text(v ? 'true' : 'false'),
                                        value: v,
                                        onChanged: canEdit
                                            ? (nv) => setState(() {
                                                  final d = _draft ??= _normalize(_defaults());
                                                  final flags = _map(_getPath(d, const ['featureFlags']));
                                                  flags[k] = nv;
                                                  _setPath(d, const ['featureFlags'], flags);
                                                  _dirty = true;
                                                })
                                            : null,
                                      ),
                                      const Divider(height: 1),
                                    ],
                                  );
                                }).toList();
                              })(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),
                      if (canEdit)
                        FilledButton.icon(
                          onPressed: !_dirty || _saving ? null : () => _save(user: user, draft: draft),
                          icon: const Icon(Icons.save),
                          label: const Text('儲存全部變更'),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// -------------------- Simple Error Page --------------------

class _SimpleErrorPage extends StatelessWidget {
  const _SimpleErrorPage({
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重試'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () async => onLogout(),
                        icon: const Icon(Icons.logout),
                        label: const Text('登出'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
