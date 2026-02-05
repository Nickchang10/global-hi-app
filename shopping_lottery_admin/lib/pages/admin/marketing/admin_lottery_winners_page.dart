import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:html' as html;

class AdminLotteryWinnersPage extends StatefulWidget {
  final String? lotteryId; // 可從抽獎頁傳入
  const AdminLotteryWinnersPage({super.key, this.lotteryId});

  @override
  State<AdminLotteryWinnersPage> createState() => _AdminLotteryWinnersPageState();
}

class _AdminLotteryWinnersPageState extends State<AdminLotteryWinnersPage> {
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

  @override
  void initState() {
    super.initState();
    _loadWinners();
  }

  Future<void> _loadWinners() async {
    setState(() => _loading = true);
    try {
      Query<Map<String, dynamic>> q =
          FirebaseFirestore.instance.collection('lottery_winners');

      if (widget.lotteryId != null) {
        q = q.where('lotteryId', isEqualTo: widget.lotteryId);
      }

      final keyword = _searchCtrl.text.trim();
      if (keyword.isNotEmpty) {
        q = q
            .where('userName', isGreaterThanOrEqualTo: keyword)
            .where('userName', isLessThanOrEqualTo: '$keyword\uf8ff');
      }

      q = q.orderBy('createdAt', descending: true);
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

  Future<void> _exportCSV() async {
    if (_docs.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('無中獎資料可匯出')));
      return;
    }

    final csvBuffer = StringBuffer();
    csvBuffer.writeln('活動名稱,使用者名稱,Email,獎項,中獎時間');

    final df = DateFormat('yyyy/MM/dd HH:mm');
    for (final doc in _docs) {
      final d = doc.data();
      final title = d['lotteryTitle'] ?? '';
      final name = d['userName'] ?? '';
      final email = d['userEmail'] ?? '';
      final prize = d['prizeName'] ?? '';
      final createdAt =
          (d['createdAt'] != null) ? df.format((d['createdAt'] as Timestamp).toDate()) : '';
      csvBuffer.writeln('$title,$name,$email,$prize,$createdAt');
    }

    final blob = html.Blob([utf8.encode(csvBuffer.toString())], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'lottery_winners.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy/MM/dd HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('中獎名單管理'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: _loadWinners,
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
          _buildSearchBar(),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _docs.isEmpty
                    ? const Center(child: Text('尚無中獎紀錄'))
                    : ListView.builder(
                        itemCount: _docs.length,
                        itemBuilder: (context, i) {
                          final d = _docs[i].data();
                          final prize = d['prizeName'] ?? '';
                          final name = d['userName'] ?? '';
                          final email = d['userEmail'] ?? '';
                          final title = d['lotteryTitle'] ?? '';
                          final createdAt = (d['createdAt'] as Timestamp?)?.toDate();

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: const Icon(Icons.emoji_events_outlined, color: Colors.amber),
                              title: Text('$name（$email）'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('活動：$title'),
                                  Text('獎項：$prize'),
                                  if (createdAt != null)
                                    Text('中獎時間：${df.format(createdAt)}'),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋使用者名稱',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onSubmitted: (_) => _loadWinners(),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _loadWinners,
            icon: const Icon(Icons.filter_alt_outlined),
            label: const Text('篩選'),
          ),
        ],
      ),
    );
  }
}
