// lib/pages/admin/marketing/admin_segment_edit_page.dart
//
// ✅ AdminSegmentEditPage（分眾 / 會員分群編輯｜正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// ✅ 修正：use_build_context_synchronously
// - await 前先取得 messenger / navigator，await 後不再直接用 context
// ✅ 修正：control_flow_in_finally
// - finally 區塊不使用 return，改用 if (mounted) setState(...)
//
// Firestore collection（預設）：segments
//
// 建議資料結構（可自由調整）：
// {
//   name: "高活躍會員",
//   description: "...",
//   enabled: true,
//   rules: {
//     minPoints: 1000,
//     minOrders: 3,
//     lastActiveDays: 30,
//     tags: ["vip","early_adopter"]
//   },
//   updatedAt: Timestamp,
//   createdAt: Timestamp,
// }
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSegmentEditPage extends StatefulWidget {
  const AdminSegmentEditPage({
    super.key,
    this.segmentId,
    this.collectionName = 'segments',
  });

  /// null/empty => 新增；有值 => 編輯
  final String? segmentId;

  final String collectionName;

  @override
  State<AdminSegmentEditPage> createState() => _AdminSegmentEditPageState();
}

class _AdminSegmentEditPageState extends State<AdminSegmentEditPage> {
  final _formKey = GlobalKey<FormState>();

  late final CollectionReference<Map<String, dynamic>> _col;
  late final DocumentReference<Map<String, dynamic>> _ref;

  bool _loading = true;
  String? _loadError;

  // fields
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _enabled = true;

  final _minPointsCtrl = TextEditingController(text: '0');
  final _minOrdersCtrl = TextEditingController(text: '0');
  final _lastActiveDaysCtrl = TextEditingController(text: '0');
  final _tagsCtrl = TextEditingController(text: ''); // comma separated

  bool get _isEdit => (widget.segmentId ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _col = FirebaseFirestore.instance.collection(widget.collectionName);
    _ref = _isEdit ? _col.doc(widget.segmentId!.trim()) : _col.doc();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _minPointsCtrl.dispose();
    _minOrdersCtrl.dispose();
    _lastActiveDaysCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  // ---------------------------
  // helpers
  // ---------------------------
  int _parseInt(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  List<String> _parseTags(String input) {
    return input
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  // ---------------------------
  // load
  // ---------------------------
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      if (_isEdit) {
        final snap = await _ref.get();
        final data = snap.data();
        if (data == null) throw StateError('找不到分眾資料：${_ref.id}');
        _applyData(data);
      } else {
        // defaults
        _enabled = true;
        _nameCtrl.text = '';
        _descCtrl.text = '';
        _minPointsCtrl.text = '0';
        _minOrdersCtrl.text = '0';
        _lastActiveDaysCtrl.text = '0';
        _tagsCtrl.text = '';
      }
    } catch (e) {
      _loadError = e.toString();
    } finally {
      // ✅ FIX: control_flow_in_finally（finally 不使用 return）
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyData(Map<String, dynamic> d) {
    _nameCtrl.text = (d['name'] ?? d['title'] ?? '').toString();
    _descCtrl.text = (d['description'] ?? d['desc'] ?? '').toString();
    _enabled = d['enabled'] == true;

    final rules = _asMap(d['rules']);
    _minPointsCtrl.text = (rules['minPoints'] ?? rules['min_points'] ?? 0)
        .toString();
    _minOrdersCtrl.text = (rules['minOrders'] ?? rules['min_orders'] ?? 0)
        .toString();
    _lastActiveDaysCtrl.text =
        (rules['lastActiveDays'] ?? rules['last_active_days'] ?? 0).toString();

    final tags = rules['tags'];
    if (tags is List) {
      _tagsCtrl.text = tags
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .join(', ');
    } else {
      _tagsCtrl.text = '';
    }
  }

  // ---------------------------
  // actions
  // ---------------------------
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // ✅ FIX: await 前先取出 messenger / navigator，await 後不再用 context
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final payload = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'enabled': _enabled,
      'rules': {
        'minPoints': _parseInt(_minPointsCtrl),
        'minOrders': _parseInt(_minOrdersCtrl),
        'lastActiveDays': _parseInt(_lastActiveDaysCtrl),
        'tags': _parseTags(_tagsCtrl.text),
      },
      'updatedAt': FieldValue.serverTimestamp(),
      if (!_isEdit) 'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await _ref.set(payload, SetOptions(merge: true));
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(content: Text(_isEdit ? '已更新分眾' : '已新增分眾（ID：${_ref.id}）')),
      );
      nav.pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    }
  }

  Future<void> _delete() async {
    // ✅ FIX: await 前先取出 messenger / navigator，await 後不再用 context
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    if (!_isEdit) {
      nav.pop(false);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除分眾'),
        content: Text(
          '確定要刪除「${_nameCtrl.text.trim().isEmpty ? _ref.id : _nameCtrl.text.trim()}」？此操作不可復原。',
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

    if (!mounted) return;
    if (ok != true) return;

    try {
      await _ref.delete();
      if (!mounted) return;

      messenger.showSnackBar(const SnackBar(content: Text('已刪除')));
      nav.pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  // ---------------------------
  // UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? '編輯分眾' : '新增分眾';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '儲存',
            onPressed: _loading ? null : _save,
            icon: const Icon(Icons.save),
          ),
          if (_isEdit)
            IconButton(
              tooltip: '刪除',
              onPressed: _loading ? null : _delete,
              icon: const Icon(Icons.delete_outline),
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
        title: const Text('Segment ID'),
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
                labelText: '分眾名稱（name）',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return '請輸入分眾名稱';
                if (s.length < 2) return '名稱太短';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: '描述（description，可空）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
              '分群規則（rules）',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minPointsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '最低點數（minPoints）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minOrdersCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '最低訂單數（minOrders）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastActiveDaysCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '最近活躍天數（lastActiveDays）',
                helperText: '例如 30 表示近 30 天內有活躍才算符合（可為 0 表示不限制）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tagsCtrl,
              decoration: const InputDecoration(
                labelText: '標籤（tags，逗號分隔）',
                helperText: '例如 vip, early_adopter（可空）',
                border: OutlineInputBorder(),
              ),
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
  final Future<void> Function() onRetry;

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
