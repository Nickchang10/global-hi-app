// lib/pages/admin_app_config_page.dart
//
// ✅ AdminAppConfigPage（App 控制中心/設定頁｜單檔完整版｜可編譯）
// -----------------------------------------------------------------------------
// - Firestore 直連：app_config/main
// - 支援：
//    1) 基本設定：maintenance / maintenanceMessage
//    2) 版本/升級：minAppVersion / latestAppVersion / forceUpdate
//    3) 客服/聯絡：supportEmail / supportLine / supportPhone
//    4) SOS：sosEnabled / sosCooldownSeconds
//    5) 其他：bannerText / announcement
// - ✅ 修正重點：use_build_context_synchronously
//    -> 所有 async gap 後要用 UI（SnackBar / Navigator / Dialog）
//       都先抓 messenger/nav，await 後再 mounted guard
//
// 依賴：cloud_firestore
// -----------------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAppConfigPage extends StatefulWidget {
  const AdminAppConfigPage({super.key});

  @override
  State<AdminAppConfigPage> createState() => _AdminAppConfigPageState();
}

class _AdminAppConfigPageState extends State<AdminAppConfigPage> {
  final _db = FirebaseFirestore.instance;

  // doc: app_config/main
  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('app_config').doc('main');

  bool _loading = true;
  String? _error;

  // Fields
  bool _maintenance = false;
  String _maintenanceMessage = '';

  String _minAppVersion = '';
  String _latestAppVersion = '';
  bool _forceUpdate = false;

  String _supportEmail = '';
  String _supportLine = '';
  String _supportPhone = '';

  bool _sosEnabled = true;
  int _sosCooldownSeconds = 30;

  String _bannerText = '';
  String _announcement = '';

  // Controllers (避免表單輸入被 setState 重設)
  late final TextEditingController _maintenanceMsgCtrl;
  late final TextEditingController _minVerCtrl;
  late final TextEditingController _latestVerCtrl;
  late final TextEditingController _supportEmailCtrl;
  late final TextEditingController _supportLineCtrl;
  late final TextEditingController _supportPhoneCtrl;
  late final TextEditingController _cooldownCtrl;
  late final TextEditingController _bannerCtrl;
  late final TextEditingController _announcementCtrl;

  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _maintenanceMsgCtrl = TextEditingController();
    _minVerCtrl = TextEditingController();
    _latestVerCtrl = TextEditingController();
    _supportEmailCtrl = TextEditingController();
    _supportLineCtrl = TextEditingController();
    _supportPhoneCtrl = TextEditingController();
    _cooldownCtrl = TextEditingController();
    _bannerCtrl = TextEditingController();
    _announcementCtrl = TextEditingController();

    _load();
  }

  @override
  void dispose() {
    _maintenanceMsgCtrl.dispose();
    _minVerCtrl.dispose();
    _latestVerCtrl.dispose();
    _supportEmailCtrl.dispose();
    _supportLineCtrl.dispose();
    _supportPhoneCtrl.dispose();
    _cooldownCtrl.dispose();
    _bannerCtrl.dispose();
    _announcementCtrl.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Load
  // ===========================================================================
  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _dirty = false;
    });

    try {
      final snap = await _ref.get();
      final data = snap.data() ?? <String, dynamic>{};

      if (!mounted) return;

      _maintenance = (data['maintenance'] ?? false) == true;
      _maintenanceMessage = (data['maintenanceMessage'] ?? '').toString();

      _minAppVersion = (data['minAppVersion'] ?? '').toString();
      _latestAppVersion = (data['latestAppVersion'] ?? '').toString();
      _forceUpdate = (data['forceUpdate'] ?? false) == true;

      _supportEmail = (data['supportEmail'] ?? '').toString();
      _supportLine = (data['supportLine'] ?? '').toString();
      _supportPhone = (data['supportPhone'] ?? '').toString();

      _sosEnabled = (data['sosEnabled'] ?? true) == true;
      _sosCooldownSeconds = _toInt(data['sosCooldownSeconds'], fallback: 30);

      _bannerText = (data['bannerText'] ?? '').toString();
      _announcement = (data['announcement'] ?? '').toString();

      // 同步到 controllers（只在 load 時做）
      _maintenanceMsgCtrl.text = _maintenanceMessage;
      _minVerCtrl.text = _minAppVersion;
      _latestVerCtrl.text = _latestAppVersion;
      _supportEmailCtrl.text = _supportEmail;
      _supportLineCtrl.text = _supportLine;
      _supportPhoneCtrl.text = _supportPhone;
      _cooldownCtrl.text = _sosCooldownSeconds.toString();
      _bannerCtrl.text = _bannerText;
      _announcementCtrl.text = _announcement;

      setState(() {
        _loading = false;
        _error = null;
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  int _toInt(dynamic v, {required int fallback}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  // ===========================================================================
  // Save
  // ===========================================================================
  Future<void> _save() async {
    if (_saving) return;

    // ✅ 先抓 messenger，避免 await 後再用 context
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _saving = true);

    try {
      // 先把 controller 值寫回 fields
      _maintenanceMessage = _maintenanceMsgCtrl.text.trim();
      _minAppVersion = _minVerCtrl.text.trim();
      _latestAppVersion = _latestVerCtrl.text.trim();
      _supportEmail = _supportEmailCtrl.text.trim();
      _supportLine = _supportLineCtrl.text.trim();
      _supportPhone = _supportPhoneCtrl.text.trim();
      _sosCooldownSeconds = _toInt(_cooldownCtrl.text.trim(), fallback: 30);
      _bannerText = _bannerCtrl.text.trim();
      _announcement = _announcementCtrl.text.trim();

      final payload = <String, dynamic>{
        'maintenance': _maintenance,
        'maintenanceMessage': _maintenanceMessage,
        'minAppVersion': _minAppVersion,
        'latestAppVersion': _latestAppVersion,
        'forceUpdate': _forceUpdate,
        'supportEmail': _supportEmail,
        'supportLine': _supportLine,
        'supportPhone': _supportPhone,
        'sosEnabled': _sosEnabled,
        'sosCooldownSeconds': _sosCooldownSeconds,
        'bannerText': _bannerText,
        'announcement': _announcement,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _ref.set(payload, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
      });

      messenger.showSnackBar(const SnackBar(content: Text('已儲存設定')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    }
  }

  // ✅ PopScope callback 不要 async：改成呼叫 async helper
  void _handleBackPressed() {
    _handleBackPressedAsync();
  }

  Future<void> _handleBackPressedAsync() async {
    final ok = await _confirmLeaveIfDirty();
    if (!mounted) return;
    if (ok) Navigator.of(context).pop();
  }

  Future<bool> _confirmLeaveIfDirty() async {
    if (!_dirty) return true;

    // ✅ 先抓 nav，避免 await 後又用 context
    final nav = Navigator.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          '尚未儲存變更',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text('你有尚未儲存的變更，確定要離開嗎？'),
        actions: [
          TextButton(onPressed: () => nav.pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => nav.pop(true), child: const Text('離開')),
        ],
      ),
    );

    return ok == true;
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  // ===========================================================================
  // UI
  // ===========================================================================
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
            'App 控制中心',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: _ErrorView(
          title: '讀取設定失敗',
          message: _error!,
          onRetry: _load,
          hint: '請確認 Firestore 權限與 app_config/main 是否可讀寫。',
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'App 控制中心',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              tooltip: '重新載入',
              onPressed: _saving ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: (_saving || !_dirty) ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? '儲存中...' : '儲存'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _topHintCard(cs),
            const SizedBox(height: 12),

            _sectionTitle('維護模式'),
            _card(
              children: [
                SwitchListTile(
                  value: _maintenance,
                  title: const Text(
                    'Maintenance（維護模式）',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    _maintenance ? '目前：維護中（前台可顯示維護頁）' : '目前：正常營運',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  onChanged: (v) {
                    setState(() => _maintenance = v);
                    _markDirty();
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _maintenanceMsgCtrl,
                  onChanged: (_) => _markDirty(),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: '維護訊息 maintenanceMessage',
                    hintText: '例如：系統維護中，請稍後再試',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _sectionTitle('版本與升級'),
            _card(
              children: [
                TextField(
                  controller: _minVerCtrl,
                  onChanged: (_) => _markDirty(),
                  decoration: InputDecoration(
                    labelText: 'minAppVersion（最低可用版本）',
                    hintText: '例如：1.0.0',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _latestVerCtrl,
                  onChanged: (_) => _markDirty(),
                  decoration: InputDecoration(
                    labelText: 'latestAppVersion（最新版本）',
                    hintText: '例如：1.2.3',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _forceUpdate,
                  title: const Text(
                    'forceUpdate（強制更新）',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    _forceUpdate ? '若版本低於 minAppVersion，將要求強制更新' : '允許用戶稍後再更新',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  onChanged: (v) {
                    setState(() => _forceUpdate = v);
                    _markDirty();
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            _sectionTitle('客服與聯絡'),
            _card(
              children: [
                TextField(
                  controller: _supportEmailCtrl,
                  onChanged: (_) => _markDirty(),
                  decoration: InputDecoration(
                    labelText: 'supportEmail',
                    hintText: '例如：support@osmile.com.tw',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _supportLineCtrl,
                  onChanged: (_) => _markDirty(),
                  decoration: InputDecoration(
                    labelText: 'supportLine（Line ID / 連結）',
                    hintText: '例如：@osmile',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _supportPhoneCtrl,
                  onChanged: (_) => _markDirty(),
                  decoration: InputDecoration(
                    labelText: 'supportPhone',
                    hintText: '例如：02-1234-5678',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _sectionTitle('SOS'),
            _card(
              children: [
                SwitchListTile(
                  value: _sosEnabled,
                  title: const Text(
                    'sosEnabled（SOS 開關）',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    _sosEnabled ? 'SOS 功能啟用中' : 'SOS 功能已停用',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  onChanged: (v) {
                    setState(() => _sosEnabled = v);
                    _markDirty();
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cooldownCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _markDirty(),
                  decoration: InputDecoration(
                    labelText: 'sosCooldownSeconds（冷卻秒數）',
                    hintText: '例如：30',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _sectionTitle('公告與 Banner'),
            _card(
              children: [
                TextField(
                  controller: _bannerCtrl,
                  onChanged: (_) => _markDirty(),
                  decoration: InputDecoration(
                    labelText: 'bannerText（頂部橫幅）',
                    hintText: '例如：春節出貨調整公告',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _announcementCtrl,
                  maxLines: 4,
                  onChanged: (_) => _markDirty(),
                  decoration: InputDecoration(
                    labelText: 'announcement（公告內容）',
                    hintText: '例如：本週系統更新內容...',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Text(
              _dirty ? '＊有未儲存變更' : '＊已同步',
              style: TextStyle(
                color: _dirty ? cs.error : cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _topHintCard(ColorScheme cs) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.tune, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '此頁直接讀寫 Firestore：app_config/main。\n'
                '建議把會被前台讀取的設定集中放這裡。',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

// =============================================================================
// Error View
// =============================================================================
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
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
