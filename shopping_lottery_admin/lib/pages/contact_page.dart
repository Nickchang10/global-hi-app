// lib/pages/contact_page.dart
//
// ✅ ContactPage（最終正式完整版｜聯絡我們｜顯示聯絡資訊 + 表單送出｜Web+App）
// ------------------------------------------------------------
// Route: /contact
//
// Firestore：
// 1) site_contents/contact  (用來顯示聯絡資訊，可選)
//    - title: String
//    - content: String
//    - email: String
//    - phone: String
//    - address: String
//    - line: String
//    - website: String
//
// 2) contact_messages/{autoId} (表單送出)
//    - name: String
//    - email: String
//    - phone: String
//    - subject: String
//    - message: String
//    - source: String ('contact_page')
//    - createdAt: Timestamp
//    - status: String ('new')
//
// 依賴：cloud_firestore, flutter/material, flutter/services, flutter/foundation
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});
  static const String routeName = '/contact';

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _db = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  bool _sending = false;
  String _sendingLabel = '';

  DocumentReference<Map<String, dynamic>> get _infoDoc =>
      _db.collection('site_contents').doc('contact');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Utils
  // -------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _copy(String text, {String done = '已複製'}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    _snack(done);
  }

  Future<void> _setSending(bool v, {String label = ''}) async {
    if (!mounted) return;
    setState(() {
      _sending = v;
      _sendingLabel = label;
    });
  }

  bool _isValidEmail(String v) {
    final s = v.trim();
    if (s.isEmpty) return true;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
  }

  // -------------------------
  // Actions
  // -------------------------
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final name = _s(_nameCtrl.text);
    final email = _s(_emailCtrl.text);
    final phone = _s(_phoneCtrl.text);
    final subject = _s(_subjectCtrl.text);
    final message = _s(_messageCtrl.text);

    await _setSending(true, label: '送出中...');
    try {
      await _db.collection('contact_messages').add({
        'name': name,
        'email': email,
        'phone': phone,
        'subject': subject,
        'message': message,
        'source': 'contact_page',
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _snack('已送出，我們會盡快回覆您');
      _nameCtrl.clear();
      _emailCtrl.clear();
      _phoneCtrl.clear();
      _subjectCtrl.clear();
      _messageCtrl.clear();
    } catch (e) {
      _snack('送出失敗：$e');
    } finally {
      await _setSending(false);
    }
  }

  // -------------------------
  // UI helper widgets
  // -------------------------
  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;
    final v = value.trim();
    if (v.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withOpacity(0.18)),
        color: cs.surfaceContainerHighest.withOpacity(0.18),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(v),
        trailing: IconButton(
          tooltip: '複製',
          onPressed: () => _copy(v, done: '已複製 $label'),
          icon: const Icon(Icons.copy),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          t,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      );

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('聯絡我們'),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'Debug：複製 Firestore doc 路徑',
              onPressed: () => _copy('site_contents/contact'),
              icon: const Icon(Icons.bug_report_outlined),
            ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _infoDoc.snapshots(),
            builder: (context, snap) {
              final data = snap.data?.data() ?? {};
              final title = _s(data['title']).isEmpty ? '聯絡我們' : _s(data['title']);
              final content = _s(data['content']).isEmpty
                  ? '若你有任何問題或合作需求，請填寫下方表單，我們會盡快回覆。'
                  : _s(data['content']);

              final email = _s(data['email']);
              final phone = _s(data['phone']);
              final address = _s(data['address']);
              final line = _s(data['line']);
              final website = _s(data['website']);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  Text(content, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),

                  _sectionTitle('聯絡資訊'),
                  _infoTile(icon: Icons.email_outlined, label: 'Email', value: email),
                  _infoTile(icon: Icons.phone_outlined, label: '電話', value: phone),
                  _infoTile(icon: Icons.location_on_outlined, label: '地址', value: address),
                  _infoTile(icon: Icons.chat_outlined, label: 'LINE', value: line),
                  _infoTile(icon: Icons.public_outlined, label: '網站', value: website),

                  const SizedBox(height: 8),
                  Divider(color: cs.outline.withOpacity(0.25)),
                  const SizedBox(height: 12),

                  _sectionTitle('聯絡表單'),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          enabled: !_sending,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: '姓名（必填）',
                            isDense: true,
                          ),
                          validator: (v) => _s(v).isEmpty ? '請輸入姓名' : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _emailCtrl,
                          enabled: !_sending,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Email（選填）',
                            isDense: true,
                          ),
                          validator: (v) =>
                              _isValidEmail(_s(v)) ? null : 'Email 格式不正確',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _phoneCtrl,
                          enabled: !_sending,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: '電話（選填）',
                            isDense: true,
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _subjectCtrl,
                          enabled: !_sending,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: '主旨（選填）',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _messageCtrl,
                          enabled: !_sending,
                          minLines: 3,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: '內容（必填）',
                            isDense: true,
                          ),
                          validator: (v) => _s(v).isEmpty ? '請輸入內容' : null,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _sending ? null : _submit,
                            icon: const Icon(Icons.send),
                            label: Text(_sending ? '送出中...' : '送出'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (kDebugMode)
                          Text(
                            'Debug：送出集合 contact_messages（rules 已允許 create）',
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          if (_sending)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BusyBar(label: _sendingLabel.isEmpty ? '處理中...' : _sendingLabel),
            ),
        ],
      ),
    );
  }
}

// -------------------------
// Busy bar widget
// -------------------------
class _BusyBar extends StatelessWidget {
  final String label;
  const _BusyBar({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
