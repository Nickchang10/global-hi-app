// lib/pages/admin/app_center/admin_feature_flags_page.dart
//
// ✅ AdminFeatureFlagsPage（專業完整版｜可編譯）
// ------------------------------------------------------------
// 目的：後台「App 功能開關」管理（讀寫 Firestore app_config/feature_flags）
//
// Firestore Doc：app_config/feature_flags
// 建議欄位：
// {
//   checkoutEnabled: true,      // ✅ 下單/結帳流程
//   lotteryEnabled: true,       // ✅ 活動抽獎
//   couponsEnabled: true,       // 優惠券（可選）
//   campaignsEnabled: true,     // 活動系統（可選）
//   sosEnabled: true,           // SOS
//   healthEnabled: true,        // 健康模組
//   voiceAssistantEnabled: true,// 語音助理（可選）
//   updatedAt: Timestamp,
//   updatedBy: uid/email (可選)
// }
//
// 功能：
// - 讀取/顯示/修改 Switch
// - 一鍵套用「最小可用（只保留：下單 + 抽獎）」
// - 一鍵全開 / 全關（可選）
// - 儲存至 Firestore（merge）
// - 預覽「目前 App 啟用功能」摘要
//
// 依賴：cloud_firestore, flutter/material
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminFeatureFlagsPage extends StatefulWidget {
  const AdminFeatureFlagsPage({super.key});

  @override
  State<AdminFeatureFlagsPage> createState() => _AdminFeatureFlagsPageState();
}

class _AdminFeatureFlagsPageState extends State<AdminFeatureFlagsPage> {
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;
  bool _dirty = false;

  // ✅ Flags（保持 bool 非 null）
  bool checkoutEnabled = true;
  bool lotteryEnabled = true;

  bool couponsEnabled = false;
  bool campaignsEnabled = false;

  bool sosEnabled = false;
  bool healthEnabled = false;

  bool voiceAssistantEnabled = false;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('app_config').doc('feature_flags');

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ============================================================
  // Load / Save
  // ============================================================

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _dirty = false;
    });

    try {
      final snap = await _ref.get();
      final d = snap.data();

      // 若尚未建立，採用預設（以「下單+抽獎」為核心）
      final m = d ?? <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        checkoutEnabled = _asBool(m['checkoutEnabled'], fallback: true);
        lotteryEnabled = _asBool(m['lotteryEnabled'], fallback: true);

        couponsEnabled = _asBool(m['couponsEnabled'], fallback: false);
        campaignsEnabled = _asBool(m['campaignsEnabled'], fallback: false);

        sosEnabled = _asBool(m['sosEnabled'], fallback: false);
        healthEnabled = _asBool(m['healthEnabled'], fallback: false);

        voiceAssistantEnabled = _asBool(m['voiceAssistantEnabled'], fallback: false);

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    try {
      final payload = <String, dynamic>{
        'checkoutEnabled': checkoutEnabled,
        'lotteryEnabled': lotteryEnabled,
        'couponsEnabled': couponsEnabled,
        'campaignsEnabled': campaignsEnabled,
        'sosEnabled': sosEnabled,
        'healthEnabled': healthEnabled,
        'voiceAssistantEnabled': voiceAssistantEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
        'type': 'feature_flags',
      };

      await _ref.set(payload, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _dirty = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已儲存功能開關設定')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    }
  }

  // ============================================================
  // Presets
  // ============================================================

  Future<void> _applyMinimalPreset() async {
    final ok = await _confirm(
      title: '套用最小可用（只保留：下單 + 抽獎）',
      message: '將關閉其他模組（優惠券/活動系統/SOS/健康/語音助理）。是否繼續？',
      confirmText: '套用',
      isDanger: true,
    );
    if (ok != true) return;

    setState(() {
      checkoutEnabled = true;
      lotteryEnabled = true;

      couponsEnabled = false;
      campaignsEnabled = false;

      sosEnabled = false;
      healthEnabled = false;

      voiceAssistantEnabled = false;
      _dirty = true;
    });
  }

  Future<void> _setAll(bool v) async {
    final ok = await _confirm(
      title: v ? '一鍵全開' : '一鍵全關',
      message: v ? '將啟用所有功能。是否繼續？' : '將關閉所有功能（含下單/抽獎）。是否繼續？',
      confirmText: v ? '全開' : '全關',
      isDanger: !v,
    );
    if (ok != true) return;

    setState(() {
      checkoutEnabled = v;
      lotteryEnabled = v;

      couponsEnabled = v;
      campaignsEnabled = v;

      sosEnabled = v;
      healthEnabled = v;

      voiceAssistantEnabled = v;
      _dirty = true;
    });
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        if (!_dirty) return true;
        final ok = await _confirm(
          title: '尚未儲存變更',
          message: '你有未儲存的修改，確定要離開嗎？',
          confirmText: '離開',
          isDanger: true,
        );
        return ok == true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('App 功能開關', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: '重新載入',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _load,
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: _loading ? null : () => _setAll(true),
              icon: const Icon(Icons.done_all),
              label: const Text('全開'),
            ),
            TextButton.icon(
              onPressed: _loading ? null : () => _setAll(false),
              icon: const Icon(Icons.block),
              label: const Text('全關'),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: (_loading || !_dirty) ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('儲存'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null)
                ? _ErrorView(
                    title: '載入失敗',
                    message: _error!,
                    onRetry: _load,
                    hint:
                        '請確認 Firestore rules：/app_config/{id} 允許 admin write。\n你目前 rules 已 allow read: true、write: isAdmin（符合）。',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      _summaryCard(cs),
                      const SizedBox(height: 10),

                      _sectionTitle('核心（你目前要先完成）'),
                      _flagTile(
                        title: '下單 / 結帳（Checkout）',
                        subtitle: '控制：商品加入購物車、結帳、建立訂單、付款流程是否顯示。',
                        value: checkoutEnabled,
                        onChanged: (v) => _setFlag(() => checkoutEnabled = v),
                        leading: Icons.shopping_cart_checkout_outlined,
                      ),
                      _flagTile(
                        title: '活動抽獎（Lottery）',
                        subtitle: '控制：抽獎入口、抽獎頁與抽獎流程是否顯示。',
                        value: lotteryEnabled,
                        onChanged: (v) => _setFlag(() => lotteryEnabled = v),
                        leading: Icons.campaign_outlined,
                      ),
                      const SizedBox(height: 6),
                      FilledButton.tonalIcon(
                        onPressed: _applyMinimalPreset,
                        icon: const Icon(Icons.filter_alt_outlined),
                        label: const Text('套用最小可用（只保留：下單 + 抽獎）'),
                      ),

                      const SizedBox(height: 18),
                      _sectionTitle('商城延伸（可選）'),
                      _flagTile(
                        title: '優惠券（Coupons）',
                        subtitle: '控制：結帳頁折扣/套用優惠券、優惠券中心入口。',
                        value: couponsEnabled,
                        onChanged: (v) => _setFlag(() => couponsEnabled = v),
                        leading: Icons.confirmation_number_outlined,
                      ),
                      _flagTile(
                        title: '活動系統（Campaigns）',
                        subtitle: '控制：活動列表/活動詳情/報名或任務入口。',
                        value: campaignsEnabled,
                        onChanged: (v) => _setFlag(() => campaignsEnabled = v),
                        leading: Icons.local_activity_outlined,
                      ),

                      const SizedBox(height: 18),
                      _sectionTitle('安全 / 健康（可選）'),
                      _flagTile(
                        title: 'SOS 模組',
                        subtitle: '控制：SOS 入口、SOS 設定、求救流程是否顯示。',
                        value: sosEnabled,
                        onChanged: (v) => _setFlag(() => sosEnabled = v),
                        leading: Icons.sos_outlined,
                      ),
                      _flagTile(
                        title: '健康模組',
                        subtitle: '控制：健康入口、健康數據頁與同步功能是否顯示。',
                        value: healthEnabled,
                        onChanged: (v) => _setFlag(() => healthEnabled = v),
                        leading: Icons.monitor_heart_outlined,
                      ),

                      const SizedBox(height: 18),
                      _sectionTitle('其他（可選）'),
                      _flagTile(
                        title: '語音助理（Voice Assistant）',
                        subtitle: '控制：語音助理入口與相關 UI 是否顯示。',
                        value: voiceAssistantEnabled,
                        onChanged: (v) => _setFlag(() => voiceAssistantEnabled = v),
                        leading: Icons.record_voice_over_outlined,
                      ),

                      const SizedBox(height: 18),
                      _noteCard(cs),
                    ],
                  ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
    );
  }

  Widget _summaryCard(ColorScheme cs) {
    final enabled = <String>[];
    if (checkoutEnabled) enabled.add('下單');
    if (lotteryEnabled) enabled.add('抽獎');
    if (couponsEnabled) enabled.add('優惠券');
    if (campaignsEnabled) enabled.add('活動');
    if (sosEnabled) enabled.add('SOS');
    if (healthEnabled) enabled.add('健康');
    if (voiceAssistantEnabled) enabled.add('語音');

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('目前啟用功能摘要', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: enabled.isEmpty
                  ? [
                      Chip(
                        label: const Text('（全部關閉）'),
                        backgroundColor: cs.surfaceContainerHighest,
                      )
                    ]
                  : [
                      for (final e in enabled)
                        Chip(
                          label: Text(e, style: const TextStyle(fontWeight: FontWeight.w800)),
                          backgroundColor: cs.primaryContainer.withOpacity(0.6),
                        ),
                    ],
            ),
            const SizedBox(height: 10),
            Text(
              _dirty ? '狀態：尚未儲存變更' : '狀態：已同步（無未儲存變更）',
              style: TextStyle(
                color: _dirty ? cs.error : cs.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noteCard(ColorScheme cs) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          '實作建議：App 端啟動時讀取 app_config/feature_flags，將結果放入 Provider/State（例如 AppConfigController）。\n'
          '各頁面入口與底部導覽列渲染時，依對應 flag 決定是否顯示。\n'
          '若你要「下單 + 抽獎」先上線，建議先固定 checkoutEnabled=true、lotteryEnabled=true，其他先關閉。',
          style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
        ),
      ),
    );
  }

  Widget _flagTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData leading,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: SwitchListTile(
        secondary: Icon(leading),
        value: value,
        onChanged: (v) => onChanged(v),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
      ),
    );
  }

  void _setFlag(VoidCallback apply) {
    setState(() {
      apply();
      _dirty = true;
    });
  }

  bool _asBool(dynamic v, {required bool fallback}) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = (v ?? '').toString().trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return fallback;
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool isDanger = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDanger ? cs.error : null,
              foregroundColor: isDanger ? cs.onError : null,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// Error View
// ======================================================
class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String? hint;

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
        constraints: const BoxConstraints(maxWidth: 680),
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
                    Text(hint!, style: TextStyle(color: cs.onSurfaceVariant, height: 1.3)),
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
