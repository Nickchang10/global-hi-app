// lib/pages/firebase_debug_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Debug 工具頁：檢查 Firebase App options、Auth 與簡易 Firestore 存取
class FirebaseDebugPage extends StatefulWidget {
  const FirebaseDebugPage({super.key});

  @override
  State<FirebaseDebugPage> createState() => _FirebaseDebugPageState();
}

class _FirebaseDebugPageState extends State<FirebaseDebugPage> {
  String _log = '';
  User? _user;
  FirebaseOptions? _options;
  Map<String, dynamic>? _userDoc;
  String _orderIdForGet = '';

  @override
  void initState() {
    super.initState();
    _refreshAll();
    // 監聽 Auth state 變化
    FirebaseAuth.instance.authStateChanges().listen((u) {
      setState(() => _user = u);
    });
  }

  void _append(String s) {
    setState(() {
      final ts = DateTime.now().toIso8601String();
      _log = '[$ts] $s\n\n' + _log;
    });
  }

  Future<void> _refreshAll() async {
    _append('Refreshing debug info...');
    try {
      final app = Firebase.app();
      setState(() {
        _options = app.options;
      });
      _append('Firebase app: name=${app.name} projectId=${app.options.projectId} appId=${app.options.appId} apiKey=${app.options.apiKey}');
    } catch (e) {
      _append('Firebase.app() error: $e');
      setState(() {
        _options = null;
      });
    }

    final u = FirebaseAuth.instance.currentUser;
    setState(() => _user = u);
    _append('Current user: $u (uid=${u?.uid})');

    if (u != null) {
      await _fetchUserDoc(u.uid);
    } else {
      setState(() => _userDoc = null);
    }
  }

  Future<void> _fetchUserDoc(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (snap.exists) {
        setState(() => _userDoc = snap.data());
        _append('users/$uid exists, data=${snap.data()}');
      } else {
        setState(() => _userDoc = null);
        _append('users/$uid does NOT exist');
      }
    } catch (e, st) {
      _append('fetchUserDoc error: $e\n$st');
      setState(() => _userDoc = null);
    }
  }

  Future<void> _signInAnonymously() async {
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      setState(() => _user = cred.user);
      _append('Signed in anonymously: uid=${cred.user?.uid}');
      // optional: fetch user doc
      if (cred.user != null) await _fetchUserDoc(cred.user!.uid);
    } catch (e, st) {
      _append('signInAnonymously error: $e\n$st');
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      setState(() {
        _user = null;
        _userDoc = null;
      });
      _append('Signed out');
    } catch (e, st) {
      _append('signOut error: $e\n$st');
    }
  }

  Future<void> _ensureSelfUserDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _append('ensureSelfUserDoc: no current user');
      return;
    }
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final now = FieldValue.serverTimestamp();
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'role': 'user',
          'vendorId': '',
          'email': user.email ?? '',
          'displayName': user.displayName ?? '',
          'createdAt': now,
          'updatedAt': now,
          'lastLoginAt': now,
        }, SetOptions(merge: true));
        _append('Created users/${user.uid} (role=user)');
      } else {
        await ref.set({
          'email': user.email ?? '',
          'displayName': user.displayName ?? '',
          'updatedAt': now,
          'lastLoginAt': now,
        }, SetOptions(merge: true));
        _append('Updated users/${user.uid} metadata');
      }
      await _fetchUserDoc(user.uid);
    } catch (e, st) {
      _append('ensureSelfUserDoc error: $e\n$st');
    }
  }

  Future<void> _testBuyerList() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _append('testBuyerList: no current user');
      return;
    }
    try {
      final q = FirebaseFirestore.instance.collection('orders').where('buyerUid', isEqualTo: uid).limit(10);
      final snap = await q.get();
      _append('buyer list success: docs=${snap.size}');
      if (snap.docs.isNotEmpty) {
        _append('First order id=${snap.docs.first.id} data=${snap.docs.first.data()}');
      }
    } catch (e, st) {
      _append('buyer list error: $e\n$st');
    }
  }

  Future<void> _testUnfilteredList() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('orders').limit(1).get();
      _append('unfiltered list success: docs=${snap.size}');
    } catch (e, st) {
      _append('unfiltered list error: $e\n$st');
    }
  }

  Future<void> _testGetOrderById() async {
    final id = _orderIdForGet.trim();
    if (id.isEmpty) {
      _append('testGetOrderById: please enter orderId');
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance.collection('orders').doc(id).get();
      if (snap.exists) {
        _append('get order $id success, data=${snap.data()}');
      } else {
        _append('get order $id: not exists');
      }
    } catch (e, st) {
      _append('get order $id error: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    final user = _user;
    final userDoc = _userDoc;

    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Debug')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Firebase App Info', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  if (options != null) ...[
                    Text('projectId: ${options.projectId}'),
                    Text('appId: ${options.appId}'),
                    Text('apiKey: ${options.apiKey}'),
                    Text('authDomain: ${options.authDomain}'),
                    Text('storageBucket: ${options.storageBucket}'),
                  ] else
                    const Text('Firebase app not available'),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _refreshAll, child: const Text('Refresh Info')),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Auth / User', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Current user: ${user?.uid ?? "null"}'),
                  Text('Anonymous?: ${user?.isAnonymous ?? false}'),
                  const SizedBox(height: 8),
                  Row(children: [
                    ElevatedButton(onPressed: _signInAnonymously, child: const Text('Sign in Anon')),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _signOut, child: const Text('Sign out')),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _ensureSelfUserDoc, child: const Text('Ensure users/{uid}')),
                  ]),
                  const SizedBox(height: 8),
                  if (userDoc != null) ...[
                    const Text('users/{uid} doc:', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(userDoc.toString()),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Firestore tests', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(children: [
                    ElevatedButton(onPressed: _testBuyerList, child: const Text('Test buyer list (where)')),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _testUnfilteredList, child: const Text('Test unfiltered list')),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'orderId (for get)'),
                        onChanged: (v) => _orderIdForGet = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _testGetOrderById, child: const Text('Get order by id')),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Text(
                      _log,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
