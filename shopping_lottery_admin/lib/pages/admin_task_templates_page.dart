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

    return Scaffold(
      appBar: AppBar(title: const Text('任務範本管理')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(labelText: '選擇分類'),
              items: categories
                  .map<DropdownMenuItem<String>>(
                    (c) => DropdownMenuItem<String>(
                      value: c,
                      child: Text(c),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => selectedCategory = v),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('task_templates').snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? [];
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i].data();
                      return ListTile(
                        title: Text(d['title'] ?? ''),
                        subtitle: Text(d['category'] ?? ''),
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
