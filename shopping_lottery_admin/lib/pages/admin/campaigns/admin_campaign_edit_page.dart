// lib/pages/admin/campaigns/admin_campaign_edit_page.dart
//
// ✅ AdminCampaignEditPage（完整版｜可編譯＋可用）
// ------------------------------------------------------------
// ✅ DropdownButtonFormField.value → initialValue（Flutter v3.33+）
// ✅ PopScope + onPopInvokedWithResult
// ✅ 避免 withOpacity（改用 withAlpha）
// ✅ 修正 use_build_context_synchronously：每個 await 後先 mounted 再使用 context
//
// Firestore：campaigns/{campaignId}
// {
//   title: "春季活動",
//   type: "coupon" | "lottery" | "banner" | "mission",
//   enabled: true,
//   priority: 10,
//   targetUrl: "https://...",
//   bannerImageUrl: "https://...",
//   startAt: Timestamp?,
//   endAt: Timestamp?,
//   description: "活動說明...",
//   createdAt: Timestamp,
//   updatedAt: Timestamp
// }

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ✅ campaigns 底下要往上 3 層回到 lib/
import '../../../layouts/scaffold_with_drawer.dart';

class AdminCampaignEditPage extends StatefulWidget {
  const AdminCampaignEditPage({super.key});

  static const String routeName = '/admin-campaign-edit';

  @override
  State<AdminCampaignEditPage> createState() => _AdminCampaignEditPageState();
}

class _AdminCampaignEditPageState extends State<AdminCampaignEditPage> {
  final _db = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  bool _inited = false;
  bool _loading = true;
  bool _saving = false;

  String? _campaignId; // null => new
  late DocumentReference<Map<String, dynamic>> _docRef;

  final _titleCtrl = TextEditingController();
  final _targetUrlCtrl = TextEditingController();
  final _bannerUrlCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  bool _enabled = true;
  int _priority = 10;

  String _type = 'coupon';
  DateTime? _startAt;
  DateTime? _endAt;

  String _baselineSig = '';
  bool _dirty = false;

  Color _alpha(Color c, double opacity01) {
    final a = (opacity01 * 255).round().clamp(0, 255);
    return c.withAlpha(a);
  }

  static const _typeOptions = <String, String>{
    'coupon': '優惠券（Coupon）',
    'lottery': '抽獎（Lottery）',
    'banner': 'Banner（首頁橫幅）',
    'mission': '任務（Mission）',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.trim().isNotEmpty) {
      _campaignId = args.trim();
    } else if (args is Map) {
      final raw = args['id'];
      if (raw != null && raw.toString().trim().isNotEmpty) {
        _campaignId = raw.toString().trim();
      }
    }

    if (_campaignId == null) {
      _docRef = _db.collection('campaigns').doc(); // new id
      _loading = false;
      _baselineSig = _computeSig();
      _dirty = false;
      setState(() {});
      return;
    }

    _docRef = _db.collection('campaigns').doc(_campaignId);
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetUrlCtrl.dispose();
    _bannerUrlCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await _docRef.get();
      final data = snap.data();
      if (data == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('找不到活動資料（可能已被刪除）')));
        return;
      }

      _enabled = (data['enabled'] as bool?) ?? true;
      _priority = _asInt(data['priority'], 10).clamp(0, 9999);

      final type = (data['type'] ?? 'coupon').toString();
      _type = _typeOptions.containsKey(type) ? type : 'coupon';

      _titleCtrl.text = (data['title'] ?? '').toString();
      _targetUrlCtrl.text = (data['targetUrl'] ?? '').toString();
      _bannerUrlCtrl.text = (data['bannerImageUrl'] ?? '').toString();
      _descriptionCtrl.text = (data['description'] ?? '').toString();

      _startAt = _asDateTime(data['startAt']);
      _endAt = _asDateTime(data['endAt']);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _baselineSig = _computeSig();
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('載入失敗：$e')));
    }
  }

  int _asInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.round();
    return fallback;
  }

  DateTime? _asDateTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _computeSig() {
    return jsonEncode(<String, dynamic>{
      'enabled': _enabled,
      'priority': _priority,
      'type': _type,
      'title': _titleCtrl.text.trim(),
      'targetUrl': _targetUrlCtrl.text.trim(),
      'bannerImageUrl': _bannerUrlCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim(),
      'startAt': _startAt?.millisecondsSinceEpoch,
      'endAt': _endAt?.millisecondsSinceEpoch,
    });
  }

  void _markDirty() {
    final sig = _computeSig();
    if (!mounted) return;
    setState(() => _dirty = sig != _baselineSig);
  }

  // ✅✅✅ 修正點：await 之後再使用 context 前，一律 mounted 檢查
  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final init = isStart ? (_startAt ?? now) : (_endAt ?? now);

    final date = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );

    // ✅ await 後先確認 mounted（下一步還要用 context）
    if (!mounted) return;
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(init),
    );

    // ✅ await 後再確認 mounted（下一步會 setState）
    if (!mounted) return;
    if (time == null) return;

    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _startAt = dt;
      } else {
        _endAt = dt;
      }
    });
    _markDirty();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_startAt != null && _endAt != null && _endAt!.isBefore(_startAt!)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('結束時間不可早於開始時間')));
      return;
    }

    setState(() => _saving = true);

    try {
      final now = FieldValue.serverTimestamp();

      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'type': _type,
        'enabled': _enabled,
        'priority': _priority,
        'targetUrl': _targetUrlCtrl.text.trim(),
        'bannerImageUrl': _bannerUrlCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'startAt': _startAt == null ? null : Timestamp.fromDate(_startAt!),
        'endAt': _endAt == null ? null : Timestamp.fromDate(_endAt!),
        'updatedAt': now,
      };

      final snap = await _docRef.get();
      if (!snap.exists) {
        payload['createdAt'] = now;
      }

      await _docRef.set(payload, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _saving = false;
        _campaignId ??= _docRef.id;
        _baselineSig = _computeSig();
        _dirty = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存活動設定')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    }
  }

  Future<void> _delete() async {
    if (_campaignId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除活動'),
        content: Text(
          '確定要刪除「${_titleCtrl.text.trim().isEmpty ? '此活動' : _titleCtrl.text.trim()}」？此動作無法復原。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (ok != true) return;

    setState(() => _saving = true);

    try {
      await _docRef.delete();

      if (!mounted) return;
      setState(() => _saving = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除活動')));

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  Future<void> _confirmDiscardAndPop() async {
    if (!_dirty || _saving) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('尚未儲存'),
        content: const Text('你有未儲存的變更，確定要放棄並離開嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('放棄'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (ok != true) return;

    Navigator.of(context).pop();
  }

  void _onPopInvokedWithResult(bool didPop, Object? result) {
    if (didPop) return;
    _confirmDiscardAndPop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: ScaffoldWithDrawer(
        title: _campaignId == null ? '新增活動' : '編輯活動',
        currentRoute: AdminCampaignEditPage.routeName,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                onChanged: _markDirty,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _actionBar(context),
                    const SizedBox(height: 12),
                    _section(
                      title: '基本資訊',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(
                              labelText: '活動標題',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if ((v ?? '').trim().isEmpty) return '活動標題不可空白';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: ValueKey('type_$_type'),
                            initialValue: _type,
                            decoration: const InputDecoration(
                              labelText: '活動類型',
                              border: OutlineInputBorder(),
                            ),
                            items: _typeOptions.entries
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value),
                                  ),
                                )
                                .toList(),
                            onChanged: _saving
                                ? null
                                : (v) {
                                    if (v == null) return;
                                    setState(() => _type = v);
                                    _markDirty();
                                  },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _enabled,
                                  onChanged: _saving
                                      ? null
                                      : (v) {
                                          setState(() => _enabled = v);
                                          _markDirty();
                                        },
                                  title: const Text('啟用活動'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 220,
                                child: TextFormField(
                                  initialValue: _priority.toString(),
                                  decoration: const InputDecoration(
                                    labelText: '優先序（越大越前）',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    final n = int.tryParse((v ?? '').trim());
                                    if (n == null) return '請輸入數字';
                                    if (n < 0 || n > 9999) return '範圍 0~9999';
                                    return null;
                                  },
                                  onChanged: (v) {
                                    final n = int.tryParse(v.trim());
                                    if (n == null) return;
                                    _priority = n.clamp(0, 9999);
                                    _markDirty();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _section(
                      title: '活動時間（可空）',
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _dateTile(
                                  label: '開始時間',
                                  value: _startAt,
                                  onTap: _saving
                                      ? null
                                      : () => _pickDateTime(isStart: true),
                                  onClear: _saving
                                      ? null
                                      : () {
                                          setState(() => _startAt = null);
                                          _markDirty();
                                        },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _dateTile(
                                  label: '結束時間',
                                  value: _endAt,
                                  onTap: _saving
                                      ? null
                                      : () => _pickDateTime(isStart: false),
                                  onClear: _saving
                                      ? null
                                      : () {
                                          setState(() => _endAt = null);
                                          _markDirty();
                                        },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '提示：前台可用 startAt/endAt 判斷是否顯示活動。',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _section(
                      title: '連結與素材（可空）',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _targetUrlCtrl,
                            decoration: const InputDecoration(
                              labelText: '跳轉連結（targetUrl）',
                              hintText: 'https://...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _bannerUrlCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Banner 圖片 URL（bannerImageUrl）',
                              hintText: 'https://...jpg/png',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _section(
                      title: '活動說明（可空）',
                      child: TextFormField(
                        controller: _descriptionCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: '描述（description）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: _alpha(cs.surfaceContainerHighest, 0.55),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '目前 Doc：campaigns/${_docRef.id}\n狀態：${_dirty ? "未儲存" : "已同步"}',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _actionBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _campaignId == null ? '新增活動' : '編輯活動',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dirty ? '尚未儲存' : '已同步',
                    style: TextStyle(
                      fontSize: 12,
                      color: _dirty ? Colors.orange : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_campaignId != null)
              IconButton(
                tooltip: '刪除',
                onPressed: _saving ? null : _delete,
                icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
              ),
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: (_dirty && !_saving) ? _save : null,
              icon: _saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Icon(Icons.save),
              label: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime? value,
    required VoidCallback? onTap,
    required VoidCallback? onClear,
  }) {
    final text = value == null
        ? '未設定'
        : '${value.year.toString().padLeft(4, "0")}-'
              '${value.month.toString().padLeft(2, "0")}-'
              '${value.day.toString().padLeft(2, "0")} '
              '${value.hour.toString().padLeft(2, "0")}:'
              '${value.minute.toString().padLeft(2, "0")}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(text),
                ],
              ),
            ),
            if (value != null)
              IconButton(
                tooltip: '清除',
                onPressed: onClear,
                icon: const Icon(Icons.clear),
              )
            else
              const Icon(Icons.calendar_month_outlined),
          ],
        ),
      ),
    );
  }
}
