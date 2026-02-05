// lib/pages/admin/system/system_settings_page.dart
//
// ✅ SystemSettingsPage（系統設定｜單檔完整版｜可編譯｜專業版）
// ------------------------------------------------------------
// 功能摘要：
// - Firestore 設定中心（app_config/system_settings）
// - 支援初始化文件（不存在時自動建立預設）
// - 維運模式（maintenanceMode + message）
// - 版本控管（minVersion / forceUpdate）
// - 下單購物（checkoutEnabled / paymentMethods）
// - 活動抽獎（lotteryEnabled / dailyLimit）
// - 訂單維運參數（autoCancelMinutes 等）
// - 一鍵儲存 patch（SetOptions merge）
// - 權限錯誤（permission-denied）提示
//
// Firestore 建議：
// app_config/system_settings
// {
//   appEnabled: true,
//   maintenanceMode: false,
//   maintenanceMessage: "系統維護中，請稍後再試",
//   minAndroidVersion: "1.0.0",
//   minIosVersion: "1.0.0",
//   forceUpdate: false,
//
//   checkoutEnabled: true,
//   paymentMethods: { "credit_card": true, "line_pay": true, "atm": false, "cod": false },
//   orderAutoCancelMinutes: 30,
//
//   lotteryEnabled: true,
//   lotteryDailyLimit: 1,
//
//   supportEmail: "support@osmile.com",
//   supportPhone: "",
//
//   updatedAt: Timestamp,
//   updatedBy: "uid"
// }
//
// 依賴：cloud_firestore, intl, flutter
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('app_config').doc('system_settings');

  // 預設值（避免 doc 不存在時整頁空）
  static const Map<String, dynamic> _defaults = {
    'appEnabled': true,
    'maintenanceMode': false,
    'maintenanceMessage': '系統維護中，請稍後再試',

    'minAndroidVersion': '1.0.0',
    'minIosVersion': '1.0.0',
    'forceUpdate': false,

    'checkoutEnabled': true,
    'paymentMethods': {
      'credit_card': true,
      'line_pay': true,
      'atm': false,
      'cod': false,
    },
    'orderAutoCancelMinutes': 30,

    'lotteryEnabled': true,
    'lotteryDailyLimit': 1,

    'supportEmail': '',
    'supportPhone': '',
  };

  // 本地狀態（表單）
  bool _appEnabled = true;
  bool _maintenanceMode = false;
  bool _forceUpdate = false;
  bool _checkoutEnabled = true;
  bool _lotteryEnabled = true;

  int _orderAutoCancelMinutes = 30;
  int _lotteryDailyLimit = 1;

  final _maintenanceMessageCtrl = TextEditingController();
  final _minAndroidVersionCtrl = TextEditingController();
  final _minIosVersionCtrl = TextEditingController();
  final _supportEmailCtrl = TextEditingController();
  final _supportPhoneCtrl = TextEditingController();

  // 付款方式
  final Map<String, bool> _paymentMethods = {
    'credit_card': true,
    'line_pay': true,
    'atm': false,
    'cod': false,
  };

  bool _hydrated = false; // 避免 Stream 反覆覆蓋使用者正在編輯的內容
  bool _saving = false;

  @override
  void dispose() {
    _maintenanceMessageCtrl.dispose();
    _minAndroidVersionCtrl.dispose();
    _minIosVersionCtrl.dispose();
    _supportEmailCtrl.dispose();
    _supportPhoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('系統設定', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              _hydrated = false; // 強制重新注入一次
            }),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return _ErrorView(
              title: '載入失敗',
              message: snap.error.toString(),
              hint: '請確認 Firestore rules：app_config 可讀，但寫入需 admin。',
              onRetry: () => setState(() {}),
            );
          }

          final exists = snap.data?.exists == true;
          final data = <String, dynamic>{
            ..._defaults,
            ...(snap.data?.data() ?? const <String, dynamic>{}),
          };

          if (!_hydrated) {
            _hydrateFrom(data);
            _hydrated = true;
          }

          final updatedAt = _toDateTime(data['updatedAt']);
          final updatedText = updatedAt == null
              ? '—'
              : DateFormat('yyyy/MM/dd HH:mm').format(updatedAt);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _HeaderCard(
                exists: exists,
                updatedText: updatedText,
                onInit: exists ? null : _initDocIfMissing,
              ),
              const SizedBox(height: 12),

              _SectionTitle(
                title: '全域狀態',
                subtitle: '影響 App 是否可用、維運提示與強制更新策略',
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _appEnabled,
                        onChanged: _saving ? null : (v) => setState(() => _appEnabled = v),
                        title: const Text('App 全域啟用', style: TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(
                          _appEnabled ? '目前：啟用（正常使用）' : '目前：停用（建議搭配維運模式訊息）',
                          style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Divider(height: 18),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _maintenanceMode,
                        onChanged: _saving ? null : (v) => setState(() => _maintenanceMode = v),
                        title: const Text('維運模式（maintenanceMode）', style: TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(
                          _maintenanceMode ? '目前：維運中（App 前台建議顯示維運頁/提示）' : '目前：關閉',
                          style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _maintenanceMessageCtrl,
                        enabled: !_saving,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: '維運提示文字（maintenanceMessage）',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const Divider(height: 18),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _forceUpdate,
                        onChanged: _saving ? null : (v) => setState(() => _forceUpdate = v),
                        title: const Text('強制更新（forceUpdate）', style: TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(
                          _forceUpdate ? '目前：強制更新開啟（低於最低版本需阻擋）' : '目前：關閉（低於最低版本可提示但不阻擋）',
                          style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minAndroidVersionCtrl,
                              enabled: !_saving,
                              decoration: const InputDecoration(
                                labelText: 'Android 最低版本（minAndroidVersion）',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _minIosVersionCtrl,
                              enabled: !_saving,
                              decoration: const InputDecoration(
                                labelText: 'iOS 最低版本（minIosVersion）',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),
              _SectionTitle(
                title: '下單 / 付款設定',
                subtitle: '你要的「能下單買東西」核心開關都在這裡',
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _checkoutEnabled,
                        onChanged: _saving ? null : (v) => setState(() => _checkoutEnabled = v),
                        title: const Text('允許下單（checkoutEnabled）', style: TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(
                          _checkoutEnabled ? '目前：允許下單' : '目前：禁止下單（前台需顯示提示）',
                          style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Divider(height: 18),
                      _SubTitleRow(
                        title: '付款方式（paymentMethods）',
                        subtitle: '建議前台依此決定可選的付款選項',
                      ),
                      const SizedBox(height: 8),
                      _pmToggle('credit_card', '信用卡'),
                      _pmToggle('line_pay', 'LINE Pay'),
                      _pmToggle('atm', 'ATM 轉帳'),
                      _pmToggle('cod', '貨到付款'),
                      const Divider(height: 18),
                      _SubTitleRow(
                        title: '訂單維運參數',
                        subtitle: '下單後若未付款，自動取消（分鐘）',
                      ),
                      const SizedBox(height: 8),
                      _IntStepperRow(
                        label: 'orderAutoCancelMinutes',
                        value: _orderAutoCancelMinutes,
                        min: 5,
                        max: 1440,
                        step: 5,
                        enabled: !_saving,
                        onChanged: (v) => setState(() => _orderAutoCancelMinutes = v),
                        hint: '建議 30～60 分鐘；0 代表不自動取消（不建議）',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),
              _SectionTitle(
                title: '活動抽獎設定',
                subtitle: '你要的「活動抽獎」核心開關與限制在這裡',
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _lotteryEnabled,
                        onChanged: _saving ? null : (v) => setState(() => _lotteryEnabled = v),
                        title: const Text('啟用抽獎（lotteryEnabled）', style: TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(
                          _lotteryEnabled ? '目前：抽獎可用' : '目前：抽獎停用（前台需隱藏入口或提示）',
                          style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Divider(height: 18),
                      _IntStepperRow(
                        label: 'lotteryDailyLimit',
                        value: _lotteryDailyLimit,
                        min: 0,
                        max: 50,
                        step: 1,
                        enabled: !_saving,
                        onChanged: (v) => setState(() => _lotteryDailyLimit = v),
                        hint: '0 代表不限制（通常不建議）',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),
              _SectionTitle(
                title: '客服資訊',
                subtitle: '前台可讀取這裡顯示聯絡方式',
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _supportEmailCtrl,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: '客服 Email（supportEmail）',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _supportPhoneCtrl,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: '客服電話（supportPhone）',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: cs.surface,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '提示：\n'
                    '1) app_config/* 讀取 rules 允許所有人 read，但 write 僅 admin。\n'
                    '2) 前台 App 建議在啟動時讀取 system_settings：\n'
                    '   - maintenanceMode / message：顯示維運頁\n'
                    '   - minVersion + forceUpdate：提示/阻擋\n'
                    '   - checkoutEnabled / lotteryEnabled：控制入口\n',
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? '儲存中...' : '儲存設定'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // UI helpers
  // ------------------------------------------------------------

  Widget _pmToggle(String key, String label) {
    final cs = Theme.of(context).colorScheme;
    final v = _paymentMethods[key] == true;
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: v,
      onChanged: _saving ? null : (nv) => setState(() => _paymentMethods[key] = nv),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        key,
        style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _hydrateFrom(Map<String, dynamic> d) {
    _appEnabled = _asBool(d['appEnabled'], fallback: true);
    _maintenanceMode = _asBool(d['maintenanceMode'], fallback: false);
    _forceUpdate = _asBool(d['forceUpdate'], fallback: false);

    _checkoutEnabled = _asBool(d['checkoutEnabled'], fallback: true);
    _lotteryEnabled = _asBool(d['lotteryEnabled'], fallback: true);

    _orderAutoCancelMinutes = _asInt(d['orderAutoCancelMinutes'], fallback: 30);
    _lotteryDailyLimit = _asInt(d['lotteryDailyLimit'], fallback: 1);

    _maintenanceMessageCtrl.text = (d['maintenanceMessage'] ?? _defaults['maintenanceMessage']).toString();
    _minAndroidVersionCtrl.text = (d['minAndroidVersion'] ?? _defaults['minAndroidVersion']).toString();
    _minIosVersionCtrl.text = (d['minIosVersion'] ?? _defaults['minIosVersion']).toString();

    _supportEmailCtrl.text = (d['supportEmail'] ?? '').toString();
    _supportPhoneCtrl.text = (d['supportPhone'] ?? '').toString();

    final pm = _asBoolMap(d['paymentMethods']);
    if (pm.isNotEmpty) {
      for (final k in _paymentMethods.keys) {
        _paymentMethods[k] = pm[k] ?? _paymentMethods[k]!;
      }
      // 若資料庫多了新 key，也補進來（避免被吃掉）
      for (final e in pm.entries) {
        _paymentMethods.putIfAbsent(e.key, () => e.value);
      }
    }
  }

  Future<void> _initDocIfMissing() async {
    final ok = await _confirm(
      title: '初始化系統設定',
      message: '將建立 app_config/system_settings 並寫入預設值，是否繼續？',
      confirmText: '建立',
    );
    if (ok != true) return;

    try {
      await _ref.set({
        ..._defaults,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已初始化 system_settings')));
      setState(() {
        _hydrated = false;
      });
    } catch (e) {
      _snack('初始化失敗：$e');
    }
  }

  Future<void> _save() async {
    // 基本防呆
    final msg = _maintenanceMessageCtrl.text.trim();
    if (_maintenanceMode && msg.isEmpty) {
      _snack('維運模式開啟時，maintenanceMessage 建議不要空白');
      return;
    }

    final autoCancel = _orderAutoCancelMinutes;
    if (autoCancel < 0) {
      _snack('orderAutoCancelMinutes 不可小於 0');
      return;
    }

    setState(() => _saving = true);
    try {
      final patch = <String, dynamic>{
        'appEnabled': _appEnabled,
        'maintenanceMode': _maintenanceMode,
        'maintenanceMessage': _maintenanceMessageCtrl.text.trim(),
        'minAndroidVersion': _minAndroidVersionCtrl.text.trim(),
        'minIosVersion': _minIosVersionCtrl.text.trim(),
        'forceUpdate': _forceUpdate,

        'checkoutEnabled': _checkoutEnabled,
        'paymentMethods': _paymentMethods,
        'orderAutoCancelMinutes': _orderAutoCancelMinutes,

        'lotteryEnabled': _lotteryEnabled,
        'lotteryDailyLimit': _lotteryDailyLimit,

        'supportEmail': _supportEmailCtrl.text.trim(),
        'supportPhone': _supportPhoneCtrl.text.trim(),

        'updatedAt': FieldValue.serverTimestamp(),
        // 'updatedBy': uid（若你有 auth service，可在這裡寫）
      };

      await _ref.set(patch, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已更新系統設定')));
    } catch (e) {
      _snack('儲存失敗：$e\n（若是 permission-denied，請確認當前帳號為 admin）');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmText)),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ------------------------------------------------------------
  // Type helpers
  // ------------------------------------------------------------
  static bool _asBool(dynamic v, {required bool fallback}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.toLowerCase() == 'true';
    return fallback;
  }

  static int _asInt(dynamic v, {required int fallback}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static Map<String, bool> _asBoolMap(dynamic v) {
    if (v is Map) {
      final out = <String, bool>{};
      v.forEach((k, val) {
        out[k.toString()] = val == true;
      });
      return out;
    }
    return <String, bool>{};
  }

  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}

// ============================================================
// UI components
// ============================================================

class _HeaderCard extends StatelessWidget {
  final bool exists;
  final String updatedText;
  final VoidCallback? onInit;

  const _HeaderCard({
    required this.exists,
    required this.updatedText,
    required this.onInit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.settings_outlined, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exists ? '系統設定已啟用' : '尚未建立 system_settings',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '更新時間：$updatedText',
                    style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (!exists && onInit != null)
              FilledButton.tonalIcon(
                onPressed: onInit,
                icon: const Icon(Icons.add),
                label: const Text('初始化'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

class _SubTitleRow extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SubTitleRow({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            subtitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _IntStepperRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final String? hint;

  const _IntStepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.enabled,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canDec = enabled && value - step >= min;
    final canInc = enabled && value + step <= max;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              tooltip: '-$step',
              onPressed: canDec ? () => onChanged(value - step) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                value.toString(),
                style: TextStyle(fontWeight: FontWeight.w900, color: cs.onPrimaryContainer),
              ),
            ),
            IconButton(
              tooltip: '+$step',
              onPressed: canInc ? () => onChanged(value + step) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(hint!, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final String? hint;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 44, color: cs.error),
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                  if (hint != null) ...[
                    const SizedBox(height: 10),
                    Text(hint!, style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重試'),
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
