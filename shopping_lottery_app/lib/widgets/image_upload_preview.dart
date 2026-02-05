import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class ImageUploadPreview extends StatefulWidget {
  final List<File> images;
  final Function(int) onRemove;

  const ImageUploadPreview({super.key, required this.images, required this.onRemove});

  @override
  State<ImageUploadPreview> createState() => _ImageUploadPreviewState();
}

class _ImageUploadPreviewState extends State<ImageUploadPreview> {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(widget.images.length, (i) {
        final file = widget.images[i];
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(file, width: 90, height: 90, fit: BoxFit.cover),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => widget.onRemove(i),
                child: Container(
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child:
                      const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            )
          ],
        );
      }),
    );
  }

  /// 修正版：新版 image 套件用命名參數 radius
  Future<File?> blurImage(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return null;
    final blurred = img.gaussianBlur(image, radius: 0.3);
    final output = File(file.path)..writeAsBytesSync(img.encodeJpg(blurred));
    return output;
  }
}
