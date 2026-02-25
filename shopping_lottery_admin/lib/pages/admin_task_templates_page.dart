import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminTaskTemplatesPage extends StatefulWidget {
  const AdminTaskTemplatesPage({super.key});

  @override
  State<AdminTaskTemplatesPage> createState() => _AdminTaskTemplatesPageState();
}

class _AdminTaskTemplatesPageState extends State<AdminTaskTemplatesPage> {
  String? selectedCategory;

  @override
  Widget build(BuildContext context) {
    final List<String> categories = ['一般', '緊急', '客服', '出貨'];

    // ✅ 依分類做 Firestore query（有選分類就篩選）
    final Query<Map<String, dynamic>> query = selectedCategory == null
        ? FirebaseFirestore.instance.collection('task_templates')
        : FirebaseFirestore.instance
              .collection('task_templates')
              .where('category', isEqualTo: selectedCategory);

    return Scaffold(
      appBar: AppBar(title: const Text('任務範本管理')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              // ✅ FIX: value deprecated → initialValue
              // initialValue 只負責初始值，因此配合 key 讓它在 setState 後能正確重建
              key: ValueKey(selectedCategory),
              initialValue: selectedCategory,
              decoration: const InputDecoration(
                labelText: '選擇分類',
                hintText: '全部',
                border: OutlineInputBorder(),
              ),
              items: [
                // 提供「全部」選項（null）
                const DropdownMenuItem<String>(value: null, child: Text('全部')),
                ...categories.map(
                  (c) => DropdownMenuItem<String>(value: c, child: Text(c)),
                ),
              ],
              onChanged: (v) => setState(() => selectedCategory = v),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: query.snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        '讀取失敗：${snap.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('沒有任務範本'));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i].data();
                      return ListTile(
                        title: Text((d['title'] ?? '').toString()),
                        subtitle: Text((d['category'] ?? '').toString()),
                      );
                    },
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
