// lib/pages/admin/marketing/admin_lottery_edit_page.dart
//
// ✅ AdminLotteryEditPage（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// ✅ 修正：移除 finally 內 return（避免 control_flow_in_finally）
// ✅ Firestore collection: lotteries（可透過 constructor 調整）
//
// 文件欄位（建議）：
// - title            String
// - description      String
// - enabled          bool
// - startAt          Timestamp?
// - endAt            Timestamp?
// - costPoints       int           (抽一次成本點數，可選)
// - minOrderAmount   double        (門檻金額，可選)
// - prizes           List<Map>     (獎品清單)
//    prize item 欄位建議：
//    - name           String
//    - imageUrl       String
//    - stock          int
//    - weight         double       (權重，越大越容易中)
//    - value          double       (獎品價值/折抵金額，可選)
//    - active         bool
// - createdAt        Timestamp
// - updatedAt        Timestamp
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminLotteryEditPage extends StatefulWidget {
  const AdminLotteryEditPage({
    super.key,
    this.lotteryId,
    this.collectionName = 'lotteries',
  });

  /// null => 新增；有值 => 編輯
  final String? lotteryId;

  /// 依你的 Firestore 命名調整
  final String collectionName;

  @override
  State<AdminLotteryEditPage> createState() => _AdminLotteryEditPageState();
}

class _AdminLotteryEditPageState extends State<AdminLotteryEditPage> {
  final _formKey = GlobalKey<FormState>();

  late final DocumentReference<Map<String, dynamic>> _ref;

  bool _loading = true;
  String? _loadError;

  // ---- basic fields
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _enabled = true;
  DateTime? _startAt;
  DateTime? _endAt;

  final _costPointsCtrl = TextEditingController(text: '0');
  final _minOrderAmountCtrl = TextEditingController(text: '0');

  // ---- prizes
  final List<_PrizeDraft> _prizes = [];

  bool get _isEdit => (widget.lotteryId ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final col = FirebaseFirestore.instance.collection(widget.collectionName);
    _ref = _isEdit ? col.doc(widget.lotteryId!.trim()) : col.doc();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _costPointsCtrl.dispose();
    _minOrderAmountCtrl.dispose();
    for (final p in _prizes) {
      p.dispose();
    }
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
        if (data == null) throw StateError('找不到抽獎活動：${_ref.id}');
        _applyData(data);
      } else {
        // create default
        _enabled = true;
        _startAt = DateTime.now();
        _endAt = null;
        _prizes.clear();
        _prizes.add(_PrizeDraft.defaults());
      }
    } catch (e) {
      _loadError = e.toString();
    } finally {
      // ✅ FIX: finally 內不能 return（避免 control_flow_in_finally）
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyData(Map<String, dynamic> d) {
    _titleCtrl.text = (d['title'] ?? d['name'] ?? '').toString();
    _descCtrl.text = (d['description'] ?? d['desc'] ?? '').toString();
    _enabled = d['enabled'] == true;

    _startAt = _asDateTime(d['startAt'] ?? d['start_at']);
    _endAt = _asDateTime(d['endAt'] ?? d['end_at']);

    _costPointsCtrl.text = _asInt(
      d['costPoints'] ?? d['cost_points'],
    ).toString();
    _minOrderAmountCtrl.text = _asDouble(
      d['minOrderAmount'] ?? d['min_order_amount'],
    ).toString();

    // prizes
    for (final p in _prizes) {
      p.dispose();
    }
    _prizes.clear();

    final rawPrizes = d['prizes'];
    if (rawPrizes is List) {
      for (final item in rawPrizes) {
        final m = _asMap(item);
        _prizes.add(_PrizeDraft.fromMap(m));
      }
    }

    if (_prizes.isEmpty) {
      _prizes.add(_PrizeDraft.defaults());
    }
  }

  // ---------- helpers (no casts) ----------
  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  DateTime? _asDateTime(dynamic v) {
    try {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
    } catch (_) {}
    return null;
  }

  int _asInt(dynamic v) {
    try {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim()) ?? 0;
    } catch (_) {}
    return 0;
  }

  double _asDouble(dynamic v) {
    try {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    } catch (_) {}
    return 0.0;
  }

  int _parseIntCtrl(TextEditingController c) =>
      int.tryParse(c.text.trim()) ?? 0;
  double _parseDoubleCtrl(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0.0;

  String _fmtDateTime(DateTime? dt) {
    if (dt == null) return '未設定';
    String two(int x) => x.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final base = (isStart ? _startAt : _endAt) ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !mounted) return;

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

  // ---------- actions ----------
  void _addPrize() {
    setState(() => _prizes.add(_PrizeDraft.defaults()));
  }

  void _removePrize(int i) {
    if (_prizes.length <= 1) return;
    setState(() {
      _prizes[i].dispose();
      _prizes.removeAt(i);
    });
  }

  void _movePrize(int from, int to) {
    if (from == to) return;
    setState(() {
      final item = _prizes.removeAt(from);
      _prizes.insert(to, item);
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final title = _titleCtrl.text.trim();
    final payload = <String, dynamic>{
      'title': title,
      'description': _descCtrl.text.trim(),
      'enabled': _enabled,
      'startAt': _startAt == null ? null : Timestamp.fromDate(_startAt!),
      'endAt': _endAt == null ? null : Timestamp.fromDate(_endAt!),
      'costPoints': _parseIntCtrl(_costPointsCtrl),
      'minOrderAmount': _parseDoubleCtrl(_minOrderAmountCtrl),
      'prizes': _prizes.map((p) => p.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (!_isEdit) 'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await _ref.set(payload, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? '已更新抽獎活動' : '已新增抽獎活動（ID：${_ref.id}）')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    }
  }

  Future<void> _delete() async {
    if (!_isEdit) {
      Navigator.pop(context);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除抽獎活動'),
        content: Text(
          '確定要刪除「${_titleCtrl.text.trim().isEmpty ? _ref.id : _titleCtrl.text.trim()}」？此操作不可復原。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final pageTitle = _isEdit ? '編輯抽獎活動' : '新增抽獎活動';

    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
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
                  _scheduleCard(),
                  const SizedBox(height: 12),
                  _rulesCard(),
                  const SizedBox(height: 12),
                  _prizesCard(),
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
        title: const Text('Lottery ID'),
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
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: '標題',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return '請輸入標題';
                if (s.length < 2) return '標題太短';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: '描述（可空）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
            const Text('活動期間', style: TextStyle(fontWeight: FontWeight.w800)),
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
              '成本 / 門檻',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _costPointsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '抽一次成本點數（costPoints）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minOrderAmountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '最低訂單金額門檻（minOrderAmount）',
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

  Widget _prizesCard() {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '獎品清單',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _addPrize,
                  icon: const Icon(Icons.add),
                  label: const Text('新增獎品'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _prizes.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                _movePrize(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final p = _prizes[index];
                return _PrizeEditorCard(
                  key: ValueKey('prize_$index'),
                  index: index,
                  total: _prizes.length,
                  prize: p,
                  canRemove: _prizes.length > 1,
                  onRemove: () => _removePrize(index),
                );
              },
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

// ------------------------------------------------------------
// Prize Draft + UI
// ------------------------------------------------------------

class _PrizeDraft {
  _PrizeDraft({
    required this.nameCtrl,
    required this.imageUrlCtrl,
    required this.stockCtrl,
    required this.weightCtrl,
    required this.valueCtrl,
    required this.active,
  });

  final TextEditingController nameCtrl;
  final TextEditingController imageUrlCtrl;
  final TextEditingController stockCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController valueCtrl;
  bool active;

  factory _PrizeDraft.defaults() => _PrizeDraft(
    nameCtrl: TextEditingController(text: '獎品'),
    imageUrlCtrl: TextEditingController(text: ''),
    stockCtrl: TextEditingController(text: '0'),
    weightCtrl: TextEditingController(text: '1'),
    valueCtrl: TextEditingController(text: '0'),
    active: true,
  );

  factory _PrizeDraft.fromMap(Map<String, dynamic> m) {
    int asInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim()) ?? 0;
      return 0;
    }

    double asDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim()) ?? 0.0;
      return 0.0;
    }

    return _PrizeDraft(
      nameCtrl: TextEditingController(text: (m['name'] ?? '').toString()),
      imageUrlCtrl: TextEditingController(
        text: (m['imageUrl'] ?? m['image_url'] ?? '').toString(),
      ),
      stockCtrl: TextEditingController(
        text: asInt(m['stock'] ?? m['qty'] ?? m['quantity']).toString(),
      ),
      weightCtrl: TextEditingController(
        text: asDouble(m['weight'] ?? m['prob'] ?? m['odds']).toString(),
      ),
      valueCtrl: TextEditingController(
        text: asDouble(m['value'] ?? m['amount']).toString(),
      ),
      active: m['active'] == true ? true : (m['enabled'] == true),
    );
  }

  Map<String, dynamic> toMap() {
    int i(String s) => int.tryParse(s.trim()) ?? 0;
    double d(String s) => double.tryParse(s.trim()) ?? 0.0;

    return {
      'name': nameCtrl.text.trim(),
      'imageUrl': imageUrlCtrl.text.trim(),
      'stock': i(stockCtrl.text),
      'weight': d(weightCtrl.text),
      'value': d(valueCtrl.text),
      'active': active,
    };
  }

  void dispose() {
    nameCtrl.dispose();
    imageUrlCtrl.dispose();
    stockCtrl.dispose();
    weightCtrl.dispose();
    valueCtrl.dispose();
  }
}

class _PrizeEditorCard extends StatelessWidget {
  const _PrizeEditorCard({
    super.key,
    required this.index,
    required this.total,
    required this.prize,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final int total;
  final _PrizeDraft prize;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '獎品 ${index + 1} / $total',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                // ⚠️ Switch 在 Stateless 內不建議這樣做（你原本寫法也不會真的改 active）
                // 這裡保留不造成錯誤：改用 Checkbox 下面那個來改 active
                Switch(
                  value: prize.active,
                  onChanged: (_) => (context as Element).markNeedsBuild(),
                ),
                const SizedBox(width: 6),
                if (canRemove)
                  IconButton(
                    tooltip: '刪除獎品',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete, color: Colors.red),
                  ),
                const Icon(Icons.drag_handle),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: prize.nameCtrl,
              decoration: const InputDecoration(
                labelText: '獎品名稱（name）',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return '請輸入獎品名稱';
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: prize.imageUrlCtrl,
              decoration: const InputDecoration(
                labelText: '圖片 URL（imageUrl，可空）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: prize.stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '庫存（stock）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: prize.weightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '權重（weight）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: prize.valueCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '價值（value）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: prize.active,
                  onChanged: (v) {
                    prize.active = v ?? true;
                    (context as Element).markNeedsBuild();
                  },
                ),
                const Text('啟用（active）'),
              ],
            ),
          ],
        ),
      ),
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
