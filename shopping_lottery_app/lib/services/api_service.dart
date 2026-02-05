import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'auth_service.dart';
import 'security_service.dart';

/// 🌐 模擬後端伺服器 + 安全封包傳輸層
///
/// 功能：
/// - 模擬 API 請求 / 回應
/// - AES 封包加密
/// - Token 驗證
/// - 防火牆驗證整合
class ApiService {
  static final ApiService instance = ApiService._internal();
  ApiService._internal();

  final _serverKey = "OsmileSecretKey123"; // 模擬伺服器金鑰
  String? _token;

  /// 取得目前 Token
  String? get token => _token;

  /// 生成 JWT-like Token
  Future<String> generateToken(String username) async {
    final header = base64UrlEncode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
    final payload = base64UrlEncode(
        utf8.encode('{"user":"$username","iat":${DateTime.now().millisecondsSinceEpoch}}'));
    final signature = base64UrlEncode(
        Hmac(sha256, utf8.encode(_serverKey)).convert(utf8.encode("$header.$payload")).bytes);

    _token = "$header.$payload.$signature";
    return _token!;
  }

  /// 驗證 Token 合法性
  bool validateToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final signature = base64UrlEncode(
          Hmac(sha256, utf8.encode(_serverKey))
              .convert(utf8.encode("${parts[0]}.${parts[1]}"))
              .bytes);
      return signature == parts[2];
    } catch (_) {
      return false;
    }
  }

  /// AES 加密
  String encryptPayload(Map<String, dynamic> data) {
    final key = encrypt.Key.fromUtf8(_serverKey.substring(0, 16));
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted =
        encrypter.encrypt(jsonEncode(data), iv: iv);
    return encrypted.base64;
  }

  /// AES 解密
  Map<String, dynamic> decryptPayload(String encryptedData) {
    final key = encrypt.Key.fromUtf8(_serverKey.substring(0, 16));
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final decrypted =
        encrypter.decrypt64(encryptedData, iv: iv);
    return jsonDecode(decrypted);
  }

  /// 🔗 模擬安全 API 請求
  Future<Map<String, dynamic>> sendSecureRequest({
    required String endpoint,
    required Map<String, dynamic> payload,
    bool requireAuth = true,
  }) async {
    final username = AuthService.instance.username ?? "訪客";
    final security = SecurityService.instance;

    // 🔒 防火牆驗證
    if (!security.validateAccess(username, endpoint)) {
      return {"status": 403, "message": "封鎖使用者請求被攔截"};
    }

    // 🔑 驗證 Token
    if (requireAuth && (_token == null || !validateToken(_token!))) {
      return {"status": 401, "message": "未授權的請求"};
    }

    // 🔐 加密傳送
    final encrypted = encryptPayload(payload);
    await Future.delayed(const Duration(milliseconds: 600));

    // 🔓 模擬伺服器回傳
    final response = {
      "status": 200,
      "endpoint": endpoint,
      "encrypted": encrypted,
      "timestamp": DateTime.now().toIso8601String(),
    };

    security._addLog("API請求", "成功處理安全請求：$endpoint");

    return response;
  }
}
