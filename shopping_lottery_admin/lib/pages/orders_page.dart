// lib/pages/orders_page.dart
//
// ✅ OrdersPage（完整版｜可編譯｜Admin/Vendor 訂單列表）
// ------------------------------------------------------------
// - 角色判斷：AdminGate.ensureAndGetRole -> RoleInfo
// - 修正：不再使用 RoleInfo.error（不存在）
//        改用：info.hasError / info.errorMessage
// - Admin：看全部訂單（可用 vendorId 篩選）
// - Vendor：只看自己 vendorId 的訂單
// - 支援：搜尋（前端過濾）、狀態篩選、基本詳情預覽
//
// Firestore（假設）orders/{orderId} 常見欄位（可缺）：
// - vendorId, buyerUid/userId, buyerName, buyerEmail
// - status, total/amount, currency
// - createdAt, updatedAt
// - items: [{title, qty, price}, ...]
//
// 依賴：cloud_firestore, firebase_auth, flutter/material, provider, intl

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _vendorFilterCtrl = TextEditingController();

  String _statusFilter = 'all';
  bool _onlyMine = false; // admin 可切換：只看自己（buyerUid=我）(可選)

  // role
  Future<RoleInfo>? _roleFuture;
  String? _lastUid;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _vendorFilterCtrl.dispose();
    super.dispose();
  }

  void _primeRole() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_roleFuture == null || _lastUid != user.uid) {
      _lastUid = user.uid;
      final gate = context.read<AdminGate>();
      _roleFuture = gate.ensureAndGetRole(user, forceRefresh: false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmtDateTime(DateTime? d) {
    if (d == null) return '-';
    final f = DateFormat('yyyy/MM/dd HH:mm');
    return f.format(d);
  }

  num _toNum(dynamic v, {num fallback = 0}) {
    if (v is num) return v;
    return num.tryParse('${v ?? ''}') ?? fallback;
  }

  // ----------------------------
  // Query builder
  // ----------------------------
  Query<Map<String, dynamic>> _buildQuery({
    required bool isAdmin,
    required bool isVendor,
    required String vendorId,
    required String uid,
  }) {
    Query<Map<String, dynamic>> q = _db
        .collection('orders')
        .orderBy('createdAt', descending: true);

    if (isVendor) {
      // Vendor: 僅看自己 vendorId
      if (vendorId.isNotEmpty) {
        q = q.where('vendorId', isEqualTo: vendorId);
      } else {
        // vendorId 空：直接回傳一個不可能命中的條件避免炸
        q = q.where('vendorId', isEqualTo: '__missing_vendorId__');
      }
    } else if (isAdmin) {
      // Admin: 可用 vendorId 篩選（輸入框）
      final vf = _vendorFilterCtrl.text.trim();
      if (vf.isNotEmpty) {
        q = q.where('vendorId', isEqualTo: vf);
      }
      if (_onlyMine) {
        // 可選：只看自己下的單（buyerUid/userId）
        // 注意：欄位可能不同，這裡用 buyerUid 或 userId 任一命中較難做 OR
        // 所以採用前端過濾（下方 _filterClientSide 會處理）
      }
    }

    // status：由於 status 種類不一定、且要有 index，這裡先不做 where（避免缺 index）
    // 改以前端過濾處理
    return q.limit(500);
  }

  // ----------------------------
  // Client-side filters
  // ----------------------------
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterClientSide(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required bool isAdmin,
    required bool isVendor,
    required String uid,
  }) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final status = _statusFilter;

    bool matchStatus(Map<String, dynamic> d) {
      if (status == 'all') return true;
      final s = _s(d['status']).toLowerCase();
      return s == status;
    }

    bool matchSearch(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      if (q.isEmpty) return true;
      final d = doc.data();
      final id = doc.id.toLowerCase();
      final buyerName = _s(d['buyerName']).toLowerCase();
      final buyerEmail = _s(d['buyerEmail']).toLowerCase();
      final vendorId = _s(d['vendorId']).toLowerCase();
      final status = _s(d['status']).toLowerCase();
      return id.contains(q) ||
          buyerName.contains(q) ||
          buyerEmail.contains(q) ||
          vendorId.contains(q) ||
          status.contains(q);
    }

    bool matchOnlyMine(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      if (!(isAdmin && _onlyMine)) return true;
      final d = doc.data();
      final buyerUid = _s(d['buyerUid']);
      final userId = _s(d['userId']);
      return buyerUid == uid || userId == uid;
    }

    return docs
        .where((doc) => matchStatus(doc.data()))
        .where((doc) => matchOnlyMine(doc))
        .where((doc) => matchSearch(doc))
        .toList();
  }

  Set<String> _collectStatuses(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final set = <String>{'all'};
    for (final d in docs) {
      final s = _s(d.data()['status']).toLowerCase();
      if (s.isNotEmpty) set.add(s);
    }
    return set;
  }

  Color _statusColor(BuildContext context, String status) {
    final s = status.toLowerCase().trim();
    final cs = Theme.of(context).colorScheme;
    switch (s) {
      case 'paid':
      case 'success':
      case 'completed':
        return cs.primaryContainer;
      case 'pending':
      case 'processing':
        return cs.tertiaryContainer;
      case 'cancelled':
      case 'canceled':
      case 'failed':
        return cs.errorContainer;
      case 'shipped':
      case 'delivered':
        return cs.secondaryContainer;
      default:
        // ✅ surfaceVariant deprecated → surfaceContainerHighest
        return cs.surfaceContainerHighest;
    }
  }

  Future<void> _openPreview(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required bool isAdmin,
    required bool isVendor,
  }) async {
    final d = doc.data();
    final createdAt = _toDate(d['createdAt']);
    final total = _toNum(
      d['total'],
      fallback: _toNum(d['amount'], fallback: 0),
    );
    final currency = _s(d['currency']).isEmpty ? 'NT\$' : _s(d['currency']);
    final status = _s(d['status']).isEmpty ? '-' : _s(d['status']);
    final vendorId = _s(d['vendorId']).isEmpty ? '-' : _s(d['vendorId']);
    final buyerName = _s(d['buyerName']);
    final buyerEmail = _s(d['buyerEmail']);
    final buyerUid = _s(d['buyerUid']).isEmpty
        ? _s(d['userId'])
        : _s(d['buyerUid']);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('訂單預覽：${doc.id}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('狀態', status),
                _kv('建立時間', _fmtDateTime(createdAt)),
                _kv('金額', '$currency${total.toStringAsFixed(0)}'),
                _kv('vendorId', vendorId),
                _kv('買家', buyerName.isEmpty ? '-' : buyerName),
                _kv('Email', buyerEmail.isEmpty ? '-' : buyerEmail),
                _kv('buyerUid/userId', buyerUid.isEmpty ? '-' : buyerUid),
                const SizedBox(height: 12),
                const Text(
                  '原始資料（debug）',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    // ✅ surfaceVariant deprecated → surfaceContainerHighest
                    // ✅ withOpacity deprecated → withValues(alpha: ...)
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.60),
                  ),
                  child: Text(
                    d.toString(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: doc.id));
              if (!mounted) return;
              _snack('已複製訂單 ID');
            },
            child: const Text('複製訂單ID'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _primeRole();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;

        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (user == null) {
          return const Scaffold(body: Center(child: Text('請先登入')));
        }

        return FutureBuilder<RoleInfo>(
          future: _roleFuture,
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final info = roleSnap.data;
            if (info == null) {
              return const Scaffold(body: Center(child: Text('讀取角色失敗')));
            }

            // ✅ 修正：RoleInfo.error 不存在 → 改用 hasError / errorMessage
            if (info.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('訂單管理')),
                body: Center(
                  child: Text(
                    info.errorMessage.isEmpty ? '讀取角色失敗' : info.errorMessage,
                  ),
                ),
              );
            }

            final role = info.role.toLowerCase().trim();
            final isAdmin = role == 'admin';
            final isVendor = role == 'vendor';
            final vendorId = info.vendorId.trim();

            if (!isAdmin && !isVendor) {
              return const Scaffold(
                body: Center(child: Text('需要 Admin / Vendor 權限')),
              );
            }

            if (isVendor && vendorId.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Vendor 帳號缺少 vendorId，請在 users/{uid} 補上 vendorId',
                  ),
                ),
              );
            }

            final query = _buildQuery(
              isAdmin: isAdmin,
              isVendor: isVendor,
              vendorId: vendorId,
              uid: user.uid,
            );

            return Scaffold(
              appBar: AppBar(
                title: Text(isAdmin ? '訂單管理（Admin）' : '訂單管理（Vendor）'),
                actions: [
                  if (isAdmin)
                    Row(
                      children: [
                        const Text('只看我的', style: TextStyle(fontSize: 12)),
                        Switch(
                          value: _onlyMine,
                          onChanged: (v) => setState(() => _onlyMine = v),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  IconButton(
                    tooltip: '重新整理',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() {}),
                  ),
                ],
              ),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: _buildTopFilters(
                      isAdmin: isAdmin,
                      vendorId: vendorId,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: query.snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snap.hasError) {
                          return Center(child: Text('載入失敗：${snap.error}'));
                        }

                        final docs = snap.data!.docs;
                        if (docs.isEmpty) {
                          return const Center(child: Text('目前沒有訂單'));
                        }

                        final filtered = _filterClientSide(
                          docs,
                          isAdmin: isAdmin,
                          isVendor: isVendor,
                          uid: user.uid,
                        );

                        final statuses = _collectStatuses(docs).toList()
                          ..sort();
                        // 若目前 _statusFilter 不存在，強制回 all（避免 Dropdown assertion）
                        if (!statuses.contains(_statusFilter)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            setState(() => _statusFilter = 'all');
                          });
                        }

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                10,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '共 ${filtered.length} 筆',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Spacer(),
                                  DropdownButton<String>(
                                    value: _statusFilter,
                                    items: statuses
                                        .map(
                                          (s) => DropdownMenuItem(
                                            value: s,
                                            child: Text(
                                              s == 'all' ? '全部狀態' : s,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) => setState(
                                      () => _statusFilter = v ?? 'all',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final doc = filtered[i];
                                  final d = doc.data();

                                  final createdAt = _toDate(d['createdAt']);
                                  final status = _s(d['status']).isEmpty
                                      ? '-'
                                      : _s(d['status']);
                                  final vendor = _s(d['vendorId']).isEmpty
                                      ? '-'
                                      : _s(d['vendorId']);
                                  final buyerName = _s(d['buyerName']);
                                  final buyerEmail = _s(d['buyerEmail']);

                                  final total = _toNum(
                                    d['total'],
                                    fallback: _toNum(d['amount'], fallback: 0),
                                  );
                                  final currency = _s(d['currency']).isEmpty
                                      ? 'NT\$'
                                      : _s(d['currency']);

                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _statusColor(
                                        context,
                                        status,
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long_outlined,
                                      ),
                                    ),
                                    title: Text(
                                      '訂單 ${doc.id}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${_fmtDateTime(createdAt)} ｜ '
                                      '狀態：$status ｜ '
                                      '金額：$currency${total.toStringAsFixed(0)}'
                                      '${isAdmin ? ' ｜ vendorId：$vendor' : ''}'
                                      '${(buyerName.isNotEmpty || buyerEmail.isNotEmpty) ? ' ｜ 買家：${buyerName.isNotEmpty ? buyerName : buyerEmail}' : ''}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: IconButton(
                                      tooltip: '預覽',
                                      icon: const Icon(
                                        Icons.remove_red_eye_outlined,
                                      ),
                                      onPressed: () => _openPreview(
                                        doc,
                                        isAdmin: isAdmin,
                                        isVendor: isVendor,
                                      ),
                                    ),
                                    onTap: () => _openPreview(
                                      doc,
                                      isAdmin: isAdmin,
                                      isVendor: isVendor,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopFilters({required bool isAdmin, required String vendorId}) {
    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 760;

        final search = TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: '搜尋：訂單ID / 狀態 / vendorId / 買家姓名 / Email',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        );

        final vendorFilter = TextField(
          controller: _vendorFilterCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.store_mall_directory_outlined),
            hintText: 'vendorId 篩選（Admin）',
            border: const OutlineInputBorder(),
            isDense: true,
            helperText: isAdmin ? '留空 = 全部廠商' : '你的 vendorId：$vendorId',
          ),
          enabled: isAdmin,
        );

        if (isNarrow) {
          return Column(
            children: [
              search,
              const SizedBox(height: 10),
              if (isAdmin) vendorFilter,
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: search),
            const SizedBox(width: 12),
            if (isAdmin) Expanded(flex: 2, child: vendorFilter),
          ],
        );
      },
    );
  }
}
