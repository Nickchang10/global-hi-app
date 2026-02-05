// lib/pages/admin/marketing/admin_lottery_page.dart
//
// ✅ AdminLotteryPage（抽獎列表頁｜完整版｜可編譯）
// ------------------------------------------------------------
// - Firestore 集合：lotteries
// - 功能：搜尋、列表、啟用切換、刪除、進入編輯、建立新抽獎
// - 快捷操作：手動抽獎（可選）、匯出得獎者（可選）
// - 路由依你的 main.dart：
//   - 新增：Navigator.pushNamed(context, '/admin/lottery/edit');
//   - 編輯：Navigator.pushNamed(context, '/admin/lottery/edit', arguments: id);
//
// ⚠️ 注意：
// 1) 本頁不強制依賴 file_saver，避免 Web 編譯踩雷。
// 2) 若你已在 AdminLotteryEditPage 裡做匯出/抽獎，就用「進入編輯」去做即可。
// 3) 若你的 lotteries 欄位不同，可在 _readInt / _readListLen 做兼容。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminLotteryPage extends StatefulWidget {
  const AdminLotteryPage({super.key});

  @override
  State<AdminLotteryPage> createState() => _AdminLotteryPageState();
}

class _AdminLotteryPageState extends State<AdminLotteryPage> {
  final _searchCtrl = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // =====================================================
  // Firestore ops
  // =====================================================

  Future<void> _toggleActive(String id, bool value) async {
    try {
      await FirebaseFirestore.instance.collection('lotteries').doc(id).update({
        'isActive': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? '已啟用抽獎活動' : '已停用抽獎活動')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失敗：$e')),
      );
    }
  }

  Future<void> _deleteLottery(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除確認'),
        content: const Text('確定要刪除此抽獎活動嗎？此動作無法復原。'),
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
      await FirebaseFirestore.instance.collection('lotteries').doc(id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已刪除成功')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刪除失敗：$e')),
      );
    }
  }

  // （可選）手動抽獎：若你要在列表就直接抽，啟用此功能
  // - 會更新 winners 欄位（List<String>）
  // - 預設抽 3 人，可自行調整
  Future<void> _quickDraw(String id, List<String> participants) async {
    if (participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無參與者可抽獎')),
      );
      return;
    }

    final countCtrl = TextEditingController(text: '3');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('手動抽獎'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('參與者共 ${participants.length} 人'),
            const SizedBox(height: 10),
            TextField(
              controller: countCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '抽出人數',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('開始抽獎')),
        ],
      ),
    );
    if (ok != true) return;

    final want = int.tryParse(countCtrl.text.trim()) ?? 3;
    final count = want.clamp(1, participants.length);

    setState(() => _busy = true);
    try {
      // 簡單洗牌
      final list = List<String>.from(participants);
      list.shuffle();
      final winners = list.take(count).toList();

      await FirebaseFirestore.instance.collection('lotteries').doc(id).update({
        'winners': winners,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已抽出 $count 名得獎者')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('抽獎失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // =====================================================
  // Helpers
  // =====================================================

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  int _readInt(Map<String, dynamic> data, String key, {int fallback = 0}) {
    final v = data[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  int _readListLen(Map<String, dynamic> data, String key) {
    final v = data[key];
    if (v is List) return v.length;
    return 0;
  }

  List<String> _readStringList(Map<String, dynamic> data, String key) {
    final v = data[key];
    if (v is List) {
      return v.map((e) => e.toString()).toList();
    }
    return <String>[];
  }

  bool _matchKeyword(Map<String, dynamic> data, String keyword) {
    if (keyword.isEmpty) return true;
    final title = (data['title'] ?? '').toString();
    final desc = (data['description'] ?? '').toString();
    return title.contains(keyword) || desc.contains(keyword);
  }

  // =====================================================
  // UI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy/MM/dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('抽獎管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: '新增抽獎',
            onPressed: () => Navigator.pushNamed(context, '/admin/lottery/edit'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('lotteries')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const Center(child: Text('讀取失敗'));
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final keyword = _searchCtrl.text.trim();
                    final docs = snap.data!.docs.where((d) {
                      return _matchKeyword(d.data(), keyword);
                    }).toList();

                    if (docs.isEmpty) {
                      return const Center(child: Text('尚無抽獎活動'));
                    }

                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final doc = docs[i];
                        final id = doc.id;
                        final data = doc.data();

                        final title = (data['title'] ?? '未命名').toString();
                        final isActive = data['isActive'] == true;
                        final autoDraw = data['autoDraw'] == true;

                        final startAt = _toDate(data['startAt']);
                        final endAt = _toDate(data['endAt']);

                        final participantsCount = _readListLen(data, 'participants');
                        final winnersCount = _readListLen(data, 'winners');

                        // ✅ 兼容：若你有用 participantsCount / winnersCount 數值欄位，也能顯示
                        final participantsCount2 =
                            _readInt(data, 'participantsCount', fallback: participantsCount);
                        final winnersCount2 =
                            _readInt(data, 'winnersCount', fallback: winnersCount);

                        final dateText = () {
                          final s = startAt == null ? '未設定' : df.format(startAt);
                          final e = endAt == null ? '未設定' : df.format(endAt);
                          return '$s ~ $e';
                        }();

                        return ListTile(
                          leading: Switch(
                            value: isActive,
                            onChanged: (v) => _toggleActive(id, v),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (autoDraw)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: Colors.purple.shade200),
                                  ),
                                  child: const Text(
                                    '自動抽獎',
                                    style: TextStyle(fontSize: 12, color: Colors.purple),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                Text('期間：$dateText'),
                                Text('參與：$participantsCount2'),
                                Text('得獎：$winnersCount2'),
                              ],
                            ),
                          ),
                          trailing: Wrap(
                            spacing: 0,
                            children: [
                              IconButton(
                                tooltip: '編輯',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  '/admin/lottery/edit',
                                  arguments: id,
                                ),
                              ),
                              IconButton(
                                tooltip: '刪除',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteLottery(id),
                              ),
                              PopupMenuButton<String>(
                                tooltip: '更多',
                                onSelected: (v) {
                                  if (v == 'edit') {
                                    Navigator.pushNamed(
                                      context,
                                      '/admin/lottery/edit',
                                      arguments: id,
                                    );
                                  }
                                  if (v == 'draw') {
                                    final participants = _readStringList(data, 'participants');
                                    _quickDraw(id, participants);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('進入編輯頁')),
                                  PopupMenuItem(value: 'draw', child: Text('手動抽獎（列表快捷）')),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/admin/lottery/edit',
                            arguments: id,
                          ),
                        );
                      },
                    );
                  },
                ),

                if (_busy)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: true,
                      child: Container(
                        color: Colors.black.withOpacity(0.05),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: TextField(
        controller: _searchCtrl,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: '搜尋抽獎名稱 / 說明',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
