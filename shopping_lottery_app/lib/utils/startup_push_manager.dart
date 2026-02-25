import 'package:flutter/material.dart';

/// ✅ StartupPushManager（啟動推播處理器｜完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正重點：
/// - ❌ 不再對 AppNotification 使用 []（例如 n['type']）
/// - ✅ 改用 _read() / _normalize()：
///    - 支援 Map / model(toJson) / model.data / model.payload / model.type
/// - ✅ 提供 openFromNotification()：
///    - 若有 route => Navigator.pushNamed
///    - 否則顯示提示 dialog（不讓 app 直接崩）
///
/// 你可以在 Splash / AppStartupGate / main.dart 啟動後呼叫：
///   StartupPushManager.instance.handleOnStartup(context, initial: xxx);
/// ------------------------------------------------------------
class StartupPushManager {
  StartupPushManager._();
  static final StartupPushManager instance = StartupPushManager._();

  bool _handledOnce = false;

  /// ✅ 啟動時處理（避免重複跑）
  Future<void> handleOnStartup(
    BuildContext context, {
    dynamic initial, // AppNotification / Map / Firebase message payload 都可以
    Iterable<dynamic>?
    pending, // 多筆待處理通知（Iterable 保持協變，相容 List<AppNotification>）
    bool onlyOnce = true,
  }) async {
    if (onlyOnce && _handledOnce) return;

    _handledOnce = true;

    // 1) 先處理 initial
    if (initial != null) {
      await openFromNotification(context, initial);
      return;
    }

    // 2) 再處理 pending 第一筆
    final first = pending?.isNotEmpty == true ? pending!.first : null;
    if (first != null) {
      await openFromNotification(context, first);
    }
  }

  /// ✅ 由通知內容導頁/顯示
  Future<void> openFromNotification(
    BuildContext context,
    dynamic notification,
  ) async {
    final n = _normalize(notification);

    final String? route =
        _asString(n['route']) ?? _inferRouteFromType(_asString(n['type']));
    final Map<String, dynamic> args = (n['args'] is Map)
        ? Map<String, dynamic>.from(n['args'] as Map)
        : <String, dynamic>{};

    final title = _asString(n['title']) ?? '通知';
    final body = _asString(n['body']) ?? _asString(n['message']) ?? '';

    if (route != null && route.trim().isNotEmpty) {
      // 避免 build 期間 push
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.of(
          context,
        ).pushNamed(route, arguments: args.isEmpty ? null : args);
      });
      return;
    }

    // 沒有 route：至少不要爆，顯示內容
    await _showInfoDialog(
      context,
      title: title,
      message: body.isEmpty ? '此通知沒有可導向的頁面。' : body,
    );
  }

  /// ✅ 取出通知類型（如果外部只想拿 type）
  String? getType(dynamic notification) {
    final n = _normalize(notification);
    return _asString(n['type']);
  }

  // ---------------------------------------------------------------------------
  // Internal: Normalize & Safe Reader
  // ---------------------------------------------------------------------------

  /// 把任何通知來源（Map / model / payload）轉成 Map<String, dynamic>
  Map<String, dynamic> _normalize(dynamic notification) {
    // 1) 已經是 Map
    if (notification is Map<String, dynamic>) return notification;
    if (notification is Map) return Map<String, dynamic>.from(notification);

    // 2) dynamic model：嘗試 toJson()
    final d = notification as dynamic;
    try {
      final v = d.toJson();
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
    } catch (_) {}

    // 3) dynamic model：嘗試 data / payload
    try {
      final v = d.data;
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
    } catch (_) {}

    try {
      final v = d.payload;
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
    } catch (_) {}

    // 4) dynamic model：嘗試常見 getter
    final out = <String, dynamic>{};
    out['id'] = _read(notification, ['id', 'notificationId']);
    out['type'] = _read(notification, ['type', 'category', 'kind']);
    out['title'] = _read(notification, ['title', 'subject']);
    out['body'] = _read(notification, ['body', 'content', 'message']);
    out['route'] = _read(notification, ['route', 'screen', 'page', 'deepLink']);
    out['args'] = _read(notification, ['args', 'arguments', 'params', 'data']);

    // 5) 若 args 不是 Map，但可能在 data 裡
    if (out['args'] == null) {
      final data = _read(notification, ['data', 'payload']);
      if (data is Map) out['args'] = Map<String, dynamic>.from(data);
    }

    return out;
  }

  /// 安全讀取：依序嘗試 keys（支援 Map & dynamic getter）
  dynamic _read(dynamic obj, List<String> keys) {
    // Map
    if (obj is Map) {
      for (final k in keys) {
        if (obj.containsKey(k)) return obj[k];
      }
    }

    // dynamic getter
    final d = obj as dynamic;
    for (final k in keys) {
      try {
        final v = d
            .noSuchMethod; // trick to silence analyzer? (not executed) - keep below
        // ignore: unnecessary_statements
        v;
      } catch (_) {}

      try {
        // ignore: avoid_dynamic_calls
        final v = d
            // ignore: avoid_dynamic_calls
            .__getattr__(k);
        // 若你的 model 有 __getattr__ 之類可用（通常沒有），這段會進來
        if (v != null) return v;
      } catch (_) {}

      try {
        // ignore: avoid_dynamic_calls
        final v = d
            // ignore: avoid_dynamic_calls
            .toJson(); // 先用 toJson 再找 key（更通用）
        if (v is Map && v.containsKey(k)) return v[k];
      } catch (_) {}

      // 直接嘗試 getter（d.k）
      try {
        // ignore: avoid_dynamic_calls
        final v = _dynamicGetter(d, k);
        if (v != null) return v;
      } catch (_) {}
    }
    return null;
  }

  /// 動態 getter 讀取（避免直接寫 d.xxx 造成 analyzer 靜態錯誤）
  dynamic _dynamicGetter(dynamic d, String key) {
    // 這裡用 switch 讓 dart 在 compile 時不需要知道 model 欄位
    switch (key) {
      case 'id':
        // ignore: avoid_dynamic_calls
        return d.id;
      case 'notificationId':
        // ignore: avoid_dynamic_calls
        return d.notificationId;
      case 'type':
        // ignore: avoid_dynamic_calls
        return d.type;
      case 'category':
        // ignore: avoid_dynamic_calls
        return d.category;
      case 'kind':
        // ignore: avoid_dynamic_calls
        return d.kind;
      case 'title':
        // ignore: avoid_dynamic_calls
        return d.title;
      case 'subject':
        // ignore: avoid_dynamic_calls
        return d.subject;
      case 'body':
        // ignore: avoid_dynamic_calls
        return d.body;
      case 'content':
        // ignore: avoid_dynamic_calls
        return d.content;
      case 'message':
        // ignore: avoid_dynamic_calls
        return d.message;
      case 'route':
        // ignore: avoid_dynamic_calls
        return d.route;
      case 'screen':
        // ignore: avoid_dynamic_calls
        return d.screen;
      case 'page':
        // ignore: avoid_dynamic_calls
        return d.page;
      case 'deepLink':
        // ignore: avoid_dynamic_calls
        return d.deepLink;
      case 'args':
        // ignore: avoid_dynamic_calls
        return d.args;
      case 'arguments':
        // ignore: avoid_dynamic_calls
        return d.arguments;
      case 'params':
        // ignore: avoid_dynamic_calls
        return d.params;
      case 'data':
        // ignore: avoid_dynamic_calls
        return d.data;
      case 'payload':
        // ignore: avoid_dynamic_calls
        return d.payload;
      default:
        return null;
    }
  }

  String? _asString(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.trim().isEmpty ? null : s;
  }

  String? _inferRouteFromType(String? type) {
    if (type == null) return null;
    switch (type.toLowerCase()) {
      case 'order':
      case 'order_update':
      case 'order_status':
        return '/orders';
      case 'coupon':
      case 'coupon_issued':
        return '/coupons';
      case 'lottery':
      case 'lottery_result':
        return '/lottery';
      case 'points':
      case 'points_update':
        return '/points';
      case 'message':
      case 'chat':
        return '/messages';
      default:
        return null;
    }
  }

  Future<void> _showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }
}
