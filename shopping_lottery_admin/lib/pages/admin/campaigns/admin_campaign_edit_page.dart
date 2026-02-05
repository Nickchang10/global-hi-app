import 'package:flutter/material.dart';
import '../../../models/campaign_model.dart';
import '../../../services/campaign_service.dart';

class AdminCampaignEditPage extends StatefulWidget {
  final Campaign? campaign;
  const AdminCampaignEditPage({super.key, this.campaign});

  @override
  State<AdminCampaignEditPage> createState() => _AdminCampaignEditPageState();
}

class _AdminCampaignEditPageState extends State<AdminCampaignEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = CampaignService();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  bool _isPublic = false;
  String _ruleType = 'percentage';
  DateTime? _startAt;
  DateTime? _endAt;

  @override
  void initState() {
    super.initState();
    if (widget.campaign != null) {
      final c = widget.campaign!;
      _titleCtrl.text = c.title;
      _descCtrl.text = c.description;
      _discountCtrl.text = c.discountValue.toString();
      _isPublic = c.isPublic;
      _ruleType = c.ruleType;
      _startAt = c.startAt;
      _endAt = c.endAt;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.campaign != null;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? '編輯活動' : '新增活動')),
      body: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: c.maxWidth, minHeight: c.maxHeight),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: '活動名稱'),
                    validator: (v) => v!.isEmpty ? '請輸入活動名稱' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(labelText: '活動說明'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),

                  // ✅ 修正 Dropdown 重複 value 問題
                  DropdownButtonFormField<String>(
                    value: _ruleType.isNotEmpty &&
                            ['percentage', 'amount', 'gift'].contains(_ruleType)
                        ? _ruleType
                        : 'percentage',
                    items: const [
                      DropdownMenuItem(
                          value: 'percentage', child: Text('折扣百分比')),
                      DropdownMenuItem(value: 'amount', child: Text('折抵金額')),
                      DropdownMenuItem(value: 'gift', child: Text('贈品')),
                    ],
                    onChanged: (v) => setState(() => _ruleType = v ?? 'percentage'),
                    decoration: const InputDecoration(labelText: '活動類型'),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _discountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '折扣值'),
                    validator: (v) =>
                        v == null || v.isEmpty ? '請輸入折扣值' : null,
                  ),
                  const SizedBox(height: 12),

                  _datePicker('開始日期', _startAt, (d) => setState(() => _startAt = d)),
                  _datePicker('結束日期', _endAt, (d) => setState(() => _endAt = d)),

                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('是否公開'),
                    value: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                  ),
                  const SizedBox(height: 20),

                  Center(
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('儲存活動'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _datePicker(String label, DateTime? date, Function(DateTime) onPicked) {
    return Row(
      children: [
        Expanded(
          child: Text('$label：${date != null ? date.toString().substring(0, 10) : "未選擇"}'),
        ),
        TextButton(
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? now,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 2),
            );
            if (picked != null) onPicked(picked);
          },
          child: const Text('選擇'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startAt == null || _endAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請選擇活動日期')),
      );
      return;
    }

    final campaign = Campaign(
      id: widget.campaign?.id ?? '',
      title: _titleCtrl.text,
      vendorId: 'admin',
      vendorName: 'Osmile',
      description: _descCtrl.text,
      startAt: _startAt!,
      endAt: _endAt!,
      status: 'active',
      isPublic: _isPublic,
      ruleType: _ruleType,
      discountValue: num.tryParse(_discountCtrl.text) ?? 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      if (widget.campaign == null) {
        await _service.addCampaign(campaign);
      } else {
        await _service.updateCampaign(widget.campaign!.id, campaign.toMap());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('儲存成功')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('錯誤：$e')),
      );
    }
  }
}
