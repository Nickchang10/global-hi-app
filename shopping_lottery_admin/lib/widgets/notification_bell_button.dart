// lib/widgets/notification_bell_button.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<int> _unreadCountStream() {
    if (_uid.isEmpty) return const Stream<int>.empty();

    final q = FirebaseFirestore.instance
        .collection('notifications')
        .doc(_uid)
        .collection('items')
        .where('read', isEqualTo: false)
        .limit(99);

    return q.snapshots().map((s) => s.size);
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return IconButton(
        tooltip: '通知',
        onPressed: null,
        icon: const Icon(Icons.notifications_none_outlined),
      );
    }

    return StreamBuilder<int>(
      stream: _unreadCountStream(),
      builder: (context, snap) {
        final n = snap.data ?? 0;

        return IconButton(
          tooltip: n > 0 ? '通知（未讀 $n）' : '通知',
          onPressed: () => Navigator.pushNamed(context, '/notifications'),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_outlined),
              if (n > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.4),
                    ),
                    child: Text(
                      n > 99 ? '99+' : '$n',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
