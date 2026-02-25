import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAutoCampaignEditPage extends StatefulWidget {
  const AdminAutoCampaignEditPage({
    super.key,
    this.campaignId,
    this.collectionName = 'auto_campaigns',
  });

  final String? campaignId;
  final String collectionName;

  @override
  State<AdminAutoCampaignEditPage> createState() =>
      _AdminAutoCampaignEditPageState();
}

class _AdminAutoCampaignEditPageState extends State<AdminAutoCampaignEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final DocumentReference<Map<String, dynamic>> _ref;

  bool _loading = true;
  String? _loadError;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _segment = 'all';
  String _channel = 'push';
  bool _enabled = true;

  DateTime? _startAt;
  DateTime? _endAt;
  final _cronCtrl = TextEditingController(text: '0 9 * * *');
  final _timezoneCtrl = TextEditingController(text: 'Asia/Taipei');

  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _deepLinkCtrl = TextEditingController(text: '/');

  final _minPointsCtrl = TextEditingController(text: '0');
  final _lastPurchaseDaysCtrl = TextEditingController(text: '0');
  final _minOrderAmountCtrl = TextEditingController(text: '0');

  static const _segments = <_Option>[
    _Option('all', '全部'),
    _Option('new', '新客'),
    _Option('active', '活躍'),
    _Option('vip', 'VIP'),
    _Option('churn_risk', '流失風險'),
    _Option('sleeping', '沉睡'),
  ];

  static const _channels = <_Option>[
    _Option('push', 'Push'),
    _Option('email', 'Email'),
    _Option('line', 'LINE'),
  ];

  bool get _isEdit =>
      widget.campaignId != null && widget.campaignId!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final col = FirebaseFirestore.instance.collection(widget.collectionName);
    _ref = _isEdit ? col.doc(widget.campaignId!.trim()) : col.doc();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _cronCtrl.dispose();
    _timezoneCtrl.dispose();
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _deepLinkCtrl.dispose();
    _minPointsCtrl.dispose();
    _lastPurchaseDaysCtrl.dispose();
    _minOrderAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      if (_isEdit) {
        final snap = await _ref.get();
        final data = snap.data();
        if (data == null) {
          throw StateError('找不到活動資料：${_ref.id}');
        }
        _applyData(data);
      } else {
        _startAt = DateTime.now().add(const Duration(minutes: 5));
        _endAt = null;
      }
    } catch (e) {
      _loadError = e.toString();
    } finally {
      // ✅ FIX: 不在 finally 用 return
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyData(Map<String, dynamic> d) {
    _nameCtrl.text = (d['name'] ?? '').toString();
    _descCtrl.text = (d['description'] ?? '').toString();
    _enabled = d['enabled'] == true;

    _segment = (d['segment'] ?? 'all').toString();
    if (!_segments.any((e) => e.value == _segment)) _segment = 'all';

    _channel = (d['channel'] ?? 'push').toString();
    if (!_channels.any((e) => e.value == _channel)) _channel = 'push';

    final schedule = (d['schedule'] is Map)
        ? Map<String, dynamic>.from(d['schedule'])
        : <String, dynamic>{};
    _startAt = _asDateTime(schedule['startAt']);
    _endAt = _asDateTime(schedule['endAt']);
    _cronCtrl.text = (schedule['cron'] ?? _cronCtrl.text).toString();
    _timezoneCtrl.text = (schedule['timezone'] ?? _timezoneCtrl.text)
        .toString();

    final template = (d['template'] is Map)
        ? Map<String, dynamic>.from(d['template'])
        : <String, dynamic>{};
    _titleCtrl.text = (template['title'] ?? '').toString();
    _messageCtrl.text = (template['message'] ?? '').toString();
    _deepLinkCtrl.text = (template['deepLink'] ?? '/').toString();

    final rules = (d['rules'] is Map)
        ? Map<String, dynamic>.from(d['rules'])
        : <String, dynamic>{};
    _minPointsCtrl.text = (rules['minPoints'] ?? 0).toString();
    _lastPurchaseDaysCtrl.text = (rules['lastPurchaseDays'] ?? 0).toString();
    _minOrderAmountCtrl.text = (rules['minOrderAmount'] ?? 0).toString();
  }

  DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  int _asInt(String s) => int.tryParse(s.trim()) ?? 0;
  double _asDouble(String s) => double.tryParse(s.trim()) ?? 0.0;

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final base = (isStart ? _startAt : _endAt) ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    if (!mounted) return;

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
  }

  String _fmtDateTime(DateTime? dt) {
    if (dt == null) return '未設定';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'enabled': _enabled,
      'segment': _segment,
      'channel': _channel,
      'schedule': {
        'startAt': _startAt == null ? null : Timestamp.fromDate(_startAt!),
        'endAt': _endAt == null ? null : Timestamp.fromDate(_endAt!),
        'cron': _cronCtrl.text.trim(),
        'timezone': _timezoneCtrl.text.trim(),
      },
      'template': {
        'title': _titleCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
        'deepLink': _deepLinkCtrl.text.trim(),
      },
      'rules': {
        'minPoints': _asInt(_minPointsCtrl.text),
        'lastPurchaseDays': _asInt(_lastPurchaseDaysCtrl.text),
        'minOrderAmount': _asDouble(_minOrderAmountCtrl.text),
      },
    };
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      await _ref.set({
        ..._buildPayload(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (!_isEdit) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(_isEdit ? '已更新活動' : '已新增活動（ID：${_ref.id}）')),
      );

      if (!_isEdit) setState(() {});
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    }
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!_isEdit) {
      navigator.pop();
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('刪除活動'),
        content: Text(
          '確定要刪除「${_nameCtrl.text.trim().isEmpty ? _ref.id : _nameCtrl.text.trim()}」？此操作不可復原。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _ref.delete();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('已刪除')));
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? '編輯自動行銷活動' : '新增自動行銷活動';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: '儲存',
            onPressed: _loading ? null : _save,
            icon: const Icon(Icons.save),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _ErrorView(message: '載入失敗：$_loadError', onRetry: _load)
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _idCard(),
                  const SizedBox(height: 12),
                  _basicCard(),
                  const SizedBox(height: 12),
                  _targetCard(),
                  const SizedBox(height: 12),
                  _scheduleCard(),
                  const SizedBox(height: 12),
                  _templateCard(),
                  const SizedBox(height: 12),
                  _rulesCard(),
                  const SizedBox(height: 16),
                  _bottomActions(),
                ],
              ),
            ),
    );
  }

  Widget _idCard() {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: const Text('Campaign ID'),
        subtitle: Text(_ref.id),
        trailing: Switch(
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
      ),
    );
  }

  Widget _basicCard() {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('基本資訊', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '活動名稱',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return '請輸入活動名稱';
                if (s.length < 2) return '名稱太短';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: '活動描述（可空）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _targetCard() {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('分眾與渠道', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    // ✅ 若你版本也把 value 標 deprecated，改 initialValue
                    initialValue: _segment,
                    items: _segments
                        .map(
                          (o) => DropdownMenuItem(
                            value: o.value,
                            child: Text(o.label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _segment = v ?? _segment),
                    decoration: const InputDecoration(
                      labelText: '分眾 Segment',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _channel,
                    items: _channels
                        .map(
                          (o) => DropdownMenuItem(
                            value: o.value,
                            child: Text(o.label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _channel = v ?? _channel),
                    decoration: const InputDecoration(
                      labelText: '渠道 Channel',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduleCard() {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('排程', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _dtTile(
                    label: '開始時間',
                    value: _fmtDateTime(_startAt),
                    onPick: () => _pickDateTime(isStart: true),
                    onClear: () => setState(() => _startAt = null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dtTile(
                    label: '結束時間（可空）',
                    value: _fmtDateTime(_endAt),
                    onPick: () => _pickDateTime(isStart: false),
                    onClear: () => setState(() => _endAt = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cronCtrl,
              decoration: const InputDecoration(
                labelText: 'Cron（例：0 9 * * *）',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  ((v ?? '').trim().isEmpty) ? '請輸入 cron（或填預設）' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _timezoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Timezone（例：Asia/Taipei）',
                border: OutlineInputBorder(),
              ),
              validator: (v) => ((v ?? '').trim().isEmpty) ? '請輸入時區' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dtTile({
    required String label,
    required String value,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: Colors.grey[800])),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.calendar_month),
                label: const Text('選擇'),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: onClear, child: const Text('清除')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _templateCard() {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('訊息模板', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: '標題（可空）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _messageCtrl,
              decoration: const InputDecoration(
                labelText: '內容 Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (v) => ((v ?? '').trim().isEmpty) ? '請輸入訊息內容' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _deepLinkCtrl,
              decoration: const InputDecoration(
                labelText: 'Deep Link（例：/campaign/xxx）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rulesCard() {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '觸發規則（Rules）',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minPointsCtrl,
                    decoration: const InputDecoration(
                      labelText: '最低點數 minPoints',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastPurchaseDaysCtrl,
                    decoration: const InputDecoration(
                      labelText: '距上次購買天數 lastPurchaseDays',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minOrderAmountCtrl,
              decoration: const InputDecoration(
                labelText: '最低訂單金額 minOrderAmount',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomActions() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('儲存'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _delete,
            icon: Icon(_isEdit ? Icons.delete : Icons.close),
            label: Text(_isEdit ? '刪除' : '取消'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _isEdit ? Colors.red : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重試'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Option {
  final String value;
  final String label;
  const _Option(this.value, this.label);
}
