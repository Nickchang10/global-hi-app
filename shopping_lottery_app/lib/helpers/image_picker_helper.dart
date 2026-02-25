import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// ✅ ImagePickerHelper（完整版｜不依賴 package:image）
/// ------------------------------------------------------------
/// - 使用 image_picker 內建 maxWidth/maxHeight/imageQuality 做縮圖/壓縮
/// - 回傳 PickedImage（含 bytes / 檔名 / mimeType / XFile）
/// - 支援：相簿、相機、相簿多選
/// ------------------------------------------------------------
class ImagePickerHelper {
  ImagePickerHelper._();

  static final ImagePicker _picker = ImagePicker();

  /// 從相簿選取 1 張
  static Future<PickedImage?> pickFromGallery({
    double? maxWidth = 1600,
    double? maxHeight = 1600,
    int imageQuality = 85,
  }) async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    if (file == null) return null;
    return _toPickedImage(file);
  }

  /// 從相機拍攝 1 張
  static Future<PickedImage?> pickFromCamera({
    double? maxWidth = 1600,
    double? maxHeight = 1600,
    int imageQuality = 85,
  }) async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    if (file == null) return null;
    return _toPickedImage(file);
  }

  /// 相簿多選（注意：iOS/Android 需新版 image_picker 才支援 pickMultiImage）
  static Future<List<PickedImage>> pickMultiFromGallery({
    double? maxWidth = 1600,
    double? maxHeight = 1600,
    int imageQuality = 85,
    int? limit,
  }) async {
    final List<XFile> files = await _picker.pickMultiImage(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      limit: limit,
    );

    if (files.isEmpty) return <PickedImage>[];
    final results = <PickedImage>[];
    for (final f in files) {
      results.add(await _toPickedImage(f));
    }
    return results;
  }

  /// 轉換成 PickedImage（讀 bytes + 推斷 mimeType）
  static Future<PickedImage> _toPickedImage(XFile file) async {
    final Uint8List bytes = await file.readAsBytes();
    final String name = _fileName(file);
    final String mimeType = _guessMimeType(name);

    return PickedImage(
      file: file,
      bytes: bytes,
      name: name,
      mimeType: mimeType,
      sizeBytes: bytes.lengthInBytes,
    );
  }

  static String _fileName(XFile file) {
    // XFile.name 在多數平台可用；web 也通常有值
    final n = file.name.trim();
    if (n.isNotEmpty) return n;

    // fallback：從 path 拿最後一段
    final p = file.path;
    final idx = p.lastIndexOf('/');
    final idx2 = p.lastIndexOf('\\');
    final cut = idx > idx2 ? idx : idx2;
    return (cut >= 0 && cut + 1 < p.length) ? p.substring(cut + 1) : 'image';
  }

  static String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';

    // unknown -> 預設 jpeg（多數相機輸出）
    return 'image/jpeg';
  }

  /// 可選：檔案大小上限檢查（避免上傳過大）
  static void assertMaxSize({
    required PickedImage image,
    required int maxBytes,
  }) {
    if (image.sizeBytes != null && image.sizeBytes! > maxBytes) {
      throw Exception('圖片過大：${image.sizeBytes} bytes（上限 $maxBytes bytes）');
    }
  }
}

/// 選取圖片結果（可直接拿 bytes 上傳 Firestore Storage / API）
class PickedImage {
  final XFile file;
  final Uint8List bytes;
  final String name;
  final String mimeType;
  final int? sizeBytes;

  const PickedImage({
    required this.file,
    required this.bytes,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
  });

  @override
  String toString() {
    return 'PickedImage(name=$name, mimeType=$mimeType, sizeBytes=$sizeBytes)';
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'mimeType': mimeType,
    'sizeBytes': sizeBytes,
  };
}
