// lib/services/api_service.dart
//
// ✅ ApiService（HTTP API 封裝｜可編譯完整版｜已避免 unnecessary_cast）
// ------------------------------------------------------------
// - 支援 GET / POST / PUT / DELETE
// - 自動帶 Firebase idToken（可關閉）
// - JSON decode 安全處理：Map / List / String / 空 body
// - 統一回傳 ApiResponse，方便 UI 顯示錯誤
//
// 依賴：
//   - http
//   - firebase_auth
// ------------------------------------------------------------

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ApiResponse<T> {
  final bool ok;
  final int statusCode;
  final T? data;
  final String? message;
  final Object? error;

  const ApiResponse({
    required this.ok,
    required this.statusCode,
    this.data,
    this.message,
    this.error,
  });

  static ApiResponse<T> success<T>(int code, T data) =>
      ApiResponse<T>(ok: true, statusCode: code, data: data);

  static ApiResponse<T> fail<T>(int code, {String? message, Object? error}) =>
      ApiResponse<T>(
        ok: false,
        statusCode: code,
        message: message,
        error: error,
      );
}

class ApiService {
  ApiService({
    required this.baseUrl,
    FirebaseAuth? auth,
    http.Client? client,
    this.defaultTimeout = const Duration(seconds: 25),
  }) : _auth = auth ?? FirebaseAuth.instance,
       _client = client ?? http.Client();

  final String baseUrl;
  final Duration defaultTimeout;

  final FirebaseAuth _auth;
  final http.Client _client;

  /// 若你不想帶 Firebase token（例如公開 API），呼叫時傳 false
  Future<Map<String, String>> _buildHeaders({
    bool withAuthToken = true,
    Map<String, String>? extra,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
    };

    if (withAuthToken) {
      final user = _auth.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (extra != null && extra.isNotEmpty) {
      headers.addAll(extra);
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final u = Uri.parse('$cleanBase$cleanPath');
    if (query == null || query.isEmpty) return u;

    // query 轉成 String（避免 Object -> String 問題）
    final q = <String, String>{};
    query.forEach((k, v) {
      if (v == null) return;
      q[k] = v.toString();
    });
    return u.replace(queryParameters: q);
  }

  // -------------------------
  // Public methods
  // -------------------------

  Future<ApiResponse<dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool withAuthToken = true,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final res = await _client
          .get(
            _uri(path, query),
            headers: await _buildHeaders(
              withAuthToken: withAuthToken,
              extra: headers,
            ),
          )
          .timeout(timeout ?? defaultTimeout);

      return _handleResponse(res);
    } catch (e) {
      return ApiResponse.fail(-1, message: 'GET 失敗', error: e);
    }
  }

  Future<ApiResponse<dynamic>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool withAuthToken = true,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final res = await _client
          .post(
            _uri(path, query),
            headers: await _buildHeaders(
              withAuthToken: withAuthToken,
              extra: headers,
            ),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(timeout ?? defaultTimeout);

      return _handleResponse(res);
    } catch (e) {
      return ApiResponse.fail(-1, message: 'POST 失敗', error: e);
    }
  }

  Future<ApiResponse<dynamic>> put(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool withAuthToken = true,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final res = await _client
          .put(
            _uri(path, query),
            headers: await _buildHeaders(
              withAuthToken: withAuthToken,
              extra: headers,
            ),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(timeout ?? defaultTimeout);

      return _handleResponse(res);
    } catch (e) {
      return ApiResponse.fail(-1, message: 'PUT 失敗', error: e);
    }
  }

  Future<ApiResponse<dynamic>> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool withAuthToken = true,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final res = await _client
          .delete(
            _uri(path, query),
            headers: await _buildHeaders(
              withAuthToken: withAuthToken,
              extra: headers,
            ),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(timeout ?? defaultTimeout);

      return _handleResponse(res);
    } catch (e) {
      return ApiResponse.fail(-1, message: 'DELETE 失敗', error: e);
    }
  }

  // -------------------------
  // Response decode (no unnecessary cast)
  // -------------------------

  ApiResponse<dynamic> _handleResponse(http.Response res) {
    final code = res.statusCode;
    final raw = res.body.trim();

    dynamic decoded;
    if (raw.isEmpty) {
      decoded = null;
    } else {
      decoded = _tryJsonDecode(raw);
    }

    // 你若後端習慣 { ok, message, data }，可在這裡集中解包
    String? message;
    dynamic data = decoded;

    if (decoded is Map<String, dynamic>) {
      // 這裡不用任何 `as Map<String, dynamic>`，避免 unnecessary_cast
      if (decoded.containsKey('message')) {
        message = decoded['message']?.toString();
      }
      if (decoded.containsKey('data')) {
        data = decoded['data'];
      }
    }

    if (code >= 200 && code < 300) {
      return ApiResponse.success(code, data);
    }

    // error body fallback message
    message ??= 'HTTP $code';
    if (decoded is Map<String, dynamic>) {
      // 常見錯誤欄位
      message = decoded['error']?.toString() ?? message;
    }
    return ApiResponse.fail(code, message: message, error: decoded);
  }

  dynamic _tryJsonDecode(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      // 不是 JSON 就回字串
      return raw;
    }
  }

  void dispose() {
    _client.close();
  }
}
