// lib/pages/admin/marketing/admin_coupons_page.dart
//
// ✅ AdminCouponsPage（正式可用穩定版 v3.5）
// ------------------------------------------------------------
// - Firestore 即時更新（snapshots）
// - 搜尋 / 篩選 / 排序（本地處理，避開複合索引）
// - 批次啟用 / 停用 / 刪除（含刪除確認）
// - KPI 統計卡片（防 Overflow）
// - 完全避免 Column overflow（上方工具列固定 + 內容 ListView）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminCouponsPage extends StatefulWidget {
  const AdminCouponsPage({super.key});

  @override
  State<AdminCouponsPage> createState() => _AdminCouponsPageState();
}

class _AdminCouponsPageState extends State<AdminCouponsPage> {
  final _searchCtrl = TextEditingController();

  String _filterStatus = 'all'; // all/active/upcoming/expired
  String _sortBy = 'updatedAt'; // updatedAt/startAt/usedCount
  bool _descending = true;

  // ✅ FIX: prefer_final_fields（Set 本身可變，field 可 final）
  final Set<String> _selected = <String>{};

  // 拉多少筆進來做本地過濾/排序
  static const int _limit = 500;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // =====================================================
  // Firestore Stream（只做最基本排序 + 限制筆數）
  // =====================================================
  Query<Map<String, dynamic>> _baseQuery() {
    // 這裡不要加 where(keyword...)，避免與 orderBy 衝突/索引爆炸
    return FirebaseFirestore.instance
        .collection('coupons')
        .orderBy('updatedAt', descending: true)
        .limit(_limit);
  }

  // =====================================================
  // Helpers（容錯：num/string/timestamp）
  // =====================================================
  String _s(dynamic v, [String fallback = '']) =>
      (v == null ? fallback : v.toString());

  num _n(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? fallback;
  }

  DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.tryParse(v.toString());
  }

  bool _isActive(Map<String, dynamic> d, DateTime now) {
    final isActive = d['isActive'] == true;
    if (!isActive) return false;

    final startAt = _dt(d['startAt']);
    final endAt = _dt(d['endAt']);

    if (startAt != null && startAt.isAfter(now)) return false;
    if (endAt != null && endAt.isBefore(now)) return false;
    return true;
  }

  bool _isUpcoming(Map<String, dynamic> d, DateTime now) {
    final startAt = _dt(d['startAt']);
    return startAt != null && startAt.isAfter(now);
  }

  bool _isExpired(Map<String, dynamic> d, DateTime now) {
    final endAt = _dt(d['endAt']);
    return endAt != null && endAt.isBefore(now);
  }

  // =====================================================
  // 本地篩選 / 搜尋 / 排序
  // =====================================================
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyLocal(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final now = DateTime.now();
    final kw = _searchCtrl.text.trim().toLowerCase();

    bool matchStatus(Map<String, dynamic> d) {
      switch (_filterStatus) {
        case 'active':
          return _isActive(d, now);
        case 'upcoming':
          return _isUpcoming(d, now);
        case 'expired':
          return _isExpired(d, now);
        default:
          return true;
      }
    }

    bool matchKeyword(Map<String, dynamic> d, String id) {
      if (kw.isEmpty) return true;
      final title = _s(d['title']).toLowerCase();
      final code = _s(d['code']).toLowerCase();
      final name = _s(d['name']).toLowerCase();
      return id.toLowerCase().contains(kw) ||
          title.contains(kw) ||
          name.contains(kw) ||
          code.contains(kw);
    }

    final filtered = docs
        .where((doc) {
          final d = doc.data();
          return matchStatus(d) && matchKeyword(d, doc.id);
        })
        .toList(growable: false);

    int cmp(
      QueryDocumentSnapshot<Map<String, dynamic>> a,
      QueryDocumentSnapshot<Map<String, dynamic>> b,
    ) {
      final da = a.data();
      final db = b.data();

      int base;
      switch (_sortBy) {
        case 'startAt':
          final ta =
              _dt(da['startAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final tb =
              _dt(db['startAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
          base = ta.compareTo(tb);
          break;
        case 'usedCount':
          final ua = _n(da['usedCount']).toDouble();
          final ub = _n(db['usedCount']).toDouble();
          base = ua.compareTo(ub);
          break;
        case 'updatedAt':
        default:
          final ta =
              _dt(da['updatedAt']) ??
              _dt(da['createdAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final tb =
              _dt(db['updatedAt']) ??
              _dt(db['createdAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          base = ta.compareTo(tb);
          break;
      }

      if (_descending) base = -base;
      if (base != 0) return base;

      // 同值時用 id 穩定排序
      return a.id.compareTo(b.id);
    }

    filtered.sort(cmp);
    return filtered;
  }

  // =====================================================
  // 批次操作
  // =====================================================
  Future<void> _batchToggle(bool newState) async {
    if (_selected.isEmpty) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in _selected) {
        final ref = FirebaseFirestore.instance.collection('coupons').doc(id);
        batch.update(ref, {
          'isActive': newState,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      final count = _selected.length;
      if (mounted) {
        setState(() => _selected.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已批次${newState ? '啟用' : '停用'} $count 筆')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('批次操作失敗：$e')));
    }
  }

  Future<void> _batchDelete() async {
    if (_selected.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除確認'),
        content: Text('確定要刪除 ${_selected.length} 筆優惠券嗎？此操作不可復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in _selected) {
        final ref = FirebaseFirestore.instance.collection('coupons').doc(id);
        batch.delete(ref);
      }
      await batch.commit();

      final count = _selected.length;
      if (mounted) {
        setState(() => _selected.clear());
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已刪除 $count 筆優惠券')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('批次刪除失敗：$e')));
    }
  }

  // =====================================================
  // KPI
  // =====================================================
  Widget _kpiSummary(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) return const SizedBox.shrink();

    num totalIssued = 0, totalUsed = 0, totalClicks = 0;
    for (final doc in docs) {
      final d = doc.data();
      totalIssued += _n(d['issuedCount']);
      totalUsed += _n(d['usedCount']);
      totalClicks += _n(d['clickCount']);
    }

    final avgCTR = totalIssued > 0 ? (totalClicks / totalIssued * 100) : 0.0;
    final avgCVR = totalIssued > 0 ? (totalUsed / totalIssued * 100) : 0.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _kpiCard('總發放量', totalIssued.toInt().toString(), Icons.local_offer),
          _kpiCard('總使用量', totalUsed.toInt().toString(), Icons.check_circle),
          _kpiCard('平均 CTR', '${avgCTR.toStringAsFixed(1)}%', Icons.touch_app),
          _kpiCard(
            '平均 CVR',
            '${avgCVR.toStringAsFixed(1)}%',
            Icons.trending_up,
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon) {
    return Container(
      width: 180,
      constraints: const BoxConstraints(minHeight: 90),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy/MM/dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('優惠券管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新整理（重建畫面）',
            onPressed: () => setState(() {}),
          ),
          if (_selected.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: '批次操作',
              onSelected: (v) {
                if (v == 'enable') _batchToggle(true);
                if (v == 'disable') _batchToggle(false);
                if (v == 'delete') _batchDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'enable', child: Text('批次啟用')),
                PopupMenuItem(value: 'disable', child: Text('批次停用')),
                PopupMenuItem(value: 'delete', child: Text('批次刪除')),
              ],
            ),
          IconButton(
            tooltip: '新增優惠券',
            icon: const Icon(Icons.add),
            onPressed: () =>
                Navigator.pushNamed(context, '/admin/coupons/edit'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _baseQuery().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('讀取失敗：${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rawDocs = snap.data!.docs;
                final visible = _applyLocal(rawDocs);

                // 清理：如果某些 id 已不存在（被刪除），選取集合也清一下
                final visibleIds = rawDocs.map((e) => e.id).toSet();
                _selected.removeWhere((id) => !visibleIds.contains(id));

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_selected.isNotEmpty) _selectedBar(visible),
                    _kpiSummary(visible),
                    const SizedBox(height: 14),
                    if (visible.isEmpty)
                      const Center(child: Text('尚無符合條件的優惠券'))
                    else
                      ...visible.map((doc) => _couponTile(doc, df)),
                    const SizedBox(height: 60),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedBar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> visible,
  ) {
    final canSelectAll = visible.isNotEmpty;
    final allVisibleSelected =
        canSelectAll && visible.every((d) => _selected.contains(d.id));

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '已選取：${_selected.length} 筆',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            if (canSelectAll)
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    if (allVisibleSelected) {
                      for (final d in visible) {
                        _selected.remove(d.id);
                      }
                    } else {
                      for (final d in visible) {
                        _selected.add(d.id);
                      }
                    }
                  });
                },
                icon: Icon(
                  allVisibleSelected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                ),
                label: Text(allVisibleSelected ? '取消全選（可見）' : '全選（可見）'),
              ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _selected.clear()),
              icon: const Icon(Icons.clear),
              label: const Text('清空選取'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _couponTile(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    DateFormat df,
  ) {
    final d = doc.data();
    final id = doc.id;
    final selected = _selected.contains(id);

    final title = _s(d['title'], _s(d['name'], '未命名'));
    final code = _s(d['code']);

    final startAt = _dt(d['startAt']);
    final endAt = _dt(d['endAt']);
    final dateText = startAt == null
        ? ''
        : '期間：${df.format(startAt)} ~ ${endAt != null ? df.format(endAt) : ''}';

    final issued = _n(d['issuedCount']).toDouble();
    final clicks = _n(d['clickCount']).toDouble();
    final used = _n(d['usedCount']).toDouble();

    final ctr = issued > 0 ? (clicks / issued * 100) : 0.0;
    final cvr = issued > 0 ? (used / issued * 100) : 0.0;

    final isActive = d['isActive'] == true;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onLongPress: () {
          setState(() {
            if (selected) {
              _selected.remove(id);
            } else {
              _selected.add(id);
            }
          });
        },
        leading: Checkbox(
          value: selected,
          onChanged: (v) {
            setState(() {
              if (v == true) {
                _selected.add(id);
              } else {
                _selected.remove(id);
              }
            });
          },
        ),
        title: Row(
          children: [
            Switch(
              value: isActive,
              onChanged: (v) async {
                try {
                  await FirebaseFirestore.instance
                      .collection('coupons')
                      .doc(id)
                      .update({
                        'isActive': v,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
                }
              },
            ),
            Expanded(
              child: Text(
                '$title${code.isNotEmpty ? '  |  $code' : ''}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              'CTR ${ctr.toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.blue),
            ),
            const SizedBox(width: 8),
            Text(
              'CVR ${cvr.toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.green),
            ),
          ],
        ),
        subtitle: dateText.isEmpty ? null : Text(dateText),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => Navigator.pushNamed(
            context,
            '/admin/coupons/edit',
            arguments: {'id': id},
          ),
        ),
      ),
    );
  }

  // =====================================================
  // 工具列（搜尋 / 篩選 / 排序）
  // =====================================================
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, c) {
          // 用 Wrap 避免小螢幕 Row overflow
          return Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: c.maxWidth >= 820 ? 360 : c.maxWidth,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: '搜尋優惠券代碼 / 標題',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                    suffixIcon: _searchCtrl.text.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除',
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => setState(() {}),
                ),
              ),
              DropdownButton<String>(
                value: _filterStatus,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('全部')),
                  DropdownMenuItem(value: 'active', child: Text('進行中')),
                  DropdownMenuItem(value: 'upcoming', child: Text('未開始')),
                  DropdownMenuItem(value: 'expired', child: Text('已結束')),
                ],
                onChanged: (v) => setState(() => _filterStatus = v ?? 'all'),
              ),
              DropdownButton<String>(
                value: _sortBy,
                items: const [
                  DropdownMenuItem(value: 'updatedAt', child: Text('最近更新')),
                  DropdownMenuItem(value: 'startAt', child: Text('開始時間')),
                  DropdownMenuItem(value: 'usedCount', child: Text('使用量')),
                ],
                onChanged: (v) => setState(() => _sortBy = v ?? 'updatedAt'),
              ),
              IconButton(
                tooltip: _descending ? '降冪' : '升冪',
                icon: Icon(
                  _descending ? Icons.arrow_downward : Icons.arrow_upward,
                ),
                onPressed: () => setState(() => _descending = !_descending),
              ),
            ],
          );
        },
      ),
    );
  }
}
