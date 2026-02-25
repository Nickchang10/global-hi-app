import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'points_history_page.dart';
import 'points_mission_page.dart';
import 'points_mall_page.dart';
import 'points_notification_page.dart';

/// ✅ PointsSystemModule（點數系統模組｜修改後完整版）
/// ------------------------------------------------------------
/// ✅ 修正重點：
/// - 移除 FirestoreMockService.userPoints 依賴（解掉 undefined_getter）
/// - 改用 FirebaseAuth + Firestore 讀取 users/{uid}.points
/// - 模組入口：
///   - 點數紀錄 PointsHistoryPage
///   - 任務中心 PointsMissionPage
///   - 點數商城 PointsMallPage
///   - 點數通知 PointsNotificationPage
///
/// 資料：
/// users/{uid}:
///   - points: num
/// ------------------------------------------------------------
class PointsSystemModule extends StatefulWidget {
  const PointsSystemModule({super.key});

  @override
  State<PointsSystemModule> createState() => _PointsSystemModuleState();
}

class _PointsSystemModuleState extends State<PointsSystemModule> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  void _goLogin() {
    Navigator.of(context, rootNavigator: true).pushNamed('/login');
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;

        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (user == null) {
          return _needLoginCard();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _fs.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnap) {
            if (userSnap.hasError) {
              return _errorCard('讀取點數失敗：${userSnap.error}');
            }
            if (!userSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = userSnap.data!.data() ?? {};
            final points = _asNum(data['points'], fallback: 0);

            return _module(points: points);
          },
        );
      },
    );
  }

  Widget _module({required num points}) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.stars_outlined, color: Colors.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '我的點數：$points',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '重新整理',
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              '點數系統',
              style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // ✅ 入口按鈕
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _entryCard(
                  icon: Icons.receipt_long_outlined,
                  title: '點數紀錄',
                  subtitle: '查詢流水 / 統計',
                  onTap: () => _open(const PointsHistoryPage()),
                ),
                _entryCard(
                  icon: Icons.assignment_turned_in_outlined,
                  title: '任務中心',
                  subtitle: '完成任務領點',
                  onTap: () => _open(const PointsMissionPage()),
                ),
                _entryCard(
                  icon: Icons.redeem_outlined,
                  title: '點數商城',
                  subtitle: '用點數兌換好禮',
                  onTap: () => _open(const PointsMallPage()),
                ),
                _entryCard(
                  icon: Icons.notifications_outlined,
                  title: '點數通知',
                  subtitle: '點數相關提醒',
                  onTap: () => _open(const PointsNotificationPage()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blueGrey),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _needLoginCard() {
    return Center(
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
                  const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    '請先登入才能查看點數系統模組',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _goLogin, child: const Text('前往登入')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorCard(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
