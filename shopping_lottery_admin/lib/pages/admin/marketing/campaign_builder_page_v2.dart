// lib/pages/admin/marketing/campaign_builder_page_v2.dart
//
// ✅ CampaignBuilderPageV2（行銷活動建立器 v2｜完整版｜可直接編譯）
// ------------------------------------------------------------
// ✅ FIX: use_build_context_synchronously
// - 所有 await 之後會用到 context（SnackBar / Navigator / showDialog）
//   都先做 if (!mounted) return;
//
// ✅ FIX: unnecessary_cast
// - _loadPickLists() 改用 Future.wait<QuerySnapshot<Map<String,dynamic>>>()
//   讓 results 直接是正確型別，移除不必要 cast
// ------------------------------------------------------------
//
// 功能（通用版）
// - 新增 / 編輯活動（collection: marketing_campaigns_v2，可自行改）
// - 基本欄位：title / message / type / channel / segment / coupon / lottery
// - 排程：sendAt（可空=立即）
// - 狀態：isActive（可切換）
// - 載入 segments / coupons / lotteries 下拉選單（各取前 500）
//
// 依賴：cloud_firestore, flutter/material, intl
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CampaignBuilderPageV2 extends StatefulWidget {
  const CampaignBuilderPageV2({
    super.key,
    this.campaignId,
    this.collectionName = 'marketing_campaigns_v2',
  });

  final String? campaignId;
  final String collectionName;

  @override
  State<CampaignBuilderPageV2> createState() => _CampaignBuilderPageV2State();
}

class _CampaignBuilderPageV2State extends State<CampaignBuilderPageV2> {
  // UI
  bool _loading = true;
  bool _saving = false;

  // form controllers
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  // selections
  String _type = 'custom'; // custom/coupon/lottery/segment_blast
  String _channel = 'push'; // push/line/email/inapp
  String _segmentId = 'all';
  String? _couponId;
  String? _lotteryId;

  bool _isActive = true;

  // schedule
  DateTime? _sendAt;

  // pick lists
  List<_PickItem> _segments = const [];
  List<_PickItem> _coupons = const [];
  List<_PickItem> _lotteries = const [];

  String get _modeTitle => widget.campaignId == null ? '新增活動' : '編輯活動';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // Helpers
  // ============================================================

  String _s(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    return v.toString();
  }

  bool _b(dynamic v, {bool fallback = false}) {
    if (v == true) return true;
    if (v == false) return false;
    return fallback;
  }

  DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  // ============================================================
  // Load
  // ============================================================

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      await Future.wait([
        _loadPickLists(),
        if (widget.campaignId != null) _loadCampaign(widget.campaignId!),
      ]);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('初始化失敗：$e')));
    }
  }

  Future<void> _loadPickLists() async {
    final fs = FirebaseFirestore.instance;

    final Future<QuerySnapshot<Map<String, dynamic>>> segFuture = fs
        .collection('segments')
        .orderBy('updatedAt', descending: true)
        .limit(500)
        .get();

    final Future<QuerySnapshot<Map<String, dynamic>>> couponFuture = fs
        .collection('coupons')
        .orderBy('updatedAt', descending: true)
        .limit(500)
        .get();

    final Future<QuerySnapshot<Map<String, dynamic>>> lotteryFuture = fs
        .collection('lotteries')
        .orderBy('updatedAt', descending: true)
        .limit(500)
        .get();

    // ✅ FIX: 給 Future.wait 泛型，results 直接是正確型別 -> 不需要任何 cast
    final List<QuerySnapshot<Map<String, dynamic>>> results =
        await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
          segFuture,
          couponFuture,
          lotteryFuture,
        ]);

    final segSnap = results[0];
    final couponSnap = results[1];
    final lotterySnap = results[2];

    final segs = <_PickItem>[
      const _PickItem(id: 'all', label: '全部'),
      ...segSnap.docs.map((d) {
        final m = d.data();
        final title = _s(m['title'], fallback: _s(m['name'], fallback: d.id));
        return _PickItem(id: d.id, label: title);
      }),
    ];

    final coupons = couponSnap.docs
        .map((d) {
          final m = d.data();
          final title = _s(m['title'], fallback: _s(m['name'], fallback: d.id));
          return _PickItem(id: d.id, label: title);
        })
        .toList(growable: false);

    final lotteries = lotterySnap.docs
        .map((d) {
          final m = d.data();
          final title = _s(m['title'], fallback: _s(m['name'], fallback: d.id));
          return _PickItem(id: d.id, label: title);
        })
        .toList(growable: false);

    if (!mounted) return;
    setState(() {
      _segments = segs;
      _coupons = coupons;
      _lotteries = lotteries;
    });
  }

  Future<void> _loadCampaign(String id) async {
    final doc = await FirebaseFirestore.instance
        .collection(widget.collectionName)
        .doc(id)
        .get();

    if (!doc.exists) return;

    final m = doc.data() ?? <String, dynamic>{};

    if (!mounted) return;
    setState(() {
      _titleCtrl.text = _s(m['title']);
      _messageCtrl.text = _s(m['message']);

      final t = _s(m['type'], fallback: 'custom').trim();
      _type = t.isEmpty ? 'custom' : t;

      final ch = _s(m['channel'], fallback: 'push').trim();
      _channel = ch.isEmpty ? 'push' : ch;

      final seg = _s(m['segmentId'], fallback: 'all').trim();
      _segmentId = seg.isEmpty ? 'all' : seg;

      final cId = _s(m['couponId']).trim();
      _couponId = cId.isEmpty ? null : cId;

      final lId = _s(m['lotteryId']).trim();
      _lotteryId = lId.isEmpty ? null : lId;

      _isActive = _b(m['isActive'], fallback: true);
      _sendAt = _dt(m['sendAt']);
    });
  }

  // ============================================================
  // Pick date time
  // ============================================================

  Future<void> _pickSendAt() async {
    final now = DateTime.now();
    final base = _sendAt ?? now;

    final d = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null) return;

    if (!mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (t == null) return;

    final picked = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (!mounted) return;
    setState(() => _sendAt = picked);
  }

  void _clearSendAt() => setState(() => _sendAt = null);

  // ============================================================
  // Validate & Save
  // ============================================================

  bool _validate() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _toast('請輸入活動標題');
      return false;
    }

    if (_type == 'coupon' && (_couponId == null || _couponId!.trim().isEmpty)) {
      _toast('類型為「優惠券」時，請選擇 coupon');
      return false;
    }
    if (_type == 'lottery' &&
        (_lotteryId == null || _lotteryId!.trim().isEmpty)) {
      _toast('類型為「抽獎」時，請選擇 lottery');
      return false;
    }
    return true;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_validate()) return;

    setState(() => _saving = true);

    try {
      final fs = FirebaseFirestore.instance;
      final ref = widget.campaignId == null
          ? fs.collection(widget.collectionName).doc()
          : fs.collection(widget.collectionName).doc(widget.campaignId);

      final now = FieldValue.serverTimestamp();

      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
        'type': _type,
        'channel': _channel,
        'segmentId': _segmentId,
        'couponId': _type == 'coupon' ? _couponId : null,
        'lotteryId': _type == 'lottery' ? _lotteryId : null,
        'isActive': _isActive,
        'sendAt': _sendAt == null ? null : Timestamp.fromDate(_sendAt!),
        'updatedAt': now,
        if (widget.campaignId == null) 'createdAt': now,
      };

      payload.removeWhere((_, v) => v == null);

      await ref.set(payload, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已儲存：${ref.id}')));
      Navigator.pop(context, {'id': ref.id});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ============================================================
  // Preview
  // ============================================================

  void _preview() {
    final df = DateFormat('yyyy/MM/dd HH:mm');
    final sendAtText = _sendAt == null ? '立即' : df.format(_sendAt!);

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
                    '預覽',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _kv('標題', _titleCtrl.text.trim()),
                  _kv('訊息', _messageCtrl.text.trim()),
                  _kv('類型', _type),
                  _kv('渠道', _channel),
                  _kv('Segment', _segmentId),
                  _kv('Coupon', _couponId ?? '-'),
                  _kv('Lottery', _lotteryId ?? '-'),
                  _kv('排程', sendAtText),
                  _kv('啟用', _isActive ? '是' : '否'),
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

  Widget _kv(String k, String v) {
    final vv = v.trim().isEmpty ? '-' : v.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Expanded(child: Text(vv)),
        ],
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final df = DateFormat('yyyy/MM/dd HH:mm');
    final sendAtText = _sendAt == null ? '立即' : df.format(_sendAt!);

    return Scaffold(
      appBar: AppBar(
        title: Text(_modeTitle),
        actions: [
          IconButton(
            tooltip: '預覽',
            onPressed: _preview,
            icon: const Icon(Icons.visibility),
          ),
          IconButton(
            tooltip: '儲存',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('基本資訊'),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: '活動標題',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: '訊息內容',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle('投放設定'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _dropdown<String>(
                label: '類型',
                value: _type,
                items: const [
                  DropdownMenuItem(value: 'custom', child: Text('自訂')),
                  DropdownMenuItem(value: 'coupon', child: Text('優惠券')),
                  DropdownMenuItem(value: 'lottery', child: Text('抽獎')),
                  DropdownMenuItem(value: 'segment_blast', child: Text('分群群發')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _type = v;
                    if (_type != 'coupon') _couponId = null;
                    if (_type != 'lottery') _lotteryId = null;
                  });
                },
              ),
              _dropdown<String>(
                label: '渠道',
                value: _channel,
                items: const [
                  DropdownMenuItem(value: 'push', child: Text('推播')),
                  DropdownMenuItem(value: 'line', child: Text('LINE')),
                  DropdownMenuItem(value: 'email', child: Text('Email')),
                  DropdownMenuItem(value: 'inapp', child: Text('站內通知')),
                ],
                onChanged: (v) => setState(() => _channel = v ?? 'push'),
              ),
              _dropdown<String>(
                label: '分群',
                value: _segments.any((e) => e.id == _segmentId)
                    ? _segmentId
                    : 'all',
                items: _segments
                    .map(
                      (s) =>
                          DropdownMenuItem(value: s.id, child: Text(s.label)),
                    )
                    .toList(growable: false),
                onChanged: (v) => setState(() => _segmentId = v ?? 'all'),
              ),
            ],
          ),
          if (_type == 'coupon') ...[
            const SizedBox(height: 12),
            _dropdown<String>(
              label: 'Coupon',
              value: _couponId,
              hint: '選擇優惠券',
              items: _coupons
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.label)),
                  )
                  .toList(growable: false),
              onChanged: (v) => setState(() => _couponId = v),
            ),
          ],
          if (_type == 'lottery') ...[
            const SizedBox(height: 12),
            _dropdown<String>(
              label: 'Lottery',
              value: _lotteryId,
              hint: '選擇抽獎活動',
              items: _lotteries
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.label)),
                  )
                  .toList(growable: false),
              onChanged: (v) => setState(() => _lotteryId = v),
            ),
          ],
          const SizedBox(height: 18),
          _sectionTitle('排程 / 狀態'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickSendAt,
                  icon: const Icon(Icons.schedule),
                  label: Text('發送時間：$sendAtText'),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(onPressed: _clearSendAt, child: const Text('清除')),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
            title: const Text('啟用'),
            subtitle: const Text('停用時不會被派發/執行（依你的後端邏輯）'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: Text(_saving ? '儲存中...' : '儲存'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            hint: hint == null ? null : Text(hint),
            isExpanded: true,
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _PickItem {
  final String id;
  final String label;
  const _PickItem({required this.id, required this.label});
}
