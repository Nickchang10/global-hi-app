// lib/pages/admin/marketing/admin_auto_campaign_edit_page.dart
//
// ✅ AdminAutoCampaignEditPage（自動派發編輯頁｜最終可編譯完整版本）
// ------------------------------------------------------------
// - 新增 / 編輯 / 刪除 auto_campaigns
// - 可選擇 segment / coupon / lottery（提供簡易 picker 對話框）
// - 排程設定（簡化但可用）：
//   frequency: once/daily/weekly/monthly
//   timeOfDay: HH:mm
//   weekdays: [1..7]（週模式）
//   dayOfMonth: 1..28（月模式）
//   startAt / endAt
// - 自動寫入：createdAt / updatedAt (serverTimestamp)
// - 防呆：欄位缺失也不會噴錯
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminAutoCampaignEditPage extends StatefulWidget {
  final String? campaignId;
  const AdminAutoCampaignEditPage({super.key, this.campaignId});

  @override
  State<AdminAutoCampaignEditPage> createState() => _AdminAutoCampaignEditPageState();
}

class _AdminAutoCampaignEditPageState extends State<AdminAutoCampaignEditPage> {
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  String _type = 'birthday';
  String _channel = 'push';
  bool _isActive = true;

  String? _segmentId;
  String? _couponId;
  String? _lotteryId;

  // schedule
  String _frequency = 'daily'; // once/daily/weekly/monthly
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  final Set<int> _weekdays = {1}; // 1..7 (Mon..Sun)
  int _dayOfMonth = 1;

  DateTime? _startAt;
  DateTime? _endAt;

  bool _loading = true;
  bool _saving = false;

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('auto_campaigns').doc(widget.campaignId ?? '_new');

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // helpers
  // ============================================================

  String _s(dynamic v, {String fallback = ''}) => v == null ? fallback : v.toString();

  bool _b(dynamic v, {bool fallback = false}) => v == true ? true : (v == false ? false : fallback);

  DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  int _i(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  // ============================================================
  // load
  // ============================================================

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      if (widget.campaignId == null) {
        // new
        _loading = false;
        if (mounted) setState(() {});
        return;
      }

      final snap = await FirebaseFirestore.instance.collection('auto_campaigns').doc(widget.campaignId).get();
      final d = snap.data();
      if (d != null) {
        _titleCtrl.text = _s(d['title']);
        _messageCtrl.text = _s(d['message']);

        _type = _s(d['type'], fallback: 'birthday');
        _channel = _s(d['channel'], fallback: 'push');
        _isActive = _b(d['isActive'], fallback: true);

        _segmentId = _s(d['segmentId']).isEmpty ? null : _s(d['segmentId']);
        _couponId = _s(d['couponId']).isEmpty ? null : _s(d['couponId']);
        _lotteryId = _s(d['lotteryId']).isEmpty ? null : _s(d['lotteryId']);

        final sched = (d['schedule'] is Map) ? Map<String, dynamic>.from(d['schedule']) : <String, dynamic>{};
        _frequency = _s(sched['frequency'], fallback: 'daily');

        final hour = _i(sched['hour'], fallback: 10);
        final minute = _i(sched['minute'], fallback: 0);
        _time = TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));

        final w = (sched['weekdays'] is List) ? List.from(sched['weekdays']) : <dynamic>[];
        _weekdays
          ..clear()
          ..addAll(w.map((e) => _i(e)).where((x) => x >= 1 && x <= 7));
        if (_weekdays.isEmpty) _weekdays.add(1);

        _dayOfMonth = _i(sched['dayOfMonth'], fallback: 1).clamp(1, 28);

        _startAt = _dt(d['startAt']);
        _endAt = _dt(d['endAt']);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('讀取失敗：$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ============================================================
  // pickers
  // ============================================================

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null) return;
    setState(() => _time = picked);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final init = isStart ? (_startAt ?? now) : (_endAt ?? _startAt ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;

    setState(() {
      final date = DateTime(picked.year, picked.month, picked.day);
      if (isStart) {
        _startAt = date;
        if (_endAt != null && _endAt!.isBefore(_startAt!)) _endAt = null;
      } else {
        _endAt = date;
      }
    });
  }

  Future<String?> _pickDocId({
    required String collection,
    required String title,
    String titleField = 'title',
    String subtitleField = 'code',
  }) async {
    final fs = FirebaseFirestore.instance;

    return showDialog<String>(
      context: context,
      builder: (_) {
        final keywordCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 520,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: keywordCtrl,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: '搜尋...',
                        isDense: true,
                      ),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: fs.collection(collection).orderBy('updatedAt', descending: true).limit(300).snapshots(),
                        builder: (context, snap) {
                          if (snap.hasError) return Center(child: Text('讀取失敗：${snap.error}'));
                          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                          final kw = keywordCtrl.text.trim().toLowerCase();
                          final docs = snap.data!.docs.where((doc) {
                            if (kw.isEmpty) return true;
                            final d = doc.data();
                            final hay = <String>[
                              doc.id,
                              (d[titleField] ?? '').toString(),
                              (d[subtitleField] ?? '').toString(),
                            ].join(' | ').toLowerCase();
                            return hay.contains(kw);
                          }).toList();

                          if (docs.isEmpty) return const Center(child: Text('沒有資料'));

                          return ListView.separated(
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final doc = docs[i];
                              final d = doc.data();
                              final t = (d[titleField] ?? '').toString();
                              final s = (d[subtitleField] ?? '').toString();

                              return ListTile(
                                title: Text(t.isEmpty ? doc.id : t),
                                subtitle: Text(s.isEmpty ? doc.id : s),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.pop(ctx, doc.id),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // save/delete
  // ============================================================

  Map<String, dynamic> _buildSchedule() {
    return {
      'frequency': _frequency,
      'hour': _time.hour,
      'minute': _time.minute,
      'weekdays': _weekdays.toList()..sort(),
      'dayOfMonth': _dayOfMonth,
    };
  }

  DateTime _calcNextRunAt(DateTime now) {
    // 簡化版 nextRunAt：依 frequency + time 做推算（用於 UI 及排程參考）
    DateTime base = DateTime(now.year, now.month, now.day, _time.hour, _time.minute);

    if (_frequency == 'once') {
      // 若有 startAt，就用 startAt 的日期 + time；否則用今天/明天
      final d = _startAt ?? now;
      final t = DateTime(d.year, d.month, d.day, _time.hour, _time.minute);
      return t.isAfter(now) ? t : t.add(const Duration(days: 1));
    }

    if (_frequency == 'daily') {
      if (base.isAfter(now)) return base;
      return base.add(const Duration(days: 1));
    }

    if (_frequency == 'weekly') {
      // 找下一個符合 weekday 的日期
      // weekday: Mon=1..Sun=7
      final sorted = _weekdays.toList()..sort();
      for (int add = 0; add <= 14; add++) {
        final candidate = base.add(Duration(days: add));
        if (sorted.contains(candidate.weekday) && candidate.isAfter(now)) return candidate;
      }
      return base.add(const Duration(days: 7));
    }

    if (_frequency == 'monthly') {
      final day = _dayOfMonth.clamp(1, 28);
      DateTime candidate = DateTime(now.year, now.month, day, _time.hour, _time.minute);
      if (candidate.isAfter(now)) return candidate;
      // next month
      final nextMonth = DateTime(now.year, now.month + 1, day, _time.hour, _time.minute);
      return nextMonth;
    }

    // fallback
    return base.isAfter(now) ? base : base.add(const Duration(days: 1));
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('標題不可為空')));
      return;
    }

    setState(() => _saving = true);
    try {
      final fs = FirebaseFirestore.instance;
      final now = DateTime.now();

      final data = <String, dynamic>{
        'title': title,
        'message': _messageCtrl.text.trim(),
        'type': _type,
        'channel': _channel,
        'isActive': _isActive,
        'segmentId': _segmentId,
        'couponId': _couponId,
        'lotteryId': _lotteryId,
        'schedule': _buildSchedule(),
        'startAt': _startAt == null ? null : Timestamp.fromDate(_startAt!),
        'endAt': _endAt == null ? null : Timestamp.fromDate(_endAt!),
        'nextRunAt': Timestamp.fromDate(_calcNextRunAt(now)),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // remove nulls
      data.removeWhere((k, v) => v == null);

      if (widget.campaignId == null) {
        await fs.collection('auto_campaigns').add({
          ...data,
          'sentCount': 0,
          'conversionCount': 0,
          'errorCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await fs.collection('auto_campaigns').doc(widget.campaignId).update(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已儲存')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.campaignId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認刪除'),
        content: const Text('確定刪除此自動派發活動？此操作不可復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('auto_campaigns').doc(widget.campaignId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ============================================================
  // UI
  // ============================================================

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      children: [
        SizedBox(width: 92, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w800))),
        Expanded(child: Text(v, style: const TextStyle(color: Colors.black54))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy/MM/dd');

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.campaignId == null ? '新增自動派發' : '編輯自動派發'),
        actions: [
          if (widget.campaignId != null)
            IconButton(
              tooltip: '刪除',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: const Text('儲存'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('基本資訊'),
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: '活動標題',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _messageCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '訊息內容（可選）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<String>(
                        value: _type,
                        items: const [
                          DropdownMenuItem(value: 'birthday', child: Text('類型：生日')),
                          DropdownMenuItem(value: 'new_user', child: Text('類型：新用戶')),
                          DropdownMenuItem(value: 'winback', child: Text('類型：喚回')),
                          DropdownMenuItem(value: 'cart_abandon', child: Text('類型：購物車')),
                          DropdownMenuItem(value: 'segment_blast', child: Text('類型：分群群發')),
                          DropdownMenuItem(value: 'custom', child: Text('類型：自訂')),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? 'birthday'),
                      ),
                      DropdownButton<String>(
                        value: _channel,
                        items: const [
                          DropdownMenuItem(value: 'push', child: Text('渠道：推播')),
                          DropdownMenuItem(value: 'line', child: Text('渠道：LINE')),
                          DropdownMenuItem(value: 'email', child: Text('渠道：Email')),
                          DropdownMenuItem(value: 'inapp', child: Text('渠道：站內通知')),
                        ],
                        onChanged: (v) => setState(() => _channel = v ?? 'push'),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
                          Text(_isActive ? '啟用' : '停用', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),

                  _sectionTitle('綁定資源'),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final id = await _pickDocId(collection: 'segments', title: '選擇受眾分群', titleField: 'name', subtitleField: 'description');
                          if (id == null) return;
                          setState(() => _segmentId = id);
                        },
                        icon: const Icon(Icons.group_work_outlined),
                        label: Text(_segmentId == null ? '選擇分群' : '分群：$_segmentId'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final id = await _pickDocId(collection: 'coupons', title: '選擇優惠券', titleField: 'title', subtitleField: 'code');
                          if (id == null) return;
                          setState(() => _couponId = id);
                        },
                        icon: const Icon(Icons.card_giftcard_outlined),
                        label: Text(_couponId == null ? '選擇優惠券' : '券：$_couponId'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final id = await _pickDocId(collection: 'lotteries', title: '選擇抽獎活動', titleField: 'title', subtitleField: 'status');
                          if (id == null) return;
                          setState(() => _lotteryId = id);
                        },
                        icon: const Icon(Icons.emoji_events_outlined),
                        label: Text(_lotteryId == null ? '選擇抽獎（可選）' : '抽：$_lotteryId'),
                      ),
                      if (_segmentId != null || _couponId != null || _lotteryId != null)
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _segmentId = null;
                            _couponId = null;
                            _lotteryId = null;
                          }),
                          icon: const Icon(Icons.clear),
                          label: const Text('清除綁定'),
                        ),
                    ],
                  ),

                  _sectionTitle('排程設定'),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<String>(
                        value: _frequency,
                        items: const [
                          DropdownMenuItem(value: 'once', child: Text('頻率：單次')),
                          DropdownMenuItem(value: 'daily', child: Text('頻率：每日')),
                          DropdownMenuItem(value: 'weekly', child: Text('頻率：每週')),
                          DropdownMenuItem(value: 'monthly', child: Text('頻率：每月')),
                        ],
                        onChanged: (v) => setState(() => _frequency = v ?? 'daily'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.schedule),
                        label: Text('時間：${_time.format(context)}'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(isStart: true),
                        icon: const Icon(Icons.date_range),
                        label: Text(_startAt == null ? '開始：不限' : '開始：${df.format(_startAt!)}'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(isStart: false),
                        icon: const Icon(Icons.date_range),
                        label: Text(_endAt == null ? '結束：不限' : '結束：${df.format(_endAt!)}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_frequency == 'weekly') ...[
                    _sectionTitle('每週星期'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(7, (idx) {
                        final wd = idx + 1; // 1..7
                        final label = const ['一', '二', '三', '四', '五', '六', '日'][idx];
                        final selected = _weekdays.contains(wd);
                        return FilterChip(
                          label: Text('週$label'),
                          selected: selected,
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _weekdays.add(wd);
                              } else {
                                if (_weekdays.length > 1) _weekdays.remove(wd);
                              }
                            });
                          },
                        );
                      }),
                    ),
                  ],

                  if (_frequency == 'monthly') ...[
                    _sectionTitle('每月日期（1~28）'),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _dayOfMonth.toDouble(),
                            min: 1,
                            max: 28,
                            divisions: 27,
                            label: '$_dayOfMonth',
                            onChanged: (v) => setState(() => _dayOfMonth = v.toInt()),
                          ),
                        ),
                        SizedBox(width: 54, child: Text('$_dayOfMonth 日', style: const TextStyle(fontWeight: FontWeight.w900))),
                      ],
                    ),
                  ],

                  const Divider(height: 28),
                  _sectionTitle('預覽（將寫入 nextRunAt）'),
                  Builder(
                    builder: (_) {
                      final next = _calcNextRunAt(DateTime.now());
                      return _kv('下次執行', DateFormat('yyyy/MM/dd HH:mm').format(next));
                    },
                  ),

                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: const Text('儲存'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('返回'),
                      ),
                    ],
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
