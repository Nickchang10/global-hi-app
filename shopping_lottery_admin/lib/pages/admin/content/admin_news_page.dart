import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../layouts/scaffold_with_drawer.dart';

class AdminNewsPage extends StatefulWidget {
  const AdminNewsPage({super.key});

  static const String routeName = '/admin/news';

  @override
  State<AdminNewsPage> createState() => _AdminNewsPageState();
}

class _AdminNewsPageState extends State<AdminNewsPage> {
  final _col = FirebaseFirestore.instance.collection('news');
  bool _loading = true;
  String? _error;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snap = await _col
          .orderBy('updatedAt', descending: true)
          .limit(50)
          .get(const GetOptions(source: Source.serverAndCache));

      setState(() {
        _docs = snap.docs;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openEditor({String? docId}) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AdminNewsEditPage(docId: docId)));
    await _load();
  }

  Future<void> _delete(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除最新消息'),
        content: const Text('確定要刪除嗎？此操作無法復原。'),
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

    try {
      await _col.doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldWithDrawer(
      title: '最新消息',
      currentRoute: AdminNewsPage.routeName,
      body: Column(
        children: [
          _toolbar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _errorView()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _docs.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 60),
                              Center(child: Text('目前沒有資料')),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _docs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) => _tile(_docs[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: () => _openEditor(docId: null),
            icon: const Icon(Icons.add),
            label: const Text('新增'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新'),
          ),
          const Spacer(),
          Text(
            '${_docs.length} 筆',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 30),
        const Icon(Icons.error_outline, size: 44),
        const SizedBox(height: 12),
        const Text(
          '載入失敗',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Center(
          child: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('重試'),
          ),
        ),
      ],
    );
  }

  Widget _tile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final title = (data['title'] ?? '').toString().trim();
    final published = (data['isPublished'] == true);
    final updatedAt = data['updatedAt'];
    final updatedText = _tsText(updatedAt);

    return Card(
      elevation: 1,
      child: ListTile(
        leading: Icon(
          published ? Icons.public : Icons.visibility_off,
          color: published ? Colors.green : Colors.grey,
        ),
        title: Text(
          title.isEmpty ? '(未命名)' : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('更新：$updatedText'),
        onTap: () => _openEditor(docId: doc.id),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _openEditor(docId: doc.id);
            if (v == 'delete') _delete(doc.id);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('編輯')),
            PopupMenuItem(value: 'delete', child: Text('刪除')),
          ],
        ),
      ),
    );
  }

  String _tsText(Object? v) {
    if (v is Timestamp) {
      final dt = v.toDate();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }
}

class AdminNewsEditPage extends StatefulWidget {
  final String? docId;
  const AdminNewsEditPage({super.key, this.docId});

  @override
  State<AdminNewsEditPage> createState() => _AdminNewsEditPageState();
}

class _AdminNewsEditPageState extends State<AdminNewsEditPage> {
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _body = TextEditingController();
  final _cover = TextEditingController();

  bool _isPublished = false;
  bool _loading = true;
  bool _saving = false;

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('news').doc(widget.docId);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.docId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final snap = await _ref.get();
      final data = snap.data();
      if (data != null) {
        _title.text = (data['title'] ?? '').toString();
        _summary.text = (data['summary'] ?? '').toString();
        _body.text = (data['body'] ?? '').toString();
        _cover.text = (data['coverImageUrl'] ?? '').toString();
        _isPublished = (data['isPublished'] == true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _body.dispose();
    _cover.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final now = FieldValue.serverTimestamp();

      final data = <String, dynamic>{
        'title': _title.text.trim(),
        'summary': _summary.text.trim(),
        'body': _body.text.trim(),
        'coverImageUrl': _cover.text.trim(),
        'isPublished': _isPublished,
        'updatedAt': now,
        'updatedBy': uid,
      };

      if (widget.docId == null) {
        // create
        final doc = FirebaseFirestore.instance.collection('news').doc();
        if (_isPublished) {
          data['publishedAt'] = now;
        }
        data['createdAt'] = now;
        data['createdBy'] = uid;
        await doc.set(data, SetOptions(merge: true));
      } else {
        // update
        final snap = await _ref.get();
        final cur = snap.data() ?? {};
        if (_isPublished && cur['publishedAt'] == null) {
          data['publishedAt'] = now;
        }
        await _ref.set(data, SetOptions(merge: true));
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.docId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '編輯最新消息' : '新增最新消息'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('儲存'),
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
                  SwitchListTile(
                    value: _isPublished,
                    onChanged: (v) => setState(() => _isPublished = v),
                    title: const Text('公開'),
                    subtitle: const Text('開啟後表示對外發布（isPublished=true）'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: '標題',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '請輸入標題' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _summary,
                    decoration: const InputDecoration(
                      labelText: '摘要（可選）',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cover,
                    decoration: const InputDecoration(
                      labelText: '封面圖片 URL（可選）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _body,
                    decoration: const InputDecoration(
                      labelText: '內容',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 10,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? '儲存中...' : '儲存'),
                  ),
                ],
              ),
            ),
    );
  }
}
