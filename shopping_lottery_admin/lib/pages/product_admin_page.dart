import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/product_service.dart';
import 'new_product_dialog.dart';

class ProductAdminPage extends StatefulWidget {
  const ProductAdminPage({Key? key}) : super(key: key);

  @override
  State<ProductAdminPage> createState() => _ProductAdminPageState();
}

class _ProductAdminPageState extends State<ProductAdminPage> {
  String _search = '';
  String _vendorFilter = '';
  bool? _activeFilter;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openNewDialog({String? productId, Map<String, dynamic>? initial}) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => NewProductDialog(initialProductId: productId, initialData: initial),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('商品資料已更新')));
    }
  }

  Future<void> _confirmDelete(String id) async {
    final svc = context.read<ProductService>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認刪除'),
        content: const Text('確定要刪除此商品（連同圖片）嗎？此動作無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await svc.deleteProductWithImages(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('商品已刪除')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.read<ProductService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('後台商品管理'),
        actions: [
          IconButton(
            onPressed: () => _openNewDialog(),
            icon: const Icon(Icons.add),
            tooltip: '新增商品',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search), hintText: '搜尋商品 (ID / 標題)'),
                onChanged: (v) => setState(() => _search = v.trim()),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: _vendorFilter.isEmpty ? null : _vendorFilter,
              hint: const Text('廠商'),
              items: const [DropdownMenuItem(value: '', child: Text('全部廠商'))],
              onChanged: (v) => setState(() => _vendorFilter = v ?? ''),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _activeFilter == null
                  ? 'all'
                  : (_activeFilter! ? 'active' : 'inactive'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('全部')),
                DropdownMenuItem(value: 'active', child: Text('上架')),
                DropdownMenuItem(value: 'inactive', child: Text('下架')),
              ],
              onChanged: (v) {
                if (v == 'all') setState(() => _activeFilter = null);
                if (v == 'active') setState(() => _activeFilter = true);
                if (v == 'inactive') setState(() => _activeFilter = false);
              },
            ),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: svc.streamProducts(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      '讀取錯誤：${snap.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final list = snap.data ?? [];
                var filtered = list;
                if (_search.isNotEmpty) {
                  final s = _search.toLowerCase();
                  filtered = filtered.where((m) {
                    final id = (m['id'] ?? '').toString().toLowerCase();
                    final title = (m['title'] ?? '').toString().toLowerCase();
                    return id.contains(s) || title.contains(s);
                  }).toList();
                }
                if (_vendorFilter.isNotEmpty) {
                  filtered = filtered
                      .where((m) => (m['vendorId'] ?? '') == _vendorFilter)
                      .toList();
                }
                if (_activeFilter != null) {
                  filtered = filtered
                      .where((m) => (m['isActive'] ?? false) == _activeFilter)
                      .toList();
                }

                if (filtered.isEmpty) {
                  return const Center(child: Text('目前無商品'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    final id = (item['id'] ?? '').toString();
                    final title = (item['title'] ?? '').toString();
                    final price = item['price'];
                    final isActive = (item['isActive'] ?? false) as bool;
                    final images =
                        (item['images'] ?? <Map<String, dynamic>>[]) as List<dynamic>;
                    final firstImg = images.isNotEmpty
                        ? (images[0]['url'] ?? '').toString()
                        : null;

                    return ListTile(
                      leading: firstImg != null && firstImg.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(firstImg,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image)))
                          : Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: Colors.grey[200],
                              ),
                              child: const Icon(Icons.image)),
                      title: Text('$id — $title'),
                      subtitle: Text('NT\$${(price ?? 0).toString()}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Switch(
                            value: isActive,
                            onChanged: (v) async =>
                                await svc.toggleActive(id, v)),
                        IconButton(
                            onPressed: () =>
                                _openNewDialog(productId: id, initial: item),
                            icon: const Icon(Icons.edit)),
                        IconButton(
                            onPressed: () => _confirmDelete(id),
                            icon: const Icon(Icons.delete)),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
