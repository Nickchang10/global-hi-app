import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AdminLotteryEditPage extends StatefulWidget {
  final String? lotteryId;
  const AdminLotteryEditPage({super.key, this.lotteryId});

  @override
  State<AdminLotteryEditPage> createState() => _AdminLotteryEditPageState();
}

class _AdminLotteryEditPageState extends State<AdminLotteryEditPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _startAtCtrl = TextEditingController();
  final _endAtCtrl = TextEditingController();

  final List<Map<String, dynamic>> _prizes = [];

  bool _isActive = true;
  bool _loading = false;
  bool _isNew = true;

  int _participantCount = 0;
  int _winnerCount = 0;

  DateTime? _createdAt;
  DateTime? _updatedAt;

  bool _dirty = false;

  @override
  void initState() {
    super.initState();

    _titleCtrl.addListener(_markDirty);
    _descCtrl.addListener(_markDirty);
    _startAtCtrl.addListener(_markDirty);
    _endAtCtrl.addListener(_markDirty);

    if (widget.lotteryId != null && widget.lotteryId!.trim().isNotEmpty) {
      _isNew = false;
      _loadLottery();
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _startAtCtrl.dispose();
    _endAtCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLottery() async {
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('lotteries')
          .doc(widget.lotteryId)
          .get();

      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('找不到此抽獎活動（可能已被刪除）')),
        );
        context.go('/admin/lottery');
        return;
      }

      final data = doc.data()!;
      _titleCtrl.text = (data['title'] ?? '').toString();
      _descCtrl.text = (data['description'] ?? '').toString();
      _isActive = (data['isActive'] as bool?) ?? true;

      _participantCount = (data['participantCount'] as int?) ?? 0;
      _winnerCount = (data['winnerCount'] as int?) ?? 0;

      _createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      _updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

      final startTs = data['startAt'] as Timestamp?;
      final endTs = data['endAt'] as Timestamp?;

      if (startTs != null) {
        _startAtCtrl.text =
            DateFormat('yyyy/MM/dd').format(startTs.toDate());
      }
      if (endTs != null) {
        _endAtCtrl.text = DateFormat('yyyy/MM/dd').format(endTs.toDate());
      }

      final prizeList = (data['prizes'] as List<dynamic>?) ?? [];
      _prizes
        ..clear()
        ..addAll(
          prizeList
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );

      // load 完後視為乾淨狀態
      _dirty = false;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('讀取失敗：$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _parseYmd(String text) {
    if (text.trim().isEmpty) return null;
    try {
      return DateFormat('yyyy/MM/dd').parseStrict(text.trim());
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickDateInto(TextEditingController ctrl) async {
    final now = DateTime.now();
    final existing = _parseYmd(ctrl.text);
    final date = await showDatePicker(
      context: context,
      initialDate: existing ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() => ctrl.text = DateFormat('yyyy/MM/dd').format(date));
      _markDirty();
    }
  }

  void _validateDateRangeOrThrow() {
    final start = _parseYmd(_startAtCtrl.text);
    final end = _parseYmd(_endAtCtrl.text);
    if (start != null && end != null && start.isAfter(end)) {
      throw Exception('開始日期不得晚於結束日期');
    }
  }

  Future<void> _saveLottery() async {
    if (_loading) return;

    if (!_formKey.currentState!.validate()) return;

    try {
      _validateDateRangeOrThrow();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      return;
    }

    setState(() => _loading = true);

    try {
      final now = DateTime.now();
      final start = _parseYmd(_startAtCtrl.text);
      final end = _parseYmd(_endAtCtrl.text);

      final Map<String, dynamic> data = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'isActive': _isActive,
        'prizes': _prizes,
        'updatedAt': Timestamp.fromDate(now),
        // 空值用 delete 清掉欄位（避免存 null）
        'startAt': start != null
            ? Timestamp.fromDate(start)
            : FieldValue.delete(),
        'endAt':
            end != null ? Timestamp.fromDate(end) : FieldValue.delete(),
      };

      final ref = FirebaseFirestore.instance.collection('lotteries');

      if (_isNew) {
        final docRef = ref.doc();
        await docRef.set({
          ...data,
          'createdAt': Timestamp.fromDate(now),
          'participantCount': 0,
          'winnerCount': 0,
        }, SetOptions(merge: true));
      } else {
        await ref.doc(widget.lotteryId).update(data);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isNew ? '新增成功' : '已儲存修改')),
      );

      _dirty = false;
      context.go('/admin/lottery');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteLottery() async {
    if (_loading) return;
    if (widget.lotteryId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除確認'),
        content: const Text('確定要刪除此抽獎活動？此動作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('lotteries')
          .doc(widget.lotteryId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已刪除活動')));
      _dirty = false;
      context.go('/admin/lottery');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upsertPrizeDialog({int? editIndex}) async {
    final isEdit = editIndex != null;

    final nameCtrl = TextEditingController(
      text: isEdit ? (_prizes[editIndex!]['name'] ?? '').toString() : '',
    );
    final qtyCtrl = TextEditingController(
      text: isEdit ? (_prizes[editIndex!]['quantity'] ?? 0).toString() : '',
    );
    final descCtrl = TextEditingController(
      text:
          isEdit ? (_prizes[editIndex!]['description'] ?? '').toString() : '',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? '編輯獎項' : '新增獎項'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '獎項名稱 *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '數量（名額）*'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: '說明（選填）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isEdit ? '儲存' : '新增'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final name = nameCtrl.text.trim();
    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
    final desc = descCtrl.text.trim();

    if (name.isEmpty || qty <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請填寫獎項名稱，並確保數量大於 0')),
      );
      return;
    }

    setState(() {
      final item = <String, dynamic>{
        'name': name,
        'quantity': qty,
        'description': desc,
      };

      if (isEdit) {
        _prizes[editIndex!] = item;
      } else {
        _prizes.add(item);
      }

      _dirty = true;
    });
  }

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_dirty) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('尚未儲存'),
        content: const Text('你有未儲存的變更，確定要離開嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('離開'),
          ),
        ],
      ),
    );

    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy/MM/dd HH:mm');

    return WillPopScope(
      onWillPop: () async {
        final ok = await _confirmDiscardIfDirty();
        return ok;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? '新增抽獎活動' : '編輯抽獎活動'),
          actions: [
            if (!_isNew)
              IconButton(
                tooltip: '刪除此活動',
                icon: const Icon(Icons.delete_outline),
                onPressed: _deleteLottery,
              ),
            IconButton(
              tooltip: '儲存',
              icon: const Icon(Icons.save_outlined),
              onPressed: _saveLottery,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 基本資訊
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          labelText: '活動名稱 *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? '請輸入活動名稱'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '活動說明',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 期間
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _startAtCtrl,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: '開始日期',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.date_range_outlined),
                              ),
                              onTap: () => _pickDateInto(_startAtCtrl),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _endAtCtrl,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: '結束日期',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.date_range_outlined),
                              ),
                              onTap: () => _pickDateInto(_endAtCtrl),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 啟用
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _isActive,
                        onChanged: (v) => setState(() {
                          _isActive = v;
                          _dirty = true;
                        }),
                        title: const Text('啟用狀態'),
                        subtitle: Text(_isActive ? '目前啟用中' : '目前停用中'),
                      ),

                      const Divider(height: 32),

                      // 獎項
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '獎項列表',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _upsertPrizeDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('新增'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_prizes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('尚未新增獎項'),
                        ),

                      ...List.generate(_prizes.length, (i) {
                        final p = _prizes[i];
                        final name = (p['name'] ?? '').toString();
                        final qty = (p['quantity'] ?? 0).toString();
                        final desc = (p['description'] ?? '').toString();

                        return Card(
                          child: ListTile(
                            onTap: () => _upsertPrizeDialog(editIndex: i),
                            title: Text('$name（$qty 名）'),
                            subtitle: desc.trim().isEmpty ? null : Text(desc),
                            trailing: IconButton(
                              tooltip: '刪除',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                setState(() {
                                  _prizes.removeAt(i);
                                  _dirty = true;
                                });
                              },
                            ),
                          ),
                        );
                      }),

                      const Divider(height: 32),

                      // 統計（只讀）
                      Text(
                        '統計資訊',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('參與人數：$_participantCount'),
                      Text('中獎人數：$_winnerCount'),
                      const SizedBox(height: 12),
                      if (_createdAt != null) Text('建立時間：${df.format(_createdAt!)}'),
                      if (_updatedAt != null) Text('最後更新：${df.format(_updatedAt!)}'),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/*
========================
必備路由（GoRouter）示例
========================

GoRoute(
  path: '/admin/lottery',
  builder: (context, state) => const AdminLotteryPage(),
  routes: [
    GoRoute(
      path: 'create',
      builder: (context, state) => const AdminLotteryEditPage(),
    ),
    GoRoute(
      path: 'edit/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return AdminLotteryEditPage(lotteryId: id);
      },
    ),
  ],
),

列表頁導向：
- 新增：context.go('/admin/lottery/create');
- 編輯：context.go('/admin/lottery/edit/$id');
*/
