// lib/services/splash_page.dart
import 'dart:async';
import 'package:flutter/material.dart';

/// ✅ SplashPage（啟動畫面｜完整版｜可編譯｜已修正 withOpacity deprecated）
/// ------------------------------------------------------------
/// - 使用 withValues(alpha: ...) 取代 withOpacity(...)
/// - 支援自動跳轉到 nextRoute（預設 /）
class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    this.nextRoute = '/',
    this.delay = const Duration(milliseconds: 900),
    this.title = 'Osmile',
    this.subtitle = '啟動中…',
    this.background = const Color(0xFFF6F8FB),
    this.logoIcon = Icons.watch,
  });

  final String nextRoute;
  final Duration delay;
  final String title;
  final String subtitle;
  final Color background;
  final IconData logoIcon;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    // 防止 splash 被重複 push（避免 back stack 一堆 splash）
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(widget.nextRoute, (r) => false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: widget.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _logoCard(theme),
                  const SizedBox(height: 18),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 14),
                  Text(
                    widget.subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Powered by Osmile',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.10), // ✅ 修正
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.blueAccent.withValues(alpha: 0.18), // ✅ 修正
                ),
              ),
              child: Icon(widget.logoIcon, color: Colors.blueAccent, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Shopping • Lottery • Health',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.06), // ✅ 修正
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'v1',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
