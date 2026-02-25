import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class FirebaseDiagnosticsPage extends StatefulWidget {
  const FirebaseDiagnosticsPage({super.key});

  @override
  State<FirebaseDiagnosticsPage> createState() =>
      _FirebaseDiagnosticsPageState();
}

class _FirebaseDiagnosticsPageState extends State<FirebaseDiagnosticsPage> {
  String _log = '';
  bool _busy = false;

  void _append(String s) {
    setState(() => _log = '$_log$s\n');
    debugPrint(s);
  }

  Future<void> _ensureAnon() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return;
    await auth.signInAnonymously();
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    _log = '';

    try {
      final app = Firebase.app();
      _append('projectId: ${app.options.projectId}');
      _append('appId: ${app.options.appId}');
      _append('platform: ${kIsWeb ? "web" : "mobile"}');

      await _ensureAnon();
      final u = FirebaseAuth.instance.currentUser;
      _append('auth uid: ${u?.uid} | isAnon=${u?.isAnonymous}');

      // 1) debug_ping 測試
      try {
        await FirebaseFirestore.instance.collection('debug_ping').add({
          'ts': FieldValue.serverTimestamp(),
          'uid': u?.uid,
          'platform': kIsWeb ? 'web' : 'mobile',
        });
        _append('✅ debug_ping write OK');
      } on FirebaseException catch (e) {
        _append('❌ debug_ping denied: ${e.code} | ${e.message}');
        rethrow;
      }

      // 2) orders 測試（最小 payload）
      try {
        await FirebaseFirestore.instance.collection('orders').add({
          'uid': u!.uid,
          'buyerUid': u.uid,
          'userId': u.uid,
          'items': [
            {'productId': 'test', 'name': 'test', 'qty': 1, 'price': 1},
          ],
          'paymentMethod': 'test',
          'total': 1,
          'totalAmount': 1,
          'shipping': {'method': 'test', 'fee': 0, 'address': '1'},
          'status': 'placed',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _append('✅ orders write OK (rules 已生效)');
      } on FirebaseException catch (e) {
        _append('❌ orders denied: ${e.code} | ${e.message}');
        rethrow;
      }
    } catch (e) {
      _append('ERROR: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Diagnostics')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _run,
                child: Text(_busy ? 'Running...' : 'Run Diagnostics'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(_log.isEmpty ? 'Press Run Diagnostics' : _log),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
