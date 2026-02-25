// lib/pages/admin/content/admin_faq_page.dart
//
// ✅ AdminFaqPage（faqs 管理｜單檔完整版｜可編譯）
// ------------------------------------------------------------
// Firestore: collection 'faqs'
// 欄位建議：question, answer, enabled, order, createdAt, updatedAt
//

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminFaqPage extends StatefulWidget {
  const AdminFaqPage({super.key});

  static const String routeName = '/admin-content/faqs';

  @override
  State<AdminFaqPage> createState() => _AdminFaqPageState();
}

class _AdminFaqPageState extends State<AdminFaqPage> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  String _keyword = '';

  Query<Map<String, dynamic>> _query() {
    // ✅ 先 orderBy(order) 再 updatedAt 可能需要索引；為了穩：只 orderBy(updatedAt)
    return _db
        .collection('faqs')
        .orderBy('updatedAt', descending: true)
        .limit(300);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }
      setState(() => _keyword = v.trim().toLowerCase());
    });
  }

  bool _hit(Map<String, dynamic> m, String id) {
    if (_keyword.isEmpty) {
      return true;
    }
    final q = (m['question'] ?? '').toString().toLowerCase();
    final a = (m['answer'] ?? '').toString().toLowerCase();
    final pid = id.toLowerCase();
    return q.contains(_keyword) ||
        a.contains(_keyword) ||
        pid.contains(_keyword);
  }

  int _toInt(dynamic v, {int fallback = 0}) {
    if (v is int) {
      return v;
    }
    final n = int.tryParse(v?.toString() ?? '');
    return n ?? fallback;
  }

  Future<void> _openEditor({String? docId, Map<String, dynamic>? data}) async {
    final isNew = docId == null;

    final qCtrl = TextEditingController(
      text: (data?['question'] ?? '').toString(),
    );
    final aCtrl = TextEditingController(
      text: (data?['answer'] ?? '').toString(),
    );
    final orderCtrl = TextEditingController(
      text: _toInt(data?['order'], fallback: 0).toString(),
    );
    bool enabled = (data?['enabled'] ?? true) == true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? '新增 FAQ' : '編輯 FAQ'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qCtrl,
                  decoration: const InputDecoration(labelText: '問題'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: aCtrl,
                  minLines: 6,
                  maxLines: 16,
                  decoration: const InputDecoration(labelText: '答案'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: orderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '排序（order）',
                    helperText: '數字越小越前面（前台若有用到排序）',
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: enabled,
                  onChanged: (v) {
                    enabled = v;
                    (ctx as Element).markNeedsBuild();
                  },
                  title: const Text('啟用（enabled）'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('儲存'),
          ),
        ],
      ),
    );

    if (ok != true) {
      return;
    }

    final payload = <String, dynamic>{
      'question': qCtrl.text.trim(),
      'answer': aCtrl.text.trim(),
      'enabled': enabled,
      'order': _toInt(orderCtrl.text, fallback: 0),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (isNew) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        await _db.collection('faqs').add(payload);
      } else {
        await _db
            .collection('faqs')
            .doc(docId)
            .set(payload, SetOptions(merge: true));
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(isNew ? '已新增 FAQ' : '已更新 FAQ')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    }
  }

  Future<void> _delete(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除確認'),
        content: Text('確定要刪除這筆 FAQ？\n$docId'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) {
      return;
    }

    try {
      await _db.collection('faqs').doc(docId).delete();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FAQ（faqs）',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '新增',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋問題/答案/docId（本地過濾）',
                isDense: true,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchCtrl.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除',
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _keyword = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('讀取失敗：${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs
                    .where((d) => _hit(d.data(), d.id))
                    .toList(growable: false);

                if (docs.isEmpty) {
                  return const Center(child: Text('沒有資料'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final m = d.data();
                    final q = (m['question'] ?? '').toString().trim();
                    final a = (m['answer'] ?? '').toString().trim();
                    final enabled = (m['enabled'] ?? true) == true;
                    final order = _toInt(m['order'], fallback: 0);

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    q.isEmpty ? '(未填問題)' : q,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: enabled
                                        ? cs.primaryContainer
                                        : cs.surfaceContainerHighest,
                                  ),
                                  child: Text(
                                    enabled ? 'enabled' : 'disabled',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: enabled
                                          ? cs.onPrimaryContainer
                                          : cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'order:$order',
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              a.isEmpty ? '-' : a,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: () =>
                                      _openEditor(docId: d.id, data: m),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('編輯'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _delete(d.id),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('刪除'),
                                ),
                              ],
                            ),
                          ],
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
    );
  }
}
