// lib/services/notification_service.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_notification.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final bool enableDebugLog = kDebugMode;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  bool _initialized = false;
  bool get initialized => _initialized;

  final List<AppNotification> _items = [];
  List<AppNotification> get items => List.unmodifiable(_items);

  // =========================
  // ✅ 舊版相容：notifications / unreadCount
  // =========================
  List<AppNotification> get notifications => items;

  int get unreadCount => _items.where((e) => !e.read).length;

  // =========================
  // ✅ init：改成 Future<void>（頁面 await 才不會炸）
  // - force=true：重掛監聽
  // =========================
  Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;

    if (force) {
      await _authSub?.cancel();
      _authSub = null;
      await _sub?.cancel();
      _sub = null;
      _items.clear();
      _initialized = false;
      notifyListeners();
    }

    if (_initialized) return;
    _initialized = true;

    _authSub = _auth.authStateChanges().listen((u) {
      if (enableDebugLog) debugPrint('🔔[NotificationService] auth changed: ${u?.uid ?? "-"}');

      if (u == null) {
        _stopListen();
        _items.clear();
        notifyListeners();
        return;
      }

      _startListen(u.uid);
    });
  }

  void _startListen(String uid) {
    _stopListen();

    // ✅ Firestore watch（若你 web 仍 ca9/b815，我再幫你改輪詢版）
    _sub = _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .listen((qs) {
      final list = <AppNotification>[];
      for (final d in qs.docs) {
        list.add(AppNotification.fromMap(d.data(), fallbackId: d.id));
      }
      _items
        ..clear()
        ..addAll(list);
      notifyListeners();
    }, onError: (e) {
      if (enableDebugLog) debugPrint('❌[NotificationService] listen error: $e');
    });
  }

  void _stopListen() {
    _sub?.cancel();
    _sub = null;
  }

  // =========================
  // ✅ 新/舊共用：新增通知（相容 message/body/content）
  // =========================
  Future<void> addNotification({
    required String type,
    required String title,
    String? message,
    String? body,
    String? content,
    IconData? icon,
    Map<String, dynamic> data = const <String, dynamic>{},
    bool pushToFirestore = true,
  }) async {
    final text = (message ?? body ?? content ?? '').toString();
    final now = DateTime.now();

    final n = AppNotification(
      id: 'local_${now.microsecondsSinceEpoch}',
      type: type,
      title: title,
      message: text,
      read: false,
      createdAt: now,
      iconCodePoint: icon?.codePoint,
      iconFontFamily: icon?.fontFamily,
      iconFontPackage: icon?.fontPackage,
      data: data,
    );

    _items.insert(0, n);
    notifyListeners();

    if (!pushToFirestore) return;

    final u = _auth.currentUser;
    if (u == null) return;

    try {
      await _db.collection('users').doc(u.uid).collection('notifications').add(n.toMap());
    } catch (e) {
      if (enableDebugLog) debugPrint('❌[NotificationService] add firestore failed: $e');
    }
  }

  // =========================
  // ✅ 舊版相容：markAllRead / clearAll / remove
  // =========================
  Future<void> markAllRead() async => markAllAsRead();

  Future<void> clearAll() async {
    _items.clear();
    notifyListeners();

    final u = _auth.currentUser;
    if (u == null) return;

    try {
      final col = _db.collection('users').doc(u.uid).collection('notifications');
      final snap = await col.get();
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } catch (e) {
      if (enableDebugLog) debugPrint('❌[NotificationService] clearAll failed: $e');
    }
  }

  Future<void> remove(String id) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      _items.removeAt(idx);
      notifyListeners();
    }

    final u = _auth.currentUser;
    if (u == null) return;

    // local_ 是本地 id，不用刪 firestore
    if (id.startsWith('local_')) return;

    try {
      await _db.collection('users').doc(u.uid).collection('notifications').doc(id).delete();
    } catch (_) {}
  }

  // =========================
  // ✅ 已讀相關：markAsRead / markAllAsRead
  // =========================
  Future<void> markAsRead(String id) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx >= 0 && !_items[idx].read) {
      _items[idx] = _items[idx].copyWith(read: true);
      notifyListeners();
    }

    final u = _auth.currentUser;
    if (u == null) return;
    if (id.startsWith('local_')) return;

    try {
      await _db
          .collection('users')
          .doc(u.uid)
          .collection('notifications')
          .doc(id)
          .set({'read': true}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].read) _items[i] = _items[i].copyWith(read: true);
    }
    notifyListeners();

    final u = _auth.currentUser;
    if (u == null) return;

    try {
      final col = _db.collection('users').doc(u.uid).collection('notifications');
      final snap = await col.get();
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.set(d.reference, {'read': true}, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (_) {}
  }

  // =========================
  // ✅ UI helper：iconForType / colorForType
  // =========================
  IconData iconForType(String type) {
    switch (type) {
      case 'shop':
        return Icons.shopping_bag_outlined;
      case 'order':
        return Icons.receipt_long_outlined;
      case 'payment':
        return Icons.credit_card_outlined;
      case 'lottery':
        return Icons.emoji_events_outlined;
      case 'sos':
        return Icons.sos_rounded;
      case 'system':
      default:
        return Icons.notifications_outlined;
    }
  }

  Color colorForType(String type) {
    switch (type) {
      case 'shop':
        return Colors.orangeAccent;
      case 'order':
        return Colors.blueAccent;
      case 'payment':
        return Colors.green;
      case 'lottery':
        return Colors.purple;
      case 'sos':
        return Colors.redAccent;
      case 'system':
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _stopListen();
    super.dispose();
  }
}
