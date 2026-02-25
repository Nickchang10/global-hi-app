import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/mission_service.dart';

/// ✅ MissionPage（任務中心｜完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正重點：
/// - uid 改為「可選」(String?)
/// - 若未傳 uid，會自動使用 FirebaseAuth.currentUser?.uid
/// - 未登入：顯示提示並提供前往登入（若你有 /login route）
/// ------------------------------------------------------------
class MissionPage extends StatefulWidget {
  const MissionPage({super.key, this.uid});

  /// ✅ 不再 required，避免外部 MissionPage() 直接呼叫時報錯
  final String? uid;

  @override
  State<MissionPage> createState() => _MissionPageState();
}

class _MissionPageState extends State<MissionPage> {
  final MissionService _svc = MissionService.instance;

  String? _uid;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final uid = widget.uid ?? FirebaseAuth.instance.currentUser?.uid;
    setState(() => _uid = uid);

    if (uid == null) return;

    // 初始化並載入任務
    await _svc.init(uid: uid);
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('任務中心')),
        body: _needLogin(context),
      );
    }

    return AnimatedBuilder(
      animation: _svc,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('任務中心'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _svc.refresh(),
              ),
            ],
          ),
          body: _svc.loading
              ? const Center(child: CircularProgressIndicator())
              : _svc.missions.isEmpty
              ? Center(child: Text(_svc.error ?? '目前沒有任務'))
              : RefreshIndicator(
                  onRefresh: _svc.refresh,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _summaryCards(),
                      const SizedBox(height: 12),
                      ..._svc.missions.map(_missionCard),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _needLogin(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 52, color: Colors.grey),
            const SizedBox(height: 10),
            const Text('請先登入才能查看任務', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                // 若你有 /login route 可以直接用
                Navigator.of(context).pushNamed('/login');
              },
              child: const Text('前往登入'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCards() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _kpiCard(
          title: '已完成',
          value: _svc.completedCount.toString(),
          icon: Icons.check_circle,
        ),
        _kpiCard(
          title: '進行中',
          value: _svc.pendingCount.toString(),
          icon: Icons.timelapse,
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(title, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _missionCard(AppMission m) {
    final p = _svc.progressOf(m.id);

    final target = m.target <= 0 ? 1 : m.target;
    final progress = p.progress.clamp(0, target);
    final percent = target == 0 ? 0.0 : (progress / target).clamp(0.0, 1.0);

    final completed = p.completed;
    final rewardClaimed = p.rewardClaimed;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    m.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _badge(m.category),
              ],
            ),
            const SizedBox(height: 6),
            Text(m.description, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),

            // 進度條
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$progress / $target',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 操作區
            Row(
              children: [
                if (!completed)
                  FilledButton.tonal(
                    onPressed: () => _svc.addProgress(m.id, delta: 1),
                    child: const Text('+1 進度'),
                  )
                else
                  const Chip(
                    label: Text('已完成', style: TextStyle(color: Colors.white)),
                    backgroundColor: Colors.green,
                  ),
                const Spacer(),
                if (m.rewardPoints > 0)
                  Row(
                    children: [
                      Text(
                        '獎勵：${m.rewardPoints} 點',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      if (completed && !rewardClaimed)
                        FilledButton(
                          onPressed: () async {
                            final ok = await _svc.claimReward(m.id);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok ? '已領取獎勵 ✅' : '無法領取（可能已領過）'),
                              ),
                            );
                          },
                          child: const Text('領取'),
                        )
                      else if (rewardClaimed)
                        const Text(
                          '已領取',
                          style: TextStyle(color: Colors.green),
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String category) {
    final text = category.isEmpty ? 'mission' : category;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
      ),
    );
  }
}
