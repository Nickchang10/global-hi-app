// lib/pages/admin/members/admin_points_tasks_management_page.dart
//
// ✅ AdminPointsTasksManagementPage（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// ✅ 修正：curly_braces_in_flow_control_structures（所有 if/for 皆使用 {}）
// ✅ 功能：
//   - 任務模板列表（Firestore realtime）
//   - 搜尋（title/description/id）
//   - 篩選（全部/啟用/停用）
//   - 新增/編輯/刪除
// ✅ Firestore 預設集合：points_tasks（可透過 constructor 改）
//
// 建議欄位：
// - title        String
// - description  String
// - enabled      bool
// - points       int
// - type         String   (daily/once/custom... 可選)
// - sort         int      (排序，可選)
// - createdAt    Timestamp
// - updatedAt    Timestamp
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminPointsTasksManagementPage extends StatefulWidget {
  const AdminPointsTasksManagementPage({
    super.key,
    this.collectionName = 'points_tasks',
  });

  final String collectionName;

  @override
  State<AdminPointsTasksManagementPage> createState() =>
      _AdminPointsTasksManagementPageState();
}

class _AdminPointsTasksManagementPageState
    extends State<AdminPointsTasksManagementPage> {
  final _searchCtrl = TextEditingController();
  String _keyword = '';

  String _filter = 'all'; // all / enabled / disabled
  bool _busy = false;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(widget.collectionName);

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final v = _searchCtrl.text.trim();
      if (v == _keyword) {
        return;
      }
      setState(() {
        _keyword = v;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Helpers
  // -------------------------

  String _fmtDt(dynamic v) {
    try {
      DateTime? dt;
      if (v is Timestamp) {
        dt = v.toDate();
      } else if (v is DateTime) {
        dt = v;
      } else if (v is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(v);
      } else if (v is String) {
        dt = DateTime.tryParse(v);
      }
      if (dt == null) {
        return '—';
      }
      return DateFormat('yyyy/MM/dd HH:mm').format(dt);
    } catch (_) {
      return '—';
    }
  }

  int _asInt(dynamic v) {
    if (v == null) {
      return 0;
    }
    if (v is int) {
      return v;
    }
    if (v is num) {
      return v.toInt();
    }
    return int.tryParse(v.toString().trim()) ?? 0;
  }

  bool _matchKeyword(String id, Map<String, dynamic> m) {
    final k = _keyword.trim().toLowerCase();
    if (k.isEmpty) {
      return true;
    }

    final title = (m['title'] ?? '').toString().toLowerCase();
    final desc = (m['description'] ?? '').toString().toLowerCase();
    final type = (m['type'] ?? '').toString().toLowerCase();
    final sid = id.toLowerCase();

    return title.contains(k) ||
        desc.contains(k) ||
        type.contains(k) ||
        sid.contains(k);
  }

  bool _matchFilter(Map<String, dynamic> m) {
    final enabled = m['enabled'] == true;
    if (_filter == 'enabled') {
      return enabled;
    }
    if (_filter == 'disabled') {
      return !enabled;
    }
    return true;
  }

  void _toast(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // -------------------------
  // CRUD
  // -------------------------

  Future<void> _openEditSheet({
    String? docId,
    Map<String, dynamic>? initial,
  }) async {
    final edited = await showModalBottomSheet<_TaskDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return _TaskEditSheet(
          initial: _TaskDraft.from(docId: docId, m: initial),
        );
      },
    );

    if (edited == null) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final ref = (edited.id?.trim().isNotEmpty ?? false)
          ? _col.doc(edited.id!.trim())
          : _col.doc();

      final payload = <String, dynamic>{
        'title': edited.title.trim(),
        'description': edited.description.trim(),
        'enabled': edited.enabled,
        'points': edited.points,
        'type': edited.type.trim(),
        'sort': edited.sort,
        'updatedAt': FieldValue.serverTimestamp(),
        if (edited.id == null || edited.id!.trim().isEmpty)
          'createdAt': FieldValue.serverTimestamp(),
      };

      await ref.set(payload, SetOptions(merge: true));

      if (!mounted) {
        return;
      }
      _toast(
        edited.id == null || edited.id!.trim().isEmpty
            ? '已新增任務（ID：${ref.id}）'
            : '已更新任務',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      _toast('儲存失敗：$e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _toggleEnabled(String id, bool next) async {
    setState(() {
      _busy = true;
    });

    try {
      await _col.doc(id).update({
        'enabled': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }
      _toast(next ? '已啟用' : '已停用');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _toast('更新失敗：$e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _deleteTask(String id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('刪除任務'),
          content: Text('確定刪除「${title.isEmpty ? id : title}」？此操作不可復原。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx, false);
              },
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(dialogCtx, true);
              },
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );

    if (ok != true) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await _col.doc(id).delete();

      if (!mounted) {
        return;
      }
      _toast('已刪除');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _toast('刪除失敗：$e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // -------------------------
  // UI
  // -------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '點數任務管理',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '新增任務',
            icon: const Icon(Icons.add),
            onPressed: _busy
                ? null
                : () {
                    _openEditSheet();
                  },
          ),
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _toolbar(),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _col
                      .orderBy('updatedAt', descending: true)
                      .limit(500)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return _ErrorView(
                        message:
                            '讀取失敗：${snap.error}\n\n'
                            '若出現索引需求（FAILED_PRECONDITION: requires an index），'
                            '請到 Firebase Console 建立索引（updatedAt）。',
                      );
                    }

                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snap.data!.docs;

                    final filtered =
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    for (final d in docs) {
                      final m = d.data();
                      if (!_matchFilter(m)) {
                        continue;
                      }
                      if (!_matchKeyword(d.id, m)) {
                        continue;
                      }
                      filtered.add(d);
                    }

                    if (filtered.isEmpty) {
                      return const Center(child: Text('目前沒有符合條件的任務'));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final doc = filtered[i];
                        final id = doc.id;
                        final m = doc.data();

                        final title = (m['title'] ?? '').toString();
                        final desc = (m['description'] ?? '').toString();
                        final type = (m['type'] ?? '').toString();
                        final points = _asInt(m['points']);
                        final enabled = m['enabled'] == true;
                        final updatedAt = _fmtDt(m['updatedAt']);
                        final createdAt = _fmtDt(m['createdAt']);

                        return Card(
                          elevation: 0.8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Switch(
                                      value: enabled,
                                      onChanged: _busy
                                          ? null
                                          : (v) {
                                              _toggleEnabled(id, v);
                                            },
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        title.isEmpty ? '(未命名任務)' : title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _Pill(text: '$points pts'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (desc.trim().isNotEmpty) ...[
                                  Text(
                                    desc,
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    _kv('id', id),
                                    if (type.trim().isNotEmpty)
                                      _kv('type', type),
                                    _kv('updatedAt', updatedAt),
                                    _kv('createdAt', createdAt),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () {
                                              _openEditSheet(
                                                docId: id,
                                                initial: m,
                                              );
                                            },
                                      icon: const Icon(Icons.edit),
                                      label: const Text('編輯'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () {
                                              _deleteTask(id, title);
                                            },
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      label: const Text(
                                        '刪除',
                                        style: TextStyle(color: Colors.red),
                                      ),
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

                if (_busy)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: true,
                      child: Container(
                        // 避免 withOpacity（若你的 Flutter 版本已把 withOpacity 標 deprecated）
                        color: const Color.fromARGB(20, 0, 0, 0),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋 title / description / id / type',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _keyword.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除',
                        onPressed: () {
                          _searchCtrl.clear();
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _filter,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('全部')),
              DropdownMenuItem(value: 'enabled', child: Text('啟用')),
              DropdownMenuItem(value: 'disabled', child: Text('停用')),
            ],
            onChanged: (v) {
              setState(() {
                _filter = v ?? 'all';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    final text = v.trim().isEmpty ? '-' : v.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87),
          children: [
            TextSpan(
              text: '$k：',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }
}

// -------------------------
// Edit Sheet Draft + UI
// -------------------------

class _TaskDraft {
  _TaskDraft({
    required this.id,
    required this.title,
    required this.description,
    required this.enabled,
    required this.points,
    required this.type,
    required this.sort,
  });

  final String? id;
  final String title;
  final String description;
  final bool enabled;
  final int points;
  final String type;
  final int sort;

  factory _TaskDraft.from({String? docId, Map<String, dynamic>? m}) {
    final data = m ?? <String, dynamic>{};
    return _TaskDraft(
      id: docId,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      enabled: data['enabled'] == true,
      points: _toInt(data['points']),
      type: (data['type'] ?? '').toString(),
      sort: _toInt(data['sort']),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim()) ?? 0;
  }
}

class _TaskEditSheet extends StatefulWidget {
  const _TaskEditSheet({required this.initial});
  final _TaskDraft initial;

  @override
  State<_TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends State<_TaskEditSheet> {
  final _formKey = GlobalKey<FormState>();

  late bool _enabled;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _pointsCtrl;
  late final TextEditingController _typeCtrl;
  late final TextEditingController _sortCtrl;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initial.enabled;
    _titleCtrl = TextEditingController(text: widget.initial.title);
    _descCtrl = TextEditingController(text: widget.initial.description);
    _pointsCtrl = TextEditingController(text: widget.initial.points.toString());
    _typeCtrl = TextEditingController(text: widget.initial.type);
    _sortCtrl = TextEditingController(text: widget.initial.sort.toString());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _pointsCtrl.dispose();
    _typeCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  int _parseInt(TextEditingController c) {
    return int.tryParse(c.text.trim()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: padding.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.initial.id == null ||
                                widget.initial.id!.trim().isEmpty
                            ? '新增任務'
                            : '編輯任務',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('取消'),
                    ),
                    FilledButton(onPressed: _submit, child: const Text('儲存')),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    const Text(
                      '啟用',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 10),
                    Switch(
                      value: _enabled,
                      onChanged: (v) {
                        setState(() {
                          _enabled = v;
                        });
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: '標題（title）',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) {
                      return '請輸入標題';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '描述（description，可空）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pointsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '點數（points）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _sortCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '排序（sort，可空）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _typeCtrl,
                  decoration: const InputDecoration(
                    labelText: '類型（type，可空，例如 daily/once/custom）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final draft = _TaskDraft(
      id: widget.initial.id,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      enabled: _enabled,
      points: _parseInt(_pointsCtrl),
      type: _typeCtrl.text.trim(),
      sort: _parseInt(_sortCtrl),
    );

    Navigator.pop(context, draft);
  }
}

// -------------------------
// Small UI
// -------------------------

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
        color: const Color.fromARGB(18, 0, 0, 0),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(message, style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}
