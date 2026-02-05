// lib/pages/admin/members/admin_member_detail_page.dart
//
// ✅ AdminMemberDetailPage（會員詳情｜完整版｜可編譯）
// ------------------------------------------------------------
// - 三分頁：基本資料 / 會員訂單 / 點數與任務（點數 Ledger）
// - 管理操作：停權/解停、停權原因、客服備註、Tag 標籤管理
// - 點數操作：加點/扣點（transaction + ledger）
// - 訂單列表：依 userId 篩選（可能需要 Firestore 複合索引）
// - 相容 Web/桌面/手機
//
// ------------------------------------------------------------
// Firestore 建議：
// users/{uid} {
//   displayName/name, phone, email,
//   createdAt, lastLoginAt, updatedAt: Timestamp,
//   blocked: bool,
//   blockedReason: string,
//   adminNote: string,
//   tags: array<string>,
//   pointsBalance: num,
//   lifetimeSpend: num,
//   orderCount: num
// }
//
// users/{uid}/pointsLedger/{ledgerId} {
//   delta: num,                 // +10 / -10
//   reason: string,
//   createdAt: Timestamp,
//   balanceAfter: num
// }
//
// orders/{orderId} {
//   userId: uid,
//   status: string,
//   finalAmount/total/amount: num,
//   createdAt: Timestamp,
//   items: [...]
//
// ⚠️ 訂單查詢：where(userId==uid) + orderBy(createdAt) 可能需要複合索引
// ------------------------------------------------------------
//
// ✅ 路由註冊建議：
// routes: {
//   '/admin_member_detail': (_) => const AdminMemberDetailPage(),
// }
//
// ✅ 呼叫方式：
// Navigator.pushNamed(context, '/admin_member_detail', arguments: {'uid': uid});
// 或 arguments: uid (String)
//
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminMemberDetailPage extends StatefulWidget {
  const AdminMemberDetailPage({super.key});

  @override
  State<AdminMemberDetailPage> createState() => _AdminMemberDetailPageState();
}

class _AdminMemberDetailPageState extends State<AdminMemberDetailPage> {
  final _db = FirebaseFirestore.instance;

  String? _uid;
  String? _argError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_uid != null || _argError != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;

    String? uid;
    if (args is String) uid = args.trim();
    if (args is Map) {
      final v = args['uid'] ?? args['userId'] ?? args['id'];
      if (v != null) uid = v.toString().trim();
    }

    if (uid == null || uid.isEmpty) {
      setState(() => _argError = '缺少 uid 參數，請用 Navigator.pushNamed(..., arguments: {\'uid\': uid})');
      return;
    }
    setState(() => _uid = uid);
  }

  DocumentReference<Map<String, dynamic>> get _userRef =>
      _db.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _ledgerCol =>
      _db.collection('users').doc(_uid).collection('pointsLedger');

  // ===========================================================
  // UI
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_argError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('會員詳情')),
        body: _ErrorView(
          title: '開啟失敗',
          message: _argError!,
          hint: '請確認你有傳入 uid 參數。',
          onRetry: () => Navigator.pop(context),
          retryText: '返回',
        ),
      );
    }

    if (_uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('會員詳情：$_uid', style: const TextStyle(fontWeight: FontWeight.w900)),
          bottom: const TabBar(
            tabs: [
              Tab(text: '基本資料'),
              Tab(text: '會員訂單'),
              Tab(text: '點數 / 任務'),
            ],
          ),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userRef.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return _ErrorView(
                title: '讀取會員失敗',
                message: snap.error.toString(),
                hint: '常見原因：users 權限不足、文件不存在、欄位型別錯誤。',
                onRetry: () => setState(() {}),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final doc = snap.data!;
            if (!doc.exists) {
              return _ErrorView(
                title: '會員不存在',
                message: '找不到此 uid 的 users 文件：$_uid',
                hint: '請確認 users/{uid} 是否存在。',
                onRetry: () => Navigator.pop(context),
                retryText: '返回',
              );
            }

            final d = doc.data() ?? <String, dynamic>{};
            final vm = _MemberDetailVM.fromMap(uid: _uid!, data: d);

            return Column(
              children: [
                _headerCard(cs, vm),
                const Divider(height: 1),
                Expanded(
                  child: TabBarView(
                    children: [
                      _tabBasic(cs, vm),
                      _tabOrders(cs, vm),
                      _tabPoints(cs, vm),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===========================================================
  // Header
  // ===========================================================
  Widget _headerCard(ColorScheme cs, _MemberDetailVM vm) {
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
    final fmtDateTime = DateFormat('yyyy/MM/dd HH:mm');

    final badgeColor = vm.blocked ? cs.errorContainer : cs.primaryContainer;
    final badgeTextColor = vm.blocked ? cs.onErrorContainer : cs.onPrimaryContainer;
    final badgeText = vm.blocked ? '停權中' : '正常';

    final createdText = vm.createdAt == null ? '—' : fmtDateTime.format(vm.createdAt!);
    final loginText = vm.lastLoginAt == null ? '—' : fmtDateTime.format(vm.lastLoginAt!);

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: badgeColor,
                  child: Text(
                    badgeText,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: badgeTextColor),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vm.displayName.isEmpty ? '（未命名）' : vm.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (vm.phone.isNotEmpty) '電話：${vm.phone}',
                          if (vm.email.isNotEmpty) 'Email：${vm.email}',
                        ].join('  •  '),
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '操作',
                  onSelected: (v) => _handleHeaderAction(vm, v),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'toggle_block', child: Text(vm.blocked ? '解除停權' : '停權')),
                    const PopupMenuItem(value: 'note', child: Text('編輯備註')),
                    const PopupMenuItem(value: 'tags', child: Text('管理標籤')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'edit_basic', child: Text('編輯基本資料')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _pill('註冊', createdText),
                _pill('最近登入', loginText),
                _pill('訂單數', '${vm.orderCount.toInt()}'),
                _pill('累積消費', fmtMoney.format(vm.lifetimeSpend)),
                _pill('點數', '${vm.pointsBalance.toInt()}'),
              ],
            ),
            if (vm.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in vm.tags.take(12))
                      Chip(
                        label: Text(t),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (vm.tags.length > 12)
                      Text('...+${vm.tags.length - 12}', style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
            if (vm.blocked && vm.blockedReason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '停權原因：${vm.blockedReason}',
                  style: TextStyle(color: cs.error, fontWeight: FontWeight.w800),
                ),
              ),
            ],
            if (vm.adminNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('備註：${vm.adminNote}', style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _toggleBlock(vm),
                  icon: Icon(vm.blocked ? Icons.lock_open : Icons.lock_outline),
                  label: Text(vm.blocked ? '解除停權' : '停權'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _editNote(vm),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('備註'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _manageTags(vm),
                  icon: const Icon(Icons.sell),
                  label: const Text('標籤'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
        color: Colors.white,
      ),
      child: Text('$k：$v', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  void _handleHeaderAction(_MemberDetailVM vm, String action) {
    switch (action) {
      case 'toggle_block':
        _toggleBlock(vm);
        break;
      case 'note':
        _editNote(vm);
        break;
      case 'tags':
        _manageTags(vm);
        break;
      case 'edit_basic':
        _editBasic(vm);
        break;
    }
  }

  // ===========================================================
  // Tab: Basic
  // ===========================================================
  Widget _tabBasic(ColorScheme cs, _MemberDetailVM vm) {
    final fmtDateTime = DateFormat('yyyy/MM/dd HH:mm');

    Widget kv(String k, String v, {bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 100, child: Text(k, style: const TextStyle(color: Colors.black54))),
            Expanded(
              child: Text(
                v.isEmpty ? '—' : v,
                style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('基本資訊', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 12),
                kv('UID', vm.uid, bold: true),
                kv('名稱', vm.displayName),
                kv('電話', vm.phone),
                kv('Email', vm.email),
                kv('狀態', vm.blocked ? '停權' : '正常'),
                kv('註冊時間', vm.createdAt == null ? '' : fmtDateTime.format(vm.createdAt!)),
                kv('最近登入', vm.lastLoginAt == null ? '' : fmtDateTime.format(vm.lastLoginAt!)),
                kv('更新時間', vm.updatedAt == null ? '' : fmtDateTime.format(vm.updatedAt!)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _editBasic(vm),
                      icon: const Icon(Icons.edit),
                      label: const Text('編輯基本資料'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _toggleBlock(vm),
                      icon: Icon(vm.blocked ? Icons.lock_open : Icons.lock_outline),
                      label: Text(vm.blocked ? '解除停權' : '停權'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('客服備註 / Tag', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 10),
                kv('備註', vm.adminNote),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (vm.tags.isEmpty)
                      Text('—', style: TextStyle(color: cs.onSurfaceVariant))
                    else
                      for (final t in vm.tags)
                        Chip(
                          label: Text(t),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _editNote(vm),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('編輯備註'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _manageTags(vm),
                      icon: const Icon(Icons.sell),
                      label: const Text('管理標籤'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================
  // Tab: Orders
  // ===========================================================
  Widget _tabOrders(ColorScheme cs, _MemberDetailVM vm) {
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
    final fmtDateTime = DateFormat('yyyy/MM/dd HH:mm');

    final q = _db
        .collection('orders')
        .where('userId', isEqualTo: vm.uid)
        .orderBy('createdAt', descending: true)
        .limit(80);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorView(
            title: '載入訂單失敗',
            message: snap.error.toString(),
            hint:
                '若錯誤包含 index，請依 Firestore Console 建立複合索引（userId + createdAt）。',
            onRetry: () => setState(() {}),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const _EmptyView(
            title: '尚無訂單',
            message: '此會員目前沒有訂單紀錄。',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final d = doc.data();

            final status = (d['status'] ?? '').toString();
            final createdAt = _toDateTime(d['createdAt']);
            final createdText = createdAt == null ? '—' : fmtDateTime.format(createdAt);

            final amount = _asNum(d['finalAmount'] ?? d['total'] ?? d['amount'] ?? 0);
            final amountText = fmtMoney.format(amount);

            final items = (d['items'] is List) ? (d['items'] as List).length : 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    '$items',
                    style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w900),
                  ),
                ),
                title: Text('訂單 ${doc.id}', style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(
                  [
                    if (status.isNotEmpty) '狀態：$status',
                    '金額：$amountText',
                    '建立：$createdText',
                  ].join('  •  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // 你若有訂單詳情頁，可註冊路由 '/admin_order_detail'
                  // 並傳 orderId
                  try {
                    Navigator.pushNamed(context, '/admin_order_detail', arguments: {'orderId': doc.id});
                  } catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('尚未註冊路由：/admin_order_detail（之後做訂單詳情頁再補）')),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================
  // Tab: Points / Tasks (Points ledger)
  // ===========================================================
  Widget _tabPoints(ColorScheme cs, _MemberDetailVM vm) {
    final fmtDateTime = DateFormat('yyyy/MM/dd HH:mm');

    final q = _ledgerCol.orderBy('createdAt', descending: true).limit(120);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('點數操作', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 10),
                Text('目前點數：${vm.pointsBalance.toInt()}',
                    style: TextStyle(fontWeight: FontWeight.w900, color: cs.primary, fontSize: 18)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _applyPointsDelta(vm, isAdd: true),
                      icon: const Icon(Icons.add),
                      label: const Text('加點'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _applyPointsDelta(vm, isAdd: false),
                      icon: const Icon(Icons.remove),
                      label: const Text('扣點'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openPointsRulesHint(),
                      icon: const Icon(Icons.info_outline),
                      label: const Text('資料結構提示'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('點數紀錄（Ledger）', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: q.snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return _ErrorInline(
                        message: snap.error.toString(),
                        hint: '請確認 pointsLedger 子集合存在，且 createdAt 欄位為 Timestamp。',
                      );
                    }
                    if (!snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text('尚無點數紀錄（pointsLedger 為空）',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      );
                    }

                    return Column(
                      children: [
                        for (final doc in docs) ...[
                          _ledgerTile(
                            cs,
                            doc.data(),
                            id: doc.id,
                            fmtDateTime: fmtDateTime,
                          ),
                          const Divider(height: 1),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _ledgerTile(
    ColorScheme cs,
    Map<String, dynamic> d, {
    required String id,
    required DateFormat fmtDateTime,
  }) {
    final delta = _asNum(d['delta'] ?? 0);
    final reason = (d['reason'] ?? '').toString();
    final createdAt = _toDateTime(d['createdAt']);
    final createdText = createdAt == null ? '—' : fmtDateTime.format(createdAt);
    final balanceAfter = _asNum(d['balanceAfter'] ?? 0);

    final isAdd = delta >= 0;
    final sign = isAdd ? '+' : '';
    final color = isAdd ? cs.primary : cs.error;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      leading: CircleAvatar(
        backgroundColor: (isAdd ? cs.primaryContainer : cs.errorContainer),
        child: Icon(isAdd ? Icons.add : Icons.remove,
            color: isAdd ? cs.onPrimaryContainer : cs.onErrorContainer),
      ),
      title: Text(
        '$sign${delta.toInt()} 點',
        style: TextStyle(fontWeight: FontWeight.w900, color: color),
      ),
      subtitle: Text(
        [
          if (reason.isNotEmpty) reason,
          '時間：$createdText',
          '餘額：${balanceAfter.toInt()}',
          'id：$id',
        ].join('  •  '),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ===========================================================
  // Actions
  // ===========================================================
  Future<void> _toggleBlock(_MemberDetailVM vm) async {
    if (_uid == null) return;

    if (!vm.blocked) {
      final reason = await _askText(
        title: '停權會員',
        hint: '請輸入停權原因（可留空）',
        initial: vm.blockedReason,
        confirmText: '停權',
        isDanger: true,
      );
      if (reason == null) return;

      try {
        await _userRef.update({
          'blocked': true,
          'blockedReason': reason.trim(),
          'blockedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已停權')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('停權失敗：$e')));
      }
    } else {
      final ok = await _confirm(
        title: '解除停權',
        message: '確定要解除停權此會員嗎？\nUID：${vm.uid}',
        confirmText: '解除',
      );
      if (ok != true) return;

      try {
        await _userRef.update({
          'blocked': false,
          'blockedReason': '',
          'unblockedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已解除停權')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('解除停權失敗：$e')));
      }
    }
  }

  Future<void> _editNote(_MemberDetailVM vm) async {
    final text = await _askText(
      title: '編輯客服備註',
      hint: '輸入備註內容（可留空）',
      initial: vm.adminNote,
      confirmText: '儲存',
    );
    if (text == null) return;

    try {
      await _userRef.update({
        'adminNote': text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('備註已更新')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  Future<void> _manageTags(_MemberDetailVM vm) async {
    // 這裡用簡易 Tag Editor（可加/可刪），不依賴全站 tag 字典
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _TagEditorDialog(
        title: '管理標籤',
        uid: vm.uid,
        initial: vm.tags,
      ),
    );
    if (result == null) return;

    try {
      await _userRef.update({
        'tags': result,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('標籤已更新')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新標籤失敗：$e')));
    }
  }

  Future<void> _editBasic(_MemberDetailVM vm) async {
    final res = await showDialog<_BasicEditResult>(
      context: context,
      builder: (_) => _EditBasicDialog(
        uid: vm.uid,
        name: vm.displayName,
        phone: vm.phone,
        email: vm.email,
      ),
    );
    if (res == null) return;

    try {
      await _userRef.update({
        'displayName': res.name.trim(),
        'phone': res.phone.trim(),
        'email': res.email.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('基本資料已更新')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  Future<void> _applyPointsDelta(_MemberDetailVM vm, {required bool isAdd}) async {
    final res = await showDialog<_PointsDeltaResult>(
      context: context,
      builder: (_) => _PointsDeltaDialog(isAdd: isAdd),
    );
    if (res == null) return;

    final delta = isAdd ? res.amount : -res.amount;
    final reason = res.reason.trim();

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_userRef);
        final d = snap.data() ?? <String, dynamic>{};

        final current = _asNum(d['pointsBalance'] ?? d['points'] ?? 0);
        final next = current + delta;

        tx.update(_userRef, {
          'pointsBalance': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final ledgerRef = _ledgerCol.doc();
        tx.set(ledgerRef, {
          'delta': delta,
          'reason': reason,
          'balanceAfter': next,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAdd ? '已加點：+${res.amount}' : '已扣點：-${res.amount}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('點數更新失敗：$e')));
    }
  }

  void _openPointsRulesHint() {
    showDialog(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text('點數資料結構提示', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          '此頁使用：\n'
          '1) users/{uid}.pointsBalance 作為目前點數\n'
          '2) users/{uid}/pointsLedger 作為點數異動明細\n\n'
          '若你的專案使用不同集合或欄位名稱，請告訴我，我會直接改成你的結構。',
        ),
      ),
    );
  }

  // ===========================================================
  // Dialog helpers
  // ===========================================================
  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool isDanger = false,
  }) {
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

  Future<String?> _askText({
    required String title,
    required String hint,
    required String initial,
    required String confirmText,
    bool isDanger = false,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final c = TextEditingController(text: initial);

    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: c,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDanger ? cs.error : null,
              foregroundColor: isDanger ? cs.onError : null,
            ),
            onPressed: () => Navigator.pop(context, c.text),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    c.dispose();
    return res;
  }
}

// ============================================================================
// ViewModel + Utils
// ============================================================================
class _MemberDetailVM {
  final String uid;
  final String displayName;
  final String phone;
  final String email;

  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final DateTime? updatedAt;

  final bool blocked;
  final String blockedReason;
  final String adminNote;
  final List<String> tags;

  final num pointsBalance;
  final num lifetimeSpend;
  final num orderCount;

  _MemberDetailVM({
    required this.uid,
    required this.displayName,
    required this.phone,
    required this.email,
    required this.createdAt,
    required this.lastLoginAt,
    required this.updatedAt,
    required this.blocked,
    required this.blockedReason,
    required this.adminNote,
    required this.tags,
    required this.pointsBalance,
    required this.lifetimeSpend,
    required this.orderCount,
  });

  static _MemberDetailVM fromMap({required String uid, required Map<String, dynamic> data}) {
    String s(dynamic v) => (v ?? '').toString().trim();
    bool b(dynamic v) => v == true;

    List<String> strList(dynamic v) {
      if (v is! List) return const [];
      final out = <String>[];
      for (final x in v) {
        final t = (x ?? '').toString().trim();
        if (t.isNotEmpty) out.add(t);
      }
      return out;
    }

    num n(dynamic v) {
      if (v is num) return v;
      final p = num.tryParse((v ?? '').toString());
      return p ?? 0;
    }

    DateTime? dt(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return null;
    }

    final name = s(data['displayName'] ?? data['name'] ?? data['userName']);
    return _MemberDetailVM(
      uid: uid,
      displayName: name,
      phone: s(data['phone']),
      email: s(data['email']),
      createdAt: dt(data['createdAt']),
      lastLoginAt: dt(data['lastLoginAt']),
      updatedAt: dt(data['updatedAt']),
      blocked: b(data['blocked']),
      blockedReason: s(data['blockedReason']),
      adminNote: s(data['adminNote']),
      tags: strList(data['tags']),
      pointsBalance: n(data['pointsBalance'] ?? data['points']),
      lifetimeSpend: n(data['lifetimeSpend'] ?? data['totalSpend']),
      orderCount: n(data['orderCount']),
    );
  }
}

num _asNum(dynamic v) {
  if (v is num) return v;
  final p = num.tryParse((v ?? '').toString());
  return p ?? 0;
}

DateTime? _toDateTime(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

// ============================================================================
// Dialogs
// ============================================================================
class _PointsDeltaResult {
  final int amount;
  final String reason;
  _PointsDeltaResult({required this.amount, required this.reason});
}

class _PointsDeltaDialog extends StatefulWidget {
  final bool isAdd;
  const _PointsDeltaDialog({required this.isAdd});

  @override
  State<_PointsDeltaDialog> createState() => _PointsDeltaDialogState();
}

class _PointsDeltaDialogState extends State<_PointsDeltaDialog> {
  final _amount = TextEditingController(text: '10');
  final _reason = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = widget.isAdd ? '加點' : '扣點';

    return AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '點數數量（正整數）',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reason,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: '原因（建議填寫）',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '會同時寫入 pointsLedger 並更新 users.pointsBalance',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
        FilledButton.icon(
          onPressed: () {
            final a = int.tryParse(_amount.text.trim()) ?? 0;
            if (a <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('點數必須為正整數')));
              return;
            }
            Navigator.pop(context, _PointsDeltaResult(amount: a, reason: _reason.text));
          },
          icon: Icon(widget.isAdd ? Icons.add : Icons.remove),
          label: const Text('套用'),
        ),
      ],
    );
  }
}

class _BasicEditResult {
  final String name;
  final String phone;
  final String email;
  _BasicEditResult({required this.name, required this.phone, required this.email});
}

class _EditBasicDialog extends StatefulWidget {
  final String uid;
  final String name;
  final String phone;
  final String email;

  const _EditBasicDialog({
    required this.uid,
    required this.name,
    required this.phone,
    required this.email,
  });

  @override
  State<_EditBasicDialog> createState() => _EditBasicDialogState();
}

class _EditBasicDialogState extends State<_EditBasicDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.name);
  late final TextEditingController _phone = TextEditingController(text: widget.phone);
  late final TextEditingController _email = TextEditingController(text: widget.email);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('編輯基本資料', style: TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('UID：${widget.uid}', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: '名稱',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              decoration: InputDecoration(
                labelText: '電話',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _email,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
        FilledButton.icon(
          onPressed: () => Navigator.pop(
            context,
            _BasicEditResult(name: _name.text, phone: _phone.text, email: _email.text),
          ),
          icon: const Icon(Icons.check),
          label: const Text('儲存'),
        ),
      ],
    );
  }
}

class _TagEditorDialog extends StatefulWidget {
  final String title;
  final String uid;
  final List<String> initial;

  const _TagEditorDialog({
    required this.title,
    required this.uid,
    required this.initial,
  });

  @override
  State<_TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends State<_TagEditorDialog> {
  late List<String> tags;
  final TextEditingController _add = TextEditingController();

  @override
  void initState() {
    super.initState();
    tags = [...widget.initial]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  void _addTag(String t) {
    final s = t.trim();
    if (s.isEmpty) return;
    if (tags.map((e) => e.toLowerCase()).contains(s.toLowerCase())) return;
    setState(() {
      tags.add(s);
      tags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    });
  }

  void _removeTag(String t) {
    setState(() => tags.removeWhere((e) => e.toLowerCase() == t.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('UID：${widget.uid}', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _add,
                      decoration: InputDecoration(
                        hintText: '新增 Tag（例如：VIP / 需關懷 / 問題單）',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onSubmitted: (v) {
                        _addTag(v);
                        _add.clear();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      _addTag(_add.text);
                      _add.clear();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('加入'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('目前標籤', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (tags.isEmpty)
                const Text('（尚無標籤）', style: TextStyle(color: Colors.black54))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in tags)
                      InputChip(
                        label: Text(t),
                        onDeleted: () => _removeTag(t),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, tags),
          icon: const Icon(Icons.check),
          label: const Text('套用'),
        ),
      ],
    );
  }
}

// ============================================================================
// Shared small views
// ============================================================================
class _EmptyView extends StatelessWidget {
  final String title;
  final String message;
  const _EmptyView({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.info_outline, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 6),
            Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ErrorInline extends StatelessWidget {
  final String message;
  final String? hint;
  const _ErrorInline({required this.message, this.hint});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.error.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
        color: cs.errorContainer.withOpacity(0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('錯誤：$message', style: TextStyle(color: cs.error, fontWeight: FontWeight.w800)),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(hint!, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final String? hint;
  final VoidCallback onRetry;
  final String retryText;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    this.hint,
    this.retryText = '重試',
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
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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
                    label: Text(retryText),
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
