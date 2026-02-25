// lib/pages/admin/members/admin_points_tasks_page.dart
//
// ✅ AdminPointsTasksPage（單檔完整版｜可編譯可用｜已移除 unreachable_switch_default）
// ------------------------------------------------------------
// 功能：
// 1) 任務總覽（collectionGroup('tasks')）
// 2) 點數流水總覽（collectionGroup('points_logs')）
// 3) 搜尋 / 篩選 / 複製 uid / 快速前往會員點數頁
//
// 注意：collectionGroup 可能需要 Firestore 索引（若你 orderBy createdAt）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminPointsTasksPage extends StatefulWidget {
  const AdminPointsTasksPage({super.key});

  @override
  State<AdminPointsTasksPage> createState() => _AdminPointsTasksPageState();
}

class _AdminPointsTasksPageState extends State<AdminPointsTasksPage>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;

  late final TabController _tab;

  // ✅ 這兩個 Tab 會被 TabBar 真正使用
  static const Tab _tabUserTasks = Tab(
    icon: Icon(Icons.task_alt_outlined),
    text: '任務總覽',
  );
  static const Tab _tabPointsLogs = Tab(
    icon: Icon(Icons.payments_outlined),
    text: '點數流水',
  );

  final _search = TextEditingController();

  TaskStatusFilter _taskFilter = TaskStatusFilter.all;
  LogTypeFilter _logFilter = LogTypeFilter.all;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _search.dispose();
    super.dispose();
  }

  String _fmtDt(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('yyyy/MM/dd HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '點數/任務總覽',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: TabBar(
          controller: _tab,
          tabs: const [_tabUserTasks, _tabPointsLogs],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: '搜尋 uid / title / reason ...',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _tab,
                        builder: (_, __) {
                          final idx = _tab.index;
                          if (idx == 0) {
                            return _TaskFilterChip(
                              value: _taskFilter,
                              onChanged: (v) => setState(() => _taskFilter = v),
                            );
                          }
                          return _LogFilterChip(
                            value: _logFilter,
                            onChanged: (v) => setState(() => _logFilter = v),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('重整'),
                      onPressed: () => setState(() {}),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [_buildTasksTab(), _buildLogsTab()],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 任務總覽：collectionGroup('tasks')
  // ============================================================

  Widget _buildTasksTab() {
    final cs = Theme.of(context).colorScheme;

    final query = _db
        .collectionGroup('tasks')
        .orderBy('createdAt', descending: true)
        .limit(300);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _ErrorView(
            title: '載入任務失敗',
            message: snap.error.toString(),
            onRetry: () => setState(() {}),
            hint: '若看到 index error，請依錯誤提示建立 Firestore index。',
          );
        }

        final docs = snap.data?.docs ?? const [];
        final all = docs.map((d) => AdminUserTask.fromDoc(d)).toList();

        final filtered = _filterTasks(all, _search.text, _taskFilter);

        if (filtered.isEmpty) {
          return const _EmptyView(title: '沒有符合條件的任務', message: '請調整搜尋或篩選條件。');
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            final t = filtered[i];
            final done = t.status == 'done';

            final pillBg = done
                ? Colors.green.shade100
                : Colors.orange.shade100;
            final pillFg = done
                ? Colors.green.shade900
                : Colors.orange.shade900;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? Colors.green : Colors.orange,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.title.isEmpty ? '(未命名任務)' : t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        done ? '已完成' : '未完成',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: pillFg,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  'uid=${t.uid.isEmpty ? "—" : t.uid}  •  points=${t.points}\n'
                  'createdAt=${_fmtDt(t.createdAt)}  •  doneAt=${_fmtDt(t.doneAt)}',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: '更多',
                  onSelected: (v) {
                    if (v == 'copy_uid') _copy(t.uid);
                    if (v == 'open_user') _openMember(t.uid);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'copy_uid',
                      child: Row(
                        children: [
                          Icon(Icons.copy),
                          SizedBox(width: 10),
                          Text('複製 uid'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'open_user',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new),
                          SizedBox(width: 10),
                          Text('前往會員'),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: () => _openMember(t.uid),
              ),
            );
          },
        );
      },
    );
  }

  List<AdminUserTask> _filterTasks(
    List<AdminUserTask> list,
    String keyword,
    TaskStatusFilter filter,
  ) {
    final q = keyword.trim().toLowerCase();
    Iterable<AdminUserTask> out = list;

    if (filter == TaskStatusFilter.done) {
      out = out.where((e) => e.status == 'done');
    } else if (filter == TaskStatusFilter.pending) {
      out = out.where((e) => e.status != 'done');
    }

    if (q.isNotEmpty) {
      out = out.where((e) {
        return e.uid.toLowerCase().contains(q) ||
            e.title.toLowerCase().contains(q) ||
            e.status.toLowerCase().contains(q);
      });
    }

    return out.toList();
  }

  // ============================================================
  // 點數流水：collectionGroup('points_logs')
  // ============================================================

  Widget _buildLogsTab() {
    final cs = Theme.of(context).colorScheme;

    final query = _db
        .collectionGroup('points_logs')
        .orderBy('createdAt', descending: true)
        .limit(300);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _ErrorView(
            title: '載入點數流水失敗',
            message: snap.error.toString(),
            onRetry: () => setState(() {}),
            hint: '若看到 index error，請依錯誤提示建立 Firestore index。',
          );
        }

        final docs = snap.data?.docs ?? const [];
        final all = docs.map((d) => AdminPointsLog.fromDoc(d)).toList();

        final filtered = _filterLogs(all, _search.text, _logFilter);

        if (filtered.isEmpty) {
          return const _EmptyView(title: '沒有符合條件的點數流水', message: '請調整搜尋或篩選條件。');
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            final it = filtered[i];

            final deltaColor = it.delta >= 0
                ? Colors.green.shade700
                : Colors.red.shade700;
            final badgeBg = it.delta >= 0
                ? Colors.green.shade100
                : Colors.red.shade100;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    it.delta >= 0 ? '+${it.delta}' : it.delta.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: deltaColor,
                    ),
                  ),
                ),
                title: Text(
                  it.type.isEmpty ? '(未分類)' : it.type,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'uid=${it.uid.isEmpty ? "—" : it.uid}\n'
                  'before=${it.before}  •  after=${it.after}\n'
                  'time=${_fmtDt(it.createdAt)}'
                  '${it.reason.isNotEmpty ? '\nreason=${it.reason}' : ''}',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: '更多',
                  onSelected: (v) {
                    if (v == 'copy_uid') _copy(it.uid);
                    if (v == 'open_user') _openMember(it.uid);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'copy_uid',
                      child: Row(
                        children: [
                          Icon(Icons.copy),
                          SizedBox(width: 10),
                          Text('複製 uid'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'open_user',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new),
                          SizedBox(width: 10),
                          Text('前往會員'),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: () => _openMember(it.uid),
              ),
            );
          },
        );
      },
    );
  }

  List<AdminPointsLog> _filterLogs(
    List<AdminPointsLog> list,
    String keyword,
    LogTypeFilter filter,
  ) {
    final q = keyword.trim().toLowerCase();
    Iterable<AdminPointsLog> out = list;

    if (filter != LogTypeFilter.all) {
      out = out.where((e) => e.type == filter.value);
    }

    if (q.isNotEmpty) {
      out = out.where((e) {
        return e.uid.toLowerCase().contains(q) ||
            e.type.toLowerCase().contains(q) ||
            e.reason.toLowerCase().contains(q);
      });
    }

    return out.toList();
  }

  // ============================================================
  // Actions
  // ============================================================

  Future<void> _copy(String text) async {
    if (text.trim().isEmpty) {
      _toast('空值無法複製');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    _toast('已複製：$text');
  }

  void _openMember(String uid) {
    if (uid.trim().isEmpty) {
      _toast('找不到 uid，無法前往會員頁');
      return;
    }
    Navigator.pushNamed(
      context,
      '/admin-member-points-tasks',
      arguments: {'uid': uid},
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ============================================================
// Models
// ============================================================

DateTime? _toDt(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

String _extractUidFromCollectionGroupPath(String path) {
  // users/{uid}/tasks/{id}  or users/{uid}/points_logs/{id}
  final parts = path.split('/');
  final idx = parts.indexOf('users');
  if (idx >= 0 && idx + 1 < parts.length) return parts[idx + 1];
  return '';
}

class AdminUserTask {
  final String id;
  final String uid;
  final String title;
  final String status;
  final int points;
  final DateTime? createdAt;
  final DateTime? doneAt;

  AdminUserTask({
    required this.id,
    required this.uid,
    required this.title,
    required this.status,
    required this.points,
    required this.createdAt,
    required this.doneAt,
  });

  factory AdminUserTask.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? <String, dynamic>{};
    final uid = (m['uid'] ?? '').toString().trim().isNotEmpty
        ? (m['uid'] ?? '').toString()
        : _extractUidFromCollectionGroupPath(doc.reference.path);

    return AdminUserTask(
      id: doc.id,
      uid: uid,
      title: (m['title'] ?? '').toString(),
      status: (m['status'] ?? 'pending').toString(),
      points: _toInt(m['points']),
      createdAt: _toDt(m['createdAt']),
      doneAt: _toDt(m['doneAt']),
    );
  }
}

class AdminPointsLog {
  final String id;
  final String uid;
  final String type;
  final int delta;
  final int before;
  final int after;
  final String reason;
  final DateTime? createdAt;

  AdminPointsLog({
    required this.id,
    required this.uid,
    required this.type,
    required this.delta,
    required this.before,
    required this.after,
    required this.reason,
    required this.createdAt,
  });

  factory AdminPointsLog.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? <String, dynamic>{};
    final uid = (m['uid'] ?? '').toString().trim().isNotEmpty
        ? (m['uid'] ?? '').toString()
        : _extractUidFromCollectionGroupPath(doc.reference.path);

    return AdminPointsLog(
      id: doc.id,
      uid: uid,
      type: (m['type'] ?? '').toString(),
      delta: _toInt(m['delta']),
      before: _toInt(m['before']),
      after: _toInt(m['after']),
      reason: (m['reason'] ?? '').toString(),
      createdAt: _toDt(m['createdAt']),
    );
  }
}

// ============================================================
// Filters
// ============================================================

enum TaskStatusFilter { all, pending, done }

enum LogTypeFilter {
  all,
  earn,
  spend,

  // ✅ 修正：enum value 必須 lowerCamelCase
  // Firestore 字串仍維持 'admin_manual_adjust'
  adminManualAdjust,

  other;

  String get label {
    switch (this) {
      case LogTypeFilter.all:
        return '全部';
      case LogTypeFilter.earn:
        return 'earn';
      case LogTypeFilter.spend:
        return 'spend';
      case LogTypeFilter.adminManualAdjust:
        return 'admin_manual_adjust';
      case LogTypeFilter.other:
        return 'other';
    }
  }

  String? get value {
    switch (this) {
      case LogTypeFilter.all:
        return null;
      case LogTypeFilter.earn:
        return 'earn';
      case LogTypeFilter.spend:
        return 'spend';
      case LogTypeFilter.adminManualAdjust:
        return 'admin_manual_adjust';
      case LogTypeFilter.other:
        return 'other';
    }
  }
}

class _TaskFilterChip extends StatelessWidget {
  final TaskStatusFilter value;
  final ValueChanged<TaskStatusFilter> onChanged;

  const _TaskFilterChip({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // ✅ 移除 default（enum 已全覆蓋）
    String label(TaskStatusFilter f) {
      switch (f) {
        case TaskStatusFilter.pending:
          return '未完成';
        case TaskStatusFilter.done:
          return '已完成';
        case TaskStatusFilter.all:
          return '全部';
      }
    }

    return Row(
      children: [
        const Icon(Icons.filter_alt_outlined),
        const SizedBox(width: 8),
        DropdownButton<TaskStatusFilter>(
          value: value,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: TaskStatusFilter.values
              .map((f) => DropdownMenuItem(value: f, child: Text(label(f))))
              .toList(),
        ),
      ],
    );
  }
}

class _LogFilterChip extends StatelessWidget {
  final LogTypeFilter value;
  final ValueChanged<LogTypeFilter> onChanged;

  const _LogFilterChip({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.filter_alt_outlined),
        const SizedBox(width: 8),
        DropdownButton<LogTypeFilter>(
          value: value,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: LogTypeFilter.values
              .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
              .toList(),
        ),
      ],
    );
  }
}

// ============================================================
// Common Views
// ============================================================

class _EmptyView extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyView({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 44, color: cs.primary),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String? hint;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 44, color: cs.error),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                  if (hint != null) ...[
                    const SizedBox(height: 10),
                    Text(hint!, style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重試'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
