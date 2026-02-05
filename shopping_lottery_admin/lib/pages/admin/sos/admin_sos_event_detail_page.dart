class AdminSOSEventDetailPage extends StatefulWidget {
  final String docId;
  const AdminSOSEventDetailPage({super.key, required this.docId});

  @override
  State<AdminSOSEventDetailPage> createState() =>
      _AdminSOSEventDetailPageState();
}

class _AdminSOSEventDetailPageState extends State<AdminSOSEventDetailPage> {
  final _noteCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final ref =
        FirebaseFirestore.instance.collection('sos_events').doc(widget.docId);

    return Scaffold(
      appBar: AppBar(title: const Text('SOS 事件詳情')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: ref.get(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data()!;
          final handled = data['handled'] == true;

          _noteCtrl.text = data['handledNote'] ?? '';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _row('孩童', data['childName']),
              _row('裝置', data['deviceId']),
              _row('時間',
                  DateFormat('yyyy/MM/dd HH:mm').format(data['triggeredAt'].toDate())),
              const Divider(),
              TextField(
                controller: _noteCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '處理備註',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: Icon(handled ? Icons.check : Icons.done_all),
                label: Text(handled ? '已處理' : '標記為已處理'),
                onPressed: handled
                    ? null
                    : () async {
                        await ref.set({
                          'handled': true,
                          'handledNote': _noteCtrl.text.trim(),
                          'handledAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));

                        if (mounted) Navigator.pop(context);
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String k, dynamic v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$k：${v ?? '-'}',
          style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
