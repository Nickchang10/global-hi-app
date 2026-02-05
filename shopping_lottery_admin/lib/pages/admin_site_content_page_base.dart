// lib/pages/admin_site_content_page_base.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSiteContentPageBase extends StatefulWidget {
  final String category;
  final String title;
  const AdminSiteContentPageBase({super.key, required this.category, required this.title});

  @override
  State<AdminSiteContentPageBase> createState() => _AdminSiteContentPageBaseState();
}

class _AdminSiteContentPageBaseState extends State<AdminSiteContentPageBase> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final q = await _db
        .collection('site_contents')
        .where('category', isEqualTo: widget.category)
        .orderBy('updatedAt', descending: true)
        .get();
    setState(() {
      _docs = q.docs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_outlined)),
        IconButton(
          icon: const Icon(Icons.add_outlined),
          tooltip: '新增內容',
          onPressed: () async {
            final ref = _db.collection('site_contents').doc();
            await ref.set({
              'category': widget.category,
              'title': '${widget.title} 新項目',
              'body': '',
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            if (context.mounted) _load();
          },
        )
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _docs.length,
              itemBuilder: (context, i) {
                final d = _docs[i].data();
                return ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text((d['title'] ?? '').toString()),
                  subtitle: Text((d['updatedAt'] ?? '').toString()),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () async {
                      await _docs[i].reference.delete();
                      _load();
                    },
                  ),
                  onTap: () async {
                    await Navigator.pushNamed(
                      context,
                      '/site/edit',
                      arguments: {'docId': _docs[i].id, 'category': widget.category},
                    );
                    if (context.mounted) _load();
                  },
                );
              },
            ),
    );
  }
}
