// lib/pages/admin/marketing/campaign_builder_page.dart
//
// ✅ CampaignBuilderPage（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// ✅ 修正：CampaignNodeType.from(...) 不存在（extension static 不會掛在 enum 上）
//    -> 改用 CampaignNodeTypeParser.fromValue(...)
// ✅ 修正：DropdownButtonFormField 的 value 已 deprecated
//    -> 改用 initialValue（並加上 key 避免 initialValue 不更新）
// ✅ 修正：Color.withOpacity deprecated -> 改用 withValues(alpha: ...)
// ✅ 功能：
//   - Builder 基本資料：name/description/enabled
//   - 流程節點 Nodes：新增/刪除/拖曳排序/編輯
//   - 儲存到 Firestore（預設 collection: campaign_builders）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CampaignBuilderPage extends StatefulWidget {
  const CampaignBuilderPage({
    super.key,
    this.builderId,
    this.collectionName = 'campaign_builders',
  });

  /// null => 新增；有值 => 編輯
  final String? builderId;

  final String collectionName;

  @override
  State<CampaignBuilderPage> createState() => _CampaignBuilderPageState();
}

class _CampaignBuilderPageState extends State<CampaignBuilderPage> {
  final _formKey = GlobalKey<FormState>();

  late final CollectionReference<Map<String, dynamic>> _col;
  late final DocumentReference<Map<String, dynamic>> _ref;

  bool _loading = true;
  String? _loadError;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _enabled = true;

  final List<CampaignNode> _nodes = [];

  bool get _isEdit => (widget.builderId ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _col = FirebaseFirestore.instance.collection(widget.collectionName);
    _ref = _isEdit ? _col.doc(widget.builderId!.trim()) : _col.doc();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Load / Apply
  // -------------------------
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    String? err;
    try {
      if (_isEdit) {
        final snap = await _ref.get();
        final data = snap.data();
        if (data == null) throw StateError('找不到 Builder：${_ref.id}');
        _applyData(data);
      } else {
        // default
        _enabled = true;
        _nodes
          ..clear()
          ..add(CampaignNode.defaults(CampaignNodeType.condition))
          ..add(CampaignNode.defaults(CampaignNodeType.message));
      }
    } catch (e) {
      err = e.toString();
    }

    if (!mounted) return;
    setState(() {
      _loadError = err;
      _loading = false;
    });
  }

  void _applyData(Map<String, dynamic> d) {
    _nameCtrl.text = (d['name'] ?? '').toString();
    _descCtrl.text = (d['description'] ?? '').toString();
    _enabled = d['enabled'] == true;

    _nodes.clear();
    final raw = d['nodes'];
    if (raw is List) {
      for (final it in raw) {
        final m = _asMap(it);
        _nodes.add(CampaignNode.fromMap(m));
      }
    }
    if (_nodes.isEmpty) {
      _nodes.add(CampaignNode.defaults(CampaignNodeType.message));
    }
  }

  // -------------------------
  // Node ops
  // -------------------------

  void _addNode(CampaignNodeType type) {
    setState(() {
      _nodes.add(CampaignNode.defaults(type));
    });
  }

  /// ✅ 會被 UI 呼叫，不會 unused
  Future<void> _deleteNode(int index) async {
    if (index < 0 || index >= _nodes.length) return;

    final node = _nodes[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除節點'),
        content: Text(
          '確定刪除「${node.title.isEmpty ? node.type.label : node.title}」？',
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

    if (!mounted) return;
    setState(() {
      _nodes.removeAt(index);
      if (_nodes.isEmpty) {
        _nodes.add(CampaignNode.defaults(CampaignNodeType.message));
      }
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _nodes.removeAt(oldIndex);
      _nodes.insert(newIndex, item);
    });
  }

  Future<void> _editNode(int index) async {
    final node = _nodes[index];
    final edited = await showModalBottomSheet<CampaignNode>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NodeEditorSheet(node: node),
    );
    if (edited == null) return;

    if (!mounted) return;
    setState(() => _nodes[index] = edited);
  }

  // -------------------------
  // Save
  // -------------------------
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final payload = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'enabled': _enabled,
      'nodes': _nodes.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (!_isEdit) 'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await _ref.set(payload, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? '已更新 Builder' : '已新增 Builder（ID：${_ref.id}）'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    }
  }

  // -------------------------
  // Utils
  // -------------------------
  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? '編輯 Campaign Builder' : '新增 Campaign Builder';

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
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddNodeMenu,
              icon: const Icon(Icons.add),
              label: const Text('新增節點'),
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
                  _basicCard(),
                  const SizedBox(height: 12),
                  _nodesCard(),
                  const SizedBox(height: 16),
                  _bottomActions(),
                ],
              ),
            ),
    );
  }

  void _showAddNodeMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.rule),
              title: const Text('條件節點（Condition）'),
              subtitle: const Text('例如：segment=vip / 近30天有下單…'),
              onTap: () {
                Navigator.pop(context);
                _addNode(CampaignNodeType.condition);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('延遲節點（Delay）'),
              subtitle: const Text('例如：等待 10 分鐘再發送'),
              onTap: () {
                Navigator.pop(context);
                _addNode(CampaignNodeType.delay);
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign),
              title: const Text('訊息節點（Message）'),
              subtitle: const Text('Push / LINE / Email（示範）'),
              onTap: () {
                Navigator.pop(context);
                _addNode(CampaignNodeType.message);
              },
            ),
            const SizedBox(height: 8),
          ],
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
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '基本設定',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Switch(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Builder 名稱',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return '請輸入名稱';
                if (s.length < 2) return '名稱太短';
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '描述（可空）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text('ID：${_ref.id}', style: TextStyle(color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  Widget _nodesCard() {
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
                    '流程節點（Nodes）',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '共 ${_nodes.length} 個',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _nodes.length,
              onReorder: _reorder,
              itemBuilder: (context, index) {
                final node = _nodes[index];
                return _NodeCard(
                  key: ValueKey(node.id),
                  index: index,
                  node: node,
                  onEdit: () => _editNode(index),
                  onDelete: () => _deleteNode(index),
                );
              },
            ),
            const SizedBox(height: 6),
            Text(
              '提示：可拖曳排序；點卡片可編輯；右上角可刪除。',
              style: TextStyle(color: Colors.grey[700]),
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
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回'),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Node Model
// ============================================================

enum CampaignNodeType { delay, message, condition }

extension CampaignNodeTypeUi on CampaignNodeType {
  String get value {
    switch (this) {
      case CampaignNodeType.delay:
        return 'delay';
      case CampaignNodeType.message:
        return 'message';
      case CampaignNodeType.condition:
        return 'condition';
    }
  }

  String get label {
    switch (this) {
      case CampaignNodeType.delay:
        return 'Delay';
      case CampaignNodeType.message:
        return 'Message';
      case CampaignNodeType.condition:
        return 'Condition';
    }
  }

  IconData get icon {
    switch (this) {
      case CampaignNodeType.delay:
        return Icons.timer;
      case CampaignNodeType.message:
        return Icons.campaign;
      case CampaignNodeType.condition:
        return Icons.rule;
    }
  }
}

/// ✅ 解析器：取代 CampaignNodeType.from(...)
class CampaignNodeTypeParser {
  static CampaignNodeType fromValue(dynamic v) {
    final s = (v ?? '').toString().toLowerCase();
    if (s == 'delay') return CampaignNodeType.delay;
    if (s == 'message') return CampaignNodeType.message;
    if (s == 'condition') return CampaignNodeType.condition;
    return CampaignNodeType.message;
  }
}

class CampaignNode {
  CampaignNode({
    required this.id,
    required this.type,
    required this.title,
    required this.data,
  });

  final String id;
  final CampaignNodeType type;
  final String title;
  final Map<String, dynamic> data;

  static String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  factory CampaignNode.defaults(CampaignNodeType type) {
    switch (type) {
      case CampaignNodeType.condition:
        return CampaignNode(
          id: _id(),
          type: type,
          title: '分眾條件',
          data: {'segment': 'vip', 'rule': 'segment == vip'},
        );
      case CampaignNodeType.delay:
        return CampaignNode(
          id: _id(),
          type: type,
          title: '等待',
          data: {'minutes': 10},
        );
      case CampaignNodeType.message:
        return CampaignNode(
          id: _id(),
          type: type,
          title: '訊息推送',
          data: {'channel': 'push', 'template': 'Hi {name}，這是一則活動提醒～'},
        );
    }
  }

  factory CampaignNode.fromMap(Map<String, dynamic> m) {
    final id = (m['id'] ?? '').toString().trim();
    final type = CampaignNodeTypeParser.fromValue(m['type']);
    final title = (m['title'] ?? '').toString();
    final data = _Safe.asMap(m['data']);
    return CampaignNode(
      id: id.isEmpty ? _id() : id,
      type: type,
      title: title,
      data: data,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.value,
    'title': title,
    'data': data,
  };

  CampaignNode copyWith({
    CampaignNodeType? type,
    String? title,
    Map<String, dynamic>? data,
  }) {
    return CampaignNode(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      data: data ?? this.data,
    );
  }
}

// ============================================================
// Node Card
// ============================================================

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    super.key,
    required this.index,
    required this.node,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final CampaignNode node;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: key,
      elevation: 0.6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(node.type.icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${index + 1}. ${node.title.isEmpty ? node.type.label : node.title}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Tag(text: node.type.label),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: '刪除節點',
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                        const Icon(Icons.drag_handle),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _preview(node),
                      style: TextStyle(color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _preview(CampaignNode n) {
    switch (n.type) {
      case CampaignNodeType.condition:
        final seg = (n.data['segment'] ?? '').toString();
        final rule = (n.data['rule'] ?? '').toString();
        return 'segment=$seg · rule=$rule';
      case CampaignNodeType.delay:
        final minutes = _Num.asInt(n.data['minutes']);
        return '等待 $minutes 分鐘';
      case CampaignNodeType.message:
        final channel = (n.data['channel'] ?? '').toString();
        final tpl = (n.data['template'] ?? '').toString();
        return 'channel=$channel · $tpl';
    }
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Colors.black54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w800),
      ),
    );
  }
}

// ============================================================
// Node Editor Sheet
// ============================================================

class _NodeEditorSheet extends StatefulWidget {
  const _NodeEditorSheet({required this.node});
  final CampaignNode node;

  @override
  State<_NodeEditorSheet> createState() => _NodeEditorSheetState();
}

class _NodeEditorSheetState extends State<_NodeEditorSheet> {
  late CampaignNodeType _type;
  final _titleCtrl = TextEditingController();

  // type-specific
  final _segmentCtrl = TextEditingController();
  final _ruleCtrl = TextEditingController();
  final _minutesCtrl = TextEditingController();
  String _channel = 'push';
  final _templateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final n = widget.node;
    _type = n.type;
    _titleCtrl.text = n.title;

    if (_type == CampaignNodeType.condition) {
      _segmentCtrl.text = (n.data['segment'] ?? 'vip').toString();
      _ruleCtrl.text = (n.data['rule'] ?? '').toString();
    } else if (_type == CampaignNodeType.delay) {
      _minutesCtrl.text = _Num.asInt(n.data['minutes']).toString();
    } else {
      _channel = (n.data['channel'] ?? 'push').toString();
      _templateCtrl.text = (n.data['template'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _segmentCtrl.dispose();
    _ruleCtrl.dispose();
    _minutesCtrl.dispose();
    _templateCtrl.dispose();
    super.dispose();
  }

  void _applyTypeDefaults(CampaignNodeType t) {
    if (t == CampaignNodeType.condition) {
      _segmentCtrl.text = 'vip';
      _ruleCtrl.text = 'segment == vip';
    } else if (t == CampaignNodeType.delay) {
      _minutesCtrl.text = '10';
    } else {
      _channel = 'push';
      _templateCtrl.text = 'Hi {name}，這是一則活動提醒～';
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: padding.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '編輯節點',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  FilledButton(onPressed: _submit, child: const Text('套用')),
                ],
              ),
              const SizedBox(height: 12),

              // ✅ value deprecated -> initialValue + key
              DropdownButtonFormField<CampaignNodeType>(
                key: ValueKey('type_${_type.value}'),
                initialValue: _type,
                items: CampaignNodeType.values
                    .map(
                      (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _type = v;
                    _applyTypeDefaults(v);
                  });
                },
                decoration: const InputDecoration(
                  labelText: '節點類型',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: '節點標題（可自訂）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _typeSpecificEditor(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeSpecificEditor() {
    switch (_type) {
      case CampaignNodeType.condition:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _segmentCtrl,
              decoration: const InputDecoration(
                labelText: 'segment（例：vip / new / active）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _ruleCtrl,
              decoration: const InputDecoration(
                labelText: 'rule（可空，示意用）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        );

      case CampaignNodeType.delay:
        return TextFormField(
          controller: _minutesCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '等待分鐘數（minutes）',
            border: OutlineInputBorder(),
          ),
        );

      case CampaignNodeType.message:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ value deprecated -> initialValue + key
            DropdownButtonFormField<String>(
              key: ValueKey('channel_$_channel'),
              initialValue: _channel,
              items: const [
                DropdownMenuItem(value: 'push', child: Text('Push')),
                DropdownMenuItem(value: 'line', child: Text('LINE')),
                DropdownMenuItem(value: 'email', child: Text('Email')),
              ],
              onChanged: (v) => setState(() => _channel = v ?? 'push'),
              decoration: const InputDecoration(
                labelText: 'channel',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _templateCtrl,
              decoration: const InputDecoration(
                labelText: 'template（訊息內容）',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        );
    }
  }

  void _submit() {
    final title = _titleCtrl.text.trim();

    Map<String, dynamic> data;
    if (_type == CampaignNodeType.condition) {
      data = {
        'segment': _segmentCtrl.text.trim(),
        'rule': _ruleCtrl.text.trim(),
      };
    } else if (_type == CampaignNodeType.delay) {
      data = {'minutes': int.tryParse(_minutesCtrl.text.trim()) ?? 0};
    } else {
      data = {'channel': _channel, 'template': _templateCtrl.text.trim()};
    }

    final edited = widget.node.copyWith(type: _type, title: title, data: data);

    Navigator.pop(context, edited);
  }
}

// ============================================================
// Small helpers
// ============================================================

class _Safe {
  static Map<String, dynamic> asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }
}

class _Num {
  static int asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
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
