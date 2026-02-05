// lib/models/app_notification.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

@immutable
class AppNotification {
  final String id;
  final String type;
  final String title;

  /// ✅ 主要內容：用 message 命名（UI/搜尋最常用）
  final String message;

  /// 顯示用 icon code（可選）
  final int? iconCodePoint;
  final String? iconFontFamily;
  final String? iconFontPackage;

  final bool read;
  final DateTime createdAt;

  /// 其他 payload（可選）
  final Map<String, dynamic> data;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.read,
    required this.createdAt,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    this.data = const <String, dynamic>{},
  });

  /// 兼容舊欄位：body/content
  String get body => message;
  String get content => message;

  IconData? get icon {
    final cp = iconCodePoint;
    if (cp == null) return null;
    return IconData(
      cp,
      fontFamily: iconFontFamily,
      fontPackage: iconFontPackage,
    );
  }

  AppNotification copyWith({
    String? id,
    String? type,
    String? title,
    String? message,
    bool? read,
    DateTime? createdAt,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      data: data ?? this.data,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      // ✅ 永遠寫 message
      'message': message,
      // ✅ 也兼容寫 body/content（可選，方便舊 UI/後台）
      'body': message,
      'content': message,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
      'iconCodePoint': iconCodePoint,
      'iconFontFamily': iconFontFamily,
      'iconFontPackage': iconFontPackage,
      'data': data,
    };
  }

  static DateTime _parseTime(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) {
      final dt = DateTime.tryParse(v);
      if (dt != null) return dt;
    }
    return DateTime.now();
  }

  static AppNotification fromMap(Map<String, dynamic> m, {String? fallbackId}) {
    String s(dynamic v) => (v ?? '').toString();
    bool b(dynamic v, {bool fb = false}) => v == true ? true : (v == false ? false : fb);

    final id = s(m['id']).isNotEmpty ? s(m['id']) : (fallbackId ?? 'n_${m.hashCode}');
    final type = s(m['type']).isNotEmpty ? s(m['type']) : 'system';
    final title = s(m['title']).isNotEmpty ? s(m['title']) : '通知';

    // ✅ 兼容 message/body/content 任一欄位
    final msg = s(m['message']).isNotEmpty
        ? s(m['message'])
        : (s(m['body']).isNotEmpty ? s(m['body']) : s(m['content']));

    final dataRaw = m['data'];
    final data = dataRaw is Map ? Map<String, dynamic>.from(dataRaw) : const <String, dynamic>{};

    return AppNotification(
      id: id,
      type: type,
      title: title,
      message: msg,
      read: b(m['read'], fb: false),
      createdAt: _parseTime(m['createdAt'] ?? m['time'] ?? m['ts']),
      iconCodePoint: m['iconCodePoint'] is int ? m['iconCodePoint'] as int : int.tryParse(s(m['iconCodePoint'])),
      iconFontFamily: s(m['iconFontFamily']).isEmpty ? null : s(m['iconFontFamily']),
      iconFontPackage: s(m['iconFontPackage']).isEmpty ? null : s(m['iconFontPackage']),
      data: data,
    );
  }
}
