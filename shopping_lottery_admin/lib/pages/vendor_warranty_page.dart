// lib/pages/vendor_warranty_page.dart
//
// ✅ VendorWarrantyPage（廠商保固/維修申請管理｜可編譯完整版｜已移除不必要 ! ）
// ------------------------------------------------------------
// 功能：
// - vendorId hydration（widget.vendorId / route args / FirebaseAuth uid）
// - 保固單列表（warranty_claims）
// - 搜尋 / 狀態篩選
// - 建立保固單（簡化）
// - 詳情頁（訊息串 warranty_messages）
// - 廠商回覆 + 更新狀態
//
// 依賴：cloud_firestore, firebase_auth

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VendorWarrantyPage extends StatefulWidget {
  final String? vendorId;
  const VendorWarrantyPage({super.key, this.vendorId});

  @override
  State<VendorWarrantyPage> createState() => _VendorWarrantyPageState();
}

enum _WarrantyFilter { all, open, pending, processing, closed, rejected }

class _VendorWarrantyPageState extends State<VendorWarrantyPage> {
  String _vendorId = '';
  _WarrantyFilter _filter = _WarrantyFilter.all;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _vendorId = (widget.vendorId ?? '').trim();
  }

  void _hydrateVendorIdIfNeeded() {
    if (_vendorId.isNotEmpty) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    String vid = '';

    if (args is String) {
      vid = args.trim();
    } else if (args is Map) {
      final v = args['vendorId'] ?? args['vendor_id'] ?? args['uid'];
      if (v != null) vid = v.toString().trim();
    }

    if (vid.isEmpty) {
      vid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    }

    if (vid.isNotEmpty) setState(() => _vendorId = vid);
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Query<Map<String, dynamic>> _baseQuery() {
    return FirebaseFirestore.instance
        .collection('warranty_claims')
        .where('vendorId', isEqualTo: _vendorId)
        .orderBy('updatedAt', descending: true);
  }

  bool _matchFilter(Map<String, dynamic> d) {
    final status = _s(d['status']).toLowerCase();
    switch (_filter) {
      case _WarrantyFilter.all:
        return true;
      case _WarrantyFilter.open:
        return status == 'open';
      case _WarrantyFilter.pending:
        return status == 'pending';
      case _WarrantyFilter.processing:
        return status == 'processing';
      case _WarrantyFilter.closed:
        return status == 'closed';
      case _WarrantyFilter.rejected:
        return status == 'rejected';
    }
  }

  bool _matchKeyword(Map<String, dynamic> d) {
    final k = _keyword.trim().toLowerCase();
    if (k.isEmpty) return true;

    final title = _s(d['title']).toLowerCase();
    final orderId = _s(d['orderId']).toLowerCase();
    final productId = _s(d['productId']).toLowerCase();
    final customer = _s(d['customerName']).toLowerCase();
    final last = _s(d['lastMessage']).toLowerCase();

    return title.contains(k) ||
        orderId.contains(k) ||
        productId.contains(k) ||
        customer.contains(k) ||
        last.contains(k);
  }

  // ------------------------------------------------------------
  // Create / Update
  // ------------------------------------------------------------
  Future<void> _createClaim() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final orderCtrl = TextEditingController();
    final productCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    String status = 'open';

    final ok =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('新增保固/維修單'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: '標題（必填）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: '問題描述（必填）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: orderCtrl,
                            decoration: const InputDecoration(
                              labelText: '訂單號（選填）',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: productCtrl,
                            decoration: const InputDecoration(
                              labelText: '商品ID（選填）',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: '客戶姓名（選填）',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: phoneCtrl,
                            decoration: const InputDecoration(
                              labelText: '電話（選填）',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email（選填）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: status, // ✅ value -> initialValue
                      items: const [
                        DropdownMenuItem(value: 'open', child: Text('open')),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('pending'),
                        ),
                        DropdownMenuItem(
                          value: 'processing',
                          child: Text('processing'),
                        ),
                        DropdownMenuItem(
                          value: 'closed',
                          child: Text('closed'),
                        ),
                        DropdownMenuItem(
                          value: 'rejected',
                          child: Text('rejected'),
                        ),
                      ],
                      onChanged: (v) => status = v ?? 'open',
                      decoration: const InputDecoration(
                        labelText: '初始狀態',
                        border: OutlineInputBorder(),
                      ),
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
                child: const Text('建立'),
              ),
            ],
          ),
        ) ??
        false;

    // ✅ 先把值全部取出，再 dispose（避免 disposed controller 被讀取）
    final title = titleCtrl.text.trim();
    final desc = descCtrl.text.trim();
    final orderId = orderCtrl.text.trim();
    final productId = productCtrl.text.trim();
    final customerName = nameCtrl.text.trim();
    final customerPhone = phoneCtrl.text.trim();
    final customerEmail = emailCtrl.text.trim();

    titleCtrl.dispose();
    descCtrl.dispose();
    orderCtrl.dispose();
    productCtrl.dispose();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();

    if (!ok) return;

    if (_vendorId.isEmpty) {
      _snack('尚未取得 vendorId');
      return;
    }
    if (title.isEmpty) {
      _snack('請輸入標題');
      return;
    }
    if (desc.isEmpty) {
      _snack('請輸入問題描述');
      return;
    }

    try {
      final now = FieldValue.serverTimestamp();
      final ref = await FirebaseFirestore.instance
          .collection('warranty_claims')
          .add({
            'vendorId': _vendorId,
            'title': title,
            'description': desc,
            'orderId': orderId,
            'productId': productId,
            'customerName': customerName,
            'customerPhone': customerPhone,
            'customerEmail': customerEmail,
            'status': status,
            'lastMessage': desc,
            'createdAt': now,
            'updatedAt': now,
          });

      await ref.collection('messages').add({
        'sender': 'vendor',
        'text': desc,
        'createdAt': now,
      });

      _snack('已建立保固單');
    } catch (e) {
      _snack('建立失敗：$e');
    }
  }

  Future<void> _setStatus(String claimId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('warranty_claims')
          .doc(claimId)
          .update({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      _snack('更新失敗：$e');
    }
  }

  Future<void> _openDetail(String claimId, Map<String, dynamic> data) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _WarrantyDetailPage(claimId: claimId, claimData: data),
      ),
    );
  }

  void _showQuickActions(String claimId, String currentStatus) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            runSpacing: 10,
            children: [
              Text(
                '狀態快速操作（目前：$currentStatus）',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _setStatus(claimId, 'open');
                      },
                      child: const Text('open'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _setStatus(claimId, 'pending');
                      },
                      child: const Text('pending'),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _setStatus(claimId, 'processing');
                      },
                      child: const Text('processing'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _setStatus(claimId, 'rejected');
                      },
                      child: const Text('rejected'),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _setStatus(claimId, 'closed');
                      },
                      child: const Text('closed'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    _hydrateVendorIdIfNeeded();

    if (_vendorId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('保固/維修')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 44, color: Colors.grey),
                const SizedBox(height: 10),
                const Text('尚未取得 vendorId（請先登入）'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (_) => false,
                  ),
                  child: const Text('前往登入'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('保固/維修'),
        actions: [
          IconButton(
            tooltip: '新增保固單',
            onPressed: _createClaim,
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          _WarrantyTopBar(
            filter: _filter,
            onFilterChanged: (v) => setState(() => _filter = v),
            onKeywordChanged: (v) => setState(() => _keyword = v),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _baseQuery().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        '讀取失敗：${snap.error}\n\n'
                        '若是索引問題：請建立 Firestore index（vendorId + updatedAt）。',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('尚無保固/維修單'));
                }

                final items = <_ClaimItem>[];
                for (final d in docs) {
                  final data = d.data();
                  if (_matchFilter(data) && _matchKeyword(data)) {
                    items.add(_ClaimItem(id: d.id, data: data));
                  }
                }

                if (items.isEmpty) {
                  return const Center(child: Text('此篩選/搜尋條件下無資料'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final d = item.data;

                    final title = _s(d['title']).isNotEmpty
                        ? _s(d['title'])
                        : item.id;
                    final status = _s(d['status']).toLowerCase();
                    final orderId = _s(d['orderId']);
                    final productId = _s(d['productId']);
                    final customer = _s(d['customerName']);
                    final last = _s(d['lastMessage']);

                    final updatedAt = _toDate(d['updatedAt']);
                    final updatedText = updatedAt == null
                        ? ''
                        : '${updatedAt.year}-${updatedAt.month.toString().padLeft(2, '0')}-${updatedAt.day.toString().padLeft(2, '0')} '
                              '${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}';

                    final meta = <String>[
                      if (orderId.isNotEmpty) '訂單：$orderId',
                      if (productId.isNotEmpty) '商品：$productId',
                      if (customer.isNotEmpty) '客戶：$customer',
                      if (updatedText.isNotEmpty) '更新：$updatedText',
                    ].join('  ·  ');

                    return Card(
                      child: ListTile(
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (meta.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (last.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '最後訊息：$last',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                        trailing: _StatusChip(status: status),
                        onTap: () => _openDetail(item.id, d),
                        onLongPress: () => _showQuickActions(item.id, status),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createClaim,
        icon: const Icon(Icons.add),
        label: const Text('新增保固單'),
      ),
    );
  }
}

// ============================================================
// Detail page
// ============================================================

class _WarrantyDetailPage extends StatefulWidget {
  final String claimId;
  final Map<String, dynamic> claimData;

  const _WarrantyDetailPage({required this.claimId, required this.claimData});

  @override
  State<_WarrantyDetailPage> createState() => _WarrantyDetailPageState();
}

class _WarrantyDetailPageState extends State<_WarrantyDetailPage> {
  final _msgCtrl = TextEditingController();

  String _s(dynamic v) => (v ?? '').toString().trim();

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    try {
      final ref = FirebaseFirestore.instance
          .collection('warranty_claims')
          .doc(widget.claimId);
      final now = FieldValue.serverTimestamp();

      await ref.collection('messages').add({
        'sender': 'vendor',
        'text': text,
        'createdAt': now,
      });

      await ref.set({
        'lastMessage': text,
        'updatedAt': now,
      }, SetOptions(merge: true));

      _msgCtrl.clear();
    } catch (e) {
      _snack('送出失敗：$e');
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _s(widget.claimData['title']).isNotEmpty
        ? _s(widget.claimData['title'])
        : widget.claimId;

    final status = _s(widget.claimData['status']).toLowerCase();
    final orderId = _s(widget.claimData['orderId']);
    final productId = _s(widget.claimData['productId']);
    final customerName = _s(widget.claimData['customerName']);
    final customerPhone = _s(widget.claimData['customerPhone']);
    final customerEmail = _s(widget.claimData['customerEmail']);
    final desc = _s(widget.claimData['description']);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatusChip(status: status),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (orderId.isNotEmpty) Text('訂單：$orderId'),
                    if (productId.isNotEmpty) Text('商品：$productId'),
                    if (customerName.isNotEmpty) Text('客戶：$customerName'),
                    if (customerPhone.isNotEmpty) Text('電話：$customerPhone'),
                    if (customerEmail.isNotEmpty) Text('Email：$customerEmail'),
                    const SizedBox(height: 8),
                    Text(desc.isEmpty ? '（無描述）' : desc),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('warranty_claims')
                  .doc(widget.claimId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('讀取失敗：${snap.error}'));
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('尚無訊息'));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    final sender = _s(d['sender']).toLowerCase();
                    final text = _s(d['text']);
                    final isVendor = sender == 'vendor';

                    return Align(
                      alignment: isVendor
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        constraints: const BoxConstraints(maxWidth: 560),
                        decoration: BoxDecoration(
                          color: isVendor
                              ? Colors.blue.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Text(text.isEmpty ? '（空訊息）' : text),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '輸入回覆…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                    label: const Text('送出'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Widgets
// ============================================================

class _WarrantyTopBar extends StatelessWidget {
  final _WarrantyFilter filter;
  final ValueChanged<_WarrantyFilter> onFilterChanged;
  final ValueChanged<String> onKeywordChanged;

  const _WarrantyTopBar({
    required this.filter,
    required this.onFilterChanged,
    required this.onKeywordChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          TextField(
            onChanged: onKeywordChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '搜尋：標題 / 訂單 / 商品 / 客戶 / 最後訊息',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('全部'),
                  selected: filter == _WarrantyFilter.all,
                  onSelected: (_) => onFilterChanged(_WarrantyFilter.all),
                ),
                ChoiceChip(
                  label: const Text('open'),
                  selected: filter == _WarrantyFilter.open,
                  onSelected: (_) => onFilterChanged(_WarrantyFilter.open),
                ),
                ChoiceChip(
                  label: const Text('pending'),
                  selected: filter == _WarrantyFilter.pending,
                  onSelected: (_) => onFilterChanged(_WarrantyFilter.pending),
                ),
                ChoiceChip(
                  label: const Text('processing'),
                  selected: filter == _WarrantyFilter.processing,
                  onSelected: (_) =>
                      onFilterChanged(_WarrantyFilter.processing),
                ),
                ChoiceChip(
                  label: const Text('closed'),
                  selected: filter == _WarrantyFilter.closed,
                  onSelected: (_) => onFilterChanged(_WarrantyFilter.closed),
                ),
                ChoiceChip(
                  label: const Text('rejected'),
                  selected: filter == _WarrantyFilter.rejected,
                  onSelected: (_) => onFilterChanged(_WarrantyFilter.rejected),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color color;
    switch (s) {
      case 'open':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'processing':
        color = Colors.blue;
        break;
      case 'closed':
        color = Colors.grey;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.blueGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        s.isEmpty ? '—' : s,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }
}

class _ClaimItem {
  final String id;
  final Map<String, dynamic> data;
  const _ClaimItem({required this.id, required this.data});
}
