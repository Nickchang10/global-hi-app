import 'package:flutter/material.dart';
import '../services/firestore_mock_service.dart';

class AdminProductPage extends StatefulWidget {
  const AdminProductPage({super.key});

  @override
  State<AdminProductPage> createState() => _AdminProductPageState();
}

class _AdminProductPageState extends State<AdminProductPage> {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  void _addProduct() {
    if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
    FirestoreMockService.instance.addProduct({
      "name": nameCtrl.text,
      "price": double.tryParse(priceCtrl.text) ?? 0,
      "image": "assets/images/watch_default.png",
    });
    setState(() {});
    nameCtrl.clear();
    priceCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final products = FirestoreMockService.instance.products;

    return Scaffold(
      appBar: AppBar(
        title: const Text("商品管理"),
        backgroundColor: const Color(0xFF28A745),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "商品名稱")),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "價格")),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _addProduct,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28A745),
                  foregroundColor: Colors.white),
              child: const Text("新增商品"),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: products.length,
                itemBuilder: (_, i) {
                  final p = products[i];
                  return Card(
                    child: ListTile(
                      title: Text(p["name"]),
                      subtitle: Text("NT\$${p["price"]}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          FirestoreMockService.instance.removeProduct(p["name"]);
                          setState(() {});
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
