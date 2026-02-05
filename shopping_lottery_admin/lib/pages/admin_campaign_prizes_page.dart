// lib/pages/admin_campaign_prizes_page.dart
//
// ✅ AdminCampaignPrizesPage（最終穩定完整版｜獎項管理｜可編譯）
// ------------------------------------------------------------
// Firestore：campaigns/{campaignId}/prizes/{prizeId}
// 建議欄位：
// - title: String
// - description: String
// - quantity: int
// - isActive: bool
// - sortIndex: int (optional)
// - imageUrl: String (optional)
// - createdAt / updatedAt: Timestamp
//
// 權限：
// - Admin：可管理所有活動的獎項
// - Vendor：僅能管理 vendorId == 自己 vendorId 的活動獎項
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';

class AdminCampaignPrizesPage extends StatefulWidget {
  final String campaignId;
  const AdminCampaignPrizesPage({super.key, required this.campaignId});

  @override
  State<AdminCampaignPrizesPage> createState() => _AdminCampaignPrizesPageState();
}

class _AdminCampaignPrizesPageState extends State<AdminCampaignPrizesPage> {
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  bool _accessDenied = false;

  String _role = '';
  String _myVendorId = '';
  String _campaignTitle = '';
  String _campaignVendorId = '';

  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _accessDenied = false;
    });

    try {
      final gate = context.read<AdminGate>();
      _role = (gate.cachedRoleInfo?.role ?? '').toLowerCase().trim();
      _myVendorId = (gate.cachedVendorId ?? '').trim();

      if (_role.isEmpty) {
        setState(() {
          _accessDenied = true;
          _loading = false;
        });
        return;
      }

      final campDoc = await _db.collection('campaigns').doc(widget.campaignId).get();
      if (!campDoc.exists) {
        setState(() {
          _accessDenied = true;
          _loading = false;
        });
        _snack('活動不存在或已被刪除');
        return;
      }

      final d = campDoc.data() ?? <String, dynamic>{};
      _campaignTitle = (d['title'] ?? '').toString().trim();
      _campaignVendorId = (d['vendorId'] ?? '').toString().trim();

      // Vendor 僅能管理自己活動
      if (_role == 'vendor') {
        if (_myVendorId.isEmpty) {
          setState(() {
            _accessDenied = true;
            _loading = false;
          });
          _snack('你的帳號缺少 vendorId，無法使用獎項管理');
          return;
        }
        if (_campaignVendorId.isNotEmpty && _campaignVendorId != _myVendorId) {
          setState(() {
            _accessDenied = true;
            _loading = false;
          });
          _snack('你無權限管理其他 Vendor 的活動獎項');
          return;
        }
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _accessDenied = true;
        _loading = false;
      });
      _snack('初始化失敗：$e');
    }
  }

  CollectionReference<Map<String, dynamic>> get _prizesCol =>
      _db.collection('campaigns').doc(widget.campaignId).collection('prizes');

  Query<Map<String, dynamic>> _prizesQuery() {
    // 先用 sortIndex，再用 updatedAt
    // 若你資料沒有 sortIndex，也不影響（Firestore 允許 orderBy 不存在欄位，但排序結果可能不一致）
    return _prizesCol.orderBy('sortIndex').orderBy('updatedAt', descending: true);
  }

  bool _matchQuery(Map<String, dynamic> d, String q) {
    final v = q.toLowerCase().trim();
    if (v.isEmpty) return true;
    final title = (d['title'] ?? '').toString().toLowerCase();
    final desc = (d['description'] ?? '').toString().toLowerCase();
    return title.contains(v) || desc.contains(v);
  }

  Future<void> _toggleActive(String prizeId, bool to) async {
    try {
      await _prizesCol.doc(prizeId).set({
        'isActive': to,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _snack('更新狀態失敗：$e');
    }
  }

  Future<void> _deletePrize(String prizeId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除獎項'),
        content: const Text('確定刪除此獎項？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _prizesCol.doc(prizeId).delete();
      _snack('已刪除');
    } catch (e) {
      _snack('刪除失敗：$e');
    }
  }

  Future<void> _openEditSheet({String? prizeId, Map<String, dynamic>? existing}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PrizeEditSheet(
        campaignId: widget.campaignId,
        prizeId: prizeId,
        existing: existing,
      ),
    );

    if (result == true) {
      _snack('已儲存');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_accessDenied) {
      return Scaffold(
        appBar: AppBar(title: const Text('獎項管理')),
        body: const Center(child: Text('無權限存取獎項管理')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('獎項管理${_campaignTitle.isEmpty ? '' : '｜$_campaignTitle'}'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: _bootstrap,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _prizesQuery().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('錯誤：${snap.error}'));
                }
                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Center(child: Text('尚無獎項'));
                }

                final filtered = docs.where((doc) {
                  final d = doc.data();
                  return _matchQuery(d, _query);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('無符合條件的獎項'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final doc = filtered[i];
                    final d = doc.data();
                    final id = doc.id;

                    final title = (d['title'] ?? '(未命名獎項)').toString();
                    final desc = (d['description'] ?? '').toString();
                    final qty = (d['quantity'] is num) ? (d['quantity'] as num).toInt() : 0;
                    final active = d['isActive'] == true;

                    return ListTile(
                      leading: const Icon(Icons.card_giftcard),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (desc.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                desc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text('數量：$qty｜狀態：${active ? '啟用' : '停用'}'),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          switch (v) {
                            case 'edit':
                              await _openEditSheet(prizeId: id, existing: d);
                              break;
                            case 'toggle':
                              await _toggleActive(id, !active);
                              break;
                            case 'delete':
                              await _deletePrize(id);
                              break;
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('編輯')),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(active ? '停用' : '啟用'),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(value: 'delete', child: Text('刪除')),
                        ],
                      ),
                      onTap: () => _openEditSheet(prizeId: id, existing: d),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('新增獎項'),
        onPressed: () => _openEditSheet(),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜尋獎項名稱/描述',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (_campaignVendorId.isNotEmpty)
            Text('Vendor：$_campaignVendorId', style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// ✅ BottomSheet：新增 / 編輯獎項
// ------------------------------------------------------------
class _PrizeEditSheet extends StatefulWidget {
  final String campaignId;
  final String? prizeId;
  final Map<String, dynamic>? existing;

  const _PrizeEditSheet({
    required this.campaignId,
    this.prizeId,
    this.existing,
  });

  @override
  State<_PrizeEditSheet> createState() => _PrizeEditSheetState();
}

class _PrizeEditSheetState extends State<_PrizeEditSheet> {
  final _db = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _sortCtrl;
  late final TextEditingController _imgCtrl;

  bool _isActive = true;
  bool _saving = false;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('campaigns').doc(widget.campaignId).collection('prizes');

  @override
  void initState() {
    super.initState();
    final d = widget.existing ?? <String, dynamic>{};
    _titleCtrl = TextEditingController(text: (d['title'] ?? '').toString());
    _descCtrl = TextEditingController(text: (d['description'] ?? '').toString());
    _qtyCtrl = TextEditingController(
      text: ((d['quantity'] is num) ? (d['quantity'] as num).toInt() : (d['quantity'] ?? 0)).toString(),
    );
    _sortCtrl = TextEditingController(
      text: ((d['sortIndex'] is num) ? (d['sortIndex'] as num).toInt() : (d['sortIndex'] ?? 0)).toString(),
    );
    _imgCtrl = TextEditingController(text: (d['imageUrl'] ?? '').toString());
    _isActive = d['isActive'] == true || widget.prizeId == null; // 新增預設 true
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    _sortCtrl.dispose();
    _imgCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int _toInt(String s, {int fallback = 0}) {
    final v = int.tryParse(s.trim());
    return v ?? fallback;
  }

  Future<void> _save() async {
    if (_saving) return;
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _saving = true);
    try {
      final now = FieldValue.serverTimestamp();

      final data = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'quantity': _toInt(_qtyCtrl.text, fallback: 0),
        'sortIndex': _toInt(_sortCtrl.text, fallback: 0),
        'imageUrl': _imgCtrl.text.trim().isEmpty ? FieldValue.delete() : _imgCtrl.text.trim(),
        'isActive': _isActive,
        'updatedAt': now,
      };

      if (widget.prizeId == null) {
        data['createdAt'] = now;
        await _col.add(data);
      } else {
        await _col.doc(widget.prizeId).set(data, SetOptions(merge: true));
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: bottom + 16, top: 8),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.prizeId == null ? '新增獎項' : '編輯獎項',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? '儲存中…' : '儲存'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: '獎項名稱',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '請輸入獎項名稱' : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: '獎項描述（選填）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '數量',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null || n < 0) return '請輸入 >= 0 的整數';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _sortCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '排序 sortIndex',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _imgCtrl,
                decoration: const InputDecoration(
                  labelText: '圖片 URL（選填）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 6),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('啟用獎項'),
                value: _isActive,
                onChanged: _saving ? null : (v) => setState(() => _isActive = v),
              ),

              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_saving ? '儲存中…' : '儲存'),
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
