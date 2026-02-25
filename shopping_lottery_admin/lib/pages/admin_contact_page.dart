// lib/pages/admin_contact_page.dart
//
// ✅ AdminContactPage（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// - 修正：unused_local_variable（created 會被顯示於 UI，不再警告）
// - 兩個分頁：
//   1) 訊息收件匣（使用 AdminContactMessagesPage）
//   2) 聯絡資訊設定（Firestore: site_contents/contact）
// ------------------------------------------------------------
//
// Firestore 建議：
// site_contents/contact
//   - email, phone, line, address, businessHours
//   - createdAt, updatedAt (Timestamp)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_contact_messages_page.dart';

class AdminContactPage extends StatefulWidget {
  const AdminContactPage({super.key});

  @override
  State<AdminContactPage> createState() => _AdminContactPageState();
}

class _AdminContactPageState extends State<AdminContactPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  DocumentReference<Map<String, dynamic>> get _contactRef =>
      FirebaseFirestore.instance.collection('site_contents').doc('contact');

  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _lineCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();

  bool _busy = false;
  bool _didHydrate = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _lineCtrl.dispose();
    _addressCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  String _fmtTs(dynamic v) {
    DateTime? dt;
    if (v is Timestamp) dt = v.toDate();
    if (v is DateTime) dt = v;
    if (dt == null) return '-';
    final l = dt.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-'
        '${l.month.toString().padLeft(2, '0')}-'
        '${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  void _hydrate(Map<String, dynamic> m) {
    _emailCtrl.text = (m['email'] ?? '').toString();
    _phoneCtrl.text = (m['phone'] ?? '').toString();
    _lineCtrl.text = (m['line'] ?? '').toString();
    _addressCtrl.text = (m['address'] ?? '').toString();
    _hoursCtrl.text = (m['businessHours'] ?? '').toString();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await _contactRef.set({
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'line': _lineCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'businessHours': _hoursCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        // 若第一次建立時沒有 createdAt，補上
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存聯絡資訊設定')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('聯絡我們管理'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.inbox), text: '訊息'),
            Tab(icon: Icon(Icons.settings), text: '聯絡設定'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // 1) Messages
          const AdminContactMessagesPage(),

          // 2) Contact settings
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _contactRef.snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Text(
                    '讀取設定失敗：${snap.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snap.data!.data() ?? <String, dynamic>{};
              if (!_didHydrate) {
                _didHydrate = true;
                _hydrate(data);
              }

              // ✅ 這裡就是你原本的 created：現在會被顯示，所以不會 unused
              final created = _fmtTs(data['createdAt']);
              final updated = _fmtTs(data['updatedAt']);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    elevation: 0.8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '文件資訊',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              const Chip(
                                avatar: Icon(Icons.folder, size: 16),
                                label: Text('site_contents/contact'),
                              ),
                              Chip(
                                avatar: const Icon(Icons.schedule, size: 16),
                                label: Text('建立：$created'),
                              ),
                              Chip(
                                avatar: Icon(
                                  Icons.update,
                                  size: 16,
                                  color: cs.primary,
                                ),
                                label: Text('更新：$updated'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0.6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '聯絡資訊設定',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          _tf(_emailCtrl, 'Email'),
                          const SizedBox(height: 10),
                          _tf(_phoneCtrl, '電話'),
                          const SizedBox(height: 10),
                          _tf(_lineCtrl, 'LINE（ID 或連結）'),
                          const SizedBox(height: 10),
                          _tf(_addressCtrl, '地址', maxLines: 2),
                          const SizedBox(height: 10),
                          _tf(_hoursCtrl, '營業時間', maxLines: 2),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () {
                                          _hydrate(data);
                                          setState(() {});
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('已重新載入（覆蓋未儲存變更）'),
                                            ),
                                          );
                                        },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('重新載入'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _busy ? null : _save,
                                  icon: _busy
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.save),
                                  label: const Text('儲存'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tf(TextEditingController c, String label, {int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
