// lib/widgets/image_upload_preview.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// ✅ ImageUploadPreview（圖片上傳預覽｜完整版｜已修 unnecessary_import）
/// ------------------------------------------------------------
/// - 支援 Web（memory bytes）與一般 URL 顯示
/// - 也可支援 File（非 web）
/// - 你可以把它用在：商品編輯、Banner 上傳、會員頭像等
///
/// 使用方式：
/// ImageUploadPreview(
///   bytes: pickedBytes, // Uint8List?
///   imageUrl: existingUrl,
///   size: 140,
/// )
class ImageUploadPreview extends StatelessWidget {
  const ImageUploadPreview({
    super.key,
    this.bytes,
    this.imageUrl,
    this.filePath,
    this.size = 140,
    this.borderRadius = 16,
    this.onRemove,
    this.placeholderText = '尚未選擇圖片',
  });

  /// Web / Memory
  final Uint8List? bytes;

  /// 已上傳（或既有）URL
  final String? imageUrl;

  /// （可選）非 Web 的本地檔案路徑（若你用 image_picker 回傳 path）
  final String? filePath;

  final double size;
  final double borderRadius;

  final VoidCallback? onRemove;
  final String placeholderText;

  bool get _hasBytes => bytes != null && bytes!.isNotEmpty;
  bool get _hasUrl => (imageUrl ?? '').trim().isNotEmpty;
  bool get _hasFilePath => (filePath ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Container(
              color: Colors.grey.shade200,
              child: _buildImage(context),
            ),
          ),
          if (onRemove != null && (_hasBytes || _hasUrl || _hasFilePath))
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: Colors.black.withValues(alpha: 0.55),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (_hasBytes) {
      return Image.memory(bytes!, fit: BoxFit.cover);
    }

    if (_hasUrl) {
      return Image.network(
        imageUrl!.trim(),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
      );
    }

    // filePath：若你真的要支援 File 顯示，可解除下面註解並加回 dart:io import
    // 但注意：web 不能用 dart:io
    //
    // if (!kIsWeb && _hasFilePath) {
    //   return Image.file(File(filePath!.trim()), fit: BoxFit.cover);
    // }

    return _placeholder();
  }

  Widget _placeholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, color: Colors.grey.shade600, size: 34),
            const SizedBox(height: 8),
            Text(
              placeholderText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
