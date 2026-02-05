// lib/pages/admin/marketing/admin_auto_campaigns_page.dart
//
// ✅ AdminAutoCampaignsPage（自動派發管理｜最終可編譯完整版本）
// ------------------------------------------------------------
// - Firestore：auto_campaigns（即時監聽）
// - 搜尋：title / message / segmentId / couponId / lotteryId / channel
// - 篩選：類型 / 狀態 / 渠道
// - 排序：updatedAt / nextRunAt / conversionCount / sentCount
// - 批次：啟用 / 停用 / 刪除
// - KPI：總數、啟用數、總發送、總轉換、平均CVR
// - UI：避免 overflow（整頁可捲動）
// - 串接路由：
//   - /admin/auto_campaigns/edit（arguments = id 或 {id: ...}）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminAutoCampaignsPage extends StatefulWidget {
  const AdminAutoCampaignsPage({super.key});

  @override
  State<AdminAutoCampaignsPage> createState() => _AdminAutoCampaignsPageState();
}

class _AdminAutoCampaignsPageState extends State<AdminAutoCampaignsPage> {
  // filters
  final _keywordCtrl = TextEditingController();
  String _type = 'all';
  String _status = 'all'; // all/active/inactive
  String _channel = 'all'; // all/push/line/email/inapp/none

  // sort (client-side)
  String _sortBy = 'updatedAt'; // updatedAt/nextRunAt/conversionCount/sentCount
  bool _desc = true;

  // selection
  final Set<String> _selected = {};

  static const int _limit = 500;

  @override
  void dispose() {
    _keywordCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // helpers
  // ============================================================

  String _s(dynamic v, {String fallback = ''}) => v == null ? fallback : v.toString();

  num _n(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    final parsed = num.tryParse(v.toString());
    return parsed ?? fallback;
  }

  bool _b(dynamic v, {bool fallback = false}) => v == true ? true : (v == false ? false : fallback);

  DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'birthday':
        return '生日';
      case 'new_user':
        return '新用戶';
      case 'winback':
        return '喚回';
      case 'cart_abandon':
        return '購物車';
      case 'segment_blast':
        return '分群群發';
      case 'custom':
        return '自訂';
      default:
        return t.isEmpty ? '未知' : t;
    }
  }

  String _channelLabel(String c) {
    switch (c) {
      case 'push':
        return '推播';
      case 'line':
        return 'LINE';
      case 'email':
        return 'Email';
      case 'inapp':
        return '站內通知';
      default:
        return c.isEmpty ? '未設定' : c;
    }
  }

  Color _statusColor(bool isActive) => isActive ? Colors.green : Colors.grey;

  // ============================================================
  // local filter/sort
  // ============================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final kw = _keywordCtrl.text.trim().toLowerCase();

    bool matchKeyword(Map<String, dynamic> d) {
      if (kw.isEmpty) return true;
      final hay = <String>[
        _s(d['title']),
        _s(d['message']),
        _s(d['segmentId']),
        _s(d['couponId']),
        _s(d['lotteryId']),
        _s(d['channel']),
        _s(d['type']),
        _s(d['status']),
      ].join(' | ').toLowerCase();
      return hay.contains(kw);
    }

    bool matchType(Map<String, dynamic> d) {
      if (_type == 'all') return true;
      return _s(d['type']).trim() == _type;
    }

    bool matchStatus(Map<String, dynamic> d) {
      if (_status == 'all') return true;
      final active = _b(d['isActive'], fallback: false);
      if (_status == 'active') return active;
      if (_status == 'inactive') return !active;
      return true;
    }

    bool matchChannel(Map<String, dynamic> d) {
      if (_channel == 'all') return true;
      final c = _s(d['channel']).trim();
      if (_channel == 'none') return c.isEmpty;
      return c == _channel;
    }

    final filtered = docs.where((doc) {
      final d = doc.data();
      return matchKeyword(d) && matchType(d) && matchStatus(d) && matchChannel(d);
    }).toList(growable: false);

    int compareDocs(
      QueryDocumentSnapshot<Map<String, dynamic>> a,
      QueryDocumentSnapshot<Map<String, dynamic>> b,
    ) {
      final da = a.data();
      final db = b.data();

      int cmpNum(num x, num y) => x == y ? 0 : (x < y ? -1 : 1);
      int cmpDate(DateTime? x, DateTime? y) {
        if (x == null && y == null) return 0;
        if (x == null) return -1;
        if (y == null) return 1;
        return x.compareTo(y);
      }

      int base;
      switch (_sortBy) {
        case 'nextRunAt':
          base = cmpDate(_dt(da['nextRunAt']), _dt(db['nextRunAt']));
          break;
        case 'conversionCount':
          base = cmpNum(_n(da['conversionCount']), _n(db['conversionCount']));
          break;
        case 'sentCount':
          base = cmpNum(_n(da['sentCount']), _n(db['sentCount']));
          break;
        case 'updatedAt':
        default:
          base = cmpDate(_dt(da['updatedAt']) ?? _dt(da['createdAt']),
              _dt(db['updatedAt']) ?? _dt(db['createdAt']));
      }

      return _desc ? -base : base;
    }

    final sorted = filtered.toList()..sort(compareDocs);
    return sorted;
  }

  // ============================================================
  // batch actions
  // ============================================================

  Future<void> _batchToggle(bool newState) async {
    if (_selected.isEmpty) return;
    final fs = FirebaseFirestore.instance;
    final batch = fs.batch();
    for (final id in _selected) {
      batch.update(fs.collection('auto_campaigns').doc(id), {
        'isActive': newState,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    final count = _selected.length;
    await batch.commit();
    _selected.clear();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已批次${newState ? '啟用' : '停用'} $count 筆')),
    );
  }

  Future<void> _batchDelete() async {
    if (_selected.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定刪除選取的 ${_selected.length} 筆自動派發活動？此操作不可復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );

    if (ok != true) return;

    final fs = FirebaseFirestore.instance;
    final batch = fs.batch();
    for (final id in _selected) {
      batch.delete(fs.collection('auto_campaigns').doc(id));
    }
    final count = _selected.length;
    await batch.commit();
    _selected.clear();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已刪除 $count 筆')),
    );
  }

  // ============================================================
  // KPI
  // ============================================================

  Widget _kpiCards(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final total = docs.length;
    final active = docs.where((d) => _b(d.data()['isActive'], fallback: false)).length;

    num sent = 0;
    num conv = 0;
    for (final doc in docs) {
      final d = doc.data();
      sent += _n(d['sentCount']);
      conv += _n(d['conversionCount']);
    }
    final cvr = sent > 0 ? (conv / sent * 100) : 0;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _kpi('活動總數', '$total', Icons.campaign),
        _kpi('啟用中', '$active', Icons.toggle_on),
        _kpi('總發送', sent.toInt().toString(), Icons.send),
        _kpi('總轉換', conv.toInt().toString(), Icons.auto_graph),
        _kpi('平均 CVR', '${cvr.toStringAsFixed(1)}%', Icons.trending_up),
      ],
    );
  }

  Widget _kpi(String title, String value, IconData icon) {
    return Container(
      width: 180,
      height: 92,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  Widget _toolbar() {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _keywordCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: '搜尋：標題 / 訊息 / 分群ID / 優惠券ID / 渠道…',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            DropdownButton<String>(
              value: _type,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('類型：全部')),
                DropdownMenuItem(value: 'birthday', child: Text('類型：生日')),
                DropdownMenuItem(value: 'new_user', child: Text('類型：新用戶')),
                DropdownMenuItem(value: 'winback', child: Text('類型：喚回')),
                DropdownMenuItem(value: 'cart_abandon', child: Text('類型：購物車')),
                DropdownMenuItem(value: 'segment_blast', child: Text('類型：分群群發')),
                DropdownMenuItem(value: 'custom', child: Text('類型：自訂')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'all'),
            ),
            DropdownButton<String>(
              value: _status,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('狀態：全部')),
                DropdownMenuItem(value: 'active', child: Text('狀態：啟用')),
                DropdownMenuItem(value: 'inactive', child: Text('狀態：停用')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'all'),
            ),
            DropdownButton<String>(
              value: _channel,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('渠道：全部')),
                DropdownMenuItem(value: 'push', child: Text('渠道：推播')),
                DropdownMenuItem(value: 'line', child: Text('渠道：LINE')),
                DropdownMenuItem(value: 'email', child: Text('渠道：Email')),
                DropdownMenuItem(value: 'inapp', child: Text('渠道：站內通知')),
                DropdownMenuItem(value: 'none', child: Text('渠道：未設定')),
              ],
              onChanged: (v) => setState(() => _channel = v ?? 'all'),
            ),
            DropdownButton<String>(
              value: _sortBy,
              items: const [
                DropdownMenuItem(value: 'updatedAt', child: Text('排序：最近更新')),
                DropdownMenuItem(value: 'nextRunAt', child: Text('排序：下次執行')),
                DropdownMenuItem(value: 'sentCount', child: Text('排序：發送量')),
                DropdownMenuItem(value: 'conversionCount', child: Text('排序：轉換量')),
              ],
              onChanged: (v) => setState(() => _sortBy = v ?? 'updatedAt'),
            ),
            IconButton(
              tooltip: _desc ? '目前：由大到小' : '目前：由小到大',
              onPressed: () => setState(() => _desc = !_desc),
              icon: Icon(_desc ? Icons.arrow_downward : Icons.arrow_upward),
            ),
            OutlinedButton.icon(
              onPressed: () {
                _keywordCtrl.clear();
                setState(() {
                  _type = 'all';
                  _status = 'all';
                  _channel = 'all';
                  _sortBy = 'updatedAt';
                  _desc = true;
                });
              },
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('清除條件'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text, {Color? bg, Color? border, Color? fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border ?? Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg ?? Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg ?? Colors.grey.shade800),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('auto_campaigns')
        .orderBy('updatedAt', descending: true)
        .limit(_limit)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('自動派發管理'),
        actions: [
          if (_selected.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: '批次操作',
              onSelected: (v) {
                if (v == 'enable') _batchToggle(true);
                if (v == 'disable') _batchToggle(false);
                if (v == 'delete') _batchDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'enable', child: Text('批次啟用')),
                PopupMenuItem(value: 'disable', child: Text('批次停用')),
                PopupMenuItem(value: 'delete', child: Text('批次刪除')),
              ],
            ),
          IconButton(
            tooltip: '新增自動派發',
            onPressed: () => Navigator.pushNamed(context, '/admin/auto_campaigns/edit'),
            icon: const Icon(Icons.add),
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

          final raw = snap.data!.docs;
          final docs = _applyFilters(raw);

          final df = DateFormat('yyyy/MM/dd HH:mm');

          return Column(
            children: [
              _toolbar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kpiCards(docs),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '顯示 ${docs.length} / ${raw.length}（即時更新，最多 $_limit 筆）',
                              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (docs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('沒有符合條件的自動派發活動')),
                        ),
                      if (docs.isNotEmpty)
                        ListView.separated(
                          itemCount: docs.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final doc = docs[i];
                            final d = doc.data();
                            final id = doc.id;

                            final isActive = _b(d['isActive'], fallback: false);
                            final selected = _selected.contains(id);

                            final title = _s(d['title'], fallback: '（未命名）');
                            final type = _s(d['type']);
                            final channel = _s(d['channel']);
                            final segmentId = _s(d['segmentId']);
                            final couponId = _s(d['couponId']);
                            final lotteryId = _s(d['lotteryId']);

                            final sent = _n(d['sentCount']).toInt();
                            final conv = _n(d['conversionCount']).toInt();
                            final cvr = sent > 0 ? (conv / sent * 100) : 0.0;

                            final nextRun = _dt(d['nextRunAt']);
                            final lastRun = _dt(d['lastRunAt']);
                            final updated = _dt(d['updatedAt']) ?? _dt(d['createdAt']);

                            return Card(
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: selected,
                                          onChanged: (v) {
                                            setState(() {
                                              if (v == true) {
                                                _selected.add(id);
                                              } else {
                                                _selected.remove(id);
                                              }
                                            });
                                          },
                                        ),
                                        Switch(
                                          value: isActive,
                                          onChanged: (v) async {
                                            await FirebaseFirestore.instance
                                                .collection('auto_campaigns')
                                                .doc(id)
                                                .update({
                                              'isActive': v,
                                              'updatedAt': FieldValue.serverTimestamp(),
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _chip(
                                          Icons.circle,
                                          isActive ? '啟用' : '停用',
                                          bg: isActive ? Colors.green.withOpacity(0.10) : Colors.grey.shade200,
                                          border: isActive ? Colors.green.withOpacity(0.35) : Colors.grey.shade400,
                                          fg: _statusColor(isActive),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          tooltip: '編輯',
                                          onPressed: () => Navigator.pushNamed(
                                            context,
                                            '/admin/auto_campaigns/edit',
                                            arguments: {'id': id},
                                          ),
                                          icon: const Icon(Icons.edit),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Wrap(
                                        spacing: 10,
                                        runSpacing: 8,
                                        children: [
                                          _chip(Icons.category_outlined, '類型：${_typeLabel(type)}'),
                                          _chip(Icons.send_outlined, '渠道：${_channelLabel(channel)}'),
                                          if (segmentId.isNotEmpty)
                                            _chip(Icons.group_work_outlined, '分群：$segmentId'),
                                          if (couponId.isNotEmpty)
                                            _chip(Icons.card_giftcard_outlined, '券：$couponId'),
                                          if (lotteryId.isNotEmpty)
                                            _chip(Icons.emoji_events_outlined, '抽：$lotteryId'),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Wrap(
                                        spacing: 10,
                                        runSpacing: 8,
                                        children: [
                                          _chip(Icons.send, '發送 $sent'),
                                          _chip(Icons.auto_graph, '轉換 $conv'),
                                          _chip(Icons.trending_up, 'CVR ${cvr.toStringAsFixed(1)}%'),
                                          if (nextRun != null)
                                            _chip(Icons.schedule, '下次：${df.format(nextRun)}'),
                                          if (lastRun != null)
                                            _chip(Icons.history, '上次：${df.format(lastRun)}'),
                                          if (updated != null)
                                            _chip(Icons.update, '更新：${df.format(updated)}'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
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
                Text(message, style: const TextStyle(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
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
