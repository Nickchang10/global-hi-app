// lib/pages/admin_support_page.dart
//
// ✅ AdminSupportPage v7.6 Final（客服中心管理｜FAQ + 聯絡我們設定）
// ------------------------------------------------------------
// Firestore 結構：
// faq_items/{id}
//   - question: String
//   - answer: String
//   - category: String
//   - isActive: bool
//   - order: int
//   - createdAt, updatedAt
//
// site_settings/support
//   - email: String
//   - phone: String
//   - workingHours: String
//   - formNote: String
//
// ------------------------------------------------------------
// 依賴：cloud_firestore, intl
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminSupportPage extends StatefulWidget {
  const AdminSupportPage({super.key});

  @override
  State<AdminSupportPage> createState() => _AdminSupportPageState();
}

class _AdminSupportPageState extends State<AdminSupportPage> {
  final _db = FirebaseFirestore.instance;
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('客服中心管理'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.question_answer_outlined), text: '常見問題 FAQ'),
              Tab(icon: Icon(Icons.support_agent_outlined), text: '聯絡我們設定'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FaqManager(),
            _SupportSettings(),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// ✅ FAQ 管理區塊
// ------------------------------------------------------------
class _FaqManager extends StatefulWidget {
  @override
  State<_FaqManager> createState() => _FaqManagerState();
}

class _FaqManagerState extends State<_FaqManager> {
  final _db = FirebaseFirestore.instance;
  bool _busyReorder = false;
  String _keyword = '';
  String _category = '全部';

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _fmt(dynamic v) =>
      v is Timestamp ? DateFormat('yyyy/MM/dd HH:mm').format(v.toDate()) : '-';

  Query<Map<String, dynamic>> _query() =>
      _db.collection('faq_items').orderBy('order').limit(300);

  Future<void> _create() async {
    final ref = _db.collection('faq_items').doc();
    final now = FieldValue.serverTimestamp();
    await ref.set({
      'question': '新問題',
      'answer': '請輸入答案內容',
      'category': '一般',
      'isActive': true,
      'order': DateTime.now().millisecondsSinceEpoch,
      'createdAt': now,
      'updatedAt': now,
    });
    await _edit(ref.id);
  }

  Future<void> _edit(String id) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FaqEditSheet(id: id),
    );
  }

  Future<void> _toggleActive(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final cur = doc.data()?['isActive'] == true;
    await doc.reference.update({'isActive': !cur});
  }

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final q = (doc.data()?['question'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除 FAQ'),
        content: Text('確定要刪除「$q」嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok == true) {
      await doc.reference.delete();
      _snack('已刪除');
    }
  }

  Future<void> _applyReorder(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (_busyReorder) return;
    setState(() => _busyReorder = true);
    try {
      final batch = _db.batch();
      for (int i = 0; i < docs.length; i++) {
        batch.update(docs[i].reference, {'order': i + 1});
      }
      await batch.commit();
    } finally {
      setState(() => _busyReorder = false);
    }
  }

  bool _match(Map<String, dynamic> d) {
    final kw = _keyword.toLowerCase().trim();
    final cat = _category;
    final q = (d['question'] ?? '').toString().toLowerCase();
    final a = (d['answer'] ?? '').toString().toLowerCase();
    final c = (d['category'] ?? '').toString().trim();
    if (kw.isNotEmpty && !q.contains(kw) && !a.contains(kw)) return false;
    if (cat != '全部' && c != cat) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final stream = _query().snapshots();

    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final all = snap.data!.docs;
              if (all.isEmpty) return const Center(child: Text('目前沒有 FAQ'));

              final cats = <String>{'全部'};
              for (final d in all) {
                final c = (d['category'] ?? '').toString();
                if (c.isNotEmpty) cats.add(c);
              }

              final filtered = all.where((d) => _match(d.data())).toList();

              return Stack(
                children: [
                  ReorderableListView.builder(
                    itemCount: filtered.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (newIndex > oldIndex) newIndex--;
                      final moved = filtered.removeAt(oldIndex);
                      filtered.insert(newIndex, moved);
                      await _applyReorder(filtered);
                    },
                    itemBuilder: (context, i) {
                      final d = filtered[i].data();
                      final q = (d['question'] ?? '').toString();
                      final a = (d['answer'] ?? '').toString();
                      final cat = (d['category'] ?? '').toString();
                      final active = d['isActive'] == true;
                      final updated = _fmt(d['updatedAt']);

                      return Card(
                        key: ValueKey(filtered[i].id),
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: ListTile(
                          leading: Icon(Icons.help_outline,
                              color: active ? Colors.blue : Colors.grey),
                          title: Text(q, style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text([
                            '分類：$cat',
                            '狀態：${active ? '上架' : '下架'}',
                            '更新：$updated'
                          ].join('｜')),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') await _edit(filtered[i].id);
                              if (v == 'toggle') await _toggleActive(filtered[i]);
                              if (v == 'delete') await _delete(filtered[i]);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('編輯')),
                              PopupMenuItem(
                                  value: 'toggle', child: Text(active ? '下架' : '上架')),
                              const PopupMenuItem(value: 'delete', child: Text('刪除')),
                            ],
                          ),
                          onTap: () => _edit(filtered[i].id),
                        ),
                      );
                    },
                  ),
                  if (_busyReorder)
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Material(
                        elevation: 10,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Row(
                            children: [
                              SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('更新排序中...',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜尋問題或答案',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _keyword = v),
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: _category,
            items: ['全部', '一般', '帳號', '付款', '其他']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? '全部'),
          ),
          const SizedBox(width: 10),
          IconButton(onPressed: _create, icon: const Icon(Icons.add_outlined)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// ✅ BottomSheet：編輯 FAQ 資料
// ------------------------------------------------------------
class _FaqEditSheet extends StatefulWidget {
  final String id;
  const _FaqEditSheet({required this.id});

  @override
  State<_FaqEditSheet> createState() => _FaqEditSheetState();
}

class _FaqEditSheetState extends State<_FaqEditSheet> {
  final _db = FirebaseFirestore.instance;
  final _qCtrl = TextEditingController();
  final _aCtrl = TextEditingController();
  final _catCtrl = TextEditingController();
  bool _active = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await _db.collection('faq_items').doc(widget.id).get();
    if (doc.exists) {
      final d = doc.data()!;
      _qCtrl.text = (d['question'] ?? '').toString();
      _aCtrl.text = (d['answer'] ?? '').toString();
      _catCtrl.text = (d['category'] ?? '').toString();
      _active = d['isActive'] == true;
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _db.collection('faq_items').doc(widget.id).set({
        'question': _qCtrl.text.trim(),
        'answer': _aCtrl.text.trim(),
        'category': _catCtrl.text.trim(),
        'isActive': _active,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SafeArea(child: Center(child: CircularProgressIndicator()));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text('編輯 FAQ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              TextField(controller: _qCtrl, decoration: const InputDecoration(labelText: '問題')),
              const SizedBox(height: 8),
              TextField(controller: _aCtrl, maxLines: 4, decoration: const InputDecoration(labelText: '答案')),
              const SizedBox(height: 8),
              TextField(controller: _catCtrl, decoration: const InputDecoration(labelText: '分類')),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('上架'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('儲存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// ✅ 聯絡我們設定區塊
// ------------------------------------------------------------
class _SupportSettings extends StatefulWidget {
  @override
  State<_SupportSettings> createState() => _SupportSettingsState();
}

class _SupportSettingsState extends State<_SupportSettings> {
  final _db = FirebaseFirestore.instance;
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await _db.collection('site_settings').doc('support').get();
    if (doc.exists) {
      final d = doc.data()!;
      _emailCtrl.text = (d['email'] ?? '').toString();
      _phoneCtrl.text = (d['phone'] ?? '').toString();
      _hoursCtrl.text = (d['workingHours'] ?? '').toString();
      _noteCtrl.text = (d['formNote'] ?? '').toString();
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _db.collection('site_settings').doc('support').set({
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'workingHours': _hoursCtrl.text.trim(),
        'formNote': _noteCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已儲存設定')));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text('客服聯絡設定', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: '客服信箱')),
          const SizedBox(height: 8),
          TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: '電話')),
          const SizedBox(height: 8),
          TextField(controller: _hoursCtrl, decoration: const InputDecoration(labelText: '服務時間')),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '表單提示文字（顯示於前台）'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('儲存設定'),
          ),
        ],
      ),
    );
  }
}
