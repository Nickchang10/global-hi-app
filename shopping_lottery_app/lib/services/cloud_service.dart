import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'security_service.dart';
import 'api_service.dart';

/// ☁️ 模擬雲端儲存與伺服器部署服務
///
/// 功能：
/// - 模擬多區伺服器佈署 (Server A / B)
/// - 檔案上傳 / 下載 / 刪除
/// - API 層封裝安全請求
/// - 整合防火牆安全事件記錄
class CloudService extends ChangeNotifier {
  static final CloudService instance = CloudService._internal();
  CloudService._internal();

  final _random = Random();

  // 模擬伺服器節點
  String activeServer = "Server A (台北)";
  final List<String> servers = ["Server A (台北)", "Server B (新加坡)"];

  // 模擬已上傳檔案
  final List<Map<String, dynamic>> _files = [];

  List<Map<String, dynamic>> get files => List.unmodifiable(_files);

  /// 🪣 上傳檔案（模擬）
  Future<Map<String, dynamic>> uploadFile(String filename) async {
    final api = ApiService.instance;
    final security = SecurityService.instance;

    final payload = {"filename": filename, "action": "upload"};
    await api.sendSecureRequest(endpoint: "/api/cloud/upload", payload: payload);

    final file = {
      "name": filename,
      "url": "https://mock.osmile.cloud/$filename",
      "server": activeServer,
      "time": DateTime.now(),
    };
    _files.add(file);
    notifyListeners();

    security._addLog("雲端上傳", "上傳 $filename 至 $activeServer");
    return {"status": 200, "file": file};
  }

  /// ⬇️ 下載檔案
  Future<Map<String, dynamic>> downloadFile(String filename) async {
    final api = ApiService.instance;
    final file = _files.firstWhere(
      (f) => f["name"] == filename,
      orElse: () => {},
    );
    if (file.isEmpty) return {"status": 404, "message": "找不到檔案"};

    await api.sendSecureRequest(
        endpoint: "/api/cloud/download", payload: {"filename": filename});

    return {"status": 200, "file": file};
  }

  /// ❌ 刪除檔案
  Future<Map<String, dynamic>> deleteFile(String filename) async {
    final api = ApiService.instance;
    final security = SecurityService.instance;

    _files.removeWhere((f) => f["name"] == filename);
    await api.sendSecureRequest(
        endpoint: "/api/cloud/delete", payload: {"filename": filename});
    notifyListeners();

    security._addLog("雲端刪除", "已刪除 $filename");
    return {"status": 200, "message": "刪除成功"};
  }

  /// 🌀 切換伺服器節點
  void switchServer() {
    activeServer = (activeServer == servers[0]) ? servers[1] : servers[0];
    SecurityService.instance._addLog("伺服器切換", "目前使用節點：$activeServer");
    notifyListeners();
  }

  /// 📊 模擬健康檢查
  Map<String, dynamic> serverStatus() {
    return {
      "active": activeServer,
      "uptime": "${_random.nextInt(99)}%",
      "files": _files.length,
      "lastSync": DateTime.now().toIso8601String(),
    };
  }
}
