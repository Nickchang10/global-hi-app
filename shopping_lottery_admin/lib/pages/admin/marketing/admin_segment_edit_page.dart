import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ✅ AdminSegmentEditPage（受眾分群編輯頁｜最終可編譯完整版）
/// ------------------------------------------------------------
/// - Firestore 集合：segments
/// - 功能：
///   1. 建立 / 編輯 / 刪除分群
///   2. 條件設定（性別、年齡、地區、裝置、標籤）
///   3. 預估人數（模擬統計或 Firestore 中 users 數據）
///   4. isActive 狀態切換
/// ------------------------------------------------------------
class AdminSegmentEditPage extends StatefulWidget {
  final String? segmentId;

  const AdminSegmentEditPage({super.key, this.segmentId});

  @override
  State<AdminSegmentEditPage> createState() => _AdminSegmentEditPageState();
}

class _AdminSegmentEditPageState extends State<AdminSegmentEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _isActive = true;
  String _gender = 'all';
  RangeValues _ageRange = const RangeValues(10, 70);
  String _region = 'all';
  String _device = 'all';
  final List<String> _tags = [];
  int _estimatedCount = 0;

  bool _loading = false;
  bool _saving = false;
  DocumentSnapshot<Map<String, dynamic>>? _doc;

  @override
  void initState() {
    super.initState();
    if (widget.segmentId != null) _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // Firestore
  // ============================================================

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('segments')
          .doc(widget.segmentId)
          .get();
      if (!doc.exists) return;
      final d = doc.data()!;
      _doc = doc;
      _nameCtrl.text = d['name'] ?? '';
      _descCtrl.text = d['description'] ?? '';
      _isActive = d['isActive'] ?? true;
      _gender = d['gender'] ?? 'all';
      final from = (d['ageFrom'] ?? 10).toDouble();
      final to = (d['ageTo'] ?? 70).toDouble();
      _ageRange = RangeValues(from, to);
      _region = d['region'] ?? 'all';
      _device = d['device'] ?? 'all';
      final t = (d['tags'] as List?)?.cast<String>() ?? [];
      _tags.clear();
      _tags.addAll(t);
      _estimatedCount = (d['memberCount'] ?? 0) as int;
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('讀取失敗：$e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final ref = FirebaseFirestore.instance.collection('segments');
      final data = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'isActive': _isActive,
        'gender': _gender,
        'ageFrom': _ageRange.start.toInt(),
        'ageTo': _ageRange.end.toInt(),
        'region': _region,
        'device': _device,
        'tags': _tags,
        'memberCount': _estimatedCount,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (widget.segmentId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await ref.add(data);
      } else {
        await ref.doc(widget.segmentId).update(data);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已儲存分群設定')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.segmentId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除確認'),
        content: const Text('確定要刪除此分群嗎？此動作無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseFirestore.instance
        .collection('segments')
        .doc(widget.segmentId)
        .delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已刪除此分群')));
    Navigator.pop(context);
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy/MM/dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.segmentId == null ? '新增受眾分群' : '編輯受眾分群'),
        actions: [
          if (widget.segmentId != null)
            IconButton(
              tooltip: '刪除此分群',
              icon: const Icon(Icons.delete),
              onPressed: _delete,
            ),
          IconButton(
            tooltip: '儲存',
            icon: const Icon(Icons.save),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionTitle('基本資訊'),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '分群名稱',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '請輸入名稱' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '描述',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('啟用狀態'),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                  const Divider(height: 32),
                  _buildSectionTitle('條件設定'),
                  _buildDropdown('性別', _gender, {
                    'all': '全部',
                    'male': '男性',
                    'female': '女性',
                  }, (v) => setState(() => _gender = v)),
                  const SizedBox(height: 12),
                  Text('年齡區間：${_ageRange.start.toInt()} - ${_ageRange.end.toInt()} 歲'),
                  RangeSlider(
                    values: _ageRange,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    onChanged: (v) => setState(() => _ageRange = v),
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown('地區', _region, {
                    'all': '全部地區',
                    'north': '北部',
                    'central': '中部',
                    'south': '南部',
                    'east': '東部',
                  }, (v) => setState(() => _region = v)),
                  const SizedBox(height: 12),
                  _buildDropdown('裝置', _device, {
                    'all': '全部裝置',
                    'ios': 'iOS',
                    'android': 'Android',
                    'web': 'Web',
                  }, (v) => setState(() => _device = v)),
                  const SizedBox(height: 20),
                  _buildTagInput(),
                  const Divider(height: 32),
                  _buildSectionTitle('預估結果'),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '預估符合人數：$_estimatedCount 位',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _simulateEstimate,
                        icon: const Icon(Icons.calculate),
                        label: const Text('重新預估'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_doc != null)
                    Text(
                      '最後更新時間：${df.format((_doc!['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now())}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );

  Widget _buildDropdown(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            items: options.entries
                .map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => onChanged(v ?? value),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // 標籤輸入
  // ------------------------------------------------------------
  Widget _buildTagInput() {
    final controller = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('標籤（可多項，用於分類或行為識別）'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in _tags)
              Chip(
                label: Text(tag),
                onDeleted: () {
                  setState(() => _tags.remove(tag));
                },
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('新增標籤'),
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('新增標籤'),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: '輸入標籤文字'),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () {
                            final text = controller.text.trim();
                            if (text.isNotEmpty && !_tags.contains(text)) {
                              setState(() => _tags.add(text));
                            }
                            Navigator.pop(context);
                          },
                          child: const Text('加入')),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // 模擬預估（可未來替換為真實 Firestore 條件查詢）
  // ------------------------------------------------------------
  Future<void> _simulateEstimate() async {
    setState(() => _estimatedCount = 0);
    await Future.delayed(const Duration(milliseconds: 500));
    final seed = (_gender.hashCode +
            _region.hashCode +
            _device.hashCode +
            _tags.join('').hashCode) %
        500;
    setState(() => _estimatedCount = 100 + seed);
  }
}
