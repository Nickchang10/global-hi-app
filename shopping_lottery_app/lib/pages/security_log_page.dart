// lib/pages/security_log_page.dart
//
// ✅ SecurityLogPage（安全紀錄 / 登入紀錄｜最終完整版）
// ------------------------------------------------------------
// - 不依賴任何外部套件
// - 篩選：全部 / 高風險 / 一般
// - 搜尋：關鍵字（裝置/地點/IP/內容）
// - ✅ 修正：withOpacity deprecated → withValues(alpha: ...)
// - ✅ 修正：prefer_const_constructors（_empty() 整棵樹改為 const）
// ------------------------------------------------------------

import 'package:flutter/material.dart';

class SecurityLogPage extends StatefulWidget {
  const SecurityLogPage({super.key});

  @override
  State<SecurityLogPage> createState() => _SecurityLogPageState();
}

class _SecurityLogPageState extends State<SecurityLogPage> {
  final TextEditingController _search = TextEditingController();
  _LogFilter _filter = _LogFilter.all;

  // ✅ 模擬安全紀錄（你之後可改成 Firestore / API）
  late List<_SecurityLog> _logs = [
    _SecurityLog(
      level: _LogLevel.high,
      title: '偵測到異常登入嘗試',
      detail: '密碼輸入錯誤多次，建議更換密碼並開啟生物辨識/雙重驗證。',
      device: 'Samsung S24 Ultra',
      ip: '203.0.113.10',
      location: '台中市',
      time: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    _SecurityLog(
      level: _LogLevel.normal,
      title: '登入成功',
      detail: '使用 Email/Password 登入成功。',
      device: 'iPhone 15 Pro',
      ip: '198.51.100.22',
      location: '台北市',
      time: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    _SecurityLog(
      level: _LogLevel.normal,
      title: '變更密碼',
      detail: '你的密碼已更新。',
      device: 'MacBook Air M2',
      ip: '192.0.2.7',
      location: '新北市',
      time: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
    ),
    _SecurityLog(
      level: _LogLevel.normal,
      title: '綁定 Google 帳號',
      detail: '已綁定 Google 帳號（模擬）。',
      device: 'iPhone 15 Pro',
      ip: '198.51.100.22',
      location: '台北市',
      time: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
    ),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _fmtTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);

    if (diff.inMinutes < 1) return '剛剛';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
    if (diff.inHours < 24) return '${diff.inHours} 小時前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';

    // 簡易日期格式（不依賴 intl）
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${t.year}/${two(t.month)}/${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  List<_SecurityLog> get _filteredLogs {
    final q = _search.text.trim().toLowerCase();

    return _logs.where((e) {
      final matchFilter = switch (_filter) {
        _LogFilter.all => true,
        _LogFilter.high => e.level == _LogLevel.high,
        _LogFilter.normal => e.level == _LogLevel.normal,
      };

      if (!matchFilter) return false;
      if (q.isEmpty) return true;

      final blob = [
        e.title,
        e.detail,
        e.device,
        e.location,
        e.ip,
      ].join(' ').toLowerCase();

      return blob.contains(q);
    }).toList()..sort((a, b) => b.time.compareTo(a.time));
  }

  void _clearLogs() {
    setState(() => _logs = []);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清除安全紀錄（模擬）')));
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filteredLogs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🛡️ 安全紀錄'),
        actions: [
          IconButton(
            tooltip: '清除紀錄',
            onPressed: _logs.isEmpty ? null : _clearLogs,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          _topBar(),
          const Divider(height: 1),
          Expanded(
            child: logs.isEmpty
                ? _empty()
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: logs.length,
                    itemBuilder: (context, i) => _logTile(logs[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜尋（裝置 / 地點 / IP / 事件）',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _search.text.trim().isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _search.clear()),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ChoiceChip(
                label: const Text('全部'),
                selected: _filter == _LogFilter.all,
                onSelected: (_) => setState(() => _filter = _LogFilter.all),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('高風險'),
                selected: _filter == _LogFilter.high,
                onSelected: (_) => setState(() => _filter = _LogFilter.high),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('一般'),
                selected: _filter == _LogFilter.normal,
                onSelected: (_) => setState(() => _filter = _LogFilter.normal),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _logTile(_SecurityLog e) {
    final color = e.level == _LogLevel.high ? Colors.red : Colors.green;
    final icon = e.level == _LogLevel.high
        ? Icons.warning_amber_rounded
        : Icons.verified_user;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          // ✅ withOpacity deprecated → withValues(alpha: ...)
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          e.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          [
            '${e.device} ・ ${e.location}',
            'IP ${e.ip}',
            _fmtTime(e.time),
            e.detail,
          ].join('\n'),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => _showDetail(e),
      ),
    );
  }

  // ✅ prefer_const_constructors：整棵樹都 const
  Widget _empty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Card(
          elevation: 1,
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 56, color: Colors.grey),
                SizedBox(height: 10),
                Text('目前沒有安全紀錄', style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text(
                  '提示：之後可接 Firestore / API 將登入事件寫入並在此顯示',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(_SecurityLog e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: 10),
                _kv('等級', e.level == _LogLevel.high ? '高風險' : '一般'),
                _kv('裝置', e.device),
                _kv('地點', e.location),
                _kv('IP', e.ip),
                _kv('時間', _fmtTime(e.time)),
                const SizedBox(height: 10),
                const Text(
                  '詳細內容',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(e.detail, style: const TextStyle(color: Colors.blueGrey)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('關閉'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 72,
            child: Text(''),
          ), // placeholder to keep const? no
          SizedBox(
            width: 72,
            child: Text(k, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

enum _LogLevel { high, normal }

enum _LogFilter { all, high, normal }

class _SecurityLog {
  final _LogLevel level;
  final String title;
  final String detail;
  final String device;
  final String ip;
  final String location;
  final DateTime time;

  const _SecurityLog({
    required this.level,
    required this.title,
    required this.detail,
    required this.device,
    required this.ip,
    required this.location,
    required this.time,
  });
}
