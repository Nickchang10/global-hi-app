import 'dart:io';
import 'package:flutter/material.dart';

/// 📸 多張圖片輪播（IG 貼文用）
class CarouselWidget extends StatelessWidget {
  final List<String> images;

  const CarouselWidget({super.key, required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 260,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (_, i) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(images[i]),
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          );
        },
      ),
    );
  }
}
