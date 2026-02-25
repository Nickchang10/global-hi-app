import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ AIContextCenterPage（AI 情境中心｜最終完整版｜可編譯）
/// ------------------------------------------------------------
/// Firestore:
/// - users/{uid}/ai_contexts/{contextId}
///
/// 欄位建議：
/// - title (String)
/// - content (String)
/// - isActive (bool)
/// - createdAt / updatedAt (Timestamp)
///
/// ✅ Lints:
/// - curly_braces_in_flow_control_structures：if 一律大括號
/// - withOpacity deprecated：改用 withValues(alpha: ...)
/// - use_build_context_synchronously：async 前先取 messenger 並 mounted 防護
/// - prefer_const_constructors：可 const 的地方補 const
class AIContextCenterPage extends StatefulWidget {
  const AIContextCenterPage({super.key});

  @override
  State<AIContextCenterPage> createState() => _AIContextCenterPageState();
}

class _AIContextCenterPageState extends State<AIContextCenterPage> {
  final _fs = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _onlyActive = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _fs.collection('users').doc(uid).collection('ai_contexts');

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamPrimary(String uid) {
    return _col(
      uid,
    ).orderBy('updatedAt', descending: true).limit(200).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamFallback(String uid) {
    return _col(
      uid,
    ).orderBy('createdAt', descending: true).limit(200).snapshots();
  }

  bool _match(AIContextDoc c) {
    if (_onlyActive && !c.isActive) {
      return false;
    }
    if (_query.trim().isEmpty) {
      return true;
    }
    final q = _query.toLowerCase().trim();
    return c.title.toLowerCase().contains(q) ||
        c.content.toLowerCase().contains(q);
  }

  Future<void> _openEditor({required String uid, AIContextDoc? editing}) async {
    final messenger = ScaffoldMessenger.of(context); // ✅ async 前先取出

    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ContextEditSheet(uid: uid, initial: editing),
    );

    if (!mounted) {
      return;
    }
    if (result == null) {
      return;
    }

    if (result == _EditResult.created) {
      messenger.showSnackBar(const SnackBar(content: Text('已新增情境')));
    } else if (result == _EditResult.updated) {
      messenger.showSnackBar(const SnackBar(content: Text('已更新情境')));
    }

    // ✅ 修正：NavigatorState 沒有 focusScopeNode
    // 用 FocusManager 不依賴 context / navigator
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _delete({required String uid, required AIContextDoc doc}) async {
    final messenger = ScaffoldMessenger.of(context); // ✅ async 前先取出

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除情境'),
        content: Text('確定要刪除「${doc.title}」嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) {
      return;
    }

    try {
      await _col(uid).doc(doc.id).delete();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(const SnackBar(content: Text('已刪除情境')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  /// ✅ 設為啟用（同時取消其他啟用）
  Future<void> _setActive({
    required String uid,
    required AIContextDoc target,
  }) async {
    final messenger = ScaffoldMessenger.of(context); // ✅ async 前先取出

    try {
      final snap = await _col(uid).get();
      final batch = _fs.batch();
      final now = FieldValue.serverTimestamp();

      for (final d in snap.docs) {
        final data = d.data();
        final isActive = (data['isActive'] ?? false) == true;

        if (d.id == target.id) {
          batch.set(d.reference, <String, dynamic>{
            'isActive': true,
            'updatedAt': now,
          }, SetOptions(merge: true));
        } else {
          if (isActive) {
            batch.set(d.reference, <String, dynamic>{
              'isActive': false,
              'updatedAt': now,
            }, SetOptions(merge: true));
          }
        }
      }

      await batch.commit();

      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('已啟用：${target.title}')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('設定失敗：$e')));
    }
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  /// ✅ prefer_const_constructors（198~221）集中區：全部補 explicit const
  Widget _headerCard() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        elevation: 1,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(child: Icon(Icons.tune)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '在這裡設定 AI 助理的「情境/偏好」。\n'
                  '例如：主要客群、預算範圍、偏好功能、常見問答口吻。\n'
                  '你可以啟用其中一筆作為目前預設情境。',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜尋：標題 / 內容關鍵字',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                setState(() => _query = v.trim());
              },
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              const Text('只看啟用', style: TextStyle(fontSize: 12)),
              Switch(
                value: _onlyActive,
                onChanged: (v) {
                  setState(() => _onlyActive = v);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String uid) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.note_add_outlined, size: 72, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('尚未建立任何情境', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _openEditor(uid: uid),
              icon: const Icon(Icons.add),
              label: const Text('新增第一筆情境'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listPrimary(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _streamPrimary(uid),
      builder: (context, snap) {
        if (snap.hasError) {
          return _listFallback(uid);
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snap.data!.docs
            .map((d) => AIContextDoc.fromDoc(d))
            .where(_match)
            .toList();

        if (items.isEmpty) {
          return _emptyState(uid);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _card(uid, items[i]),
        );
      },
    );
  }

  Widget _listFallback(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _streamFallback(uid),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('讀取失敗：${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snap.data!.docs
            .map((d) => AIContextDoc.fromDoc(d))
            .where(_match)
            .toList();

        if (items.isEmpty) {
          return _emptyState(uid);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _card(uid, items[i]),
        );
      },
    );
  }

  Widget _card(String uid, AIContextDoc c) {
    final preview = c.content.trim();
    final showPreview = preview.isEmpty ? '（無內容）' : preview;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.title.isEmpty ? '(未命名情境)' : c.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (c.isActive)
                  _pill('啟用中', Colors.green)
                else
                  _pill('未啟用', Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              showPreview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openEditor(uid: uid, editing: c),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('編輯'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _delete(uid: uid, doc: c),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('刪除'),
                ),
                const Spacer(),
                if (!c.isActive)
                  TextButton(
                    onPressed: () => _setActive(uid: uid, target: c),
                    child: const Text('設為啟用'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI 情境中心')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('請先登入才能使用', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushNamed('/login'),
                  child: const Text('前往登入'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final uid = user.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 情境中心'),
        actions: [
          IconButton(
            tooltip: '新增情境',
            onPressed: () => _openEditor(uid: uid),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          _headerCard(),
          _toolBar(),
          const Divider(height: 1),
          Expanded(child: _listPrimary(uid)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(uid: uid),
        icon: const Icon(Icons.add),
        label: const Text('新增情境'),
      ),
    );
  }
}

enum _EditResult { created, updated }

class _ContextEditSheet extends StatefulWidget {
  const _ContextEditSheet({required this.uid, this.initial});

  final String uid;
  final AIContextDoc? initial;

  @override
  State<_ContextEditSheet> createState() => _ContextEditSheetState();
}

class _ContextEditSheetState extends State<_ContextEditSheet> {
  final _fs = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _content;

  bool _isActive = false;
  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  CollectionReference<Map<String, dynamic>> _col() =>
      _fs.collection('users').doc(widget.uid).collection('ai_contexts');

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial?.title ?? '');
    _content = TextEditingController(text: widget.initial?.content ?? '');
    _isActive = widget.initial?.isActive ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  String? _required(String? v) {
    if (v == null || v.trim().isEmpty) {
      return '此欄位必填';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) {
      return;
    }

    final navigator = Navigator.of(context); // ✅ async 前先取出
    final messenger = ScaffoldMessenger.of(context); // ✅ async 前先取出

    setState(() => _saving = true);

    try {
      final now = FieldValue.serverTimestamp();
      final id = widget.initial?.id ?? _col().doc().id;

      if (_isActive) {
        final snap = await _col().get();
        final batch = _fs.batch();

        for (final d in snap.docs) {
          final data = d.data();
          final isActive = (data['isActive'] ?? false) == true;

          if (d.id == id) {
            continue;
          }
          if (isActive) {
            batch.set(d.reference, <String, dynamic>{
              'isActive': false,
              'updatedAt': now,
            }, SetOptions(merge: true));
          }
        }

        batch.set(_col().doc(id), <String, dynamic>{
          'title': _title.text.trim(),
          'content': _content.text.trim(),
          'isActive': true,
          'updatedAt': now,
          if (!_isEdit) 'createdAt': now,
        }, SetOptions(merge: true));

        await batch.commit();
      } else {
        await _col().doc(id).set(<String, dynamic>{
          'title': _title.text.trim(),
          'content': _content.text.trim(),
          'isActive': false,
          'updatedAt': now,
          if (!_isEdit) 'createdAt': now,
        }, SetOptions(merge: true));
      }

      if (!mounted) {
        return;
      }
      setState(() => _saving = false);

      navigator.pop(_isEdit ? _EditResult.updated : _EditResult.created);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? '編輯情境' : '新增情境',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('儲存'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: '標題',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _content,
                      decoration: const InputDecoration(
                        labelText: '內容（情境/偏好/口吻/規則）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      minLines: 4,
                      maxLines: 10,
                      validator: _required,
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isActive,
                      onChanged: _saving
                          ? null
                          : (v) {
                              setState(() => _isActive = v);
                            },
                      title: const Text('設為啟用'),
                      subtitle: const Text('啟用後會自動取消其他啟用情境（保持唯一）'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save),
                      label: Text(_isEdit ? '儲存變更' : '建立情境'),
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
}

/// ✅ AI 情境 model
class AIContextDoc {
  final String id;
  final String title;
  final String content;
  final bool isActive;

  AIContextDoc({
    required this.id,
    required this.title,
    required this.content,
    required this.isActive,
  });

  static bool _asBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is String) {
      final t = v.toLowerCase().trim();
      if (t == 'true') return true;
      if (t == 'false') return false;
    }
    return fallback;
  }

  factory AIContextDoc.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    return AIContextDoc(
      id: doc.id,
      title: (d['title'] ?? d['name'] ?? '').toString(),
      content: (d['content'] ?? d['prompt'] ?? d['text'] ?? '').toString(),
      isActive: _asBool(d['isActive'] ?? d['active'], fallback: false),
    );
  }
}
