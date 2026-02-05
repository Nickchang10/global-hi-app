import 'package:flutter/material.dart';

/// 通用區塊標題樣式
class SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final VoidCallback? onTap;

  const SectionTitle({
    super.key,
    required this.title,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null)
                Icon(icon, color: const Color(0xFF007BFF), size: 20),
              if (icon != null) const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: const Text(
                "更多 >",
                style: TextStyle(color: Color(0xFF007BFF), fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
