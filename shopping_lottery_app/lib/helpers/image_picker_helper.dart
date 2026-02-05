import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// 🧭 ImagePickerHelper
///
/// 提供相機 / 相簿圖片、影片選取與壓縮裁切功能
/// ✅ 支援：
/// - 拍照 / 錄影
/// - 選多張圖片
/// - 圖片壓縮（控制大小）
/// - IG 正方形裁切
/// - Story 9:16 裁切
/// - 安全寫入暫存路徑
class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// 📸 從相簿選取單張圖片
  static Future<String?> pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      return picked?.path;
    } catch (e) {
      print("❌ pickImage Error: $e");
      return null;
    }
  }

  /// 📷 拍照取得圖片
  static Future<String?> takePhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      return picked?.path;
    } catch (e) {
      print("❌ takePhoto Error: $e");
      return null;
    }
  }

  /// 🖼️ 多張圖片（相簿）
  static Future<List<String>> pickMultiImages({int maxImages = 10}) async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 90);
      if (picked.isEmpty) return [];

      final images = picked.length > maxImages
          ? picked.sublist(0, maxImages)
          : picked;
      return images.map((x) => x.path).toList();
    } catch (e) {
      print("❌ pickMultiImages Error: $e");
      return [];
    }
  }

  /// 🔀 選擇來源（true = 相機，false = 相簿）
  static Future<String?> pickImageWithSource({required bool fromCamera}) async {
    try {
      final picked = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 90,
      );
      return picked?.path;
    } catch (e) {
      print("❌ pickImageWithSource Error: $e");
      return null;
    }
  }

  /// 🎬 從相簿選影片（例如 Reels 用）
  static Future<String?> pickVideo() async {
    try {
      final picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3),
      );
      return picked?.path;
    } catch (e) {
      print("❌ pickVideo Error: $e");
      return null;
    }
  }

  /// 🎥 錄影
  static Future<String?> recordVideo() async {
    try {
      final picked = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 3),
      );
      return picked?.path;
    } catch (e) {
      print("❌ recordVideo Error: $e");
      return null;
    }
  }

  /// 🪫 壓縮圖片：把檔案壓到 maxSizeInBytes 以下（預設 1MB）
  static Future<File?> compressImage(
    File file, {
    int maxSizeInBytes = 1 * 1024 * 1024, // 1MB
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final tmpDir = await getTemporaryDirectory();
      final tempPath =
          "${tmpDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg";

      int quality = 95;
      File output = File(tempPath);
      var compressed = img.encodeJpg(image, quality: quality);
      await output.writeAsBytes(compressed);

      // 逐步降低品質直到小於指定大小
      while (output.lengthSync() > maxSizeInBytes && quality > 10) {
        quality -= 10;
        compressed = img.encodeJpg(image, quality: quality);
        await output.writeAsBytes(compressed);
      }
      return output;
    } catch (e) {
      print("❌ compressImage Error: $e");
      return null;
    }
  }

  /// 🟥 裁切成正方形（IG 貼文用）
  static Future<File?> cropSquare(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final size = image.width < image.height ? image.width : image.height;
      final cropped = img.copyCrop(
        image,
        x: (image.width - size) ~/ 2,
        y: (image.height - size) ~/ 2,
        width: size,
        height: size,
      );

      final tmpDir = await getTemporaryDirectory();
      final outFile = File(
          "${tmpDir.path}/square_${DateTime.now().millisecondsSinceEpoch}.jpg");
      await outFile.writeAsBytes(img.encodeJpg(cropped, quality: 90));

      return outFile;
    } catch (e) {
      print("❌ cropSquare Error: $e");
      return null;
    }
  }

  /// 🟨 裁切為 9:16（Story / 直式影片封面用）
  static Future<File?> cropStory(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      const targetRatio = 9 / 16;
      int width = image.width;
      int height = (width / targetRatio).round();

      if (height > image.height) {
        height = image.height;
        width = (height * targetRatio).round();
      }

      final cropped = img.copyCrop(
        image,
        x: (image.width - width) ~/ 2,
        y: (image.height - height) ~/ 2,
        width: width,
        height: height,
      );

      final tmpDir = await getTemporaryDirectory();
      final outFile = File(
          "${tmpDir.path}/story_${DateTime.now().millisecondsSinceEpoch}.jpg");
      await outFile.writeAsBytes(img.encodeJpg(cropped, quality: 90));

      return outFile;
    } catch (e) {
      print("❌ cropStory Error: $e");
      return null;
    }
  }
}
