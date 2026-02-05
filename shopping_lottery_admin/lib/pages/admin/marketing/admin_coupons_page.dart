// lib/pages/admin/marketing/admin_coupons_page.dart
//
// ✅ AdminCouponsPage（升級完整穩定版 v3.4）
// ------------------------------------------------------------
// - 搜尋 / 篩選 / 排序
// - 批次啟用 / 停用 / 刪除
// - KPI 統計卡片（防 Overflow）
// - Firestore 實時更新
// - Scroll 修正：完全避免 Column overflow
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
  String _filterStatus = 'all';
  String _sortBy = 'updatedAt';
  bool _descending = true;
  bool _loading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  // =====================================================
  // Firestore 載入資料
  // =====================================================
  Future<void> _loadCoupons() async {
    setState(() => _loading = true);
    try {
      Query<Map<String, dynamic>> q =
          FirebaseFirestore.instance.collection('coupons');

      final keyword = _searchCtrl.text.trim();
      if (keyword.isNotEmpty) {
        q = q
            .where('title', isGreaterThanOrEqualTo: keyword)
            .where('title', isLessThanOrEqualTo: '$keyword\uf8ff');
      }

      final now = DateTime.now();
      if (_filterStatus == 'active') {
        q = q.where('isActive', isEqualTo: true);
      } else if (_filterStatus == 'upcoming') {
        q = q.where('startAt', isGreaterThan: Timestamp.fromDate(now));
      } else if (_filterStatus == 'expired') {
        q = q.where('endAt', isLessThan: Timestamp.fromDate(now));
      }

      q = q.orderBy(_sortBy, descending: _descending);

      final snap = await q.get();
      if (mounted) {
        setState(() {
          _docs = snap.docs;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('讀取失敗：$e')));
    }
  }

  // =====================================================
  // 批次操作
  // =====================================================
  Future<void> _batchToggle(bool newState) async {
    if (_selected.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final id in _selected) {
      final ref = FirebaseFirestore.instance.collection('coupons').doc(id);
      batch.update(ref, {'isActive': newState});
    }
    await batch.commit();
    final count = _selected.length;
    _selected.clear();
    await _loadCoupons();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已批次${newState ? '啟用' : '停用'} $count 筆')),
    );
  }

  Future<void> _batchDelete() async {
    if (_selected.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final id in _selected) {
      final ref = FirebaseFirestore.instance.collection('coupons').doc(id);
      batch.delete(ref);
    }
    await batch.commit();
    final count = _selected.length;
    _selected.clear();
    await _loadCoupons();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已刪除 $count 筆優惠券')));
  }

  // =====================================================
  // KPI 卡片（已修正 Overflow）
  // =====================================================
  Widget _kpiSummary() {
    if (_docs.isEmpty) return const SizedBox.shrink();

    num totalIssued = 0, totalUsed = 0, totalClicks = 0;
    for (final d in _docs) {
      final data = d.data();
      totalIssued += (data['issuedCount'] ?? 0) as num;
      totalUsed += (data['usedCount'] ?? 0) as num;
      totalClicks += (data['clickCount'] ?? 0) as num;
    }

    final avgCTR = totalIssued > 0 ? (totalClicks / totalIssued * 100) : 0;
    final avgCVR = totalIssued > 0 ? (totalUsed / totalIssued * 100) : 0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _kpiCard('總發放量', totalIssued.toInt().toString(), Icons.local_offer),
          _kpiCard('總使用量', totalUsed.toInt().toString(), Icons.check_circle),
          _kpiCard('平均 CTR', '${avgCTR.toStringAsFixed(1)}%', Icons.touch_app),
          _kpiCard('平均 CVR', '${avgCVR.toStringAsFixed(1)}%', Icons.trending_up),
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
        mainAxisSize: MainAxisSize.min, // ✅ 防止 Overflow
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 20),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
  // UI 主體
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
            tooltip: '重新整理',
            onPressed: _loadCoupons,
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
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(df),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(DateFormat df) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kpiSummary(),
          const SizedBox(height: 20),
          if (_docs.isEmpty)
            const Center(child: Text('尚無優惠券')),
          if (_docs.isNotEmpty)
            ListView.builder(
              itemCount: _docs.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, i) {
                final d = _docs[i].data();
                final id = _docs[i].id;
                final selected = _selected.contains(id);

                final startAt = (d['startAt'] as Timestamp?)?.toDate();
                final endAt = (d['endAt'] as Timestamp?)?.toDate();
                final dateText = (startAt != null)
                    ? '期間：${df.format(startAt)} ~ ${endAt != null ? df.format(endAt) : ''}'
                    : '';

                final ctr = (d['issuedCount'] ?? 0) > 0
                    ? ((d['clickCount'] ?? 0) /
                            (d['issuedCount'] ?? 1) *
                            100)
                        .toStringAsFixed(1)
                    : '0.0';
                final cvr = (d['issuedCount'] ?? 0) > 0
                    ? ((d['usedCount'] ?? 0) /
                            (d['issuedCount'] ?? 1) *
                            100)
                        .toStringAsFixed(1)
                    : '0.0';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
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
                          value: d['isActive'] == true,
                          onChanged: (v) {
                            FirebaseFirestore.instance
                                .collection('coupons')
                                .doc(id)
                                .update({'isActive': v});
                          },
                        ),
                        Expanded(
                          child: Text(
                            '${d['title'] ?? '未命名'}  |  ${d['code'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('CTR $ctr%',
                            style: const TextStyle(color: Colors.blue)),
                        const SizedBox(width: 8),
                        Text('CVR $cvr%',
                            style: const TextStyle(color: Colors.green)),
                      ],
                    ),
                    subtitle: Text(dateText),
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
              },
            ),
        ],
      ),
    );
  }

  // =====================================================
  // 工具列（搜尋 / 篩選 / 排序）
  // =====================================================
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋優惠券代碼 / 標題',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              onSubmitted: (_) => _loadCoupons(),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _filterStatus,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('全部')),
              DropdownMenuItem(value: 'active', child: Text('進行中')),
              DropdownMenuItem(value: 'upcoming', child: Text('未開始')),
              DropdownMenuItem(value: 'expired', child: Text('已結束')),
            ],
            onChanged: (v) {
              setState(() => _filterStatus = v ?? 'all');
              _loadCoupons();
            },
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _sortBy,
            items: const [
              DropdownMenuItem(value: 'updatedAt', child: Text('最近更新')),
              DropdownMenuItem(value: 'startAt', child: Text('開始時間')),
              DropdownMenuItem(value: 'usedCount', child: Text('使用率')),
            ],
            onChanged: (v) {
              setState(() => _sortBy = v ?? 'updatedAt');
              _loadCoupons();
            },
          ),
          IconButton(
            icon: Icon(
              _descending ? Icons.arrow_downward : Icons.arrow_upward,
            ),
            onPressed: () {
              setState(() => _descending = !_descending);
              _loadCoupons();
            },
          ),
        ],
      ),
    );
  }
}
