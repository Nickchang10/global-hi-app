import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/campaign_model.dart';
import '../../../services/campaign_service.dart';
import 'admin_campaign_edit_page.dart';

class AdminCampaignsPage extends StatefulWidget {
  const AdminCampaignsPage({super.key});

  @override
  State<AdminCampaignsPage> createState() => _AdminCampaignsPageState();
}

class _AdminCampaignsPageState extends State<AdminCampaignsPage> {
  final _service = CampaignService();
  final _searchCtrl = TextEditingController();
  List<Campaign> _campaigns = [];
  List<Campaign> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _campaigns = await _service.fetchCampaigns();
      _filtered = _campaigns;
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  void _filter(String query) {
    setState(() {
      _filtered = _campaigns.where((c) =>
          c.title.toLowerCase().contains(query.toLowerCase()) ||
          c.vendorName.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('活動管理'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final ok = await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminCampaignEditPage()));
              if (ok == true) _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('載入失敗：$_error'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _filter,
                        decoration: InputDecoration(
                          hintText: '搜尋活動名稱或廠商...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? const Center(child: Text('尚無活動資料'))
                          : ListView.builder(
                              itemCount: _filtered.length,
                              itemBuilder: (c, i) {
                                final item = _filtered[i];
                                final df = DateFormat('yyyy/MM/dd');
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: ListTile(
                                    title: Text(item.title),
                                    subtitle: Text(
                                        '期間：${df.format(item.startAt)} - ${df.format(item.endAt)}\n'
                                        '規則：${item.ruleType}（${item.discountValue}%）'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () async {
                                            final ok = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => AdminCampaignEditPage(campaign: item),
                                              ),
                                            );
                                            if (ok == true) _load();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline),
                                          onPressed: () => _confirmDelete(item.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                    ),
                  ],
                ),
    );
  }

  void _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除確認'),
        content: const Text('確定要刪除此活動嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteCampaign(id);
      _load();
    }
  }
}
