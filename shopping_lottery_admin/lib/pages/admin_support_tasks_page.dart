// lib/pages/admin_support_tasks_page.dart
//
// ✅ AdminSupportTasksPage（最終完整版｜客服任務管理｜篩選+排序+分頁+批次+CSV+指派+通知）
// ------------------------------------------------------------
// Firestore: supportTasks/{id}
// - title: String
// - description: String
// - status: String ('new'/'in_progress'/'waiting'/'resolved'/'closed')
// - priority: String ('low'/'normal'/'high'/'urgent')
// - vendorId: String?   (vendor scope)
// - customerUid: String? (optional)
// - contactId: String?   (optional, link to contacts)
// - assigneeUid: String? (指派人 uid)
// - assigneeName: String?
// - assigneeEmail: String?
// - dueAt: Timestamp?
// - tags: List<String>?
// - isActive: bool
// - createdAt / updatedAt: Timestamp
//
// 依賴：csv, file_saver（跟你商品/活動一致）
// Provider：AdminGate, NotificationService
// ------------------------------------------------------------

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';
import '../services/notification_service.dart';
import 'admin_support_task_edit_page.dart';

class AdminSupportTasksPage extends StatefulWidget {
  const AdminSupportTasksPage({super.key});

  @override
  State<AdminSupportTasksPage> createState() => _AdminSupportTasksPageState();
}

class _AdminSupportTasksPageState extends State<AdminSupportTasksPage> {
  final _db = FirebaseFirestore.instance;

  // filters
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _status = 'all';
  String _priority = 'all';
  String _active = 'active'; // active/all/inactive
  String _sortField = 'updatedAt';
  bool _ascending = false;

  // admin filter
  String _vendorFilter = 'all'; // all or vendorId
  String _assigneeFilter = 'all'; // all or assigneeUid (optional)

  // pagination
  static const int _pageSize = 20;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _loadingMore = false;

  // batch
  final Set<String> _selectedIds = {};

  // role
  Future<RoleInfo>? _roleFuture;
  String? _lastUid;
  String _role = '';
  String? _vendorId;

  // cached list
  final List<_TaskRow> _rows = [];

  // busy overlay
  bool _busy = false;
  String _busyLabel = '';

  // vendors for admin dropdown (optional)
  List<_VendorOption> _vendors = const [];
  // assignees for admin dropdown (optional)
  List<_AssigneeOption> _assignees = const [];

  @override
  void initState() {
    super.initState();
    _loadVendorsIfAny();
    _loadAssigneesIfAny();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Helpers
  // -------------------------
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _setBusy(bool v, {String label = ''}) async {
    if (!mounted) return;
    setState(() {
      _busy = v;
      _busyLabel = label;
    });
  }

  String _s(dynamic v) => (v ?? '').toString().trim();
  bool _b(dynamic v) => v == true;
  DateTime? _toDate(dynamic v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  // -------------------------
  // Optional: vendors
  // -------------------------
  Future<void> _loadVendorsIfAny() async {
    try {
      final snap = await _db.collection('vendors').orderBy('name').limit(300).get();
      final seen = <String>{};
      final list = <_VendorOption>[];
      for (final d in snap.docs) {
        final id = d.id.trim();
        if (id.isEmpty || !seen.add(id)) continue;
        final data = d.data();
        final name = _s(data['name']).isEmpty ? id : _s(data['name']);
        list.add(_VendorOption(id: id, name: name));
      }
      if (!mounted) return;
      setState(() => _vendors = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _vendors = const []);
    }
  }

  // -------------------------
  // Optional: assignees (客服/管理員清單)
  // 這裡用 users 集合，挑 role=admin/vendor/customer 都可，專案可自行改成 role in ['admin','support']
  // -------------------------
  Future<void> _loadAssigneesIfAny() async {
    try {
      final snap = await _db.collection('users').orderBy('updatedAt', descending: true).limit(300).get();
      final seen = <String>{};
      final list = <_AssigneeOption>[];
      for (final d in snap.docs) {
        final uid = d.id.trim();
        if (uid.isEmpty || !seen.add(uid)) continue;
        final data = d.data();
        final email = _s(data['email']);
        final name = _s(data['displayName']);
        if (email.isEmpty && name.isEmpty) continue;
        list.add(_AssigneeOption(uid: uid, label: name.isNotEmpty ? '$name ($email)' : email));
      }
      if (!mounted) return;
      setState(() => _assignees = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _assignees = const []);
    }
  }

  // -------------------------
  // Query builder (server-side)
  // - search 用 client-side contains，避免複合索引成本
  // -------------------------
  Query<Map<String, dynamic>> _baseQuery() {
    Query<Map<String, dynamic>> q = _db.collection('supportTasks');

    // active
    if (_active == 'active') q = q.where('isActive', isEqualTo: true);
    if (_active == 'inactive') q = q.where('isActive', isEqualTo: false);

    // role scope
    if (_role == 'vendor') {
      final vid = (_vendorId ?? '').trim();
      if (vid.isNotEmpty) {
        q = q.where('vendorId', isEqualTo: vid);
      } else {
        // vendor 沒 vendorId → 給空結果（由呼叫端處理）
        q = q.where('vendorId', isEqualTo: '__missing_vendorId__');
      }
    } else {
      // admin filters (optional)
      if (_vendorFilter != 'all') q = q.where('vendorId', isEqualTo: _vendorFilter);
      if (_assigneeFilter != 'all') q = q.where('assigneeUid', isEqualTo: _assigneeFilter);
    }

    // status
    if (_status != 'all') q = q.where('status', isEqualTo: _status);

    // priority
    if (_priority != 'all') q = q.where('priority', isEqualTo: _priority);

    // sort
    q = q.orderBy(_sortField, descending: !_ascending);

    return q;
  }

  // -------------------------
  // Load tasks (paging)
  // -------------------------
  Future<void> _load({bool refresh = false}) async {
    if (_loadingMore || (!_hasMore && !refresh)) return;

    setState(() {
      _loadingMore = true;
      if (refresh) {
        _rows.clear();
        _selectedIds.clear();
        _lastDoc = null;
        _hasMore = true;
      }
    });

    try {
      final q = _baseQuery().limit(_pageSize);
      final qs = (_lastDoc != null && !refresh) ? q.startAfterDocument(_lastDoc!) : q;

      final snap = await qs.get();

      final list = snap.docs.map((d) {
        final data = d.data();
        return _TaskRow(
          id: d.id,
          title: _s(data['title']),
          description: _s(data['description']),
          status: _s(data['status']).isEmpty ? 'new' : _s(data['status']),
          priority: _s(data['priority']).isEmpty ? 'normal' : _s(data['priority']),
          vendorId: _s(data['vendorId']),
          customerUid: _s(data['customerUid']),
          contactId: _s(data['contactId']),
          assigneeUid: _s(data['assigneeUid']),
          assigneeName: _s(data['assigneeName']),
          assigneeEmail: _s(data['assigneeEmail']),
          dueAt: _toDate(data['dueAt']),
          isActive: _b(data['isActive']),
          createdAt: _toDate(data['createdAt']),
          updatedAt: _toDate(data['updatedAt']),
        );
      }).toList();

      // client-side search: title/description
      final qtext = _query.trim().toLowerCase();
      final filtered = qtext.isEmpty
          ? list
          : list
              .where((r) =>
                  r.title.toLowerCase().contains(qtext) ||
                  r.description.toLowerCase().contains(qtext))
              .toList();

      if (!mounted) return;
      setState(() {
        _rows.addAll(filtered);
        _hasMore = snap.docs.length == _pageSize;
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
      });
    } catch (e) {
      _snack('載入客服任務失敗：$e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // -------------------------
  // Batch ops
  // -------------------------
  Future<void> _batchSetStatus(String status) async {
    if (_selectedIds.isEmpty) return;
    await _setBusy(true, label: '批次更新狀態中...');
    try {
      final batch = _db.batch();
      final now = FieldValue.serverTimestamp();

      for (final id in _selectedIds) {
        batch.set(
          _db.collection('supportTasks').doc(id),
          <String, dynamic>{'status': status, 'updatedAt': now},
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      _snack('已批次更新 ${_selectedIds.length} 筆狀態');
      setState(() => _selectedIds.clear());
      await _load(refresh: true);
    } catch (e) {
      _snack('批次更新失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _batchToggleActive(bool toActive) async {
    if (_selectedIds.isEmpty) return;
    await _setBusy(true, label: toActive ? '批次啟用中...' : '批次停用中...');
    try {
      final batch = _db.batch();
      final now = FieldValue.serverTimestamp();

      for (final id in _selectedIds) {
        batch.set(
          _db.collection('supportTasks').doc(id),
          <String, dynamic>{'isActive': toActive, 'updatedAt': now},
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      _snack('已${toActive ? '啟用' : '停用'} ${_selectedIds.length} 筆任務');
      setState(() => _selectedIds.clear());
      await _load(refresh: true);
    } catch (e) {
      _snack('批次更新失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _batchDelete() async {
    if (_selectedIds.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除 ${_selectedIds.length} 筆客服任務？此動作無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok != true) return;

    await _setBusy(true, label: '批次刪除中...');
    try {
      final batch = _db.batch();
      for (final id in _selectedIds) {
        batch.delete(_db.collection('supportTasks').doc(id));
      }
      await batch.commit();
      _snack('已刪除 ${_selectedIds.length} 筆任務');
      setState(() => _selectedIds.clear());
      await _load(refresh: true);
    } catch (e) {
      _snack('批次刪除失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  // -------------------------
  // CSV export
  // -------------------------
  Future<void> _exportCSV() async {
    if (_rows.isEmpty) {
      _snack('沒有資料可匯出');
      return;
    }

    final table = <List<dynamic>>[
      ['任務ID', '標題', '狀態', '優先級', '廠商ID', '指派UID', '指派Email', '到期日', '更新時間'],
      ..._rows.map((r) => [
            r.id,
            r.title,
            r.status,
            r.priority,
            r.vendorId,
            r.assigneeUid,
            r.assigneeEmail,
            r.dueAt?.toIso8601String() ?? '',
            r.updatedAt?.toIso8601String() ?? '',
          ]),
    ];

    final csv = const ListToCsvConverter().convert(table);
    final bytes = Uint8List.fromList(utf8.encode(csv));

    await FileSaver.instance.saveFile(
      name: 'support_tasks_${DateTime.now().millisecondsSinceEpoch}',
      bytes: bytes,
      ext: 'csv',
      mimeType: MimeType.csv,
    );

    _snack('已匯出 ${table.length - 1} 筆客服任務');
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('請登入')));

    if (_roleFuture == null || _lastUid != user.uid) {
      _lastUid = user.uid;
      _roleFuture = gate.ensureAndGetRole(user, forceRefresh: false);
      _role = '';
      _vendorId = null;
      _load(refresh: true);
    }

    return FutureBuilder<RoleInfo>(
      future: _roleFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final info = snap.data;
        final role = (info?.role ?? '').toLowerCase().trim();
        final isAdmin = role == 'admin';
        final isVendor = role == 'vendor';

        if (!isAdmin && !isVendor) {
          return const Scaffold(body: Center(child: Text('此帳號無後台存取權限')));
        }

        // cache role/vendorId
        if (_role != role) _role = role;
        if (_vendorId != info?.vendorId) _vendorId = info?.vendorId;

        if (isVendor && (_vendorId ?? '').trim().isEmpty) {
          return const Scaffold(
            body: Center(child: Text('Vendor 帳號缺少 vendorId，請在 users/{uid} 補上 vendorId')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('客服任務管理'),
            actions: [
              IconButton(
                tooltip: '重新整理',
                icon: const Icon(Icons.refresh),
                onPressed: () => _load(refresh: true),
              ),
              IconButton(
                tooltip: '匯出 CSV',
                icon: const Icon(Icons.download_outlined),
                onPressed: _exportCSV,
              ),
            ],
          ),
          body: Column(
            children: [
              _buildFilterBar(isAdmin: isAdmin),
              const Divider(height: 1),
              Expanded(
                child: _rows.isEmpty
                    ? Center(
                        child: Text(
                          _loadingMore ? '載入中...' : '尚無客服任務',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _rows.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _rows.length) {
                            if (!_loadingMore) _load();
                            return const Padding(
                              padding: EdgeInsets.all(14),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final r = _rows[i];
                          final selected = _selectedIds.contains(r.id);

                          final dueText = r.dueAt == null ? '未設定到期' : _fmtDateTime(r.dueAt!);
                          final overdue = r.dueAt != null &&
                              DateTime.now().isAfter(r.dueAt!) &&
                              (r.status != 'resolved' && r.status != 'closed');

                          return ListTile(
                            leading: Checkbox(
                              value: selected,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedIds.add(r.id);
                                  } else {
                                    _selectedIds.remove(r.id);
                                  }
                                });
                              },
                            ),
                            title: Text(
                              r.title.isEmpty ? '(未命名任務)' : r.title,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            subtitle: Text(
                              [
                                '狀態:${_statusLabel(r.status)}',
                                '優先:${_priorityLabel(r.priority)}',
                                if (isAdmin && r.vendorId.isNotEmpty) 'vendor:${r.vendorId}',
                                if (r.assigneeEmail.isNotEmpty) '指派:${r.assigneeEmail}',
                                overdue ? '逾期' : dueText,
                              ].join(' · '),
                            ),
                            trailing: _StatusPill(
                              text: _statusLabel(r.status),
                              tone: _statusTone(r.status),
                            ),
                            tileColor: selected ? Colors.blue.withOpacity(0.08) : null,
                            onTap: () async {
                              final ok = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminSupportTaskEditPage(taskId: r.id),
                                ),
                              );
                              if (ok == true) _load(refresh: true);
                            },
                          );
                        },
                      ),
              ),
              if (_busy)
                Container(
                  color: Colors.black.withOpacity(0.05),
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_busyLabel)),
                    ],
                  ),
                ),
            ],
          ),
          floatingActionButton: _selectedIds.isNotEmpty
              ? FloatingActionButton.extended(
                  icon: const Icon(Icons.edit_note),
                  label: Text('批次操作 (${_selectedIds.length})'),
                  onPressed: () => _showBatchMenu(context),
                )
              : FloatingActionButton.extended(
                  icon: const Icon(Icons.add),
                  label: const Text('新增任務'),
                  onPressed: () async {
                    final ok = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminSupportTaskEditPage()),
                    );
                    if (ok == true) _load(refresh: true);
                  },
                ),
        );
      },
    );
  }

  Widget _buildFilterBar({required bool isAdmin}) {
    final statusItems = const <String>[
      'all',
      'new',
      'in_progress',
      'waiting',
      'resolved',
      'closed',
    ];
    final priorityItems = const <String>['all', 'low', 'normal', 'high', 'urgent'];
    final activeItems = const <String>['active', 'all', 'inactive'];

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜尋任務標題/描述（contains）',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                setState(() => _query = v);
                _load(refresh: true);
              },
            ),
          ),

          DropdownButton<String>(
            value: statusItems.contains(_status) ? _status : 'all',
            items: statusItems
                .map((s) => DropdownMenuItem(value: s, child: Text('狀態：${_statusLabel(s)}')))
                .toList(),
            onChanged: (v) {
              setState(() => _status = v ?? 'all');
              _load(refresh: true);
            },
          ),

          DropdownButton<String>(
            value: priorityItems.contains(_priority) ? _priority : 'all',
            items: priorityItems
                .map((p) => DropdownMenuItem(value: p, child: Text('優先：${_priorityLabel(p)}')))
                .toList(),
            onChanged: (v) {
              setState(() => _priority = v ?? 'all');
              _load(refresh: true);
            },
          ),

          DropdownButton<String>(
            value: activeItems.contains(_active) ? _active : 'active',
            items: activeItems
                .map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(a == 'active' ? '啟用中' : (a == 'inactive' ? '已停用' : '全部')),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => _active = v ?? 'active');
              _load(refresh: true);
            },
          ),

          if (isAdmin) _buildVendorFilter(),

          if (isAdmin) _buildAssigneeFilter(),

          DropdownButton<String>(
            value: _sortField,
            items: const [
              DropdownMenuItem(value: 'updatedAt', child: Text('排序：更新時間')),
              DropdownMenuItem(value: 'createdAt', child: Text('排序：建立時間')),
              DropdownMenuItem(value: 'dueAt', child: Text('排序：到期日')),
              DropdownMenuItem(value: 'priority', child: Text('排序：優先級')),
              DropdownMenuItem(value: 'status', child: Text('排序：狀態')),
            ],
            onChanged: (v) {
              setState(() => _sortField = v ?? 'updatedAt');
              _load(refresh: true);
            },
          ),

          IconButton(
            tooltip: _ascending ? '升冪' : '降冪',
            icon: Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () {
              setState(() => _ascending = !_ascending);
              _load(refresh: true);
            },
          ),

          Text('共 ${_rows.length} 筆', style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildVendorFilter() {
    if (_vendors.isEmpty) {
      return SizedBox(
        width: 180,
        child: TextField(
          decoration: const InputDecoration(
            labelText: 'vendorId 篩選（可空）',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            setState(() => _vendorFilter = v.trim().isEmpty ? 'all' : v.trim());
            _load(refresh: true);
          },
        ),
      );
    }

    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('全部廠商')),
      ..._vendors.map((v) => DropdownMenuItem(value: v.id, child: Text(v.name))),
    ];
    final safe = items.any((e) => e.value == _vendorFilter) ? _vendorFilter : 'all';

    return DropdownButton<String>(
      value: safe,
      items: items,
      onChanged: (v) {
        setState(() => _vendorFilter = v ?? 'all');
        _load(refresh: true);
      },
    );
  }

  Widget _buildAssigneeFilter() {
    if (_assignees.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('全部指派人')),
      ..._assignees.map((a) => DropdownMenuItem(value: a.uid, child: Text(a.label))),
    ];
    final safe = items.any((e) => e.value == _assigneeFilter) ? _assigneeFilter : 'all';

    return DropdownButton<String>(
      value: safe,
      items: items,
      onChanged: (v) {
        setState(() => _assigneeFilter = v ?? 'all');
        _load(refresh: true);
      },
    );
  }

  void _showBatchMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(title: Text('批次狀態')),
            ListTile(
              leading: const Icon(Icons.fiber_new),
              title: const Text('設為：未處理'),
              onTap: () {
                Navigator.pop(context);
                _batchSetStatus('new');
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_check),
              title: const Text('設為：處理中'),
              onTap: () {
                Navigator.pop(context);
                _batchSetStatus('in_progress');
              },
            ),
            ListTile(
              leading: const Icon(Icons.pause_circle_outline),
              title: const Text('設為：等待回覆'),
              onTap: () {
                Navigator.pop(context);
                _batchSetStatus('waiting');
              },
            ),
            ListTile(
              leading: const Icon(Icons.task_alt),
              title: const Text('設為：已解決'),
              onTap: () {
                Navigator.pop(context);
                _batchSetStatus('resolved');
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('設為：已關閉'),
              onTap: () {
                Navigator.pop(context);
                _batchSetStatus('closed');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('批次啟用'),
              onTap: () {
                Navigator.pop(context);
                _batchToggleActive(true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('批次停用'),
              onTap: () {
                Navigator.pop(context);
                _batchToggleActive(false);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('批次刪除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _batchDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'new':
        return '未處理';
      case 'in_progress':
        return '處理中';
      case 'waiting':
        return '等待回覆';
      case 'resolved':
        return '已解決';
      case 'closed':
        return '已關閉';
      case 'all':
      default:
        return '全部';
    }
  }

  static String _priorityLabel(String p) {
    switch (p) {
      case 'low':
        return '低';
      case 'normal':
        return '一般';
      case 'high':
        return '高';
      case 'urgent':
        return '緊急';
      case 'all':
      default:
        return '全部';
    }
  }

  static _Tone _statusTone(String s) {
    switch (s) {
      case 'new':
        return _Tone.warn;
      case 'in_progress':
        return _Tone.info;
      case 'waiting':
        return _Tone.neutral;
      case 'resolved':
        return _Tone.ok;
      case 'closed':
        return _Tone.neutral;
      default:
        return _Tone.neutral;
    }
  }

  static String _fmtDateTime(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y/$m/$day $hh:$mm';
  }
}

// -------------------------
// UI small components
// -------------------------
enum _Tone { ok, info, warn, neutral }

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.tone});
  final String text;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (tone) {
      case _Tone.ok:
        bg = Colors.green.withOpacity(0.12);
        fg = Colors.green.shade800;
        break;
      case _Tone.info:
        bg = Colors.blue.withOpacity(0.12);
        fg = Colors.blue.shade800;
        break;
      case _Tone.warn:
        bg = Colors.orange.withOpacity(0.16);
        fg = Colors.orange.shade900;
        break;
      case _Tone.neutral:
      default:
        bg = Colors.grey.withOpacity(0.14);
        fg = Colors.grey.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

// -------------------------
// Model
// -------------------------
class _TaskRow {
  final String id;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String vendorId;
  final String customerUid;
  final String contactId;
  final String assigneeUid;
  final String assigneeName;
  final String assigneeEmail;
  final DateTime? dueAt;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  _TaskRow({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.vendorId,
    required this.customerUid,
    required this.contactId,
    required this.assigneeUid,
    required this.assigneeName,
    required this.assigneeEmail,
    required this.dueAt,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
}

class _VendorOption {
  final String id;
  final String name;
  const _VendorOption({required this.id, required this.name});
}

class _AssigneeOption {
  final String uid;
  final String label;
  const _AssigneeOption({required this.uid, required this.label});
}
