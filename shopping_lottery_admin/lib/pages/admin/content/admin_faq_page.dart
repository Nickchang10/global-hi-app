import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminFaqPage extends StatefulWidget {
  const AdminFaqPage({super.key});

  @override
  State<AdminFaqPage> createState() => _AdminFaqPageState();
}

class _AdminFaqPageState extends State<AdminFaqPage> {
  final _col = FirebaseFirestore.instance.collection('faqs');
  final _search = TextEditingController();
  final _dtFmt = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ 管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新增 FAQ',
            onPressed: () => _openEditor(null),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(null),
        icon: const Icon(Icons.add),
        label: const Text('新增 FAQ'),
      ),
      body: Column(
        children: [
          _filterBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _col.orderBy('order').snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('載入失敗：${snap.error}'));
                }

                final docs = snap.data?.docs ?? [];
                final items = docs.map((d) => _FaqDoc.fromDoc(d)).where(_match).toList();

                if (items.isEmpty) {
                  return const Center(child: Text('尚無 FAQ'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _buildTile(items[i], cs),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: '搜尋（問題 / 回答 / 分類）',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  bool _match(_FaqDoc d) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return d.question.toLowerCase().contains(q) ||
        d.answer.toLowerCase().contains(q) ||
        d.category.toLowerCase().contains(q);
  }

  Widget _buildTile(_FaqDoc d, ColorScheme cs) {
    final updated = d.updatedAt == null ? '—' : _dtFmt.format(d.updatedAt!);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListTile(
        title: Text(
          d.question,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '分類：${d.category}  •  更新：$updated',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pill(d.status == 'published' ? '上架' : '草稿',
                enabled: d.status == 'published'),
            const SizedBox(width: 6),
            _pill(d.isPublic ? '公開' : '不公開', enabled: d.isPublic),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _openEditor(d),
            ),
          ],
        ),
        onTap: () => _openEditor(d),
      ),
    );
  }

  Widget _pill(String text, {bool enabled = true}) {
    final bg = enabled ? Colors.green.shade100 : Colors.grey.shade200;
    final fg = enabled ? Colors.green.shade900 : Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: fg)),
    );
  }

  Future<void> _openEditor(_FaqDoc? d) async {
    final result = await showDialog<_FaqEditResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FaqEditorDialog(initial: d),
    );

    if (result == null) return;

    final data = result.toMap()
      ..addAll({
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'admin',
      });

    if (d == null) {
      await _col.add(data);
    } else {
      await _col.doc(d.id).set(data, SetOptions(merge: true));
    }
  }
}

// ==========================
// Editor Dialog
// ==========================

class _FaqEditorDialog extends StatefulWidget {
  final _FaqDoc? initial;
  const _FaqEditorDialog({this.initial});

  @override
  State<_FaqEditorDialog> createState() => _FaqEditorDialogState();
}

class _FaqEditorDialogState extends State<_FaqEditorDialog> {
  late final TextEditingController _q;
  late final TextEditingController _a;
  late final TextEditingController _cat;
  late final TextEditingController _order;

  String _status = 'draft';
  bool _isPublic = true;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _q = TextEditingController(text: d?.question ?? '');
    _a = TextEditingController(text: d?.answer ?? '');
    _cat = TextEditingController(text: d?.category ?? '');
    _order = TextEditingController(text: (d?.order ?? 0).toString());
    _status = d?.status ?? 'draft';
    _isPublic = d?.isPublic ?? true;
  }

  @override
  void dispose() {
    _q.dispose();
    _a.dispose();
    _cat.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? '新增 FAQ' : '編輯 FAQ',
          style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _tf(_q, '問題'),
              const SizedBox(height: 8),
              _tf(_a, '回答', maxLines: 5),
              const SizedBox(height: 8),
              _tf(_cat, '分類'),
              const SizedBox(height: 8),
              _tf(_order, '排序（數字）', keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      items: const [
                        DropdownMenuItem(value: 'draft', child: Text('草稿')),
                        DropdownMenuItem(value: 'published', child: Text('已上架')),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'draft'),
                      decoration: const InputDecoration(labelText: '狀態'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SwitchListTile(
                      value: _isPublic,
                      onChanged: (v) => setState(() => _isPublic = v),
                      title: const Text('公開'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: _submit,
          child: const Text('儲存'),
        ),
      ],
    );
  }

  Widget _tf(TextEditingController c, String label,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  void _submit() {
    if (_q.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      _FaqEditResult(
        question: _q.text.trim(),
        answer: _a.text.trim(),
        category: _cat.text.trim(),
        order: int.tryParse(_order.text.trim()) ?? 0,
        status: _status,
        isPublic: _isPublic,
      ),
    );
  }
}

// ==========================
// Model
// ==========================

class _FaqDoc {
  final String id;
  final String question;
  final String answer;
  final String category;
  final int order;
  final String status;
  final bool isPublic;
  final DateTime? updatedAt;

  _FaqDoc({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    required this.order,
    required this.status,
    required this.isPublic,
    required this.updatedAt,
  });

  factory _FaqDoc.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return _FaqDoc(
      id: doc.id,
      question: (d['question'] ?? '').toString(),
      answer: (d['answer'] ?? '').toString(),
      category: (d['category'] ?? '').toString(),
      order: (d['order'] ?? 0) as int,
      status: (d['status'] ?? 'draft').toString(),
      isPublic: d['isPublic'] == true,
      updatedAt: (d['updatedAt'] is Timestamp)
          ? (d['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}

class _FaqEditResult {
  final String question;
  final String answer;
  final String category;
  final int order;
  final String status;
  final bool isPublic;

  _FaqEditResult({
    required this.question,
    required this.answer,
    required this.category,
    required this.order,
    required this.status,
    required this.isPublic,
  });

  Map<String, dynamic> toMap() => {
        'question': question,
        'answer': answer,
        'category': category,
        'order': order,
        'status': status,
        'isPublic': isPublic,
      };
}
