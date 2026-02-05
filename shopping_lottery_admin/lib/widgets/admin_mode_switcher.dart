// lib/widgets/admin_mode_switcher.dart
//
// ✅ AdminModeSwitcher（v3 Final｜防連點＋動畫光暈＋SnackBar 提示＋全平台穩定）
// ------------------------------------------------------------
// 功能特色：
// - 無 await 錯誤，toggle() 可即時執行
// - 防連點 (_busy)
// - 自動路由切換（/dashboard <-> /simple_dashboard）
// - 動畫光暈與縮放
// - 切換完成後 SnackBar 提示
// - 全平台相容（Web / Android / iOS / macOS）
// ------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/admin_mode_controller.dart';

class AdminModeSwitcher extends StatefulWidget {
  const AdminModeSwitcher({super.key});

  @override
  State<AdminModeSwitcher> createState() => _AdminModeSwitcherState();
}

class _AdminModeSwitcherState extends State<AdminModeSwitcher>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  late final AnimationController _controller;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _glowAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePressed(BuildContext context, String targetRoute) {
    if (_busy) return;
    setState(() => _busy = true);

    final mode = context.read<AdminModeController>();
    final wasSimple = mode.isSimpleMode;

    try {
      // 即時切換模式
      mode.toggle();

      // 播放光暈動畫
      _controller.forward(from: 0);

      // 顯示 SnackBar 提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wasSimple ? '已切換為完整模式' : '已切換為簡潔模式'),
          duration: const Duration(seconds: 2),
        ),
      );

      // 若路由不同則切換
      final currentRoute = ModalRoute.of(context)?.settings.name;
      if (currentRoute != targetRoute) {
        Navigator.pushReplacementNamed(context, targetRoute);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('切換模式發生錯誤：$e')),
      );
    } finally {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _busy = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSimple = context.select<AdminModeController, bool>((m) => m.isSimpleMode);
    final cs = Theme.of(context).colorScheme;

    final label = isSimple ? '切換為完整模式' : '切換為簡潔模式';
    final targetRoute = isSimple ? '/dashboard' : '/simple_dashboard';
    final baseColor = isSimple ? cs.primaryContainer : cs.primary;
    final iconColor = isSimple ? cs.onPrimaryContainer : cs.onPrimary;

    return SafeArea(
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 350),
        child: GestureDetector(
          onTap: _busy ? null : () => _handlePressed(context, targetRoute),
          child: AnimatedBuilder(
            animation: _glowAnim,
            builder: (context, child) {
              final scale = 1 + 0.08 * _glowAnim.value;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: baseColor,
                    boxShadow: [
                      BoxShadow(
                        color: baseColor.withOpacity(0.5 * _glowAnim.value),
                        blurRadius: 22 * _glowAnim.value,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: _busy
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Icon(Icons.swap_horiz, color: iconColor, size: 30),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
