// lib/utils/firestore_no_watch_stream.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ✅ 不使用 snapshots()，改成週期性 get() 產生 stream（Web 最穩）
/// - interval 建議 2~5 秒（看你需求）
/// - 需要即時性再調小
Stream<QuerySnapshot<T>> pollQuery<T>(
  Query<T> query, {
  Duration interval = const Duration(seconds: 3),
  bool emitImmediately = true,
}) async* {
  if (emitImmediately) {
    yield await query.get();
  }
  yield* Stream.periodic(interval).asyncMap((_) => query.get());
}

/// ✅ Document 版本（同樣不使用 snapshots）
Stream<DocumentSnapshot<T>> pollDoc<T>(
  DocumentReference<T> ref, {
  Duration interval = const Duration(seconds: 3),
  bool emitImmediately = true,
}) async* {
  if (emitImmediately) {
    yield await ref.get();
  }
  yield* Stream.periodic(interval).asyncMap((_) => ref.get());
}
