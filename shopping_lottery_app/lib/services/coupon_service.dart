// lib/services/coupon_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// =============================================================
/// ✅ CouponService（折價券 / 優惠券）完整版（最終穩定版本）
///
/// 功能特色：
/// - 狀態：可使用 / 已使用 / 已過期
/// - 折扣型態：金額折抵(amount) / 百分比(percent)
/// - 永續化保存（SharedPreferences）
/// - 完整相容 checkout_page / payment_page / profile_page
///
/// 對外方法：
///   - init() / reload()
///   - addCoupon() / remove() / clearAll()
///   - markUsed() / markUnused()
///   - all / available / used / expired
///   - isApplicable() / calcDiscount() / computeDiscount()
///   - pickBestAvailable()
/// =============================================================
class CouponService extends ChangeNotifier {
  static final CouponService instance = CouponService._internal();
  factory CouponService() => instance;
  CouponService._internal();

  static const String _prefsKey = 'osmile_coupons_v2';
  final List<Map<String, dynamic>> _all = [];
  bool _inited = false;

  bool get initialized => _inited;
  List<Map<String, dynamic>> get all => List.unmodifiable(_all);
  int get availableCount => available.length;

  /// ✅ 可使用（未使用 + 未過期）
  List<Map<String, dynamic>> get available {
    final now = DateTime.now();
    return _all.where((c) {
      final used = c['used'] == true;
      final exp = _parseDate(c['expiresAt']);
      return !used && (exp == null || exp.isAfter(now));
    }).toList();
  }

  /// ✅ 已使用
  List<Map<String, dynamic>> get used =>
      _all.where((c) => c['used'] == true).toList();

  /// ✅ 已過期
  List<Map<String, dynamic>> get expired {
    final now = DateTime.now();
    return _all.where((c) {
      if (c['used'] == true) return false;
      final exp = _parseDate(c['expiresAt']);
      return exp != null && exp.isBefore(now);
    }).toList();
  }

  // ======================================================
  // 初始化 / 永續化
  // ======================================================
  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      _all.clear();

      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final e in decoded) {
            if (e is Map) _all.add(_normalizeCoupon(Map<String, dynamic>.from(e)));
          }
        }
      }

      // 預設一張新手券
      if (_all.isEmpty) {
        await addCoupon(
          title: '新用戶禮｜折抵 NT\$100',
          type: 'amount',
          amountOrPercent: 100,
          minSpend: 500,
          source: 'welcome',
          expiresAt: DateTime.now().add(const Duration(days: 14)),
        );
      } else {
        await _save();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('CouponService init error: $e');
    }

    notifyListeners();
  }

  Future<void> reload() async {
    _inited = false;
    _all.clear();
    await init();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_all));
    } catch (e) {
      if (kDebugMode) debugPrint('CouponService save error: $e');
    }
  }

  // ======================================================
  // CRUD
  // ======================================================
  Future<void> addCoupon({
    required String title,
    required String type, // 'amount' or 'percent'
    num? amountOrPercent,
    num? amount,
    num? percent,
    num? minSpend,
    String? source,
    DateTime? expiresAt,
    String? code,
    String? id,
  }) async {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    final cid = (id != null && id.trim().isNotEmpty)
        ? id.trim()
        : 'cp_${nowMs}_${Random().nextInt(9999)}';

    final ccode = (code != null && code.trim().isNotEmpty)
        ? code.trim().toUpperCase()
        : _genCode();

    final t = type.trim().toLowerCase();
    num resolvedAmount = 0;
    num resolvedPercent = 0;

    if (t == 'percent') {
      resolvedPercent = (percent ?? amountOrPercent ?? 0).clamp(0, 100);
    } else {
      resolvedAmount = (amount ?? amountOrPercent ?? 0).toDouble();
    }

    final exp = expiresAt ?? now.add(const Duration(days: 14));

    _all.removeWhere((c) => (c['id'] ?? '').toString() == cid);
    _all.insert(
      0,
      _normalizeCoupon({
        'id': cid,
        'title': title,
        'type': t == 'percent' ? 'percent' : 'amount',
        'amount': t == 'percent' ? 0 : resolvedAmount,
        'percent': t == 'percent' ? resolvedPercent : 0,
        'minSpend': (minSpend ?? 0).toDouble(),
        'source': source ?? 'manual',
        'code': ccode,
        'used': false,
        'createdAt': nowMs,
        'expiresAt': exp.millisecondsSinceEpoch,
        'usedAt': null,
      }),
    );

    await _save();
    notifyListeners();
  }

  Future<void> markUsed(String id) async {
    final idx = _all.indexWhere((c) => (c['id'] ?? '').toString() == id);
    if (idx == -1) return;
    _all[idx]['used'] = true;
    _all[idx]['usedAt'] = DateTime.now().millisecondsSinceEpoch;
    await _save();
    notifyListeners();
  }

  Future<void> markUnused(String id) async {
    final idx = _all.indexWhere((c) => (c['id'] ?? '').toString() == id);
    if (idx == -1) return;
    _all[idx]['used'] = false;
    _all[idx]['usedAt'] = null;
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _all.removeWhere((c) => (c['id'] ?? '').toString() == id);
    await _save();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _all.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
    notifyListeners();
  }

  // ======================================================
  // 折扣計算邏輯
  // ======================================================
  bool isApplicable(Map<String, dynamic> coupon,
      {required double orderSubtotal}) {
    if (coupon['used'] == true) return false;
    final exp = _parseDate(coupon['expiresAt']);
    if (exp != null && exp.isBefore(DateTime.now())) return false;
    final minSpend = _toDouble(coupon['minSpend'], fallback: 0);
    return orderSubtotal >= minSpend;
  }

  double calcDiscount(Map<String, dynamic> coupon,
      {required double orderSubtotal}) {
    return computeDiscount(coupon, orderTotal: orderSubtotal);
  }

  double computeDiscount(Map<String, dynamic> coupon,
      {required double orderTotal}) {
    if (orderTotal <= 0) return 0;
    if (coupon['used'] == true) return 0;
    final exp = _parseDate(coupon['expiresAt']);
    if (exp != null && exp.isBefore(DateTime.now())) return 0;
    final minSpend = _toDouble(coupon['minSpend'], fallback: 0);
    if (orderTotal < minSpend) return 0;

    final type = (coupon['type'] ?? 'amount').toString().toLowerCase();
    if (type == 'percent') {
      final p = _toDouble(coupon['percent'], fallback: 0).clamp(0, 100);
      final d = orderTotal * (p / 100);
      return d.clamp(0, orderTotal);
    } else {
      final a = _toDouble(coupon['amount'], fallback: 0);
      return a.clamp(0, orderTotal);
    }
  }

  /// ✅ 自動挑選最優惠券
  Map<String, dynamic>? pickBestAvailable({required double orderSubtotal}) {
    final candidates = available
        .where((c) => isApplicable(c, orderSubtotal: orderSubtotal))
        .toList();
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final da = calcDiscount(a, orderSubtotal: orderSubtotal);
      final db = calcDiscount(b, orderSubtotal: orderSubtotal);
      return db.compareTo(da);
    });
    return candidates.first;
  }

  // ======================================================
  // 工具函式
  // ======================================================
  Map<String, dynamic> _normalizeCoupon(Map<String, dynamic> c) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final id = (c['id'] ?? '').toString().trim().isEmpty
        ? 'cp_${nowMs}_${Random().nextInt(9999)}'
        : c['id'].toString();

    final type = (c['type'] ?? 'amount').toString().toLowerCase();
    final used = c['used'] == true;
    final codeRaw = (c['code'] ?? '').toString().trim();
    final code = codeRaw.isEmpty ? _genCode() : codeRaw.toUpperCase();

    final createdAt = _toInt(c['createdAt'], fallback: nowMs);
    final expiresAt = _toInt(
      c['expiresAt'],
      fallback: DateTime.now()
          .add(const Duration(days: 14))
          .millisecondsSinceEpoch,
    );
    final usedAt = _toNullableInt(c['usedAt']);

    return {
      'id': id,
      'title': (c['title'] ?? '優惠券').toString(),
      'type': type == 'percent' ? 'percent' : 'amount',
      'amount': type == 'percent' ? 0 : _toDouble(c['amount'], fallback: 0),
      'percent': type == 'percent' ? _toDouble(c['percent'], fallback: 0) : 0,
      'minSpend': _toDouble(c['minSpend'], fallback: 0),
      'source': (c['source'] ?? 'manual').toString(),
      'code': code,
      'used': used,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'usedAt': used ? usedAt : null,
    };
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    final dt = DateTime.tryParse(s);
    if (dt != null) return dt;
    final ms = int.tryParse(s);
    if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    return null;
  }

  double _toDouble(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '').trim();
    return double.tryParse(s) ?? fallback;
  }

  int _toInt(dynamic v, {required int fallback}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  int? _toNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return 'OS-${List.generate(8, (_) => chars[r.nextInt(chars.length)]).join()}';
  }
}
