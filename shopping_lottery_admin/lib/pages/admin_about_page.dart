// lib/pages/admin_about_page.dart
//
// ✅ AdminAboutPage（單檔完整版｜可編譯｜已修正：control_flow_in_finally + use_build_context_synchronously）
// -----------------------------------------------------------------------------
// - 顯示：管理後台版本資訊、環境資訊、常用連結（以複製方式）
// - 支援：複製診斷資訊、檢查更新（示範 async）、回報問題（複製模板）
// - ✅ 重點：
//   1) finally 裡不使用 return（修正 control_flow_in_finally）
//   2) async 後的 UI 操作：先抓 messenger/nav + mounted 檢查
//
// 依賴：flutter/material.dart, flutter/services.dart
// -----------------------------------------------------------------------------

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminAboutPage extends StatefulWidget {
  const AdminAboutPage({super.key});

  @override
  State<AdminAboutPage> createState() => _AdminAboutPageState();
}

class _AdminAboutPageState extends State<AdminAboutPage> {
  // 不依賴 package_info_plus，避免缺套件造成編譯失敗
  static const String kAppName = 'Osmile Admin';
  static const String kAppVersion = '1.0.0';
  static const String kBuildNumber = '1';
  static const String kChannel = 'stable';

  bool _checking = false;
  DateTime? _lastCheckedAt;
  String? _checkResult;

  String _fmtDt(DateTime? dt) {
    if (dt == null) return '—';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y/$m/$d $hh:$mm:$ss';
  }

  String _platformLine() {
    if (kIsWeb) return 'Web';
    try {
      return '${Platform.operatingSystem} (${Platform.operatingSystemVersion})';
    } catch (_) {
      return 'Unknown';
    }
  }

  String _runtimeLine() {
    return kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug');
  }

  Future<void> _copyToClipboard(String text, {String? toast}) async {
    if (text.trim().isEmpty) return;

    // ✅ 先抓 messenger，避免 await 後再用 context
    final messenger = ScaffoldMessenger.of(context);

    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(toast ?? '已複製到剪貼簿')));
  }

  String _buildDiagnostics() {
    final lines = <String>[
      '[$kAppName]',
      'version=$kAppVersion+$kBuildNumber ($kChannel)',
      'platform=${_platformLine()}',
      'mode=${_runtimeLine()}',
      'lastCheck=${_fmtDt(_lastCheckedAt)}',
      if (_checkResult != null) 'checkResult=$_checkResult',
    ];
    return lines.join('\n');
  }

  Future<void> _simulateCheckUpdate() async {
    if (_checking) return;

    // ✅ 先取 messenger（避免 async gap 後用 context）
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _checking = true;
      _checkResult = null;
    });

    try {
      // 模擬 API 檢查更新（你之後換成真的 request 也不會再出現 context across async）
      await Future<void>.delayed(const Duration(milliseconds: 900));

      final now = DateTime.now();
      final result = '目前已是最新版本（示範）';

      if (!mounted) return;
      setState(() {
        _lastCheckedAt = now;
        _checkResult = result;
      });

      messenger.showSnackBar(const SnackBar(content: Text('檢查完成')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkResult = '檢查失敗：$e';
      });
      messenger.showSnackBar(SnackBar(content: Text('檢查失敗：$e')));
    } finally {
      // ✅ 修正：finally 裡不能 return
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '關於後台',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '複製診斷資訊',
            icon: const Icon(Icons.copy),
            onPressed: () =>
                _copyToClipboard(_buildDiagnostics(), toast: '已複製診斷資訊'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(cs),
          const SizedBox(height: 12),

          _sectionTitle('版本資訊'),
          _infoCard(
            children: [
              _kv('App', kAppName),
              _kv('Version', '$kAppVersion+$kBuildNumber'),
              _kv('Channel', kChannel),
              _kv('Mode', _runtimeLine()),
              _kv('Platform', _platformLine()),
            ],
          ),

          const SizedBox(height: 12),

          _sectionTitle('更新'),
          _infoCard(
            children: [
              _kv('上次檢查', _fmtDt(_lastCheckedAt)),
              if (_checkResult != null) ...[
                const SizedBox(height: 6),
                Text(
                  _checkResult!,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _checking ? null : _simulateCheckUpdate,
                    icon: _checking
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update_alt),
                    label: Text(_checking ? '檢查中...' : '檢查更新'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _copyToClipboard(_buildDiagnostics(), toast: '已複製診斷資訊'),
                    icon: const Icon(Icons.bug_report_outlined),
                    label: const Text('複製診斷'),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          _sectionTitle('常用連結（複製）'),
          _infoCard(
            children: [
              _linkRow(
                label: 'Firebase Console',
                url: 'https://console.firebase.google.com/',
                onCopy: () => _copyToClipboard(
                  'https://console.firebase.google.com/',
                  toast: '已複製 Firebase Console 連結',
                ),
              ),
              const SizedBox(height: 8),
              _linkRow(
                label: 'Google Maps',
                url: 'https://www.google.com/maps',
                onCopy: () => _copyToClipboard(
                  'https://www.google.com/maps',
                  toast: '已複製 Google Maps 連結',
                ),
              ),
              const SizedBox(height: 8),
              _linkRow(
                label: 'Osmile 官網（示範）',
                url: 'https://osmile.com.tw',
                onCopy: () =>
                    _copyToClipboard('https://osmile.com.tw', toast: '已複製官網連結'),
              ),
              const SizedBox(height: 10),
              Text(
                '提示：此頁不依賴 url_launcher，會以「複製連結」方式避免缺套件造成編譯失敗。',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _sectionTitle('回報問題（複製模板）'),
          _infoCard(
            children: [
              Text(
                '遇到 bug 時，建議把「診斷資訊」與「重現步驟」一起貼給工程端。',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  final template = [
                    '[Bug 回報]',
                    '問題描述：',
                    '重現步驟：',
                    '預期結果：',
                    '實際結果：',
                    '',
                    '--- 診斷資訊 ---',
                    _buildDiagnostics(),
                  ].join('\n');
                  _copyToClipboard(template, toast: '已複製回報模板');
                },
                icon: const Icon(Icons.copy_all),
                label: const Text('複製回報模板'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Center(
            child: Text(
              '© ${DateTime.now().year} Osmile',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _headerCard(ColorScheme cs) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: cs.primaryContainer,
              ),
              child: Icon(
                Icons.admin_panel_settings,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    kAppName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'version $kAppVersion+$kBuildNumber • $kChannel',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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

  Widget _infoCard({required List<Widget> children}) {
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

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  Widget _linkRow({
    required String label,
    required String url,
    required VoidCallback onCopy,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: onCopy,
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('複製'),
        ),
      ],
    );
  }
}
