import 'package:flutter/material.dart';

/// ✅ SOSHelpPage（SOS 求助｜完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正重點：
/// - ✅ 移除 GoogleFonts.notoSansTc 依賴（避免 undefined_method）
/// - ✅ 使用原生 TextStyle（不吃 google_fonts 版本差異）
/// - ✅ 修正 withOpacity deprecated → 改用 withValues(alpha: ...)
///
/// 功能（本頁 UI 先完整可用）：
/// - 快速求助說明
/// - 緊急聯絡操作（示範：按鈕 + SnackBar）
/// - 求救訊息模板（可複製）
/// - 守護者/緊急聯絡人（示範清單）
/// ------------------------------------------------------------
class SOSHelpPage extends StatefulWidget {
  const SOSHelpPage({super.key});

  @override
  State<SOSHelpPage> createState() => _SOSHelpPageState();
}

class _SOSHelpPageState extends State<SOSHelpPage> {
  bool _autoShareLocation = true;
  bool _autoNotifyGuardians = true;

  // 你可改成從 Firestore / Profile 帶入
  final List<Map<String, String>> _guardians = const [
    {'name': '媽媽', 'phone': '09xx-xxx-xxx'},
    {'name': '爸爸', 'phone': '09xx-xxx-xxx'},
  ];

  final String _sosTemplate =
      '我需要幫助！\n'
      '目前狀況：緊急/危險/走失/需要協助\n'
      '定位：請查看 App 位置或與我聯絡。\n'
      '（此訊息由 Osmile SOS 自動產生）';

  TextStyle get _h1 =>
      const TextStyle(fontSize: 18, fontWeight: FontWeight.w900);
  TextStyle get _h2 =>
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w900);
  TextStyle get _muted => TextStyle(color: Colors.grey.shade700);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS 求助'),
        actions: [
          IconButton(
            tooltip: '說明',
            onPressed: _showGuide,
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCard(),
          const SizedBox(height: 12),
          _quickActionsCard(),
          const SizedBox(height: 12),
          _settingsCard(),
          const SizedBox(height: 12),
          _messageTemplateCard(),
          const SizedBox(height: 12),
          _guardiansCard(),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Osmile SOS',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('遇到危險或需要協助？', style: _h1),
            const SizedBox(height: 8),
            Text('你可以在這裡快速觸發求助流程：通知守護者、分享定位、撥打緊急電話（示範）。', style: _muted),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _triggerSOS,
                    icon: const Icon(Icons.sos),
                    label: const Text('立即發出 SOS'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('緊急操作', style: _h1),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _actionChip(
                  icon: Icons.local_police_outlined,
                  label: '報警 110',
                  onTap: () => _fakeCall('110'),
                ),
                _actionChip(
                  icon: Icons.local_hospital_outlined,
                  label: '救護 119',
                  onTap: () => _fakeCall('119'),
                ),
                _actionChip(
                  icon: Icons.location_on_outlined,
                  label: '分享定位',
                  onTap: _shareLocation,
                ),
                _actionChip(
                  icon: Icons.message_outlined,
                  label: '傳送求救訊息',
                  onTap: _sendSOSMessage,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('＊若你已整合撥號/分享套件，可在這裡改成真實呼叫/分享。', style: _muted),
          ],
        ),
      ),
    );
  }

  Widget _settingsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SOS 設定', style: _h1),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('自動分享定位', style: _h2),
              subtitle: Text('觸發 SOS 後附帶最後定位資訊', style: _muted),
              value: _autoShareLocation,
              onChanged: (v) => setState(() => _autoShareLocation = v),
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('自動通知守護者', style: _h2),
              subtitle: Text('觸發 SOS 後通知你設定的守護者', style: _muted),
              value: _autoNotifyGuardians,
              onChanged: (v) => setState(() => _autoNotifyGuardians = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageTemplateCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('求救訊息模板', style: _h1),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(_sosTemplate),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _copyToClipboard(_sosTemplate),
                    icon: const Icon(Icons.copy),
                    label: const Text('複製內容'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _guardiansCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('守護者 / 緊急聯絡人', style: _h1),
            const SizedBox(height: 8),
            if (_guardians.isEmpty)
              Text('尚未設定守護者', style: _muted)
            else
              ..._guardians.map((g) {
                final name = (g['name'] ?? '守護者').toString();
                final phone = (g['phone'] ?? '').toString();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.12),
                    child: Text(name.isNotEmpty ? name.substring(0, 1) : 'G'),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(phone.isEmpty ? '未設定電話' : phone),
                  trailing: TextButton(
                    onPressed: phone.isEmpty ? null : () => _fakeCall(phone),
                    child: const Text('聯絡'),
                  ),
                );
              }),
            const Divider(height: 1),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openGuardianSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('管理守護者'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  // ---------------- actions ----------------

  void _triggerSOS() {
    final msgs = <String>[
      '已觸發 SOS',
      if (_autoNotifyGuardians) '已通知守護者（示範）',
      if (_autoShareLocation) '已附帶定位（示範）',
    ];

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msgs.join(' • '))));
  }

  void _fakeCall(String number) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('示範：撥打 $number（若要真撥號請整合 url_launcher）')),
    );
  }

  void _shareLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('示範：已分享定位（若要真分享請整合 share_plus / maps link）'),
      ),
    );
  }

  void _sendSOSMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('示範：已傳送求救訊息給守護者（可串 Firestore/推播/Line）')),
    );
  }

  void _copyToClipboard(String text) {
    // 不用 Clipboard 也能編譯；如你已修好 Clipboard import，可改成真複製
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('示範：已複製（若要真複製請引入 flutter/services.dart 的 Clipboard）'),
      ),
    );
  }

  void _openGuardianSettings() {
    // 你可改成 pushNamed('/guardians') 或任何設定頁
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('示範：前往守護者設定頁（請接你的路由）')));
  }

  void _showGuide() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('SOS 使用說明'),
        content: const Text(
          '1) 點「立即發出 SOS」\n'
          '2) 會通知守護者並分享定位（依設定）\n'
          '3) 必要時使用 110 / 119\n\n'
          '若你要真實撥號/分享：\n'
          '- 撥號：整合 url_launcher\n'
          '- 分享：整合 share_plus\n'
          '- 定位：整合 geolocator + maps link\n',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }
}
