// lib/pages/admin/marketing/admin_campaign_logs_page.dart
//
// ✅ AdminCampaignLogsPage（行銷活動日誌｜最終可編譯完整版本）
// ------------------------------------------------------------
// - Firestore：campaign_logs（即時監聽）
// - 篩選：類型 / 狀態 / 日期區間（本地過濾，避免複合索引壓力）
// - 搜尋：關鍵字（title / message / campaignId / userId 等）
// - 匯出：目前篩選結果匯出 CSV（file_saver）
// - ✅ 修正編譯錯誤：_toDate 變數與 _toDate() 函式衝突
//   -> 變數改名 _toDateFilter
//   -> 日期轉換函式改名 _asDateTime()
//
// ✅ FIX: withOpacity deprecated → withValues(alpha: double 0.0~1.0)
// ------------------------------------------------------------

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminCampaignLogsPage extends StatefulWidget {
  const AdminCampaignLogsPage({super.key});

  @override
  State<AdminCampaignLogsPage> createState() => _AdminCampaignLogsPageState();
}

class _AdminCampaignLogsPageState extends State<AdminCampaignLogsPage> {
  final _keywordCtrl = TextEditingController();

  // Filters
  String _type = 'all';
  String _status = 'all';
  DateTime? _fromDate;
  DateTime? _toDateFilter; // ✅ 修正：避免與函式命名衝突

  // UI
  bool _exporting = false;

  // Query settings
  static const int _limit = 500;

  @override
  void dispose() {
    _keywordCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // Helpers
  // ============================================================

  DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _s(dynamic v, {String fallback = ''}) =>
      (v == null) ? fallback : v.toString();

  num _n(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    final p = num.tryParse(v.toString());
    return p ?? fallback;
  }

  bool _isTrue(dynamic v) => v == true;

  /// ✅ FIX:
  /// - Color.withValues(alpha: ...) 的 alpha 型別是 double?（0.0~1.0）
  /// - 你原本用 int(0~255) 會造成編譯錯誤
  Color _withOpacity(Color c, double opacity01) {
    final a = opacity01.clamp(0.0, 1.0).toDouble();
    return c.withValues(alpha: a);
  }

  // ============================================================
  // Pick dates
  // ============================================================

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom
        ? (_fromDate ?? now)
        : (_toDateFilter ?? _fromDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked == null) return;

    setState(() {
      final d = DateTime(picked.year, picked.month, picked.day);
      if (isFrom) {
        _fromDate = d;
        if (_toDateFilter != null && _toDateFilter!.isBefore(_fromDate!)) {
          _toDateFilter = null;
        }
      } else {
        _toDateFilter = d;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _type = 'all';
      _status = 'all';
      _fromDate = null;
      _toDateFilter = null;
      _keywordCtrl.clear();
    });
  }

  // ============================================================
  // Filtering (local, index-free)
  // ============================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyLocalFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final keyword = _keywordCtrl.text.trim().toLowerCase();

    DateTime? from = _fromDate;
    DateTime? to;
    if (_toDateFilter != null) {
      // inclusive end-of-day
      to = DateTime(
        _toDateFilter!.year,
        _toDateFilter!.month,
        _toDateFilter!.day,
        23,
        59,
        59,
        999,
      );
    }

    bool matchKeyword(Map<String, dynamic> d) {
      if (keyword.isEmpty) return true;

      final hay = <String>[
        _s(d['title']),
        _s(d['message']),
        _s(d['campaignTitle']),
        _s(d['campaignId']),
        _s(d['segmentId']),
        _s(d['couponId']),
        _s(d['lotteryId']),
        _s(d['userId']),
        _s(d['channel']),
        _s(d['status']),
        _s(d['type']),
      ].join(' | ').toLowerCase();

      return hay.contains(keyword);
    }

    bool matchType(Map<String, dynamic> d) {
      if (_type == 'all') return true;
      return _s(d['type']).trim() == _type;
    }

    bool matchStatus(Map<String, dynamic> d) {
      if (_status == 'all') return true;
      return _s(d['status']).trim() == _status;
    }

    bool matchDate(Map<String, dynamic> d) {
      final dt =
          _asDateTime(d['createdAt']) ??
          _asDateTime(d['updatedAt']) ??
          _asDateTime(d['time']);
      if (dt == null) return true;

      if (from != null && dt.isBefore(from)) return false;
      if (to != null && dt.isAfter(to)) return false;
      return true;
    }

    return docs
        .where((doc) {
          final d = doc.data();
          return matchType(d) &&
              matchStatus(d) &&
              matchDate(d) &&
              matchKeyword(d);
        })
        .toList(growable: false);
  }

  // ============================================================
  // KPI
  // ============================================================

  Map<String, num> _calcKpi(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    num trigger = 0, send = 0, click = 0, conv = 0;

    for (final doc in docs) {
      final d = doc.data();
      trigger += _n(d['triggerCount']);
      send += _n(d['sendCount']);
      click += _n(d['clickCount']);
      conv += _n(d['conversionCount']);
    }
    return {'trigger': trigger, 'send': send, 'click': click, 'conv': conv};
  }

  // ============================================================
  // Export CSV
  // ============================================================

  String _csvEscape(String s) {
    final needsQuote = s.contains(',') || s.contains('\n') || s.contains('"');
    final escaped = s.replaceAll('"', '""');
    return needsQuote ? '"$escaped"' : escaped;
  }

  Future<void> _exportCsv(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered,
  ) async {
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('目前沒有可匯出的日誌資料')));
      return;
    }

    setState(() => _exporting = true);
    try {
      final df = DateFormat('yyyy-MM-dd HH:mm:ss');

      final b = StringBuffer();
      b.writeln(
        [
          'time',
          'type',
          'status',
          'campaignTitle',
          'campaignId',
          'segmentId',
          'couponId',
          'lotteryId',
          'userId',
          'channel',
          'title',
          'message',
          'triggerCount',
          'sendCount',
          'clickCount',
          'conversionCount',
        ].join(','),
      );

      for (final doc in filtered) {
        final d = doc.data();
        final dt =
            _asDateTime(d['createdAt']) ??
            _asDateTime(d['updatedAt']) ??
            _asDateTime(d['time']);
        final timeText = dt == null ? '' : df.format(dt);

        final row = <String>[
          timeText,
          _s(d['type']),
          _s(d['status']),
          _s(d['campaignTitle']),
          _s(d['campaignId']),
          _s(d['segmentId']),
          _s(d['couponId']),
          _s(d['lotteryId']),
          _s(d['userId']),
          _s(d['channel']),
          _s(d['title']),
          _s(d['message']),
          _n(d['triggerCount']).toString(),
          _n(d['sendCount']).toString(),
          _n(d['clickCount']).toString(),
          _n(d['conversionCount']).toString(),
        ].map(_csvEscape).join(',');

        b.writeln(row);
      }

      // Excel 友善：UTF-8 + BOM
      final bom = <int>[0xEF, 0xBB, 0xBF];
      final contentBytes = utf8.encode(b.toString());
      final bytes = Uint8List.fromList([...bom, ...contentBytes]);

      final name =
          'campaign_logs_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';

      await FileSaver.instance.saveFile(
        name: name,
        bytes: bytes,
        ext: 'csv',
        mimeType: MimeType.csv,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已匯出 ${filtered.length} 筆日誌至 CSV')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('匯出失敗：$e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ============================================================
  // UI helpers
  // ============================================================

  String _typeLabel(String t) {
    switch (t) {
      case 'coupon':
        return '優惠券';
      case 'lottery':
        return '抽獎';
      case 'segment':
        return '分群';
      case 'auto':
        return '自動派發';
      case 'push':
        return '推播';
      case 'line':
        return 'LINE';
      case 'email':
        return 'Email';
      default:
        return t.isEmpty ? '未知' : t;
    }
  }

  Color _statusColor(String s) {
    final v = s.toLowerCase().trim();
    if (v == 'success' || v == 'ok') return Colors.green;
    if (v == 'fail' || v == 'error') return Colors.red;
    if (v == 'pending' || v == 'queued') return Colors.orange;
    return Colors.blueGrey;
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              k,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }

  void _showDetailSheet(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final df = DateFormat('yyyy/MM/dd HH:mm:ss');
    final dt =
        _asDateTime(d['createdAt']) ??
        _asDateTime(d['updatedAt']) ??
        _asDateTime(d['time']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Log 詳情',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _kv('Doc ID', doc.id),
                  _kv('Time', dt == null ? '' : df.format(dt)),
                  _kv('Type', _s(d['type'])),
                  _kv('Status', _s(d['status'])),
                  _kv(
                    'Campaign',
                    _s(d['campaignTitle']).isNotEmpty
                        ? _s(d['campaignTitle'])
                        : _s(d['campaignId']),
                  ),
                  _kv('Segment', _s(d['segmentId'])),
                  _kv('Coupon', _s(d['couponId'])),
                  _kv('Lottery', _s(d['lotteryId'])),
                  _kv('User', _s(d['userId'])),
                  _kv('Channel', _s(d['channel'])),
                  const Divider(height: 24),
                  if (_s(d['title']).isNotEmpty) _kv('Title', _s(d['title'])),
                  if (_s(d['message']).isNotEmpty)
                    _kv('Message', _s(d['message'])),
                  const Divider(height: 24),
                  _kv('triggerCount', _n(d['triggerCount']).toString()),
                  _kv('sendCount', _n(d['sendCount']).toString()),
                  _kv('clickCount', _n(d['clickCount']).toString()),
                  _kv('conversionCount', _n(d['conversionCount']).toString()),
                  const Divider(height: 24),
                  Text(
                    'Raw Data',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      d.toString(),
                      style: const TextStyle(fontSize: 12, height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('關閉'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _filtersCard({
    required int total,
    required int filtered,
    required VoidCallback onExport,
  }) {
    final df = DateFormat('yyyy/MM/dd');
    final fromText = _fromDate == null ? '不限' : df.format(_fromDate!);
    final toText = _toDateFilter == null ? '不限' : df.format(_toDateFilter!);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _keywordCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '搜尋：標題/訊息/活動ID/用戶ID…',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                DropdownButton<String>(
                  value: _type,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('類型：全部')),
                    DropdownMenuItem(value: 'coupon', child: Text('類型：優惠券')),
                    DropdownMenuItem(value: 'lottery', child: Text('類型：抽獎')),
                    DropdownMenuItem(value: 'segment', child: Text('類型：分群')),
                    DropdownMenuItem(value: 'auto', child: Text('類型：自動派發')),
                    DropdownMenuItem(value: 'push', child: Text('類型：推播')),
                    DropdownMenuItem(value: 'line', child: Text('類型：LINE')),
                    DropdownMenuItem(value: 'email', child: Text('類型：Email')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'all'),
                ),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('狀態：全部')),
                    DropdownMenuItem(value: 'success', child: Text('狀態：成功')),
                    DropdownMenuItem(value: 'fail', child: Text('狀態：失敗')),
                    DropdownMenuItem(value: 'pending', child: Text('狀態：等待中')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'all'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(isFrom: true),
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text('起：$fromText'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(isFrom: false),
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text('迄：$toText'),
                ),
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('清除條件'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '顯示 $filtered / $total 筆（即時更新，最多 $_limit 筆）。',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _exporting ? null : onExport,
                  icon: const Icon(Icons.download, size: 18),
                  label: Text(_exporting ? '匯出中...' : '匯出 CSV'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiRow(Map<String, num> kpi) {
    Widget card(String title, String value, IconData icon) {
      return Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4)],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(title, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          card('觸發', kpi['trigger']!.toInt().toString(), Icons.touch_app),
          const SizedBox(width: 10),
          card('派發', kpi['send']!.toInt().toString(), Icons.send),
          const SizedBox(width: 10),
          card('點擊', kpi['click']!.toInt().toString(), Icons.mouse),
          const SizedBox(width: 10),
          card('轉換', kpi['conv']!.toInt().toString(), Icons.trending_up),
        ],
      ),
    );
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('campaign_logs')
        .orderBy('createdAt', descending: true)
        .limit(_limit)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('行銷活動日誌'),
        actions: [
          IconButton(
            tooltip: '清除條件',
            onPressed: _clearFilters,
            icon: const Icon(Icons.filter_alt_off),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorView(
              message: '讀取失敗：${snap.error}',
              onRetry: () => setState(() {}),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          final filtered = _applyLocalFilters(docs);
          final kpi = _calcKpi(filtered);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: _filtersCard(
                  total: docs.length,
                  filtered: filtered.length,
                  onExport: () => _exportCsv(filtered),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: _kpiRow(kpi),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('沒有符合條件的日誌'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final doc = filtered[i];
                          final d = doc.data();

                          final dt =
                              _asDateTime(d['createdAt']) ??
                              _asDateTime(d['updatedAt']) ??
                              _asDateTime(d['time']);
                          final timeText = dt == null
                              ? ''
                              : DateFormat('yyyy/MM/dd HH:mm').format(dt);

                          final type = _s(d['type']);
                          final status = _s(d['status']);
                          final title = _s(d['title']).isNotEmpty
                              ? _s(d['title'])
                              : (_s(d['campaignTitle']).isNotEmpty
                                    ? _s(d['campaignTitle'])
                                    : '（未命名）');

                          final message = _s(d['message']);
                          final campaignId = _s(d['campaignId']);
                          final userId = _s(d['userId']);
                          final channel = _s(d['channel']);

                          final isImportant =
                              _isTrue(d['isImportant']) ||
                              status.toLowerCase() == 'fail' ||
                              status.toLowerCase() == 'error';

                          final sc = _statusColor(status);

                          return Card(
                            elevation: 1,
                            child: ListTile(
                              onTap: () => _showDetailSheet(doc),
                              leading: CircleAvatar(
                                backgroundColor: isImportant
                                    ? Colors.red.shade50
                                    : Colors.blue.shade50,
                                child: Icon(
                                  Icons.receipt_long,
                                  color: isImportant ? Colors.red : Colors.blue,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      _typeLabel(type),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _withOpacity(sc, 0.10),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: _withOpacity(sc, 0.35),
                                      ),
                                    ),
                                    child: Text(
                                      status.isEmpty ? 'unknown' : status,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: sc,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (message.isNotEmpty)
                                      Text(
                                        message,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 6,
                                      children: [
                                        if (timeText.isNotEmpty)
                                          _chip(Icons.schedule, timeText),
                                        if (campaignId.isNotEmpty)
                                          _chip(
                                            Icons.flag_outlined,
                                            'CID: $campaignId',
                                          ),
                                        if (userId.isNotEmpty)
                                          _chip(
                                            Icons.person_outline,
                                            'UID: $userId',
                                          ),
                                        if (channel.isNotEmpty)
                                          _chip(Icons.send_outlined, channel),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40, color: Colors.red),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
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
    );
  }
}
