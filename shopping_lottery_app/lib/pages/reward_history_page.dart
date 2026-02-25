// lib/pages/reward_history_page.dart
// =====================================================
// ✅ RewardHistoryPage（積分紀錄頁｜完整版｜可直接編譯）
// - 顯示積分來源、加減、時間
// - 支援篩選（全部/收入/支出）
// - 支援下拉刷新（模板）、清除全部（含確認）、單筆滑動刪除
// - ✅ 修正 Dart 不支援「+20」這種寫法：改為 20 / 30
// - ✅ 修正 deprecated: withOpacity → withValues(alpha: ...)
// =====================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RewardHistoryPage extends StatefulWidget {
  const RewardHistoryPage({super.key});

  @override
  State<RewardHistoryPage> createState() => _RewardHistoryPageState();
}

class _RewardHistoryPageState extends State<RewardHistoryPage> {
  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _brand = Colors.orangeAccent;

  final _timeFmt = DateFormat('MM/dd HH:mm');

  String _filter = "全部";

  final List<Map<String, dynamic>> _logs = [
    {
      'id': 'log_1',
      'title': '每日簽到',
      'points': 20, // ✅ 不可寫 +20
      'time': DateTime.now().subtract(const Duration(hours: 2)),
    },
    {
      'id': 'log_2',
      'title': '步數達標',
      'points': 30, // ✅ 不可寫 +30
      'time': DateTime.now().subtract(const Duration(hours: 5)),
    },
    {
      'id': 'log_3',
      'title': '兌換：NT\$100 優惠券',
      'points': -200,
      'time': DateTime.now().subtract(const Duration(days: 1)),
    },
    {
      'id': 'log_4',
      'title': '抽獎活動參加',
      'points': -100,
      'time': DateTime.now().subtract(const Duration(days: 2)),
    },
  ];

  List<Map<String, dynamic>> get _filtered {
    if (_filter == "全部") return List<Map<String, dynamic>>.from(_logs);
    return _logs.where((e) {
      final points = _asInt(e['points']);
      final positive = points > 0;
      return _filter == "收入" ? positive : !positive;
    }).toList();
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  DateTime _asDateTime(dynamic v) {
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  Future<void> _onRefresh() async {
    // 模板：你之後可改成從 Service 拉資料
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已更新積分紀錄（模板）'),
        duration: Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _clearAll() async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text(
              '清除紀錄',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            content: const Text('確定要清除所有積分紀錄嗎？此操作無法復原。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text(
                  '清除',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    setState(() => _logs.clear());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("已清除所有紀錄"),
        duration: Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeOne(String id) {
    setState(() => _logs.removeWhere((e) => (e['id'] ?? '').toString() == id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已刪除一筆紀錄'),
        duration: Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          "積分紀錄",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        elevation: 0.8,
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: "全部", child: Text("全部")),
              PopupMenuItem(value: "收入", child: Text("收入")),
              PopupMenuItem(value: "支出", child: Text("支出")),
            ],
            icon: const Icon(Icons.filter_list_alt),
            tooltip: '篩選',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: "清除紀錄",
            onPressed: _logs.isEmpty ? null : _clearAll,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: filtered.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 90),
                        Center(
                          child: Text(
                            "目前沒有積分紀錄 💤",
                            style: TextStyle(color: Colors.grey, fontSize: 15),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final e = filtered[i];
                        final id = (e['id'] ?? 'log_$i').toString();
                        final title = (e['title'] ?? '').toString();
                        final points = _asInt(e['points']);
                        final time = _asDateTime(e['time']);

                        final isIncome = points > 0;
                        final color = isIncome
                            ? Colors.green
                            : Colors.redAccent;

                        return Dismissible(
                          key: ValueKey('reward_$id'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.centerRight,
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.25),
                              ),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                            ),
                          ),
                          confirmDismiss: (dir) async {
                            return await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text(
                                      '刪除紀錄',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    content: const Text('確定要刪除這筆紀錄嗎？'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('取消'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                        ),
                                        child: const Text(
                                          '刪除',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                          },
                          onDismissed: (_) => _removeOne(id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.18),
                                child: Icon(
                                  isIncome
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  color: color,
                                ),
                              ),
                              title: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(_timeFmt.format(time)),
                              trailing: Text(
                                '${points >= 0 ? '+' : ''}$points',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    final income = _logs.fold<int>(0, (sum, e) {
      final p = _asInt(e['points']);
      return sum + (p > 0 ? p : 0);
    });
    final expense = _logs.fold<int>(0, (sum, e) {
      final p = _asInt(e['points']);
      return sum + (p < 0 ? p.abs() : 0);
    });

    Widget chip(String label, bool selected) {
      return ChoiceChip(
        showCheckmark: false,
        selected: selected,
        selectedColor: _brand,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? _brand : Colors.grey.shade200),
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w900,
        ),
        label: Text(label),
        onSelected: (_) => setState(() => _filter = label),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _pill(
                  icon: Icons.trending_up_rounded,
                  label: '收入',
                  value: '+$income',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _pill(
                  icon: Icons.trending_down_rounded,
                  label: '支出',
                  value: '-$expense',
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  chip("全部", _filter == "全部"),
                  const SizedBox(width: 8),
                  chip("收入", _filter == "收入"),
                  const SizedBox(width: 8),
                  chip("支出", _filter == "支出"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontWeight: FontWeight.w900, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
