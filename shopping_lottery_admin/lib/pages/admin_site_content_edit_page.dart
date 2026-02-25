import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// AdminSiteContentEditPage（正式版｜完整版｜可直接編譯）
///
/// Firestore：site_contents/{docId}
/// 建議欄位：
/// - title: String
/// - slug: String              // about / terms / privacy ...
/// - locale: String            // zh_TW / en ...
/// - content: String           // 內文（純文字/Markdown 皆可）
/// - enabled: bool
/// - updatedAt, createdAt: Timestamp
class AdminSiteContentEditPage extends StatefulWidget {
  const AdminSiteContentEditPage({
    super.key,
    required this.docId,
    this.pageTitle,
  });

  final String docId;
  final String? pageTitle;

  @override
  State<AdminSiteContentEditPage> createState() =>
      _AdminSiteContentEditPageState();
}

class _AdminSiteContentEditPageState extends State<AdminSiteContentEditPage> {
  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('site_contents').doc(widget.docId);

  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _localeCtrl = TextEditingController(text: 'zh_TW');
  final _contentCtrl = TextEditingController();

  bool _enabled = true;
  bool _busy = false;
  bool _hydrated = false; // 避免 StreamBuilder 每次 rebuild 都覆蓋使用者正在輸入的文字

  @override
  void dispose() {
    _titleCtrl.dispose();
    _slugCtrl.dispose();
    _localeCtrl.dispose();
    _contentCtrl.dispose();
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

  void _hydrateFrom(Map<String, dynamic> data) {
    if (_hydrated) return;

    _titleCtrl.text = (data['title'] ?? '').toString();
    _slugCtrl.text = (data['slug'] ?? widget.docId).toString();
    _localeCtrl.text = (data['locale'] ?? 'zh_TW').toString();
    _contentCtrl.text = (data['content'] ?? '').toString();
    _enabled = data['enabled'] != false;

    _hydrated = true;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      final now = FieldValue.serverTimestamp();

      await _ref.set({
        'title': _titleCtrl.text.trim(),
        'slug': _slugCtrl.text.trim(),
        'locale': _localeCtrl.text.trim().isEmpty
            ? 'zh_TW'
            : _localeCtrl.text.trim(),
        'content': _contentCtrl.text,
        'enabled': _enabled,
        'updatedAt': now,
        'createdAt': now,
      }, SetOptions(merge: true));

      _snack('已儲存');
    } catch (e) {
      _snack('儲存失敗：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetHydrate() async {
    // 重新從 DB 載入覆蓋目前輸入
    setState(() => _hydrated = false);
    _snack('已重新載入（下次畫面刷新會以資料庫為準）');
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.pageTitle ?? '編輯頁面內容';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: Center(
              child: Text(
                '讀取失敗：${snap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final doc = snap.data!;
        final data = doc.data() ?? <String, dynamic>{};
        _hydrateFrom(data);

        final updatedAt = _fmtTs(data['updatedAt']);
        final createdAt = _fmtTs(data['createdAt']);

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              IconButton(
                tooltip: '重新載入（覆蓋目前輸入）',
                onPressed: _busy ? null : _resetHydrate,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: '儲存',
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.save),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              if (!_enabled)
                Container(
                  width: double.infinity,
                  // ✅ withOpacity(0.25) -> withValues(alpha: 64)
                  color: Colors.amber.withValues(alpha: 64),
                  padding: const EdgeInsets.all(10),
                  child: const Text('此頁面目前為「停用」狀態（前台可選擇不顯示）'),
                ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        elevation: 0.6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '基本資訊',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _titleCtrl,
                                decoration: const InputDecoration(
                                  labelText: '標題 title（必填）',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) =>
                                    (v ?? '').trim().isEmpty ? '必填' : null,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _slugCtrl,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'slug（例如 about / terms / privacy）',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _localeCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'locale（例如 zh_TW / en）',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('啟用 enabled'),
                                value: _enabled,
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(() => _enabled = v),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'docId: ${widget.docId}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'created: $createdAt',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'updated: $updatedAt',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0.6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '內容 content',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _contentCtrl,
                                minLines: 12,
                                maxLines: 30,
                                decoration: const InputDecoration(
                                  hintText: '支援純文字/Markdown（前台如何渲染由你前台決定）',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _busy ? null : _save,
                                  icon: const Icon(Icons.save),
                                  label: const Text('儲存'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 0.4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '預覽（純文字）',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    // ✅ withOpacity(0.4) -> withValues(alpha: 102)
                                    color: Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 102),
                                  ),
                                ),
                                child: SelectableText(
                                  _contentCtrl.text.isEmpty
                                      ? '(內容空白)'
                                      : _contentCtrl.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
