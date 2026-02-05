// lib/pages/story_view_page.dart

import 'dart:io';
import 'package:flutter/material.dart';

/// 📖 Story 全螢幕瀏覽頁
///
/// - 背景全黑
/// - 點一下關閉
/// - 顯示使用者名稱與時間
class StoryViewPage extends StatelessWidget {
  final Map<String, dynamic> story;

  const StoryViewPage({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    final String user = story["user"] ?? "";
    final DateTime? time = story["time"] as DateTime?;
    final String timeString = time != null
        ? time.toString().split(".").first
        : "";

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: Stack(
          children: [
            // 中間的圖片
            Center(
              child: Image.file(
                File(story["image"]),
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            ),

            // 上方的使用者資訊
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      child: Icon(Icons.person, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (timeString.isNotEmpty)
                          Text(
                            timeString,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
