import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/firestore_mock_service.dart';

/// ✅ SplashPage（修改後完整版｜可編譯）
/// ------------------------------------------------------------
/// - 修正：FirestoreMockService.init 不存在 → 已補齊
/// - 本頁會在啟動時呼叫 init() 以 seed mock data
/// - 初始化後導向 /root（沒有則導向 /）
/// ------------------------------------------------------------
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _loading = true;
  String? _error;

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
      FirestoreMockService? svc;
      try {
        svc = context.read<FirestoreMockService>();
      } catch (_) {
        svc = null; // 沒有 Provider 注入也不崩
      }

      await (svc ?? FirestoreMockService()).init();

      if (!mounted) return;

      // 優先去 /root，沒有再回 /
      try {
        Navigator.of(context).pushReplacementNamed('/root');
      } catch (_) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite, size: 52),
              const SizedBox(height: 12),
              const Text(
                'Osmile',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              if (_loading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 10),
                Text('初始化中…', style: TextStyle(color: Colors.grey.shade700)),
              ] else if (_error != null) ...[
                Text('啟動失敗：$_error', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _boot,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重試'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
