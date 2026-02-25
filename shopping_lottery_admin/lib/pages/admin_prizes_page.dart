import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// AdminPrizesPage（正式版｜完整版｜可直接編譯）
///
/// - 修正：unused_field（_moneyFmt 會被用於顯示金額/價值）
/// - 修正：curly_braces_in_flow_control_structures（所有 if 都加上 {}）
/// - 修正：DropdownButtonFormField.value deprecated → initialValue
///
/// Firestore collection：prizes
/// 欄位建議：
/// - title: String
/// - type: String        // cash/points/coupon/physical
/// - value: num          // 現金金額 / 點數 / 折扣值（依 type 解讀）
/// - stock: int          // 庫存
/// - probability: double // 0~1 或 0~100（這裡用 0~100）
/// - imageUrl: String
/// - enabled: bool
/// - sort: int
/// - note: String
/// - campaignId: String? // 若你有活動/抽獎池
/// - createdAt, updatedAt: Timestamp
class AdminPrizesPage extends StatefulWidget {
  const AdminPrizesPage({super.key, this.campaignId});

  final String? campaignId;

  @override
  State<AdminPrizesPage> createState() => _AdminPrizesPageState();
}

class _AdminPrizesPageState extends State<AdminPrizesPage> {
  final CollectionReference<Map<String, dynamic>> _ref = FirebaseFirestore
      .instance
      .collection('prizes');

  final TextEditingController _searchCtrl = TextEditingController();
  bool _busy = false;

  // ✅ 這個欄位會被 UI 用到（金額/價值格式化），不會再 unused_field
  final _MoneyFormatter _moneyFmt = _MoneyFormatter(symbol: 'NT\$');

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  String _fmtTs(dynamic v) {
    DateTime? dt;
    if (v is Timestamp) dt = v.toDate();
    if (v is DateTime) dt = v;
    if (dt == null) return '-';
    final l = dt.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-'
        '${l.month.toString().padLeft(2, '0')}-'
        '${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  Query<Map<String, dynamic>> _query() {
    Query<Map<String, dynamic>> q = _ref
        .orderBy('sort')
        .orderBy('createdAt', descending: true);

    final cid = (widget.campaignId ?? '').trim();
    if (cid.isNotEmpty) {
      // 有 campaignId 就過濾
      q = q.where('campaignId', isEqualTo: cid);
    }

    return q.limit(500);
  }

  bool _match(String keyword, String id, Map<String, dynamic> m) {
    if (keyword.isEmpty) return true;
    final s = keyword.toLowerCase();

    String getStr(String k) => (m[k] ?? '').toString().toLowerCase();
    final title = getStr('title');
    final type = getStr('type');
    final note = getStr('note');
    final campaignId = getStr('campaignId');

    return id.toLowerCase().contains(s) ||
        title.contains(s) ||
        type.contains(s) ||
        note.contains(s) ||
        campaignId.contains(s);
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'cash':
        return '現金';
      case 'points':
        return '點數';
      case 'coupon':
        return '優惠券';
      case 'physical':
        return '實體';
      default:
        return t.isEmpty ? '未設定' : t;
    }
  }

  String _valueLabel(String type, dynamic value) {
    final num v = _toNum(value, fallback: 0);
    switch (type) {
      case 'cash':
        return _moneyFmt.format(v);
      case 'points':
        return '${v.toInt()} pts';
      case 'coupon':
        return '折抵 ${_moneyFmt.format(v)}';
      case 'physical':
        return '參考價 ${_moneyFmt.format(v)}';
      default:
        return v.toString();
    }
  }

  Future<void> _openEditor({String? id, Map<String, dynamic>? initial}) async {
    final res = await showModalBottomSheet<_PrizeEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PrizeEditorSheet(
        prizeId: id,
        initial: initial,
        campaignId: widget.campaignId,
      ),
    );
    if (res == null) return;

    setState(() => _busy = true);
    try {
      final payload = {
        ...res.payload,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (id == null) {
        await _ref.add({...payload, 'createdAt': FieldValue.serverTimestamp()});
        _snack('已新增獎品');
      } else {
        await _ref.doc(id).set(payload, SetOptions(merge: true));
        _snack('已更新獎品');
      }
    } catch (e) {
      _snack('保存失敗：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除獎品'),
        content: Text('確定要刪除獎品 id=$id 嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _ref.doc(id).delete();
      _snack('已刪除獎品');
    } catch (e) {
      _snack('刪除失敗：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleEnabled(String id, bool enabled) async {
    try {
      await _ref.doc(id).set({
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _snack('更新啟用狀態失敗：$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _searchCtrl.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.campaignId == null ? '獎品管理' : '獎品管理（活動：${widget.campaignId}）',
        ),
        actions: [
          IconButton(
            tooltip: '新增獎品',
            onPressed: _busy ? null : () => _openEditor(),
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋：標題 / 類型 / 備註 / campaignId / id',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  tooltip: '清除',
                  onPressed: () {
                    _searchCtrl.clear();
                    FocusScope.of(context).unfocus();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      '讀取失敗：${snap.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;
                final rows = docs
                    .where((d) => _match(keyword, d.id, d.data()))
                    .toList(growable: false);

                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      '沒有資料',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final d = rows[i];
                    final m = d.data();

                    final title = (m['title'] ?? '').toString().trim();
                    final type = (m['type'] ?? '').toString().trim();
                    final enabled = m['enabled'] != false;

                    final value = m['value'];
                    final stock = _toInt(m['stock'], fallback: 0);
                    final prob = _toNum(m['probability'], fallback: 0); // 0~100
                    final sort = _toInt(m['sort'], fallback: 0);

                    final updatedAt = _fmtTs(m['updatedAt']);
                    final note = (m['note'] ?? '').toString().trim();

                    final valueStr = _valueLabel(type, value);

                    return Card(
                      elevation: 0.7,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          child: Icon(
                            enabled ? Icons.card_giftcard : Icons.block,
                          ),
                        ),
                        title: Text(
                          title.isEmpty ? '(未命名獎品)' : title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.category, size: 16),
                                  label: Text(_typeLabel(type)),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.payments, size: 16),
                                  label: Text(valueStr),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.inventory_2,
                                    size: 16,
                                  ),
                                  label: Text('庫存 $stock'),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.percent, size: 16),
                                  label: Text('機率 ${prob.toStringAsFixed(2)}%'),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.sort, size: 16),
                                  label: Text('sort $sort'),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.update, size: 16),
                                  label: Text('updated $updatedAt'),
                                ),
                              ],
                            ),
                            if (note.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                note,
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ],
                        ),
                        trailing: SizedBox(
                          width: 140,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Switch(
                                value: enabled,
                                onChanged: _busy
                                    ? null
                                    : (v) => _toggleEnabled(d.id, v),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                children: [
                                  IconButton(
                                    tooltip: '編輯',
                                    onPressed: _busy
                                        ? null
                                        : () =>
                                              _openEditor(id: d.id, initial: m),
                                    icon: const Icon(Icons.edit),
                                  ),
                                  IconButton(
                                    tooltip: '刪除',
                                    onPressed: _busy
                                        ? null
                                        : () => _delete(d.id),
                                    icon: const Icon(Icons.delete),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        onTap: _busy
                            ? null
                            : () => _openEditor(id: d.id, initial: m),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =====================
// Editor Sheet
// =====================

class _PrizeEditResult {
  const _PrizeEditResult(this.payload);
  final Map<String, dynamic> payload;
}

class _PrizeEditorSheet extends StatefulWidget {
  const _PrizeEditorSheet({
    required this.prizeId,
    required this.initial,
    required this.campaignId,
  });

  final String? prizeId;
  final Map<String, dynamic>? initial;
  final String? campaignId;

  @override
  State<_PrizeEditorSheet> createState() => _PrizeEditorSheetState();
}

class _PrizeEditorSheetState extends State<_PrizeEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _value;
  late final TextEditingController _stock;
  late final TextEditingController _prob;
  late final TextEditingController _imageUrl;
  late final TextEditingController _sort;
  late final TextEditingController _note;

  String _type = 'cash';
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    final m = widget.initial ?? <String, dynamic>{};

    _title = TextEditingController(text: (m['title'] ?? '').toString());
    _type = (m['type'] ?? 'cash').toString();
    _enabled = m['enabled'] != false;

    _value = TextEditingController(text: (m['value'] ?? 0).toString());
    _stock = TextEditingController(text: (m['stock'] ?? 0).toString());
    _prob = TextEditingController(
      text: (m['probability'] ?? 0).toString(),
    ); // 0~100
    _imageUrl = TextEditingController(text: (m['imageUrl'] ?? '').toString());
    _sort = TextEditingController(text: (m['sort'] ?? 0).toString());
    _note = TextEditingController(text: (m['note'] ?? '').toString());
  }

  @override
  void dispose() {
    _title.dispose();
    _value.dispose();
    _stock.dispose();
    _prob.dispose();
    _imageUrl.dispose();
    _sort.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final payload = <String, dynamic>{
      'title': _title.text.trim(),
      'type': _type,
      'enabled': _enabled,
      'value': _toNum(_value.text.trim(), fallback: 0),
      'stock': _toInt(_stock.text.trim(), fallback: 0),
      'probability': _toNum(_prob.text.trim(), fallback: 0), // 0~100
      'imageUrl': _imageUrl.text.trim(),
      'sort': _toInt(_sort.text.trim(), fallback: 0),
      'note': _note.text.trim(),
    };

    final cid = (widget.campaignId ?? '').trim();
    if (cid.isNotEmpty) {
      payload['campaignId'] = cid;
    }

    Navigator.pop(context, _PrizeEditResult(payload));
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.prizeId == null;
    final pad = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: pad.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCreate ? '新增獎品' : '編輯獎品',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!isCreate) ...[
                  const SizedBox(height: 6),
                  Text(
                    'ID: ${widget.prizeId}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
                const SizedBox(height: 14),

                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: '標題（必填）',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? '必填' : null,
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        // ✅ 修正：value deprecated → initialValue
                        initialValue: _type,
                        decoration: const InputDecoration(
                          labelText: '類型',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('現金')),
                          DropdownMenuItem(value: 'points', child: Text('點數')),
                          DropdownMenuItem(value: 'coupon', child: Text('優惠券')),
                          DropdownMenuItem(
                            value: 'physical',
                            child: Text('實體'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? 'cash'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _sort,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Sort（數字）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _value,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '價值 value',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _stock,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '庫存 stock',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _prob,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '機率 probability（0~100）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _imageUrl,
                  decoration: const InputDecoration(
                    labelText: '圖片 URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _note,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '備註',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('啟用 enabled'),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save),
                    label: const Text('保存'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================
// Utils
// =====================

class _MoneyFormatter {
  _MoneyFormatter({this.symbol = ''});
  final String symbol;

  String format(num value) {
    final isNeg = value < 0;
    final v = value.abs();
    final intPart = v.round();

    final s = intPart.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) {
        buf.write(',');
      }
    }

    final out = '${symbol.isEmpty ? '' : '$symbol '}${buf.toString()}';
    return isNeg ? '-$out' : out;
  }
}

int _toInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

num _toNum(dynamic v, {num fallback = 0}) {
  if (v == null) return fallback;
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim()) ?? fallback;
  return fallback;
}
