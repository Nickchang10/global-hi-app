import 'dart:async';
import 'package:flutter/material.dart';

/// ✅ AppStartupGate（啟動閘門｜通用版）
/// ------------------------------------------------------------
/// 用途：
/// - 在進入主要頁面前先做初始化（可選）
/// - 初始化中顯示 splash / loading
/// - 初始化失敗顯示錯誤畫面並可重試
///
/// 你在 shop_home_dynamic_page.dart import 的相對路徑：
///   ../startup/app_startup_gate.dart
/// 對應到實際檔案位置應為：
///   lib/pages/shop/startup/app_startup_gate.dart
/// ------------------------------------------------------------
class AppStartupGate extends StatefulWidget {
  const AppStartupGate({
    super.key,
    required this.child,
    this.initializer,
    this.splash,
    this.backgroundColor = const Color(0xFFF6F8FB),
    this.title = 'Osmile',
  });

  /// 初始化完成後要顯示的主內容
  final Widget child;

  /// 初始化流程（可不傳：直接放行）
  final Future<void> Function()? initializer;

  /// 自訂啟動畫面（可不傳：使用預設 loading）
  final Widget? splash;

  final Color backgroundColor;
  final String title;

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 沒有 initializer 就直接放行（但仍給一個 frame，避免 UI 閃爍）
      if (widget.initializer != null) {
        await widget.initializer!.call();
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.splash ?? _defaultSplash();
    }

    if (_error != null) {
      return _errorView(_error!);
    }

    return widget.child;
  }

  Widget _defaultSplash() {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.hourglass_top_rounded,
                    size: 44,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('初始化中…', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 14),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView(Object e) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 28),
                      SizedBox(width: 8),
                      Text(
                        '初始化失敗',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    e.toString(),
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _boot,
                          child: const Text('重試'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
