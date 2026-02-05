// lib/pages/admin/system/admin_system_settings_page.dart
//
// ✅ AdminSystemSettingsPage（最終完整版｜可直接使用｜可編譯）
// ------------------------------------------------------------
// Firestore: app_config/{id}  (建議用 app_config/global)
// ------------------------------------------------------------
// 支援：
// - 文字/數字/布林開關/JSON(Map/List) 設定
// - merge 儲存（不覆蓋未顯示欄位）
// - 顯示 updatedAt
//
// 建議 app_config/global 欄位（可依你需求增減）：
// {
//   appName: "Osmile",
//   maintenance: { enabled: false, message: "系統維護中" },
//   featureFlags: { coupons: true, lottery: true, vendors: true },
//   checkout: { minOrderAmount: 0, freeShippingThreshold: 999 },
//   support: { lineId: "@osmile", phone: "02-xxxxxxx" },
//   updatedAt: Timestamp,
// }
//
// ------------------------------------------------------------

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSystemSettingsPage extends StatefulWidget {
  const AdminSystemSettingsPage({super.key});

  @override
  State<AdminSystemSettingsPage> createState() => _AdminSystemSettingsPageState();
}

class _AdminSystemSettingsPageState extends State<AdminSystemSettingsPage> {
  final _db = FirebaseFirestore.instance;

  /// 你可以改成 global / prod / staging 等
  final String _docId = 'global';

  /// 基本欄位 controllers
  final _appNameCtl = TextEditingController();
  final _supportLineCtl = TextEditingController();
  final _supportPhoneCtl = TextEditingController();

  /// 數字欄位 controllers
  final _minOrderCtl = TextEditingController();
  final _freeShipCtl = TextEditingController();

  /// 布林開關
  bool _maintenanceEnabled = false;
  bool _flagCoupons = true;
  bool _flagLottery = true;
  bool _flagVendors = true;

  /// 進階 JSON editor（允許你存任何 Map/List 設定）
  final _jsonCtl = TextEditingController();
  bool _jsonValid = true;

  DateTime? _updatedAt;
  bool _loading = true;
  bool _saving = false;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('app_config').doc(_docId);

  @override
  void initState() {
    super.initState();
    _load();
    _jsonCtl.addListener(_validateJson);
  }

  @override
  void dispose() {
    _appNameCtl.dispose();
    _supportLineCtl.dispose();
    _supportPhoneCtl.dispose();
    _minOrderCtl.dispose();
    _freeShipCtl.dispose();
    _jsonCtl.removeListener(_validateJson);
    _jsonCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final snap = await _ref.get();
      final data = snap.data() ?? {};

      // 安全取值
      _appNameCtl.text = (data['appName'] ?? 'Osmile').toString();

      final maintenance = _asMap(data['maintenance']);
      _maintenanceEnabled = maintenance['enabled'] == true;

      final featureFlags = _asMap(data['featureFlags']);
      _flagCoupons = featureFlags['coupons'] != false;
      _flagLottery = featureFlags['lottery'] != false;
      _flagVendors = featureFlags['vendors'] != false;

      final checkout = _asMap(data['checkout']);
      _minOrderCtl.text = _numToText(checkout['minOrderAmount'], fallback: '0');
      _freeShipCtl.text = _numToText(checkout['freeShippingThreshold'], fallback: '0');

      final support = _asMap(data['support']);
      _supportLineCtl.text = (support['lineId'] ?? '').toString();
      _supportPhoneCtl.text = (support['phone'] ?? '').toString();

      _updatedAt = _toDateTime(data['updatedAt']);

      // JSON editor：存放「你想額外保留的設定」
      // 這裡預設把整份 doc（去掉 updatedAt）丟進 editor，讓你可完整掌控
      final clone = Map<String, dynamic>.from(data);
      clone.remove('updatedAt');

      _jsonCtl.text = const JsonEncoder.withIndent('  ').convert(clone);
      _jsonValid = true;
    } catch (e) {
      _toast('載入失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _validateJson() {
    final t = _jsonCtl.text.trim();
    if (t.isEmpty) {
      if (_jsonValid != true) setState(() => _jsonValid = true);
      return;
    }
    try {
      final obj = jsonDecode(t);
      final ok = (obj is Map) || (obj is List);
      if (_jsonValid != ok) setState(() => _jsonValid = ok);
    } catch (_) {
      if (_jsonValid != false) setState(() => _jsonValid = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    // 1) JSON 必須合法
    if (!_jsonValid) {
      _toast('JSON 格式不正確，請修正後再儲存');
      return;
    }

    // 2) 數字欄位安全解析
    final minOrder = _tryParseNum(_minOrderCtl.text, fallback: 0);
    final freeShip = _tryParseNum(_freeShipCtl.text, fallback: 0);

    // 3) JSON 內容解析（若空則使用空 map）
    Map<String, dynamic> jsonMap = {};
    final rawJson = _jsonCtl.text.trim();
    if (rawJson.isNotEmpty) {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) {
        jsonMap = decoded.map((k, v) => MapEntry(k.toString(), v));
      } else {
        // 若你想允許 List 當根節點，可自行改存到某個欄位
        _toast('JSON 根節點請使用 Object（{...}）以便儲存到 Firestore');
        return;
      }
    }

    // 4) 用 UI 欄位覆蓋 JSON 中對應 key（確保 UI 為主）
    jsonMap['appName'] = _appNameCtl.text.trim().isEmpty ? 'Osmile' : _appNameCtl.text.trim();

    jsonMap['maintenance'] = {
      ..._asMap(jsonMap['maintenance']),
      'enabled': _maintenanceEnabled,
      // message 讓你在 JSON editor 裡自行維護（不強迫 UI）
    };

    jsonMap['featureFlags'] = {
      ..._asMap(jsonMap['featureFlags']),
      'coupons': _flagCoupons,
      'lottery': _flagLottery,
      'vendors': _flagVendors,
    };

    jsonMap['checkout'] = {
      ..._asMap(jsonMap['checkout']),
      'minOrderAmount': minOrder,
      'freeShippingThreshold': freeShip,
    };

    jsonMap['support'] = {
      ..._asMap(jsonMap['support']),
      'lineId': _supportLineCtl.text.trim(),
      'phone': _supportPhoneCtl.text.trim(),
    };

    setState(() => _saving = true);

    try {
      await _ref.set(
        {
          ...jsonMap,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _toast('已儲存設定');
      await _load(); // 重新載入以更新 updatedAt
    } catch (e) {
      _toast('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('系統設定（app_config）', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '重新載入',
            icon: const Icon(Icons.refresh),
            onPressed: _loading || _saving ? null : _load,
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: _loading || _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_saving ? '儲存中' : '儲存'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              children: [
                _sectionCard(
                  title: '基本資訊',
                  child: Column(
                    children: [
                      TextField(
                        controller: _appNameCtl,
                        decoration: const InputDecoration(
                          labelText: 'App 名稱（appName）',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _supportLineCtl,
                              decoration: const InputDecoration(
                                labelText: '客服 Line ID（support.lineId）',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _supportPhoneCtl,
                              decoration: const InputDecoration(
                                labelText: '客服電話（support.phone）',
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
                const SizedBox(height: 12),

                _sectionCard(
                  title: '維護模式（maintenance）',
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('啟用維護模式', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('maintenance.enabled = true 時，前台可顯示維護頁'),
                    value: _maintenanceEnabled,
                    onChanged: (v) => setState(() => _maintenanceEnabled = v),
                  ),
                ),
                const SizedBox(height: 12),

                _sectionCard(
                  title: '功能開關（featureFlags）',
                  child: Column(
                    children: [
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('優惠券', style: TextStyle(fontWeight: FontWeight.w800)),
                        value: _flagCoupons,
                        onChanged: (v) => setState(() => _flagCoupons = v ?? false),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('抽獎', style: TextStyle(fontWeight: FontWeight.w800)),
                        value: _flagLottery,
                        onChanged: (v) => setState(() => _flagLottery = v ?? false),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('廠商功能', style: TextStyle(fontWeight: FontWeight.w800)),
                        value: _flagVendors,
                        onChanged: (v) => setState(() => _flagVendors = v ?? false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                _sectionCard(
                  title: '結帳規則（checkout）',
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minOrderCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '最低下單金額（minOrderAmount）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _freeShipCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '免運門檻（freeShippingThreshold）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                _sectionCard(
                  title: '進階設定（JSON 編輯器）',
                  subtitle: '此區塊會把整份 app_config/$ _docId（不含 updatedAt）以 JSON 顯示，可自由增減欄位。',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: _jsonValid ? Colors.grey.shade300 : cs.error),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _jsonCtl,
                          maxLines: 16,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.all(12),
                            border: InputBorder.none,
                            hintText: '{\n  "featureFlags": {...}\n}',
                          ),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _jsonValid ? Icons.check_circle : Icons.error_outline,
                            color: _jsonValid ? Colors.green : cs.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _jsonValid ? 'JSON 格式正確' : 'JSON 格式不正確（無法儲存）',
                            style: TextStyle(
                              color: _jsonValid ? Colors.green : cs.error,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          if (_updatedAt != null)
                            Text(
                              '更新：${_formatUpdatedAt(_updatedAt!)}',
                              style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ------------------------------------------------------------
  // UI helpers
  // ------------------------------------------------------------

  Widget _sectionCard({required String title, String? subtitle, required Widget child}) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  String _formatUpdatedAt(DateTime dt) {
    // 你若要固定格式可改成 intl
    return '${dt.year.toString().padLeft(4, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ------------------------------------------------------------
// Helpers（安全取值 / 型別轉換）
// ------------------------------------------------------------

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return <String, dynamic>{};
}

DateTime? _toDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

String _numToText(dynamic v, {required String fallback}) {
  if (v == null) return fallback;
  if (v is num) return v.toString();
  final s = v.toString().trim();
  return s.isEmpty ? fallback : s;
}

num _tryParseNum(String s, {required num fallback}) {
  final t = s.trim();
  if (t.isEmpty) return fallback;
  final n = num.tryParse(t);
  return n ?? fallback;
}
