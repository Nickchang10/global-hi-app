// lib/pages/admin/members/admin_points_tasks_page.dart
//
// ✅ AdminPointsTasksPage（積分 / 任務管理｜專業單檔完整版｜可編譯）
// ------------------------------------------------------------
// 目標：把「會員管理 → 積分 / 任務」一次做成後台可用版本（Web/桌面/手機皆可）
//
// 功能一覽
// 1) 任務模板管理（tasks）
//    - 新增 / 編輯 / 啟用停用 / 刪除
//    - 欄位：title/description/points/category/repeat/status/startAt/endAt
//    - 一鍵指派給指定 userId（建立 user_tasks）
//
// 2) 會員任務管理（user_tasks）
//    - 檢視所有會員任務、狀態篩選、搜尋
//    - 審核：核准(發點) / 駁回 / 重設回 assigned
//    - 核准時：transaction 同步寫入 users.points + points_ledger
//
// 3) 積分流水（points_ledger）
//    - 檢視流水、類型/日期篩選、搜尋
//    - 手動調整積分（正負皆可）：同步 users.points + points_ledger
//
// ------------------------------------------------------------
// Firestore 建議結構（可彈性）
// tasks/{taskId}
// {
//   title: string,
//   description: string,
//   points: number,
//   category: string,
//   repeat: "once"|"daily"|"weekly"|"monthly",
//   status: "active"|"inactive",
//   startAt: Timestamp?,
//   endAt: Timestamp?,
//   createdAt: Timestamp,
//   updatedAt: Timestamp,
// }
//
// user_tasks/{userTaskId}
// {
//   userId: string,
//   userName: string?,
//   taskId: string,
//   taskTitle: string,
//   points: number,
//   status: "assigned"|"submitted"|"approved"|"rejected",
//   note: string?,
//   proof: map? (可放 orderId/screenshotUrl 等),
//   assignedAt: Timestamp,
//   submittedAt: Timestamp?,
//   reviewedAt: Timestamp?,
//   reviewerId: string?,
//   reviewerName: string?,
// }
//
// points_ledger/{ledgerId}
// {
//   userId: string,
//   userName: string?,
//   delta: number,                // +加分 / -扣分
//   type: "task_reward"|"manual_adjust"|"correction",
//   reason: string,
//   ref: map? (taskId/userTaskId/orderId...)
//   createdAt: Timestamp,
//   createdBy: string?,
//   createdByName: string?,
// }
//
// users/{userId}
// {
//   points: number,   // 建議整數
//   name: string?,
//   phone: string?,
//   email: string?,
//   ...
// }
//
// ------------------------------------------------------------
// ⚠️ 注意：你的 Firestore rules 需要允許後台讀寫 tasks/user_tasks/points_ledger
// （通常 isAdmin() 允許即可）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminPointsTasksPage extends StatefulWidget {
  const AdminPointsTasksPage({super.key});

  @override
  State<AdminPointsTasksPage> createState() => _AdminPointsTasksPageState();
}

class _AdminPointsTasksPageState extends State<AdminPointsTasksPage> {
  final _db = FirebaseFirestore.instance;

  // ========= Tabs =========
  static const _tabTasks = 0;
  static const _tabUserTasks = 1;
  static const _tabLedger = 2;

  int _tabIndex = 0;
  bool _loading = false;

  // ========= Shared formatters =========
  final _moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
  final _dtFmt = DateFormat('yyyy/MM/dd HH:mm');

  // ========= Task templates filters =========
  final _taskSearch = TextEditingController();
  static const String _taskStatusAll = 'all';
  static const String _taskStatusActive = 'active';
  static const String _taskStatusInactive = 'inactive';
  String _taskStatus = _taskStatusAll;

  static const String _repeatAll = 'all';
  static const String _repeatOnce = 'once';
  static const String _repeatDaily = 'daily';
  static const String _repeatWeekly = 'weekly';
  static const String _repeatMonthly = 'monthly';
  String _taskRepeat = _repeatAll;

  // ========= User tasks filters =========
  final _userTaskSearch = TextEditingController();
  static const String _utAll = 'all';
  static const String _utAssigned = 'assigned';
  static const String _utSubmitted = 'submitted';
  static const String _utApproved = 'approved';
  static const String _utRejected = 'rejected';
  String _userTaskStatus = _utAll;

  DateTimeRange? _userTaskRange; // assignedAt 範圍（可選）

  // ========= Ledger filters =========
  final _ledgerSearch = TextEditingController();
  static const String _ledgerTypeAll = 'all';
  static const String _ledgerTask = 'task_reward';
  static const String _ledgerManual = 'manual_adjust';
  static const String _ledgerCorrection = 'correction';
  String _ledgerType = _ledgerTypeAll;

  DateTimeRange? _ledgerRange; // createdAt 範圍（可選）

  @override
  void dispose() {
    _taskSearch.dispose();
    _userTaskSearch.dispose();
    _ledgerSearch.dispose();
    super.dispose();
  }

  // ============================================================
  // Build
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('積分 / 任務管理', style: TextStyle(fontWeight: FontWeight.w900)),
          bottom: TabBar(
            onTap: (i) => setState(() => _tabIndex = i),
            tabs: const [
              Tab(text: '任務模板'),
              Tab(text: '會員任務'),
              Tab(text: '積分流水'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '重新整理',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : () => setState(() {}),
            ),
          ],
        ),
        body: Stack(
          children: [
            TabBarView(
              children: [
                _buildTaskTemplatesTab(),
                _buildUserTasksTab(),
                _buildLedgerTab(),
              ],
            ),
            if (_loading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.06),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
        floatingActionButton: _buildFab(),
      ),
    );
  }

  Widget? _buildFab() {
    if (_tabIndex == _tabTasks) {
      return FloatingActionButton.extended(
        onPressed: _loading ? null : _createTaskDialog,
        icon: const Icon(Icons.add),
        label: const Text('新增任務模板'),
      );
    }
    if (_tabIndex == _tabLedger) {
      return FloatingActionButton.extended(
        onPressed: _loading ? null : _manualAdjustDialog,
        icon: const Icon(Icons.tune),
        label: const Text('手動調整積分'),
      );
    }
    return null;
  }

  // ============================================================
  // Tab 1 - Task templates
  // ============================================================
  Widget _buildTaskTemplatesTab() {
    final q = _db.collection('tasks').orderBy('updatedAt', descending: true).limit(300);

    return Column(
      children: [
        _taskFiltersBar(),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: q.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return _ErrorView(
                  title: '載入任務模板失敗',
                  message: '${snap.error}',
                  onRetry: () => setState(() {}),
                  hint: '請確認 tasks 集合存在、updatedAt 欄位存在且為 Timestamp，並檢查 Firestore rules 權限。',
                );
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return const _EmptyView(title: '目前沒有任務模板');

              final filtered = docs.where((d) {
                final m = d.data();
                final title = _asString(m['title']).toLowerCase();
                final cat = _asString(m['category']).toLowerCase();
                final desc = _asString(m['description']).toLowerCase();
                final status = _asString(m['status']).toLowerCase();
                final repeat = _asString(m['repeat']).toLowerCase();

                final s = _taskSearch.text.trim().toLowerCase();
                final matchSearch = s.isEmpty || title.contains(s) || cat.contains(s) || desc.contains(s);

                final matchStatus = switch (_taskStatus) {
                  _taskStatusAll => true,
                  _taskStatusActive => status == _taskStatusActive,
                  _taskStatusInactive => status == _taskStatusInactive,
                  _ => true,
                };

                final matchRepeat = (_taskRepeat == _repeatAll) ? true : repeat == _taskRepeat;
                return matchSearch && matchStatus && matchRepeat;
              }).toList();

              if (filtered.isEmpty) {
                return const _EmptyView(title: '沒有符合條件的任務模板');
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final doc = filtered[i];
                  final d = doc.data();
                  return _taskTile(doc.id, d);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _taskFiltersBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 820;

          final search = TextField(
            controller: _taskSearch,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜尋任務（標題 / 分類 / 描述）',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          final status = DropdownButtonFormField<String>(
            isExpanded: true,
            value: _taskStatus,
            onChanged: (v) => setState(() => _taskStatus = v ?? _taskStatusAll),
            decoration: InputDecoration(
              labelText: '狀態',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: _taskStatusAll, child: Text('全部')),
              DropdownMenuItem(value: _taskStatusActive, child: Text('啟用')),
              DropdownMenuItem(value: _taskStatusInactive, child: Text('停用')),
            ],
          );

          final repeat = DropdownButtonFormField<String>(
            isExpanded: true,
            value: _taskRepeat,
            onChanged: (v) => setState(() => _taskRepeat = v ?? _repeatAll),
            decoration: InputDecoration(
              labelText: '週期',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: _repeatAll, child: Text('全部')),
              DropdownMenuItem(value: _repeatOnce, child: Text('一次性')),
              DropdownMenuItem(value: _repeatDaily, child: Text('每日')),
              DropdownMenuItem(value: _repeatWeekly, child: Text('每週')),
              DropdownMenuItem(value: _repeatMonthly, child: Text('每月')),
            ],
          );

          if (narrow) {
            return Column(
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: status),
                    const SizedBox(width: 10),
                    Expanded(child: repeat),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 4, child: search),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: status),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: repeat),
            ],
          );
        },
      ),
    );
  }

  Widget _taskTile(String id, Map<String, dynamic> d) {
    final cs = Theme.of(context).colorScheme;

    final title = _asString(d['title']).trim();
    final desc = _asString(d['description']).trim();
    final points = _asInt(d['points']);
    final category = _asString(d['category']).trim();
    final repeat = _asString(d['repeat']).trim().toLowerCase();
    final status = _asString(d['status']).trim().toLowerCase();

    final startAt = _toDateTime(d['startAt']);
    final endAt = _toDateTime(d['endAt']);
    final window = (startAt == null && endAt == null)
        ? '不限期間'
        : '${startAt == null ? '—' : DateFormat('yyyy/MM/dd').format(startAt)}'
            ' ～ ${endAt == null ? '—' : DateFormat('yyyy/MM/dd').format(endAt)}';

    final active = status != _taskStatusInactive;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title.isEmpty ? '(未命名任務)' : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            _pill(
              text: active ? '啟用' : '停用',
              fg: active ? Colors.green.shade800 : cs.onSurfaceVariant,
              bg: active ? Colors.green.shade100 : cs.surfaceContainerHighest,
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _miniTag('點數', '$points'),
                  _miniTag('分類', category.isEmpty ? '—' : category),
                  _miniTag('週期', _repeatLabel(repeat)),
                  _miniTag('期間', window),
                ],
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: '操作',
          onSelected: (k) => _onTaskAction(k, id, d),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('編輯')),
            const PopupMenuItem(value: 'assign', child: Text('指派給會員')),
            PopupMenuItem(value: active ? 'disable' : 'enable', child: Text(active ? '停用' : '啟用')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'delete', child: Text('刪除')),
          ],
        ),
        onTap: () => _taskDetailDialog(id, d),
      ),
    );
  }

  Future<void> _onTaskAction(String key, String taskId, Map<String, dynamic> task) async {
    switch (key) {
      case 'edit':
        await _editTaskDialog(taskId, task);
        return;
      case 'assign':
        await _assignTaskDialog(taskId, task);
        return;
      case 'enable':
        await _setTaskActive(taskId, true);
        return;
      case 'disable':
        await _setTaskActive(taskId, false);
        return;
      case 'delete':
        await _deleteTaskDialog(taskId, task);
        return;
    }
  }

  // ============================================================
  // Tab 2 - User tasks
  // ============================================================
  Widget _buildUserTasksTab() {
    // 盡量避免複合索引：只 orderBy assignedAt；其他用 client filter
    final q = _db.collection('user_tasks').orderBy('assignedAt', descending: true).limit(400);

    return Column(
      children: [
        _userTasksFiltersBar(),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: q.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return _ErrorView(
                  title: '載入會員任務失敗',
                  message: '${snap.error}',
                  onRetry: () => setState(() {}),
                  hint: '請確認 user_tasks 集合存在、assignedAt 欄位為 Timestamp、並檢查 Firestore rules。',
                );
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return const _EmptyView(title: '目前沒有會員任務');

              final filtered = docs.where((doc) {
                final d = doc.data();
                final status = _asString(d['status']).toLowerCase();
                final userId = _asString(d['userId']).toLowerCase();
                final userName = _asString(d['userName']).toLowerCase();
                final taskTitle = _asString(d['taskTitle']).toLowerCase();
                final note = _asString(d['note']).toLowerCase();

                final s = _userTaskSearch.text.trim().toLowerCase();
                final matchSearch = s.isEmpty ||
                    userId.contains(s) ||
                    userName.contains(s) ||
                    taskTitle.contains(s) ||
                    note.contains(s);

                final matchStatus = (_userTaskStatus == _utAll) ? true : status == _userTaskStatus;

                final assignedAt = _toDateTime(d['assignedAt']);
                final matchRange = () {
                  final r = _userTaskRange;
                  if (r == null || assignedAt == null) return true;
                  return !assignedAt.isBefore(r.start) && !assignedAt.isAfter(r.end);
                }();

                return matchSearch && matchStatus && matchRange;
              }).toList();

              if (filtered.isEmpty) return const _EmptyView(title: '沒有符合條件的會員任務');

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final doc = filtered[i];
                  return _userTaskTile(doc);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _userTasksFiltersBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 920;

          final search = TextField(
            controller: _userTaskSearch,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜尋（userId / userName / 任務 / 備註）',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          final status = DropdownButtonFormField<String>(
            isExpanded: true,
            value: _userTaskStatus,
            onChanged: (v) => setState(() => _userTaskStatus = v ?? _utAll),
            decoration: InputDecoration(
              labelText: '狀態',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: _utAll, child: Text('全部')),
              DropdownMenuItem(value: _utAssigned, child: Text('已指派')),
              DropdownMenuItem(value: _utSubmitted, child: Text('已提交')),
              DropdownMenuItem(value: _utApproved, child: Text('已核准')),
              DropdownMenuItem(value: _utRejected, child: Text('已駁回')),
            ],
          );

          final rangeBtn = OutlinedButton.icon(
            onPressed: _pickUserTaskRange,
            icon: const Icon(Icons.date_range),
            label: Text(_userTaskRange == null ? 'assignedAt 範圍' : _fmtRange(_userTaskRange!)),
          );

          final clearBtn = TextButton(
            onPressed: _userTaskRange == null
                ? null
                : () => setState(() {
                      _userTaskRange = null;
                    }),
            child: const Text('清除'),
          );

          if (narrow) {
            return Column(
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: status),
                    const SizedBox(width: 10),
                    Expanded(child: rangeBtn),
                    const SizedBox(width: 6),
                    clearBtn,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 5, child: search),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: status),
              const SizedBox(width: 12),
              rangeBtn,
              const SizedBox(width: 6),
              clearBtn,
            ],
          );
        },
      ),
    );
  }

  Widget _userTaskTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final cs = Theme.of(context).colorScheme;

    final userName = _asString(d['userName']).trim();
    final userId = _asString(d['userId']).trim();
    final taskTitle = _asString(d['taskTitle']).trim();
    final points = _asInt(d['points']);
    final status = _asString(d['status']).trim().toLowerCase();

    final assignedAt = _toDateTime(d['assignedAt']);
    final submittedAt = _toDateTime(d['submittedAt']);
    final reviewedAt = _toDateTime(d['reviewedAt']);

    final statusUI = _userTaskStatusPill(status);

    String timeLine = '';
    if (assignedAt != null) timeLine = '指派：${_dtFmt.format(assignedAt)}';
    if (submittedAt != null) timeLine = '$timeLine  •  提交：${_dtFmt.format(submittedAt)}';
    if (reviewedAt != null) timeLine = '$timeLine  •  審核：${_dtFmt.format(reviewedAt)}';

    final canApprove = status == _utSubmitted || status == _utAssigned;
    final canReject = status == _utSubmitted || status == _utAssigned;
    final canReset = status == _utRejected;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        title: Row(
          children: [
            Expanded(
              child: Text(
                taskTitle.isEmpty ? '(未命名任務)' : taskTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            _pill(text: statusUI.$1, fg: statusUI.$2, bg: statusUI.$3),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${userName.isEmpty ? '未知會員' : userName}${userId.isEmpty ? '' : '  •  $userId'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _miniTag('點數', '$points'),
                  if (timeLine.isNotEmpty) _miniTag('時間', timeLine),
                ],
              ),
            ],
          ),
        ),
        trailing: SizedBox(
          width: 150,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: '詳情',
                icon: Icon(Icons.open_in_new, color: cs.primary),
                onPressed: () => _userTaskDetailDialog(doc),
              ),
              PopupMenuButton<String>(
                tooltip: '操作',
                onSelected: (k) => _onUserTaskAction(k, doc),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'detail', child: Text('查看詳情')),
                  if (canApprove) const PopupMenuItem(value: 'approve', child: Text('核准並發點')),
                  if (canReject) const PopupMenuItem(value: 'reject', child: Text('駁回')),
                  if (canReset) const PopupMenuItem(value: 'reset', child: Text('重設為已指派')),
                ],
              ),
            ],
          ),
        ),
        onTap: () => _userTaskDetailDialog(doc),
      ),
    );
  }

  Future<void> _onUserTaskAction(String key, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    switch (key) {
      case 'detail':
        await _userTaskDetailDialog(doc);
        return;
      case 'approve':
        await _approveUserTask(doc);
        return;
      case 'reject':
        await _rejectUserTaskDialog(doc);
        return;
      case 'reset':
        await _resetUserTask(doc);
        return;
    }
  }

  // ============================================================
  // Tab 3 - Ledger
  // ============================================================
  Widget _buildLedgerTab() {
    final q = _db.collection('points_ledger').orderBy('createdAt', descending: true).limit(500);

    return Column(
      children: [
        _ledgerFiltersBar(),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: q.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return _ErrorView(
                  title: '載入積分流水失敗',
                  message: '${snap.error}',
                  onRetry: () => setState(() {}),
                  hint: '請確認 points_ledger 集合存在、createdAt 欄位為 Timestamp，並檢查 Firestore rules。',
                );
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return const _EmptyView(title: '目前沒有積分流水');

              final filtered = docs.where((doc) {
                final d = doc.data();
                final userId = _asString(d['userId']).toLowerCase();
                final userName = _asString(d['userName']).toLowerCase();
                final reason = _asString(d['reason']).toLowerCase();
                final type = _asString(d['type']).toLowerCase();

                final s = _ledgerSearch.text.trim().toLowerCase();
                final matchSearch =
                    s.isEmpty || userId.contains(s) || userName.contains(s) || reason.contains(s) || type.contains(s);

                final matchType = (_ledgerType == _ledgerTypeAll) ? true : type == _ledgerType;

                final createdAt = _toDateTime(d['createdAt']);
                final matchRange = () {
                  final r = _ledgerRange;
                  if (r == null || createdAt == null) return true;
                  return !createdAt.isBefore(r.start) && !createdAt.isAfter(r.end);
                }();

                return matchSearch && matchType && matchRange;
              }).toList();

              if (filtered.isEmpty) return const _EmptyView(title: '沒有符合條件的積分流水');

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                itemCount: filtered.length,
                itemBuilder: (context, i) => _ledgerTile(filtered[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _ledgerFiltersBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 980;

          final search = TextField(
            controller: _ledgerSearch,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜尋（userId / userName / reason / type）',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          final type = DropdownButtonFormField<String>(
            isExpanded: true,
            value: _ledgerType,
            onChanged: (v) => setState(() => _ledgerType = v ?? _ledgerTypeAll),
            decoration: InputDecoration(
              labelText: '類型',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: _ledgerTypeAll, child: Text('全部')),
              DropdownMenuItem(value: _ledgerTask, child: Text('任務發點')),
              DropdownMenuItem(value: _ledgerManual, child: Text('手動調整')),
              DropdownMenuItem(value: _ledgerCorrection, child: Text('修正')),
            ],
          );

          final rangeBtn = OutlinedButton.icon(
            onPressed: _pickLedgerRange,
            icon: const Icon(Icons.date_range),
            label: Text(_ledgerRange == null ? 'createdAt 範圍' : _fmtRange(_ledgerRange!)),
          );

          final clearBtn = TextButton(
            onPressed: _ledgerRange == null
                ? null
                : () => setState(() {
                      _ledgerRange = null;
                    }),
            child: const Text('清除'),
          );

          if (narrow) {
            return Column(
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: type),
                    const SizedBox(width: 10),
                    Expanded(child: rangeBtn),
                    const SizedBox(width: 6),
                    clearBtn,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 5, child: search),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: type),
              const SizedBox(width: 12),
              rangeBtn,
              const SizedBox(width: 6),
              clearBtn,
            ],
          );
        },
      ),
    );
  }

  Widget _ledgerTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final cs = Theme.of(context).colorScheme;

    final userId = _asString(d['userId']).trim();
    final userName = _asString(d['userName']).trim();
    final delta = _asInt(d['delta']);
    final type = _asString(d['type']).trim();
    final reason = _asString(d['reason']).trim();
    final createdAt = _toDateTime(d['createdAt']);

    final deltaColor = delta >= 0 ? Colors.green.shade800 : cs.error;
    final deltaText = '${delta >= 0 ? '+' : ''}$delta';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        title: Row(
          children: [
            Text(deltaText, style: TextStyle(fontWeight: FontWeight.w900, color: deltaColor)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reason.isEmpty ? '(未填寫原因)' : reason,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            _pill(
              text: _ledgerTypeLabel(type),
              fg: cs.onSurfaceVariant,
              bg: cs.surfaceContainerHighest,
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _miniTag('會員', '${userName.isEmpty ? '未知' : userName}${userId.isEmpty ? '' : ' • $userId'}'),
              if (createdAt != null) _miniTag('時間', _dtFmt.format(createdAt)),
            ],
          ),
        ),
        onTap: () => _ledgerDetailDialog(doc),
      ),
    );
  }

  // ============================================================
  // Dialogs - Task detail / create / edit / delete / assign
  // ============================================================
  Future<void> _taskDetailDialog(String taskId, Map<String, dynamic> task) async {
    final title = _asString(task['title']).trim();
    final desc = _asString(task['description']).trim();
    final points = _asInt(task['points']);
    final category = _asString(task['category']).trim();
    final repeat = _asString(task['repeat']).trim().toLowerCase();
    final status = _asString(task['status']).trim().toLowerCase();
    final startAt = _toDateTime(task['startAt']);
    final endAt = _toDateTime(task['endAt']);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title.isEmpty ? '任務詳情' : title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('Task ID', taskId),
                _kv('點數', '$points'),
                _kv('分類', category.isEmpty ? '—' : category),
                _kv('週期', _repeatLabel(repeat)),
                _kv('狀態', status == _taskStatusInactive ? '停用' : '啟用'),
                _kv('開始', startAt == null ? '—' : _dtFmt.format(startAt)),
                _kv('結束', endAt == null ? '—' : _dtFmt.format(endAt)),
                const Divider(height: 22),
                const Text('描述', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(desc.isEmpty ? '（無）' : desc),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
          FilledButton.tonalIcon(
            onPressed: () async {
              Navigator.pop(context);
              await _assignTaskDialog(taskId, task);
            },
            icon: const Icon(Icons.person_add_alt),
            label: const Text('指派給會員'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _editTaskDialog(taskId, task);
            },
            icon: const Icon(Icons.edit),
            label: const Text('編輯'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTaskDialog() async {
    await _taskUpsertDialog(
      title: '新增任務模板',
      initial: const {},
      onSubmit: (payload) async {
        final now = FieldValue.serverTimestamp();
        await _db.collection('tasks').add({
          ...payload,
          'createdAt': now,
          'updatedAt': now,
        });
      },
    );
  }

  Future<void> _editTaskDialog(String taskId, Map<String, dynamic> task) async {
    await _taskUpsertDialog(
      title: '編輯任務模板',
      initial: task,
      onSubmit: (payload) async {
        await _db.collection('tasks').doc(taskId).update({
          ...payload,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      },
    );
  }

  Future<void> _taskUpsertDialog({
    required String title,
    required Map<String, dynamic> initial,
    required Future<void> Function(Map<String, dynamic> payload) onSubmit,
  }) async {
    final tTitle = TextEditingController(text: _asString(initial['title']));
    final tDesc = TextEditingController(text: _asString(initial['description']));
    final tCategory = TextEditingController(text: _asString(initial['category']));
    final tPoints = TextEditingController(text: (_asInt(initial['points']) == 0 && initial['points'] == null)
        ? ''
        : _asInt(initial['points']).toString());

    String repeat = _asString(initial['repeat']).trim().toLowerCase();
    if (![ _repeatOnce, _repeatDaily, _repeatWeekly, _repeatMonthly ].contains(repeat)) repeat = _repeatOnce;

    String status = _asString(initial['status']).trim().toLowerCase();
    if (![ _taskStatusActive, _taskStatusInactive ].contains(status)) status = _taskStatusActive;

    DateTime? startAt = _toDateTime(initial['startAt']);
    DateTime? endAt = _toDateTime(initial['endAt']);

    bool saving = false;

    Future<void> pickStart() async {
      final d = await showDatePicker(
        context: context,
        firstDate: DateTime(DateTime.now().year - 3),
        lastDate: DateTime(DateTime.now().year + 3),
        initialDate: startAt ?? DateTime.now(),
      );
      if (d == null) return;
      startAt = DateTime(d.year, d.month, d.day, 0, 0, 0);
      setState(() {});
    }

    Future<void> pickEnd() async {
      final d = await showDatePicker(
        context: context,
        firstDate: DateTime(DateTime.now().year - 3),
        lastDate: DateTime(DateTime.now().year + 3),
        initialDate: endAt ?? (startAt ?? DateTime.now()),
      );
      if (d == null) return;
      endAt = DateTime(d.year, d.month, d.day, 23, 59, 59);
      setState(() {});
    }

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> submit() async {
            final name = tTitle.text.trim();
            final points = int.tryParse(tPoints.text.trim()) ?? 0;

            if (name.isEmpty) {
              _toast('請輸入任務標題');
              return;
            }
            if (points <= 0) {
              _toast('點數需大於 0');
              return;
            }
            if (startAt != null && endAt != null && endAt!.isBefore(startAt!)) {
              _toast('結束日期不可早於開始日期');
              return;
            }

            final payload = <String, dynamic>{
              'title': name,
              'description': tDesc.text.trim(),
              'category': tCategory.text.trim(),
              'points': points,
              'repeat': repeat,
              'status': status,
              'startAt': startAt == null ? null : Timestamp.fromDate(startAt!),
              'endAt': endAt == null ? null : Timestamp.fromDate(endAt!),
            }..removeWhere((k, v) => v == null);

            try {
              setLocal(() => saving = true);
              setState(() => _loading = true);
              await onSubmit(payload);
              if (!mounted) return;
              Navigator.pop(context);
              _toast('已儲存');
            } catch (e) {
              _toast('儲存失敗：$e');
            } finally {
              if (!mounted) return;
              setState(() => _loading = false);
              setLocal(() => saving = false);
            }
          }

          return AlertDialog(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: tTitle,
                      decoration: const InputDecoration(
                        labelText: '任務標題',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: tDesc,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '描述',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: tPoints,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '點數',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: tCategory,
                            decoration: const InputDecoration(
                              labelText: '分類（可選）',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, c) {
                        final narrow = c.maxWidth < 520;
                        final repeatDD = DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: repeat,
                          items: const [
                            DropdownMenuItem(value: _repeatOnce, child: Text('一次性')),
                            DropdownMenuItem(value: _repeatDaily, child: Text('每日')),
                            DropdownMenuItem(value: _repeatWeekly, child: Text('每週')),
                            DropdownMenuItem(value: _repeatMonthly, child: Text('每月')),
                          ],
                          onChanged: (v) => setLocal(() => repeat = v ?? _repeatOnce),
                          decoration: const InputDecoration(
                            labelText: '週期',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        );

                        final statusDD = DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: status,
                          items: const [
                            DropdownMenuItem(value: _taskStatusActive, child: Text('啟用')),
                            DropdownMenuItem(value: _taskStatusInactive, child: Text('停用')),
                          ],
                          onChanged: (v) => setLocal(() => status = v ?? _taskStatusActive),
                          decoration: const InputDecoration(
                            labelText: '狀態',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        );

                        if (narrow) {
                          return Column(
                            children: [
                              repeatDD,
                              const SizedBox(height: 10),
                              statusDD,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: repeatDD),
                            const SizedBox(width: 10),
                            Expanded(child: statusDD),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                firstDate: DateTime(DateTime.now().year - 3),
                                lastDate: DateTime(DateTime.now().year + 3),
                                initialDate: startAt ?? DateTime.now(),
                              );
                              if (d == null) return;
                              setLocal(() => startAt = DateTime(d.year, d.month, d.day, 0, 0, 0));
                            },
                            icon: const Icon(Icons.event),
                            label: Text(startAt == null ? '開始日期（可選）' : DateFormat('yyyy/MM/dd').format(startAt!)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                firstDate: DateTime(DateTime.now().year - 3),
                                lastDate: DateTime(DateTime.now().year + 3),
                                initialDate: endAt ?? (startAt ?? DateTime.now()),
                              );
                              if (d == null) return;
                              setLocal(() => endAt = DateTime(d.year, d.month, d.day, 23, 59, 59));
                            },
                            icon: const Icon(Icons.event_available),
                            label: Text(endAt == null ? '結束日期（可選）' : DateFormat('yyyy/MM/dd').format(endAt!)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: startAt == null && endAt == null
                              ? null
                              : () => setLocal(() {
                                    startAt = null;
                                    endAt = null;
                                  }),
                          child: const Text('清除期間'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('取消')),
              FilledButton.icon(
                onPressed: saving ? null : submit,
                icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                label: const Text('儲存'),
              ),
            ],
          );
        },
      ),
    );

    tTitle.dispose();
    tDesc.dispose();
    tCategory.dispose();
    tPoints.dispose();
  }

  Future<void> _deleteTaskDialog(String taskId, Map<String, dynamic> task) async {
    final ok = await _confirm(
      title: '刪除任務模板',
      message: '確定要刪除此任務模板嗎？\n此操作不可復原。\n\n${_asString(task['title'])}',
      confirmText: '刪除',
      isDanger: true,
    );
    if (ok != true) return;

    try {
      setState(() => _loading = true);
      await _db.collection('tasks').doc(taskId).delete();
      _toast('已刪除');
    } catch (e) {
      _toast('刪除失敗：$e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _setTaskActive(String taskId, bool active) async {
    try {
      setState(() => _loading = true);
      await _db.collection('tasks').doc(taskId).update({
        'status': active ? _taskStatusActive : _taskStatusInactive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _toast(active ? '已啟用' : '已停用');
    } catch (e) {
      _toast('更新失敗：$e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _assignTaskDialog(String taskId, Map<String, dynamic> task) async {
    final userIdCtrl = TextEditingController();
    final userNameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final taskTitle = _asString(task['title']).trim();
    final points = _asInt(task['points']);

    bool assigning = false;
    Map<String, dynamic>? userPreview;

    Future<void> lookupUser(String uid) async {
      final u = uid.trim();
      if (u.isEmpty) {
        userPreview = null;
        if (mounted) setState(() {});
        return;
      }
      try {
        final snap = await _db.collection('users').doc(u).get();
        userPreview = snap.data();
        final name = _asString(userPreview?['name']);
        if (name.isNotEmpty) userNameCtrl.text = name;
        if (mounted) setState(() {});
      } catch (_) {
        // ignore
      }
    }

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> submit() async {
            final userId = userIdCtrl.text.trim();
            if (userId.isEmpty) {
              _toast('請輸入 userId');
              return;
            }
            if (points <= 0) {
              _toast('此任務 points 無效，請先修正任務模板');
              return;
            }

            try {
              setLocal(() => assigning = true);
              setState(() => _loading = true);

              final now = FieldValue.serverTimestamp();

              await _db.collection('user_tasks').add({
                'userId': userId,
                'userName': userNameCtrl.text.trim(),
                'taskId': taskId,
                'taskTitle': taskTitle,
                'points': points,
                'status': _utAssigned,
                'note': noteCtrl.text.trim(),
                'assignedAt': now,
              });

              if (!mounted) return;
              Navigator.pop(context);
              _toast('已指派任務');
            } catch (e) {
              _toast('指派失敗：$e');
            } finally {
              if (!mounted) return;
              setState(() => _loading = false);
              setLocal(() => assigning = false);
            }
          }

          return AlertDialog(
            title: const Text('指派任務給會員', style: TextStyle(fontWeight: FontWeight.w900)),
            content: SizedBox(
              width: 660,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kv('任務', taskTitle.isEmpty ? '(未命名)' : taskTitle),
                    _kv('點數', '$points'),
                    const Divider(height: 18),
                    TextField(
                      controller: userIdCtrl,
                      onChanged: (v) => lookupUser(v),
                      decoration: const InputDecoration(
                        labelText: '會員 userId（必填）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: userNameCtrl,
                      decoration: const InputDecoration(
                        labelText: '會員名稱（可選）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '備註（可選）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (userPreview != null) ...[
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('會員預覽', style: TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6),
                              Text('name：${_asString(userPreview?['name'])}'),
                              Text('phone：${_asString(userPreview?['phone'])}'),
                              Text('email：${_asString(userPreview?['email'])}'),
                              Text('points：${_asInt(userPreview?['points'])}'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: assigning ? null : () => Navigator.pop(context), child: const Text('取消')),
              FilledButton.icon(
                onPressed: assigning ? null : submit,
                icon: assigning
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.person_add_alt),
                label: const Text('指派'),
              ),
            ],
          );
        },
      ),
    );

    userIdCtrl.dispose();
    userNameCtrl.dispose();
    noteCtrl.dispose();
  }

  // ============================================================
  // Dialogs - User task detail / approve / reject / reset
  // ============================================================
  Future<void> _userTaskDetailDialog(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data();
    final cs = Theme.of(context).colorScheme;

    final userId = _asString(d['userId']).trim();
    final userName = _asString(d['userName']).trim();
    final taskId = _asString(d['taskId']).trim();
    final taskTitle = _asString(d['taskTitle']).trim();
    final points = _asInt(d['points']);
    final status = _asString(d['status']).trim().toLowerCase();

    final note = _asString(d['note']).trim();
    final proof = (d['proof'] is Map) ? (d['proof'] as Map).cast<String, dynamic>() : <String, dynamic>{};

    final assignedAt = _toDateTime(d['assignedAt']);
    final submittedAt = _toDateTime(d['submittedAt']);
    final reviewedAt = _toDateTime(d['reviewedAt']);

    final reviewerName = _asString(d['reviewerName']).trim();

    final canApprove = status == _utSubmitted || status == _utAssigned;
    final canReject = status == _utSubmitted || status == _utAssigned;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(taskTitle.isEmpty ? '會員任務詳情' : taskTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('user', '${userName.isEmpty ? '未知' : userName}${userId.isEmpty ? '' : ' • $userId'}'),
                _kv('taskId', taskId.isEmpty ? '—' : taskId),
                _kv('points', '$points'),
                _kv('status', status),
                _kv('assignedAt', assignedAt == null ? '—' : _dtFmt.format(assignedAt)),
                _kv('submittedAt', submittedAt == null ? '—' : _dtFmt.format(submittedAt)),
                _kv('reviewedAt', reviewedAt == null ? '—' : _dtFmt.format(reviewedAt)),
                if (reviewerName.isNotEmpty) _kv('reviewer', reviewerName),
                const Divider(height: 22),
                const Text('備註', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(note.isEmpty ? '（無）' : note),
                const SizedBox(height: 14),
                const Text('Proof（可選）', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (proof.isEmpty)
                  Text('（無）', style: TextStyle(color: cs.onSurfaceVariant))
                else
                  ...proof.entries.map((e) => Text('${e.key}: ${e.value}')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
          if (canReject)
            FilledButton.tonalIcon(
              onPressed: () async {
                Navigator.pop(context);
                await _rejectUserTaskDialog(doc);
              },
              icon: const Icon(Icons.block),
              label: const Text('駁回'),
            ),
          if (canApprove)
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _approveUserTask(doc);
              },
              icon: const Icon(Icons.verified),
              label: const Text('核准並發點'),
            ),
        ],
      ),
    );
  }

  Future<void> _approveUserTask(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data();
    final userId = _asString(d['userId']).trim();
    final userName = _asString(d['userName']).trim();
    final taskId = _asString(d['taskId']).trim();
    final taskTitle = _asString(d['taskTitle']).trim();
    final points = _asInt(d['points']);
    final status = _asString(d['status']).trim().toLowerCase();

    if (userId.isEmpty) {
      _toast('此任務缺少 userId');
      return;
    }
    if (points <= 0) {
      _toast('此任務 points 無效');
      return;
    }
    if (status == _utApproved) {
      _toast('此任務已核准');
      return;
    }

    final ok = await _confirm(
      title: '核准並發點',
      message: '確定要核准並發放 $points 點？\n\n會員：${userName.isEmpty ? userId : '$userName • $userId'}\n任務：${taskTitle.isEmpty ? taskId : taskTitle}',
      confirmText: '核准',
    );
    if (ok != true) return;

    try {
      setState(() => _loading = true);

      await _db.runTransaction((tx) async {
        final userRef = _db.collection('users').doc(userId);
        final userSnap = await tx.get(userRef);
        final currentPoints = _asInt(userSnap.data()?['points']);
        final newPoints = currentPoints + points;

        // 1) 更新 user_task
        tx.update(doc.reference, {
          'status': _utApproved,
          'reviewedAt': FieldValue.serverTimestamp(),
        });

        // 2) 更新 users.points
        tx.set(userRef, {'points': newPoints}, SetOptions(merge: true));

        // 3) 寫入 ledger
        final ledgerRef = _db.collection('points_ledger').doc();
        tx.set(ledgerRef, {
          'userId': userId,
          'userName': userName,
          'delta': points,
          'type': _ledgerTask,
          'reason': '任務核准：${taskTitle.isEmpty ? taskId : taskTitle}',
          'ref': {
            'taskId': taskId,
            'userTaskId': doc.id,
          },
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      _toast('已核准並發點');
    } catch (e) {
      _toast('核准失敗：$e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _rejectUserTaskDialog(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final reasonCtrl = TextEditingController();
    bool rejecting = false;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> submit() async {
            final reason = reasonCtrl.text.trim();
            if (reason.isEmpty) {
              _toast('請填寫駁回原因');
              return;
            }
            try {
              setLocal(() => rejecting = true);
              setState(() => _loading = true);

              await doc.reference.update({
                'status': _utRejected,
                'reviewedAt': FieldValue.serverTimestamp(),
                'note': reason,
              });

              if (!mounted) return;
              Navigator.pop(context);
              _toast('已駁回');
            } catch (e) {
              _toast('駁回失敗：$e');
            } finally {
              if (!mounted) return;
              setState(() => _loading = false);
              setLocal(() => rejecting = false);
            }
          }

          return AlertDialog(
            title: const Text('駁回會員任務', style: TextStyle(fontWeight: FontWeight.w900)),
            content: SizedBox(
              width: 600,
              child: TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '駁回原因（會寫入 note）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: rejecting ? null : () => Navigator.pop(context), child: const Text('取消')),
              FilledButton.icon(
                onPressed: rejecting ? null : submit,
                icon: rejecting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.block),
                label: const Text('駁回'),
              ),
            ],
          );
        },
      ),
    );

    reasonCtrl.dispose();
  }

  Future<void> _resetUserTask(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final ok = await _confirm(
      title: '重設任務狀態',
      message: '確定要把此會員任務狀態重設為「已指派」嗎？',
      confirmText: '重設',
    );
    if (ok != true) return;

    try {
      setState(() => _loading = true);
      await doc.reference.update({
        'status': _utAssigned,
        'reviewedAt': null,
      });
      _toast('已重設');
    } catch (e) {
      _toast('重設失敗：$e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ============================================================
  // Dialogs - Ledger detail / manual adjust
  // ============================================================
  Future<void> _ledgerDetailDialog(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data();
    final userId = _asString(d['userId']).trim();
    final userName = _asString(d['userName']).trim();
    final delta = _asInt(d['delta']);
    final type = _asString(d['type']).trim();
    final reason = _asString(d['reason']).trim();
    final createdAt = _toDateTime(d['createdAt']);

    final ref = (d['ref'] is Map) ? (d['ref'] as Map).cast<String, dynamic>() : <String, dynamic>{};

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('積分流水詳情', style: TextStyle(fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('ledgerId', doc.id),
                _kv('user', '${userName.isEmpty ? '未知' : userName}${userId.isEmpty ? '' : ' • $userId'}'),
                _kv('delta', '${delta >= 0 ? '+' : ''}$delta'),
                _kv('type', type),
                _kv('createdAt', createdAt == null ? '—' : _dtFmt.format(createdAt)),
                const Divider(height: 22),
                const Text('原因', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(reason.isEmpty ? '（無）' : reason),
                const SizedBox(height: 14),
                const Text('Ref（可選）', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (ref.isEmpty)
                  const Text('（無）')
                else
                  ...ref.entries.map((e) => Text('${e.key}: ${e.value}')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
        ],
      ),
    );
  }

  Future<void> _manualAdjustDialog() async {
    final userIdCtrl = TextEditingController();
    final userNameCtrl = TextEditingController();
    final deltaCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: '手動調整');

    bool saving = false;
    Map<String, dynamic>? userPreview;

    Future<void> lookupUser(String uid) async {
      final u = uid.trim();
      if (u.isEmpty) {
        userPreview = null;
        if (mounted) setState(() {});
        return;
      }
      try {
        final snap = await _db.collection('users').doc(u).get();
        userPreview = snap.data();
        final name = _asString(userPreview?['name']);
        if (name.isNotEmpty) userNameCtrl.text = name;
        if (mounted) setState(() {});
      } catch (_) {}
    }

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> submit() async {
            final userId = userIdCtrl.text.trim();
            if (userId.isEmpty) {
              _toast('請輸入 userId');
              return;
            }
            final delta = int.tryParse(deltaCtrl.text.trim()) ?? 0;
            if (delta == 0) {
              _toast('delta 不可為 0（正數加分 / 負數扣分）');
              return;
            }
            final reason = reasonCtrl.text.trim();
            if (reason.isEmpty) {
              _toast('請填寫原因');
              return;
            }

            final ok = await _confirm(
              title: '確認調整積分',
              message: '確定要對此會員調整積分嗎？\n\nuserId：$userId\ndelta：${delta >= 0 ? '+' : ''}$delta\n原因：$reason',
              confirmText: '確認',
              isDanger: delta < 0,
            );
            if (ok != true) return;

            try {
              setLocal(() => saving = true);
              setState(() => _loading = true);

              await _db.runTransaction((tx) async {
                final userRef = _db.collection('users').doc(userId);
                final userSnap = await tx.get(userRef);
                final currentPoints = _asInt(userSnap.data()?['points']);
                final newPoints = currentPoints + delta;

                tx.set(userRef, {'points': newPoints, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

                final ledgerRef = _db.collection('points_ledger').doc();
                tx.set(ledgerRef, {
                  'userId': userId,
                  'userName': userNameCtrl.text.trim(),
                  'delta': delta,
                  'type': _ledgerManual,
                  'reason': reason,
                  'ref': {'source': 'admin_manual'},
                  'createdAt': FieldValue.serverTimestamp(),
                });
              });

              if (!mounted) return;
              Navigator.pop(context);
              _toast('已完成調整');
            } catch (e) {
              _toast('調整失敗：$e');
            } finally {
              if (!mounted) return;
              setState(() => _loading = false);
              setLocal(() => saving = false);
            }
          }

          return AlertDialog(
            title: const Text('手動調整積分', style: TextStyle(fontWeight: FontWeight.w900)),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: userIdCtrl,
                      onChanged: (v) => lookupUser(v),
                      decoration: const InputDecoration(
                        labelText: '會員 userId（必填）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: userNameCtrl,
                            decoration: const InputDecoration(
                              labelText: '會員名稱（可選）',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: deltaCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'delta（正加分 / 負扣分）',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '原因（必填）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (userPreview != null) ...[
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('會員預覽', style: TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6),
                              Text('name：${_asString(userPreview?['name'])}'),
                              Text('phone：${_asString(userPreview?['phone'])}'),
                              Text('email：${_asString(userPreview?['email'])}'),
                              Text('points：${_asInt(userPreview?['points'])}'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('取消')),
              FilledButton.icon(
                onPressed: saving ? null : submit,
                icon: saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('確認調整'),
              ),
            ],
          );
        },
      ),
    );

    userIdCtrl.dispose();
    userNameCtrl.dispose();
    deltaCtrl.dispose();
    reasonCtrl.dispose();
  }

  // ============================================================
  // Date pickers
  // ============================================================
  Future<void> _pickUserTaskRange() async {
    final now = DateTime.now();
    final initial = _userTaskRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29)),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      helpText: '選擇 assignedAt 範圍',
      confirmText: '套用',
      cancelText: '取消',
    );
    if (picked == null) return;

    setState(() {
      _userTaskRange = DateTimeRange(
        start: DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
      );
    });
  }

  Future<void> _pickLedgerRange() async {
    final now = DateTime.now();
    final initial = _ledgerRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29)),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      helpText: '選擇 createdAt 範圍',
      confirmText: '套用',
      cancelText: '取消',
    );
    if (picked == null) return;

    setState(() {
      _ledgerRange = DateTimeRange(
        start: DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
      );
    });
  }

  // ============================================================
  // Small UI helpers
  // ============================================================
  (String, Color, Color) _userTaskStatusPill(String status) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case _utAssigned:
        return ('已指派', cs.onSurfaceVariant, cs.surfaceContainerHighest);
      case _utSubmitted:
        return ('已提交', Colors.blue.shade800, Colors.blue.shade50);
      case _utApproved:
        return ('已核准', Colors.green.shade800, Colors.green.shade100);
      case _utRejected:
        return ('已駁回', cs.error, cs.errorContainer);
      default:
        return ('未知', cs.onSurfaceVariant, cs.surfaceContainerHighest);
    }
  }

  Widget _pill({required String text, required Color fg, required Color bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg)),
    );
  }

  Widget _miniTag(String k, String v) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$k：$v', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  String _repeatLabel(String r) {
    switch (r) {
      case _repeatDaily:
        return '每日';
      case _repeatWeekly:
        return '每週';
      case _repeatMonthly:
        return '每月';
      case _repeatOnce:
      default:
        return '一次性';
    }
  }

  String _ledgerTypeLabel(String t) {
    switch (t) {
      case _ledgerTask:
        return '任務發點';
      case _ledgerManual:
        return '手動調整';
      case _ledgerCorrection:
        return '修正';
      default:
        return t.isEmpty ? '未知' : t;
    }
  }

  String _fmtRange(DateTimeRange r) {
    final a = DateFormat('MM/dd').format(r.start);
    final b = DateFormat('MM/dd').format(r.end);
    return '$a～$b';
  }

  // ============================================================
  // Confirm + Toast
  // ============================================================
  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool isDanger = false,
  }) async {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDanger ? cs.error : null,
              foregroundColor: isDanger ? cs.onError : null,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ============================================================
  // Safe casting utils
  // ============================================================
  String _asString(dynamic v) => (v == null) ? '' : v.toString();

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    final p = int.tryParse(v?.toString() ?? '');
    return p ?? 0;
  }

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}

// ============================================================
// Common small views
// ============================================================
class _EmptyView extends StatelessWidget {
  final String title;
  const _EmptyView({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 6),
            Text('請調整篩選條件或新增資料後再試。', style: TextStyle(color: cs.onSurfaceVariant)),
          ],
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
        constraints: const BoxConstraints(maxWidth: 680),
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
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                  if (hint != null) ...[
                    const SizedBox(height: 10),
                    Text(hint!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
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
