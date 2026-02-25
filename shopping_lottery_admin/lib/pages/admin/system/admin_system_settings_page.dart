// lib/pages/admin/system/admin_system_settings_page.dart
//
// ✅ AdminSystemSettingsPage（系統設定｜可編譯完整版｜已修正 lint）
// ------------------------------------------------------------
// - Firestore 路徑：app_config/system_settings（可自行改）
// - 讀取/編輯/儲存設定（merge）
// - 常用開關：maintenanceMode / enableCoupons / enableCampaigns / enableSOS...
// - 常用欄位：supportEmail / supportPhone / maintenanceMessage...
// - 提供「原始 JSON 檢視」與「整包 JSON 編輯」
//
// ✅ 已修正：
// - deprecated_member_use：withOpacity → withValues(alpha: ...)
// - use_build_context_synchronously：async gap 後使用 context → 先取 messenger 再用
//
// 依賴：cloud_firestore
// ------------------------------------------------------------

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSystemSettingsPage extends StatefulWidget {
  const AdminSystemSettingsPage({super.key});

  @override
  State<AdminSystemSettingsPage> createState() =>
      _AdminSystemSettingsPageState();
}

class _AdminSystemSettingsPageState extends State<AdminSystemSettingsPage> {
  final _db = FirebaseFirestore.instance;

  // ✅ 你可以改成你專案實際的設定路徑
  static const String _collection = 'app_config';
  static const String _docId = 'system_settings';

  bool _loading = true;
  String? _error;

  Map<String, dynamic> _data = <String, dynamic>{};
  String? _saveResult;

  // UI controllers
  final _supportEmailCtrl = TextEditingController();
  final _supportPhoneCtrl = TextEditingController();
  final _maintenanceMsgCtrl = TextEditingController();
  final _defaultShippingFeeCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _supportEmailCtrl.dispose();
    _supportPhoneCtrl.dispose();
    _maintenanceMsgCtrl.dispose();
    _defaultShippingFeeCtrl.dispose();
    _taxRateCtrl.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection(_collection).doc(_docId);

  // -----------------------------
  // helpers
  // -----------------------------
  bool _b(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = (v ?? '').toString().toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return fallback;
  }

  num _n(dynamic v, {num fallback = 0}) {
    if (v is num) return v;
    return num.tryParse((v ?? '').toString()) ?? fallback;
  }

  String _s(dynamic v) => (v ?? '').toString();

  void _bindControllersFromData() {
    _supportEmailCtrl.text = _s(_data['supportEmail']);
    _supportPhoneCtrl.text = _s(_data['supportPhone']);
    _maintenanceMsgCtrl.text = _s(_data['maintenanceMessage']);
    _defaultShippingFeeCtrl.text = _n(_data['defaultShippingFee']).toString();
    _taxRateCtrl.text = _n(_data['taxRate']).toString();
  }

  Map<String, dynamic> _buildDefault() {
    return <String, dynamic>{
      'maintenanceMode': false,
      'maintenanceMessage': '系統維護中，請稍後再試。',
      'enableCoupons': true,
      'enableCampaigns': true,
      'enableSOS': true,
      'enableVendorPortal': true,
      'supportEmail': '',
      'supportPhone': '',
      'defaultShippingFee': 0,
      'taxRate': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // -----------------------------
  // load / save
  // -----------------------------
  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _saveResult = null;
    });

    try {
      final doc = await _ref.get();
      if (!doc.exists) {
        // 若不存在就先建立一份預設
        final defaults = _buildDefault();
        await _ref.set(defaults, SetOptions(merge: true));
        _data = Map<String, dynamic>.from(defaults);
      } else {
        _data = Map<String, dynamic>.from(doc.data() ?? <String, dynamic>{});
      }

      _bindControllersFromData();

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    // ✅ 先取 messenger，避免 async gap 後再用 context
    final messenger = ScaffoldMessenger.of(context);

    try {
      final patch = <String, dynamic>{
        'maintenanceMode': _b(_data['maintenanceMode']),
        'maintenanceMessage': _maintenanceMsgCtrl.text.trim(),
        'enableCoupons': _b(_data['enableCoupons'], fallback: true),
        'enableCampaigns': _b(_data['enableCampaigns'], fallback: true),
        'enableSOS': _b(_data['enableSOS'], fallback: true),
        'enableVendorPortal': _b(_data['enableVendorPortal'], fallback: true),
        'supportEmail': _supportEmailCtrl.text.trim(),
        'supportPhone': _supportPhoneCtrl.text.trim(),
        'defaultShippingFee': _n(
          _defaultShippingFeeCtrl.text.trim(),
          fallback: 0,
        ),
        'taxRate': _n(_taxRateCtrl.text.trim(), fallback: 0),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _ref.set(patch, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _saveResult = '已儲存：${DateTime.now().toIso8601String()}';
        _data = {..._data, ...patch}; // 本地同步
      });

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('系統設定已儲存')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    }
  }

  // -----------------------------
  // raw json edit
  // -----------------------------
  String _prettyJson(Map<String, dynamic> m) {
    return const JsonEncoder.withIndent('  ').convert(m);
  }

  Future<void> _editRawJson() async {
    // ✅ 先取 messenger，避免 async gap 後再用 context
    final messenger = ScaffoldMessenger.of(context);

    final ctrl = TextEditingController(text: _prettyJson(_data));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          '編輯原始 JSON',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: 720,
          child: TextField(
            controller: ctrl,
            maxLines: 18,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              hintText: '{ ... }',
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('套用'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final parsed = json.decode(ctrl.text) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _data = Map<String, dynamic>.from(parsed));
      _bindControllersFromData();
      messenger.showSnackBar(const SnackBar(content: Text('已套用到本地（記得按儲存）')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('JSON 格式錯誤：$e')));
    }
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            '系統設定',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Center(child: Text('載入失敗：$_error')),
      );
    }

    final maintenance = _b(_data['maintenanceMode']);
    final enableCoupons = _b(_data['enableCoupons'], fallback: true);
    final enableCampaigns = _b(_data['enableCampaigns'], fallback: true);
    final enableSOS = _b(_data['enableSOS'], fallback: true);
    final enableVendorPortal = _b(_data['enableVendorPortal'], fallback: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '系統設定',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '重新載入',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '編輯原始 JSON',
            onPressed: _editRawJson,
            icon: const Icon(Icons.code),
          ),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('儲存'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_saveResult != null)
            Card(
              elevation: 0,
              // ✅ 修正：withOpacity deprecated → withValues(alpha: ...)
              color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _saveResult!,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          const SizedBox(height: 12),

          // Feature Toggles
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '功能開關',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      '維護模式 maintenanceMode',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('開啟後可在前台顯示維護訊息／阻擋操作（由前台自行判斷）'),
                    value: maintenance,
                    onChanged: (v) =>
                        setState(() => _data['maintenanceMode'] = v),
                  ),
                  if (maintenance) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _maintenanceMsgCtrl,
                      decoration: const InputDecoration(
                        labelText: '維護訊息 maintenanceMessage',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      '啟用優惠券 enableCoupons',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    value: enableCoupons,
                    onChanged: (v) =>
                        setState(() => _data['enableCoupons'] = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      '啟用活動/投放 enableCampaigns',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    value: enableCampaigns,
                    onChanged: (v) =>
                        setState(() => _data['enableCampaigns'] = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      '啟用 SOS enableSOS',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    value: enableSOS,
                    onChanged: (v) => setState(() => _data['enableSOS'] = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      '啟用 Vendor 後台 enableVendorPortal',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    value: enableVendorPortal,
                    onChanged: (v) =>
                        setState(() => _data['enableVendorPortal'] = v),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Support info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '客服資訊',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _supportEmailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'supportEmail',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _supportPhoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'supportPhone',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Pricing defaults
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '預設金流/費用',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _defaultShippingFeeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'defaultShippingFee',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _taxRateCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'taxRate（例：0.05）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Raw JSON preview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '原始設定 JSON（檢視）',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      // ✅ 修正：withOpacity deprecated → withValues(alpha: ...)
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    ),
                    child: Text(
                      _prettyJson(_data),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _editRawJson,
                        icon: const Icon(Icons.edit),
                        label: const Text('整包 JSON 編輯'),
                      ),
                      OutlinedButton.icon(
                        // ✅ 修正：async gap 後不再用 ScaffoldMessenger.of(context)
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await _ref.set(_data, SetOptions(merge: true));
                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('已 merge 原始 JSON 到 Firestore'),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text('merge 失敗：$e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('直接 merge 上傳'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
