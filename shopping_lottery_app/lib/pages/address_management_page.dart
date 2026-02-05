import 'package:flutter/material.dart';
import 'edit_address_page.dart';

class AddressManagementPage extends StatefulWidget {
  const AddressManagementPage({super.key});

  @override
  State<AddressManagementPage> createState() => _AddressManagementPageState();
}

class _AddressManagementPageState extends State<AddressManagementPage> {
  List<Map<String, String>> addresses = [
    {'title': '家', 'detail': '台北市中正區某路 123 號'},
    {'title': '公司', 'detail': '台北市信義區某街 45 巷 6 號'},
  ];

  void _openEditor({Map<String, String>? address, int? index}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditAddressPage(address: address),
      ),
    );

    if (result != null) {
      setState(() {
        if (index == null) {
          addresses.add(result);  // 新增地址
        } else {
          addresses[index] = result; // 修改地址
        }
      });
    }
  }

  void _delete(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("刪除地址"),
        content: const Text("確定要刪除此地址嗎？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              setState(() => addresses.removeAt(index));
              Navigator.pop(context);
            },
            child: const Text("刪除"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("地址管理")),
      body: ListView.separated(
        itemCount: addresses.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final item = addresses[index];
          return ListTile(
            leading: const Icon(Icons.location_on),
            title: Text(item["title"]!),
            subtitle: Text(item["detail"]!),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => _openEditor(address: item, index: index),
                  child: const Text("編輯"),
                ),
                TextButton(
                  onPressed: () => _delete(index),
                  child: const Text("刪除", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
