import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ✅ AdminSegmentsPage（受眾分群管理｜完整版）
/// ------------------------------------------------------------
/// - Firestore 集合：segments
/// - 功能：
///   1. 即時監聽分群列表
///   2. 搜尋（名稱、描述、建立者）
///   3. 篩選（狀態 isActive / 類型 type）
///   4. 顯示條件摘要、人數預估、建立時間
///   5. 跳轉編輯頁 `/admin/segments/edit`
/// ------------------------------------------------------------
class AdminSegmentsPage extends StatefulWidget {
  const AdminSegmentsPage({super.key});

  @override
  State<AdminSegmentsPage> createState() => _AdminSegmentsPageState();
}

class _AdminSegmentsPageState extends State<AdminSegmentsPage> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all';
  String _typeFilter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('segments')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('受眾分群管理'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          IconButton(
            tooltip: '新增分群',
            icon: const Icon(Icons.add),
            onPressed: () =>
                Navigator.pushNamed(context, '/admin/segments/edit'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text('讀取錯誤：${snap.error}'),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          final filtered = _applyFilters(docs);

          return Column(
            children: [
              _buildFilterBar(docs.length, filtered.length),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('目前沒有符合條件的分群'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final d = filtered[i].data();
                          return _segmentCard(filtered[i].id, d);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // 過濾邏輯
  // ============================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final keyword = _searchCtrl.text.trim().toLowerCase();

    return docs.where((doc) {
      final d = doc.data();
      final name = (d['name'] ?? '').toString().toLowerCase();
      final desc = (d['description'] ?? '').toString().toLowerCase();
      final creator = (d['createdBy'] ?? '').toString().toLowerCase();
      final type = (d['type'] ?? '').toString().toLowerCase();
      final isActive = d['isActive'] == true;

      bool matchSearch =
          keyword.isEmpty || name.contains(keyword) || desc.contains(keyword) || creator.contains(keyword);
      bool matchStatus = _statusFilter == 'all'
          ? true
          : (_statusFilter == 'active' ? isActive : !isActive);
      bool matchType = _typeFilter == 'all'
          ? true
          : type == _typeFilter.toLowerCase();

      return matchSearch && matchStatus && matchType;
    }).toList();
  }

  // ============================================================
  // 篩選列
  // ============================================================
  Widget _buildFilterBar(int total, int filtered) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋名稱、描述或建立者',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          DropdownButton<String>(
            value: _statusFilter,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('狀態：全部')),
              DropdownMenuItem(value: 'active', child: Text('啟用中')),
              DropdownMenuItem(value: 'inactive', child: Text('已停用')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
          ),
          DropdownButton<String>(
            value: _typeFilter,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('類型：全部')),
              DropdownMenuItem(value: 'manual', child: Text('手動建立')),
              DropdownMenuItem(value: 'auto', child: Text('自動分群')),
            ],
            onChanged: (v) => setState(() => _typeFilter = v ?? 'all'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.clear, size: 18),
            label: const Text('清除'),
            onPressed: () {
              _searchCtrl.clear();
              setState(() {
                _statusFilter = 'all';
                _typeFilter = 'all';
              });
            },
          ),
          const SizedBox(width: 10),
          Text(
            '顯示 $filtered / $total 筆',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 分群卡片顯示
  // ============================================================
  Widget _segmentCard(String id, Map<String, dynamic> d) {
    final name = (d['name'] ?? '未命名分群').toString();
    final desc = (d['description'] ?? '').toString();
    final isActive = d['isActive'] == true;
    final count = (d['memberCount'] ?? 0) as num;
    final type = (d['type'] ?? 'manual').toString();
    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
    final creator = (d['createdBy'] ?? '').toString();

    final dateText = createdAt != null
        ? DateFormat('yyyy/MM/dd HH:mm').format(createdAt)
        : '-';

    return Card(
      elevation: 1,
      child: ListTile(
        onTap: () =>
            Navigator.pushNamed(context, '/admin/segments/edit', arguments: {'id': id}),
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.blue.shade50 : Colors.grey.shade200,
          child: Icon(
            Icons.people_alt_outlined,
            color: isActive ? Colors.blue : Colors.grey,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            _statusChip(isActive),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (desc.isNotEmpty)
                Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  _infoChip(Icons.category_outlined, '類型：$type'),
                  _infoChip(Icons.people_outline, '人數：$count'),
                  _infoChip(Icons.schedule, dateText),
                  if (creator.isNotEmpty)
                    _infoChip(Icons.person_outline, '建立者：$creator'),
                ],
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _statusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade50 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isActive ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Text(
        isActive ? '啟用中' : '已停用',
        style: TextStyle(
          color: isActive ? Colors.green : Colors.grey.shade700,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
