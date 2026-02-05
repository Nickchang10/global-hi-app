import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class VideoConfigService {
  static final VideoConfigService instance = VideoConfigService._internal();
  VideoConfigService._internal();

  List<Map<String, dynamic>> videoList = [];

  /// 初始化：先讀 assets，再讀本地存檔（如果有）
  Future<void> loadConfigs() async {
    try {
      // 嘗試從本地文件讀
      final file = await _getLocalFile();
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        videoList = List<Map<String, dynamic>>.from(json.decode(jsonStr));
      } else {
        // 若本地沒有，讀 assets 預設版本
        final jsonStr = await rootBundle.loadString('assets/data/video_config.json');
        videoList = List<Map<String, dynamic>>.from(json.decode(jsonStr));
      }
    } catch (e) {
      videoList = [];
    }
  }

  /// 新增或更新影片
  Future<void> saveVideo(Map<String, dynamic> newVideo) async {
    final index = videoList.indexWhere(
        (v) => v['productName'] == newVideo['productName']);
    if (index >= 0) {
      videoList[index] = newVideo;
    } else {
      videoList.add(newVideo);
    }
    await _saveToFile();
  }

  /// 刪除影片設定
  Future<void> deleteVideo(String productName) async {
    videoList.removeWhere((v) => v['productName'] == productName);
    await _saveToFile();
  }

  /// 取得指定商品影片設定
  Map<String, dynamic>? getVideoByProduct(String productName) {
    return videoList
        .firstWhere((v) => v['productName'] == productName, orElse: () => {});
  }

  /// 寫入本地文件
  Future<void> _saveToFile() async {
    final file = await _getLocalFile();
    await file.writeAsString(json.encode(videoList), flush: true);
  }

  /// 取得本地檔案路徑
  Future<File> _getLocalFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/video_config.json');
  }
}
