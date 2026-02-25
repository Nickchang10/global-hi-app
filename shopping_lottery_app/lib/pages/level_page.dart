// lib/pages/level_page.dart
//
// ✅ LevelPage（最終完整版｜已修正 use_build_context_synchronously + prefer_const_constructors）
// ------------------------------------------------------------
// - 示範：等級/經驗值/下一級進度
// - 使用 SharedPreferences 模擬存取（你也可以改 Firestore）
// - 所有 async gap 後使用 context 前都先檢查 mounted
//
// 依賴：shared_preferences / flutter/material
//

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LevelPage extends StatefulWidget {
  const LevelPage({super.key});

  @override
  State<LevelPage> createState() => _LevelPageState();
}

class _LevelPageState extends State<LevelPage> {
  bool _loading = true;

  int _level = 1;
  int _xp = 0;

  // 可自行調整每級需要多少 XP
  int _xpNeededForLevel(int level) => 100 + (level - 1) * 50;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final level = prefs.getInt('user_level') ?? 1;
    final xp = prefs.getInt('user_xp') ?? 0;

    if (!mounted) return;
    setState(() {
      _level = level.clamp(1, 999);
      _xp = xp.clamp(0, 1 << 30);
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_level', _level);
    await prefs.setInt('user_xp', _xp);
  }

  Future<void> _addXp(int add) async {
    setState(() => _loading = true);

    // 模擬 async（或你可以換成 Firestore/Cloud）
    await Future<void>.delayed(const Duration(milliseconds: 250));

    int level = _level;
    int xp = _xp + add;

    // 升級邏輯：XP 超過門檻就升級，並扣除門檻
    while (true) {
      final need = _xpNeededForLevel(level);
      if (xp < need) break;
      xp -= need;
      level += 1;
    }

    // 寫入本地（或 Firestore）
    _level = level;
    _xp = xp;
    await _save();

    if (!mounted) return;
    setState(() => _loading = false);

    // ✅ async gap 後再用 context：mounted 檢查已做
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已獲得 +$add XP')));
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重置等級資料'),
        content: const Text('會把等級與 XP 重設為初始值（示範用）。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重置'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_level');
    await prefs.remove('user_xp');

    if (!mounted) return;
    setState(() {
      _level = 1;
      _xp = 0;
      _loading = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已重置')));
  }

  @override
  Widget build(BuildContext context) {
    final need = _xpNeededForLevel(_level);
    final progress = need <= 0 ? 0.0 : (_xp / need).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('我的等級'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '重置（示範）',
            onPressed: _loading ? null : _reset,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _levelCard(
                  level: _level,
                  xp: _xp,
                  need: need,
                  progress: progress,
                ),
                const SizedBox(height: 12),
                _actions(),
                const SizedBox(height: 12),
                _tips(),
              ],
            ),
    );
  }

  Widget _levelCard({
    required int level,
    required int xp,
    required int need,
    required double progress,
  }) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('等級概覽', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  child: Text(
                    'Lv.$level',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '目前等級：Lv.$level',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '本級 XP：$xp / $need',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.black12,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '距離下一級還需要：${(need - xp).clamp(0, 1 << 30)} XP',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '快速增加 XP（示範）',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : () => _addXp(20),
                    child: const Text('+20 XP'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : () => _addXp(50),
                    child: const Text('+50 XP'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : () => _addXp(120),
                    child: const Text('+120 XP'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tips() {
    // ✅ FIX(prefer_const_constructors): 這整段都是 compile-time 常數 → 直接 const
    return const Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('小提醒', style: TextStyle(fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text(
              '• 這頁目前用 SharedPreferences 模擬資料來源，你可改成 Firestore users/{uid}。',
            ),
            Text(
              '• 修正 use_build_context_synchronously 的關鍵：await 之後再用 context 前先 if (!mounted) return;',
            ),
          ],
        ),
      ),
    );
  }
}
