// lib/pages/admin_campaign_prizes_page.dart
//
// ✅ AdminCampaignPrizesPage（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// - ✅ 修正 use_build_context_synchronously：避免使用「builder 的 context」跨 async gap
//   → 一律用 State.context + mounted 檢查，或先抓 messenger 再 await
// - ✅ 包含 _ErrorView，修正 undefined_method
// - Firestore: campaigns/{campaignId}/prizes/{prizeId}
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminCampaignPrizesPage extends StatefulWidget {
  const AdminCampaignPrizesPage({
    super.key,
    required this.campaignId,
    this.campaignTitle,
  });

  final String campaignId;
  final String? campaignTitle;

  @override
  State<AdminCampaignPrizesPage> createState() =>
      _AdminCampaignPrizesPageState();
}

class _AdminCampaignPrizesPageState extends State<AdminCampaignPrizesPage> {
  DocumentReference<Map<String, dynamic>> get _campaignRef =>
      FirebaseFirestore.instance.collection('campaigns').doc(widget.campaignId);

  CollectionReference<Map<String, dynamic>> get _prizesRef =>
      _campaignRef.collection('prizes');

  final _searchCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _match(String q, String id, Map<String, dynamic> m) {
    if (q.isEmpty) return true;
    final s = q.toLowerCase();
    final title = (m['title'] ?? '').toString().toLowerCase();
    final desc = (m['description'] ?? '').toString().toLowerCase();
    final type = (m['type'] ?? '').toString().toLowerCase();
    return id.toLowerCase().contains(s) ||
        title.contains(s) ||
        desc.contains(s) ||
        type.contains(s);
  }

  Future<void> _openEditor({
    String? prizeId,
    Map<String, dynamic>? initial,
    int? nextSort,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    final res = await showModalBottomSheet<_PrizeEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PrizeEditorSheet(
        campaignId: widget.campaignId,
        prizeId: prizeId,
        initial: initial,
        nextSort: nextSort,
      ),
    );

    if (res == null) return;

    setState(() => _busy = true);
    try {
      if (prizeId == null) {
        await _prizesRef.add({
          ...res.payload,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('已新增獎項')));
      } else {
        await _prizesRef.doc(prizeId).set({
          ...res.payload,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('已更新獎項')));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('保存失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePrize(String prizeId) async {
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除獎項'),
        content: Text('確定要刪除 prize=$prizeId 嗎？'),
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
      await _prizesRef.doc(prizeId).delete();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('已刪除獎項')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleEnabled(String prizeId, bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _prizesRef.doc(prizeId).set({
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  Future<void> _applyReorder(
    List<_PrizeRow> rows,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = rows.removeAt(oldIndex);
    rows.insert(newIndex, moved);

    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < rows.length; i++) {
      final sort = i * 10;
      batch.set(_prizesRef.doc(rows[i].id), {
        'sort': sort,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        (widget.campaignTitle == null || widget.campaignTitle!.trim().isEmpty)
        ? '活動獎項'
        : '活動獎項：${widget.campaignTitle}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: '新增獎項',
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
                hintText: '搜尋：title / type / description / id',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  tooltip: '清除',
                  onPressed: () {
                    _searchCtrl.clear();
                    FocusScope.of(context).unfocus();
                    (context as Element).markNeedsBuild();
                  },
                  icon: const Icon(Icons.clear),
                ),
              ),
              onChanged: (_) => (context as Element).markNeedsBuild(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _prizesRef.orderBy('sort').snapshots(),
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return _ErrorView(message: '讀取 prizes 失敗：${snap.error}');
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final q = _searchCtrl.text.trim();
                final docs = snap.data!.docs;

                final rows = <_PrizeRow>[];
                int maxSort = 0;

                for (final d in docs) {
                  final m = d.data();
                  final sort = _toInt(m['sort'], fallback: 0);
                  if (sort > maxSort) maxSort = sort;
                  if (_match(q, d.id, m)) {
                    rows.add(_PrizeRow(id: d.id, data: m));
                  }
                }

                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      '沒有獎項（或搜尋結果為空）',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  );
                }

                final reorderList = rows.toList();

                return ReorderableListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: reorderList.length,
                  onReorder: _busy
                      ? (_, __) {}
                      : (oldIndex, newIndex) async {
                          final messenger = ScaffoldMessenger.of(this.context);

                          setState(() => _busy = true);
                          try {
                            await _applyReorder(
                              reorderList,
                              oldIndex,
                              newIndex,
                            );
                          } catch (e) {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text('排序更新失敗：$e')),
                            );
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  itemBuilder: (ctx2, i) {
                    final r = reorderList[i];
                    final m = r.data;

                    final enabled = m['enabled'] != false;
                    final t = (m['title'] ?? '').toString().trim();
                    final type = (m['type'] ?? 'custom').toString().trim();
                    final qty = _toInt(m['quantity'], fallback: 0);
                    final rem = _toInt(m['remaining'], fallback: qty);
                    final prob = _toDouble(m['probability'], fallback: 0);
                    final value = m['value'];

                    return Card(
                      key: ValueKey(r.id),
                      elevation: 0.6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_handle),
                        ),
                        title: Text(
                          t.isEmpty ? '(未命名獎項)' : t,
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
                                  label: Text(type),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.inventory_2,
                                    size: 16,
                                  ),
                                  label: Text('剩餘 $rem / $qty'),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.percent, size: 16),
                                  label: Text('prob $prob'),
                                ),
                                if (value != null)
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    avatar: const Icon(Icons.tune, size: 16),
                                    label: Text('value $value'),
                                  ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.key, size: 16),
                                  label: Text(r.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: SizedBox(
                          width: 150,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Switch(
                                value: enabled,
                                onChanged: _busy
                                    ? null
                                    : (v) => _toggleEnabled(r.id, v),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                children: [
                                  IconButton(
                                    tooltip: '編輯',
                                    onPressed: _busy
                                        ? null
                                        : () => _openEditor(
                                            prizeId: r.id,
                                            initial: m,
                                            nextSort: maxSort + 10,
                                          ),
                                    icon: const Icon(Icons.edit),
                                  ),
                                  IconButton(
                                    tooltip: '刪除',
                                    onPressed: _busy
                                        ? null
                                        : () => _deletePrize(r.id),
                                    icon: const Icon(Icons.delete),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        onTap: _busy
                            ? null
                            : () => _openEditor(
                                prizeId: r.id,
                                initial: m,
                                nextSort: maxSort + 10,
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('新增獎項'),
      ),
    );
  }
}

class _PrizeRow {
  const _PrizeRow({required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;
}

class _PrizeEditResult {
  const _PrizeEditResult(this.payload);
  final Map<String, dynamic> payload;
}

class _PrizeEditorSheet extends StatefulWidget {
  const _PrizeEditorSheet({
    required this.campaignId,
    required this.prizeId,
    required this.initial,
    required this.nextSort,
  });

  final String campaignId;
  final String? prizeId;
  final Map<String, dynamic>? initial;
  final int? nextSort;

  @override
  State<_PrizeEditorSheet> createState() => _PrizeEditorSheetState();
}

class _PrizeEditorSheetState extends State<_PrizeEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _imageUrl;
  late final TextEditingController _type;
  late final TextEditingController _value;
  late final TextEditingController _quantity;
  late final TextEditingController _remaining;
  late final TextEditingController _prob;
  late final TextEditingController _sort;

  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    final m = widget.initial ?? <String, dynamic>{};

    _title = TextEditingController(text: (m['title'] ?? '').toString());
    _desc = TextEditingController(text: (m['description'] ?? '').toString());
    _imageUrl = TextEditingController(text: (m['imageUrl'] ?? '').toString());
    _type = TextEditingController(text: (m['type'] ?? 'custom').toString());
    _value = TextEditingController(text: (m['value'] ?? '').toString());

    final qty = _toInt(m['quantity'], fallback: 0);
    final rem = _toInt(m['remaining'], fallback: qty);

    _quantity = TextEditingController(text: qty.toString());
    _remaining = TextEditingController(text: rem.toString());
    _prob = TextEditingController(
      text: _toDouble(m['probability'], fallback: 0).toString(),
    );

    final sort = m.containsKey('sort')
        ? _toInt(m['sort'], fallback: 0)
        : (widget.nextSort ?? 0);
    _sort = TextEditingController(text: sort.toString());

    _enabled = m['enabled'] != false;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _imageUrl.dispose();
    _type.dispose();
    _value.dispose();
    _quantity.dispose();
    _remaining.dispose();
    _prob.dispose();
    _sort.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final qty = int.tryParse(_quantity.text.trim()) ?? 0;
    final rem = int.tryParse(_remaining.text.trim()) ?? qty;
    final prob = double.tryParse(_prob.text.trim()) ?? 0;
    final sort = int.tryParse(_sort.text.trim()) ?? 0;

    final payload = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'imageUrl': _imageUrl.text.trim(),
      'type': _type.text.trim().isEmpty ? 'custom' : _type.text.trim(),
      'enabled': _enabled,
      'quantity': qty,
      'remaining': rem,
      'probability': prob,
      'sort': sort,
    };

    final v = _value.text.trim();
    if (v.isNotEmpty) {
      final asInt = int.tryParse(v);
      final asDouble = double.tryParse(v);
      payload['value'] = asInt ?? asDouble ?? v;
    } else {
      payload['value'] = FieldValue.delete();
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
                  isCreate ? '新增獎項' : '編輯獎項',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!isCreate) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Prize ID: ${widget.prizeId}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
                const SizedBox(height: 14),

                _tf(_title, '獎項名稱（必填）', required: true),
                const SizedBox(height: 10),
                _tf(_type, 'type（例如 coupon/points/product/custom）'),
                const SizedBox(height: 10),
                _tf(_value, 'value（點數/折扣額/自定義）'),
                const SizedBox(height: 10),
                _tf(_desc, 'description（可空）', maxLines: 3),
                const SizedBox(height: 10),
                _tf(_imageUrl, 'imageUrl（可空）'),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _tf(
                        _quantity,
                        'quantity（總量）',
                        keyboard: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _tf(
                        _remaining,
                        'remaining（剩餘）',
                        keyboard: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _tf(
                        _prob,
                        'probability（機率/權重）',
                        keyboard: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _tf(
                        _sort,
                        'sort（排序）',
                        keyboard: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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

  Widget _tf(
    TextEditingController c,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboard,
  }) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (v) => (v ?? '').trim().isEmpty ? '必填' : null
          : null,
    );
  }
}

// ✅ 這個 class 必須存在，否則你就會看到你剛剛的 undefined_method
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(message, style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}

// helpers
int _toInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

double _toDouble(dynamic v, {double fallback = 0}) {
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? fallback;
  return fallback;
}
