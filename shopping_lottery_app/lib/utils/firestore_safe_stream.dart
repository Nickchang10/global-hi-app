// lib/utils/firestore_safe_stream.dart
// ======================================================
// ✅ Firestore Safe Snapshots (Flutter Web)
// ------------------------------------------------------
// 避免 cloud_firestore_web interop: onSnapshotUnsubscribe late init
// 作法：延後到 microtask 才真的去 listen Firestore snapshots
// 如果 StreamBuilder 很快 dispose，會先 cancel 外層 stream，
// 內層 Firestore 根本不會啟動 => 不會觸發 stopListen 的 late init
// ======================================================

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

Stream<QuerySnapshot<T>> safeSnapshots<T>(Query<T> query) {
  StreamSubscription<QuerySnapshot<T>>? innerSub;
  bool outerCanceled = false;

  late final StreamController<QuerySnapshot<T>> controller;
  controller = StreamController<QuerySnapshot<T>>(
    onListen: () {
      scheduleMicrotask(() {
        if (outerCanceled) return;

        innerSub = query.snapshots().listen(
          (event) {
            if (!controller.isClosed) controller.add(event);
          },
          onError: (e, st) {
            if (!controller.isClosed) controller.addError(e, st);
          },
          onDone: () {
            if (!controller.isClosed) controller.close();
          },
          cancelOnError: false,
        );
      });
    },
    onCancel: () async {
      outerCanceled = true;
      try {
        await innerSub?.cancel();
      } catch (_) {
        // swallow
      }
    },
  );

  return controller.stream;
}
