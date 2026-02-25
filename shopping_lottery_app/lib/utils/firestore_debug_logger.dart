import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// 一次結帳會有多筆寫入；任何一筆 permission-denied 都會讓整包失敗。
/// 用這個工具把每一次 set/update/delete/batch 的 path 全印出來。
class FsDebug {
  FsDebug._();

  static void log(String msg) {
    debugPrint('[FS] $msg');
  }

  static Future<void> loggedSet(
    DocumentReference ref,
    Map<String, dynamic> data, {
    String? label,
    SetOptions? options,
  }) async {
    final tag = label ?? 'SET';
    log('$tag -> ${ref.path}');
    try {
      if (options != null) {
        await ref.set(data, options);
      } else {
        await ref.set(data);
      }
      log('OK  $tag -> ${ref.path}');
    } on FirebaseException catch (e) {
      log('FAIL $tag -> ${ref.path} | ${e.code} | ${e.message}');
      rethrow;
    }
  }

  static Future<void> loggedUpdate(
    DocumentReference ref,
    Map<String, dynamic> data, {
    String? label,
  }) async {
    final tag = label ?? 'UPDATE';
    log('$tag -> ${ref.path}');
    try {
      await ref.update(data);
      log('OK  $tag -> ${ref.path}');
    } on FirebaseException catch (e) {
      log('FAIL $tag -> ${ref.path} | ${e.code} | ${e.message}');
      rethrow;
    }
  }

  static Future<void> loggedDelete(
    DocumentReference ref, {
    String? label,
  }) async {
    final tag = label ?? 'DELETE';
    log('$tag -> ${ref.path}');
    try {
      await ref.delete();
      log('OK  $tag -> ${ref.path}');
    } on FirebaseException catch (e) {
      log('FAIL $tag -> ${ref.path} | ${e.code} | ${e.message}');
      rethrow;
    }
  }

  /// 可控的 batch：每個 op 都會記錄 path，commit 時也會打印
  static LoggedBatch batch(FirebaseFirestore db, {String? tag}) {
    return LoggedBatch._(tag: tag);
  }
}

class LoggedBatch {
  LoggedBatch._({String? tag})
    : _tag = tag ?? 'BATCH',
      _batch = FirebaseFirestore.instance.batch();

  final WriteBatch _batch;
  final String _tag;
  final List<String> _ops = [];

  void setDoc(
    DocumentReference ref,
    Map<String, dynamic> data, {
    SetOptions? options,
    String? label,
  }) {
    final t = label ?? 'SET';
    _ops.add('$t -> ${ref.path}');
    if (options != null) {
      _batch.set(ref, data, options);
    } else {
      _batch.set(ref, data);
    }
  }

  void updateDoc(
    DocumentReference ref,
    Map<String, dynamic> data, {
    String? label,
  }) {
    final t = label ?? 'UPDATE';
    _ops.add('$t -> ${ref.path}');
    _batch.update(ref, data);
  }

  void deleteDoc(DocumentReference ref, {String? label}) {
    final t = label ?? 'DELETE';
    _ops.add('$t -> ${ref.path}');
    _batch.delete(ref);
  }

  Future<void> commit() async {
    FsDebug.log('$_tag COMMIT ops=${_ops.length}');
    for (final op in _ops) {
      FsDebug.log('$_tag OP: $op');
    }
    try {
      await _batch.commit();
      FsDebug.log('$_tag COMMIT OK');
    } on FirebaseException catch (e) {
      FsDebug.log('$_tag COMMIT FAIL | ${e.code} | ${e.message}');
      rethrow;
    }
  }
}
