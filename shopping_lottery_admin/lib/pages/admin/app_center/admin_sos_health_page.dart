// lib/pages/admin/app_center/admin_sos_health_page.dart
//
// ✅ AdminSosHealthPage（A. 基礎專業版｜單檔完整版｜可編譯）
// ------------------------------------------------------------
// SOS / 健康模組（後台設定）
// - Firestore 讀寫 app_config/sos_health
// - 初始化文件（不存在時一鍵建立預設值）
// - 分區設定：SOS / 健康 / 提醒 / 進階條件
// - 立即預覽目前設定（Snapshot + 本地草稿）
// - 專業防呆：欄位容錯、數字驗證、保存確認、錯誤提示
//
// Firestore 建議：app_config/sos_health
// {
//   enabled: true,
//
//   // SOS
//   sosEnabled: true,
//   sosButtonEnabled: true,
//   sosTriggerHoldSeconds: 3,        // 長按秒數
//   sosCooldownSeconds: 30,          // 冷卻秒數
//   sosAutoCallEnabled: true,
//   sosCallNumber: "119",            // 撥號號碼
//   sosSmsEnabled: true,
//   sosSmsTemplate: "我需要協助，位置：{lat},{lng}",
//   sosNotifyAppEnabled: true,       // App 推播通知緊急聯絡人
//   sosShareLocationEnabled: true,
//   sosLocationPrecision: "high",    // low / balanced / high
//   sosMaxContacts: 5,
//
//   // Health
//   healthEnabled: true,
//   stepEnabled: true,
//   heartRateEnabled: true,
//   sleepEnabled: false,
//
//   // Reminders
//   reminderEnabled: true,
//   reminderWaterEnabled: false,
//   reminderMedicineEnabled: false,
//
//   // Access / gating
//   requiresDeviceBound: true,       // 必須綁定裝置才顯示
//   minAppVersion: "",               // 例："1.2.0"（可留空）
//
//   updatedAt: Timestamp,
//   updatedBy: "uid"
// }
//
// 依賴：cloud_firestore, intl
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminSosHealthPage extends StatefulWidget {
  const AdminSosHealthPage({super.key});

  @override
  State<AdminSosHealthPage> createState() => _AdminSosHealthPageState();
}

class _AdminSosHealthPageState extends State<AdminSosHealthPage> {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _cfgRef =>
      _db.collection('app_config').doc('sos_health');

  // 若你也想同步入口開關：app_config/app_center.sosHealthEnabled
  DocumentReference<Map<String, dynamic>> get _appCenterRef =>
      _db.collection('app_config').doc('app_center');

  static const Map<String, dynamic> _defaults = {
    'enabled': true,

    // SOS
    'sosEnabled': true,
    'sosButtonEnabled': true,
    'sosTriggerHoldSeconds': 3,
    'sosCooldownSeconds': 30,
    'sosAutoCallEnabled': true,
    'sosCallNumber': '119',
    'sosSmsEnabled': true,
    'sosSmsTemplate': '我需要協助，位置：{lat},{lng}',
    'sosNotifyAppEnabled': true,
    'sosShareLocationEnabled': true,
    'sosLocationPrecision': 'high', // low / balanced / high
    'sosMaxContacts': 5,

    // Health
    'healthEnabled': true,
    'stepEnabled': true,
    'heartRateEnabled': true,
    'sleepEnabled': false,

    // Reminders
    'reminderEnabled': true,
    'reminderWaterEnabled': false,
    'reminderMedicineEnabled': false,

    // Access / gating
    'requiresDeviceBound': true,
    'minAppVersion': '',
  };

  // ==============
  // Local draft
  // ==============
  bool _draftLoaded = false;
  bool _dirty = false;

  // switches
  late bool enabled;

  late bool sosEnabled;
  late bool sosButtonEnabled;
  late bool sosAutoCallEnabled;
  late bool sosSmsEnabled;
  late bool sosNotifyAppEnabled;
  late bool sosShareLocationEnabled;

  late bool healthEnabled;
  late bool stepEnabled;
  late bool heartRateEnabled;
  late bool sleepEnabled;

  late bool reminderEnabled;
  late bool reminderWaterEnabled;
  late bool reminderMedicineEnabled;

  late bool requiresDeviceBound;
  late bool syncToAppCenter; // 是否同步入口 app_center.sosHealthEnabled

  // text fields
  final _callNumber = TextEditingController();
  final _smsTemplate = TextEditingController();
  final _holdSeconds = TextEditingController();
  final _cooldownSeconds = TextEditingController();
  final _maxContacts = TextEditingController();
  final _minAppVersion = TextEditingController();

  String _locationPrecision = 'high';

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // 預設：同步入口開關（你可改成 false）
    syncToAppCenter = true;

    // 先以 defaults 初始化，避免 UI 空值
    _applyToDraft({..._defaults}, markDirty: false);
    _draftLoaded = true;
  }

  @override
  void dispose() {
    _callNumber.dispose();
    _smsTemplate.dispose();
    _holdSeconds.dispose();
    _cooldownSeconds.dispose();
    _maxContacts.dispose();
    _minAppVersion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS / 健康模組', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '重載遠端資料',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          const SizedBox(width: 4),
          if (_dirty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '未儲存',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _cfgRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !_draftLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return _ErrorView(
              title: '載入失敗',
              message: snap.error.toString(),
              hint: '請確認 Firestore 權限（app_config/sos_health）與網路狀態。',
              onRetry: () => setState(() {}),
            );
          }

          final exists = snap.data?.exists == true;
          final remote = {
            ..._defaults,
            ...(snap.data?.data() ?? const <String, dynamic>{}),
          };

          final updatedAt = _toDateTime(remote['updatedAt']);
          final updatedText =
              updatedAt == null ? '—' : DateFormat('yyyy/MM/dd HH:mm').format(updatedAt);

          // 若尚未被使用者改動（不 dirty），就用遠端覆蓋草稿
          if (!_dirty) {
            _applyToDraft(remote, markDirty: false);
            _draftLoaded = true;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _HeaderCard(
                exists: exists,
                updatedText: updatedText,
                enabled: enabled,
                onInit: exists ? null : _initDocIfMissing,
              ),
              const SizedBox(height: 12),

              _SectionTitle(
                title: '總開關',
                subtitle: '建議：enabled=false 時，App 端完全隱藏 SOS/健康模組入口與功能。',
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('啟用 SOS / 健康模組', style: TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(
                          enabled ? '目前：啟用' : '目前：停用',
                          style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                        ),
                        value: enabled,
                        onChanged: (v) => _setDraft(() => enabled = v),
                      ),
                      const Divider(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('同步到 App 控制中心入口開關',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                          '保存時同步寫入 app_config/app_center.sosHealthEnabled（避免入口顯示與模組狀態不一致）',
                          style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                        ),
                        value: syncToAppCenter,
                        onChanged: (v) => _setDraft(() => syncToAppCenter = v),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),
              _SectionTitle(
                title: 'SOS 設定',
                subtitle: '控制 SOS 觸發、通知、定位、冷卻與緊急聯絡人上限。',
              ),
              const SizedBox(height: 8),
              _card(
                child: Column(
                  children: [
                    _switchRow(
                      title: '啟用 SOS 功能',
                      subtitle: 'SOS 功能開關（建議與 enabled 一致，但可單獨關閉 SOS）',
                      value: sosEnabled,
                      onChanged: (v) => _setDraft(() => sosEnabled = v),
                    ),
                    _switchRow(
                      title: '啟用 SOS 按鍵觸發',
                      subtitle: 'App/裝置端是否顯示 SOS 按鈕或允許長按觸發',
                      value: sosButtonEnabled,
                      onChanged: (v) => _setDraft(() => sosButtonEnabled = v),
                    ),
                    const Divider(height: 12),

                    _numberField(
                      controller: _holdSeconds,
                      label: '長按觸發秒數（sosTriggerHoldSeconds）',
                      hint: '建議 2～5',
                      min: 1,
                      max: 20,
                      enabled: enabled && sosEnabled && sosButtonEnabled,
                      onChanged: (_) => _markDirty(),
                    ),
                    const SizedBox(height: 10),
                    _numberField(
                      controller: _cooldownSeconds,
                      label: '冷卻秒數（sosCooldownSeconds）',
                      hint: '避免連續觸發（建議 10～120）',
                      min: 0,
                      max: 3600,
                      enabled: enabled && sosEnabled,
                      onChanged: (_) => _markDirty(),
                    ),
                    const SizedBox(height: 10),

                    _switchRow(
                      title: '自動撥號',
                      subtitle: '觸發 SOS 後是否自動撥打指定號碼',
                      value: sosAutoCallEnabled,
                      onChanged: (v) => _setDraft(() => sosAutoCallEnabled = v),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _callNumber,
                      enabled: enabled && sosEnabled && sosAutoCallEnabled,
                      decoration: InputDecoration(
                        labelText: '撥號號碼（sosCallNumber）',
                        hintText: '例：119 / 110 / 家長電話',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => _markDirty(),
                    ),

                    const SizedBox(height: 12),
                    _switchRow(
                      title: '簡訊通知',
                      subtitle: '觸發 SOS 後是否發送簡訊內容（由 App/後端負責實作）',
                      value: sosSmsEnabled,
                      onChanged: (v) => _setDraft(() => sosSmsEnabled = v),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _smsTemplate,
                      enabled: enabled && sosEnabled && sosSmsEnabled,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: '簡訊模板（sosSmsTemplate）',
                        helperText: '可用變數：{lat} {lng} {address} {userName} {deviceName}',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => _markDirty(),
                    ),

                    const SizedBox(height: 12),
                    _switchRow(
                      title: 'App 推播通知緊急聯絡人',
                      subtitle: '觸發 SOS 後推播通知（需搭配通知中心/FCM 實作）',
                      value: sosNotifyAppEnabled,
                      onChanged: (v) => _setDraft(() => sosNotifyAppEnabled = v),
                    ),
                    _switchRow(
                      title: '分享定位',
                      subtitle: '觸發 SOS 後是否附帶定位資訊（需搭配定位權限/後端寫入）',
                      value: sosShareLocationEnabled,
                      onChanged: (v) => _setDraft(() => sosShareLocationEnabled = v),
                    ),

                    const SizedBox(height: 8),
                    _dropdown<String>(
                      label: '定位精度（sosLocationPrecision）',
                      value: _locationPrecision,
                      enabled: enabled && sosEnabled && sosShareLocationEnabled,
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('低（省電）')),
                        DropdownMenuItem(value: 'balanced', child: Text('平衡')),
                        DropdownMenuItem(value: 'high', child: Text('高（精準）')),
                      ],
                      onChanged: (v) => _setDraft(() => _locationPrecision = v ?? 'high'),
                    ),

                    const SizedBox(height: 10),
                    _numberField(
                      controller: _maxContacts,
                      label: '緊急聯絡人上限（sosMaxContacts）',
                      hint: '建議 3～10',
                      min: 1,
                      max: 50,
                      enabled: enabled && sosEnabled,
                      onChanged: (_) => _markDirty(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              _SectionTitle(
                title: '健康模組設定',
                subtitle: '控制健康卡片、步數/心率/睡眠等顯示與資料採集入口。',
              ),
              const SizedBox(height: 8),
              _card(
                child: Column(
                  children: [
                    _switchRow(
                      title: '啟用健康模組',
                      subtitle: '健康入口與健康卡片顯示',
                      value: healthEnabled,
                      onChanged: (v) => _setDraft(() => healthEnabled = v),
                    ),
                    const Divider(height: 12),
                    _switchRow(
                      title: '步數',
                      subtitle: '顯示步數卡 / 步數統計入口',
                      value: stepEnabled,
                      onChanged: (v) => _setDraft(() => stepEnabled = v),
                    ),
                    _switchRow(
                      title: '心率',
                      subtitle: '顯示心率卡 / 心率統計入口',
                      value: heartRateEnabled,
                      onChanged: (v) => _setDraft(() => heartRateEnabled = v),
                    ),
                    _switchRow(
                      title: '睡眠',
                      subtitle: '顯示睡眠卡 / 睡眠統計入口（若尚未接裝置可先關）',
                      value: sleepEnabled,
                      onChanged: (v) => _setDraft(() => sleepEnabled = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              _SectionTitle(
                title: '提醒設定',
                subtitle: '控制喝水/吃藥等提醒入口（實際排程可由 App 或 Cloud Functions 產生）。',
              ),
              const SizedBox(height: 8),
              _card(
                child: Column(
                  children: [
                    _switchRow(
                      title: '啟用提醒入口',
                      subtitle: '提醒總入口顯示（未啟用時隱藏所有提醒入口）',
                      value: reminderEnabled,
                      onChanged: (v) => _setDraft(() => reminderEnabled = v),
                    ),
                    const Divider(height: 12),
                    _switchRow(
                      title: '喝水提醒',
                      subtitle: '啟用喝水提醒入口/卡片（需 App 端實作提醒排程）',
                      value: reminderWaterEnabled,
                      onChanged: (v) => _setDraft(() => reminderWaterEnabled = v),
                      enabled: enabled && reminderEnabled,
                    ),
                    _switchRow(
                      title: '吃藥提醒',
                      subtitle: '啟用吃藥提醒入口/卡片（需 App 端實作提醒排程）',
                      value: reminderMedicineEnabled,
                      onChanged: (v) => _setDraft(() => reminderMedicineEnabled = v),
                      enabled: enabled && reminderEnabled,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              _SectionTitle(
                title: '進階條件',
                subtitle: '用於灰度/版本/裝置綁定條件（不影響後台管理頁）。',
              ),
              const SizedBox(height: 8),
              _card(
                child: Column(
                  children: [
                    _switchRow(
                      title: '必須綁定裝置才顯示',
                      subtitle: '未綁定裝置的使用者不顯示 SOS/健康入口',
                      value: requiresDeviceBound,
                      onChanged: (v) => _setDraft(() => requiresDeviceBound = v),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _minAppVersion,
                      decoration: InputDecoration(
                        labelText: '最低 App 版本（minAppVersion）',
                        hintText: '例：1.2.0（留空＝不限制）',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => _markDirty(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              _ActionBar(
                saving: _saving,
                dirty: _dirty,
                onReset: () async {
                  final ok = await _confirm(
                    title: '重設草稿',
                    message: '將捨棄本地尚未儲存的變更，改用遠端最新設定。',
                    confirmText: '重設',
                  );
                  if (ok != true) return;
                  setState(() {
                    _dirty = false; // 讓 StreamBuilder 重新覆蓋 draft
                  });
                },
                onSave: _saving ? null : () => _save(remoteSnapshot: remote),
              ),

              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: cs.surface,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '實作建議：\n'
                    '1) App 端啟動時讀取 app_config/sos_health，決定是否顯示入口與功能。\n'
                    '2) 若你有裝置端（手錶）SOS 觸發，建議把「長按秒數/冷卻」同步到裝置設定表。\n'
                    '3) 觸發 SOS 後的通知/簡訊/定位上報，可由 Cloud Functions 或 App 端統一處理。\n',
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // Save / Init
  // ============================================================

  Future<void> _initDocIfMissing() async {
    final ok = await _confirm(
      title: '初始化設定文件',
      message: '將建立 app_config/sos_health，並寫入預設值。是否繼續？',
      confirmText: '建立',
    );
    if (ok != true) return;

    try {
      await _cfgRef.set({
        ..._defaults,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已初始化 app_config/sos_health')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('初始化失敗：$e')));
    }
  }

  Future<void> _save({required Map<String, dynamic> remoteSnapshot}) async {
    // 基本驗證
    final hold = _parseInt(_holdSeconds.text, fallback: 3);
    final cooldown = _parseInt(_cooldownSeconds.text, fallback: 30);
    final maxC = _parseInt(_maxContacts.text, fallback: 5);

    if (hold < 1 || hold > 20) {
      _toast('長按秒數建議 1～20');
      return;
    }
    if (cooldown < 0 || cooldown > 3600) {
      _toast('冷卻秒數建議 0～3600');
      return;
    }
    if (maxC < 1 || maxC > 50) {
      _toast('緊急聯絡人上限建議 1～50');
      return;
    }

    final ok = await _confirm(
      title: '確認儲存',
      message: '將更新 SOS/健康模組設定並寫回 Firestore。是否繼續？',
      confirmText: '儲存',
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      final patch = <String, dynamic>{
        'enabled': enabled,

        // SOS
        'sosEnabled': sosEnabled,
        'sosButtonEnabled': sosButtonEnabled,
        'sosTriggerHoldSeconds': hold,
        'sosCooldownSeconds': cooldown,
        'sosAutoCallEnabled': sosAutoCallEnabled,
        'sosCallNumber': _callNumber.text.trim(),
        'sosSmsEnabled': sosSmsEnabled,
        'sosSmsTemplate': _smsTemplate.text.trim(),
        'sosNotifyAppEnabled': sosNotifyAppEnabled,
        'sosShareLocationEnabled': sosShareLocationEnabled,
        'sosLocationPrecision': _locationPrecision,
        'sosMaxContacts': maxC,

        // Health
        'healthEnabled': healthEnabled,
        'stepEnabled': stepEnabled,
        'heartRateEnabled': heartRateEnabled,
        'sleepEnabled': sleepEnabled,

        // Reminders
        'reminderEnabled': reminderEnabled,
        'reminderWaterEnabled': reminderWaterEnabled,
        'reminderMedicineEnabled': reminderMedicineEnabled,

        // gating
        'requiresDeviceBound': requiresDeviceBound,
        'minAppVersion': _minAppVersion.text.trim(),

        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 主文件
      await _cfgRef.set(patch, SetOptions(merge: true));

      // 同步入口開關（可選）
      if (syncToAppCenter) {
        await _appCenterRef.set({
          'sosHealthEnabled': enabled,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      setState(() => _dirty = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(syncToAppCenter ? '已儲存並同步入口開關' : '已儲存設定')),
      );
    } catch (e) {
      if (!mounted) return;
      _toast('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ============================================================
  // Draft helpers
  // ============================================================

  void _applyToDraft(Map<String, dynamic> d, {required bool markDirty}) {
    enabled = d['enabled'] == true;

    sosEnabled = d['sosEnabled'] == true;
    sosButtonEnabled = d['sosButtonEnabled'] == true;
    sosAutoCallEnabled = d['sosAutoCallEnabled'] == true;
    sosSmsEnabled = d['sosSmsEnabled'] == true;
    sosNotifyAppEnabled = d['sosNotifyAppEnabled'] == true;
    sosShareLocationEnabled = d['sosShareLocationEnabled'] == true;

    healthEnabled = d['healthEnabled'] == true;
    stepEnabled = d['stepEnabled'] == true;
    heartRateEnabled = d['heartRateEnabled'] == true;
    sleepEnabled = d['sleepEnabled'] == true;

    reminderEnabled = d['reminderEnabled'] == true;
    reminderWaterEnabled = d['reminderWaterEnabled'] == true;
    reminderMedicineEnabled = d['reminderMedicineEnabled'] == true;

    requiresDeviceBound = d['requiresDeviceBound'] == true;

    _locationPrecision = _coercePrecision(d['sosLocationPrecision']);

    _callNumber.text = (d['sosCallNumber'] ?? _defaults['sosCallNumber']).toString();
    _smsTemplate.text = (d['sosSmsTemplate'] ?? _defaults['sosSmsTemplate']).toString();
    _holdSeconds.text = (d['sosTriggerHoldSeconds'] ?? _defaults['sosTriggerHoldSeconds']).toString();
    _cooldownSeconds.text =
        (d['sosCooldownSeconds'] ?? _defaults['sosCooldownSeconds']).toString();
    _maxContacts.text = (d['sosMaxContacts'] ?? _defaults['sosMaxContacts']).toString();
    _minAppVersion.text = (d['minAppVersion'] ?? _defaults['minAppVersion']).toString();

    if (markDirty) _dirty = true;
  }

  void _setDraft(VoidCallback fn) {
    setState(() {
      fn();
      _dirty = true;
    });
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  String _coercePrecision(dynamic v) {
    final s = (v ?? 'high').toString().toLowerCase().trim();
    if (s == 'low' || s == 'balanced' || s == 'high') return s;
    return 'high';
  }

  // ============================================================
  // UI helpers
  // ============================================================

  Widget _card({required Widget child}) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }

  Widget _switchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
      ),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required bool enabled,
  }) {
    return DropdownButtonFormField<T>(
      isExpanded: true,
      value: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required int min,
    required int max,
    required bool enabled,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        helperText: '範圍：$min～$max',
      ),
      onChanged: onChanged,
    );
  }

  // ============================================================
  // Dialog / Utils
  // ============================================================

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

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static int _parseInt(String s, {required int fallback}) {
    return int.tryParse(s.trim()) ?? fallback;
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
// Header / Actions / Errors
// ============================================================

class _HeaderCard extends StatelessWidget {
  final bool exists;
  final String updatedText;
  final bool enabled;
  final VoidCallback? onInit;

  const _HeaderCard({
    required this.exists,
    required this.updatedText,
    required this.enabled,
    this.onInit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pillBg = enabled ? Colors.green.shade100 : Colors.grey.shade200;
    final pillFg = enabled ? Colors.green.shade900 : cs.onSurfaceVariant;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.health_and_safety_outlined, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exists ? '設定文件已存在' : '尚未建立設定文件',
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    enabled ? '啟用中' : '已停用',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: pillFg),
                  ),
                ),
                const SizedBox(height: 8),
                if (!exists && onInit != null)
                  FilledButton.tonalIcon(
                    onPressed: onInit,
                    icon: const Icon(Icons.add),
                    label: const Text('初始化'),
                  ),
              ],
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

class _ActionBar extends StatelessWidget {
  final bool saving;
  final bool dirty;
  final VoidCallback onReset;
  final VoidCallback? onSave;

  const _ActionBar({
    required this.saving,
    required this.dirty,
    required this.onReset,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: saving ? null : onReset,
            icon: const Icon(Icons.undo),
            label: const Text('重設草稿'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: (!dirty || saving) ? null : onSave,
            icon: saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(saving ? '儲存中...' : '儲存設定'),
          ),
        ),
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
