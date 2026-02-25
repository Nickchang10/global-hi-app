import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'points_mission_page.dart';

/// ✅ PointsMissionWithSigninPage（點數任務｜需登入｜修改後完整版）
/// ------------------------------------------------------------
/// ✅ 修正重點：
/// - 解掉「missing_required_argument: uid」
/// - 這頁只負責：
///   - 未登入：顯示提示 + 導去 /login
///   - 已登入：顯示 PointsMissionPage（本身已改成用 FirebaseAuth，不需要 uid）
///
/// 你原本在這頁可能是 push 某個需要 uid 的頁面（例如 DailyMissionPage(uid: ...)）
/// 但因為沒傳 uid 才爆。改成這種包裝器最穩、最好維護。
/// ------------------------------------------------------------
class PointsMissionWithSigninPage extends StatelessWidget {
  const PointsMissionWithSigninPage({super.key});

  void _goLogin(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pushNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;

        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('點數任務（需登入）')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            size: 56,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '請先登入才能查看點數任務',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => _goLogin(context),
                            child: const Text('前往登入'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // ✅ 已登入：直接顯示你已修正版 PointsMissionPage（不需要 uid）
        return const PointsMissionPage();
      },
    );
  }
}
