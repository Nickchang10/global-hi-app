import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _phone = TextEditingController();

  bool _hydrated = false;
  bool _saving = false;

  User? get _user => _auth.currentUser;
  String get _uid => _user?.uid ?? '';

  DocumentReference<Map<String, dynamic>> _userRef() =>
      _db.collection('users').doc(_uid);

  @override
  void dispose() {
    _displayName.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _hydrate(Map<String, dynamic> udoc) {
    if (_hydrated) return;
    _displayName.text = (udoc['displayName'] ?? _user?.displayName ?? '')
        .toString();
    _phone.text = (udoc['phone'] ?? '').toString();
    _hydrated = true;
  }

  Future<void> _save() async {
    final u = _user;
    if (u == null) return;

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final dn = _displayName.text.trim();
      final ph = _phone.text.trim();

      if (dn.isNotEmpty && u.displayName != dn) {
        await u.updateDisplayName(dn);
      }

      await _userRef().set({
        'displayName': dn,
        'phone': ph,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存基本資料')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(body: Center(child: Text('請先登入')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('基本資料')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userRef().snapshots(),
        builder: (context, snap) {
          final udoc = snap.data?.data() ?? <String, dynamic>{};
          _hydrate(udoc);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _displayName,
                          decoration: const InputDecoration(
                            labelText: '顯示名稱',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: '電話',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('儲存'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
