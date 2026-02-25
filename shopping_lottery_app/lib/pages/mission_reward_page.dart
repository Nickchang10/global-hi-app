// lib/pages/mission_reward_page.dart
//
// ✅ MissionRewardPage（最終完整版｜修正 withOpacity deprecated → withValues(alpha: ...)）
// ✅ 修正：control_flow_in_finally（finally 內不再 return）
// ------------------------------------------------------------
// - 顯示任務獎勵 / 點數 / 抽獎券等（示範版 UI，可直接用）
// - 支援：
//   1) 顯示目前點數、抽獎券數
//   2) 獎勵紀錄清單（Firestore：users/{uid}/rewards）
//   3) 一鍵領取（示範：寫入 claimed=true、claimedAt）
// - Analyzer：
//   ✅ withOpacity -> withValues(alpha: ...)
//   ✅ async 後 UI 操作皆先 mounted 檢查（finally 內不 return）
// - Web/App 可用（不使用 dart:io）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MissionRewardPage extends StatefulWidget {
  const MissionRewardPage({super.key});

  @override
  State<MissionRewardPage> createState() => _MissionRewardPageState();
}

class _MissionRewardPageState extends State<MissionRewardPage> {
  static const _brand = Color(0xFF3B82F6);

  bool _loadingClaimAll = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('任務獎勵'),
        actions: [
          if (user != null)
            IconButton(
              tooltip: '重新整理',
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: user == null ? _needLogin() : _body(uid: user.uid),
    );
  }

  Widget _needLogin() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('請先登入才能查看任務獎勵', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamed('/login'),
              child: const Text('前往登入'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body({required String uid}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      children: [
        _summaryCards(uid),
        const SizedBox(height: 12),
        _claimAllBar(uid),
        const SizedBox(height: 10),
        _rewardList(uid),
      ],
    );
  }

  // ------------------------------------------------------------
  // Summary
  // ------------------------------------------------------------
  Widget _summaryCards(String uid) {
    // 假設 users/{uid} 裡有 points / tickets 欄位（沒有也不會爆）
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? const <String, dynamic>{};
        final points = _num(data['points']);
        final tickets = _num(data['lotteryTickets'] ?? data['tickets']);

        return Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.stars_rounded,
                title: '點數',
                value: points.toStringAsFixed(0),
                color: Colors.orangeAccent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                icon: Icons.confirmation_number_outlined,
                title: '抽獎券',
                value: tickets.toStringAsFixed(0),
                color: Colors.purpleAccent,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Claim all
  // ------------------------------------------------------------
  Widget _claimAllBar(String uid) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.card_giftcard, color: _brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '可領取的任務獎勵會顯示在下方清單（示範）',
              style: TextStyle(color: Colors.grey.shade700, height: 1.25),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _loadingClaimAll ? null : () => _claimAll(uid),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _loadingClaimAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '全部領取',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _claimAll(String uid) async {
    if (_loadingClaimAll) return;

    if (mounted) {
      setState(() => _loadingClaimAll = true);
    }

    try {
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('rewards');

      final qs = await col.where('claimed', isEqualTo: false).limit(200).get();
      if (qs.docs.isEmpty) {
        _toast('沒有可領取的獎勵');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final d in qs.docs) {
        batch.update(d.reference, {
          'claimed': true,
          'claimedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      _toast('已全部領取（示範）');
    } catch (e) {
      _toast('領取失敗：$e');
    } finally {
      // ✅ finally 內不使用 return，避免 control_flow_in_finally
      if (mounted) {
        setState(() => _loadingClaimAll = false);
      }
    }
  }

  // ------------------------------------------------------------
  // Reward list
  // ------------------------------------------------------------
  Widget _rewardList(String uid) {
    final q = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('rewards')
        .orderBy('createdAt', descending: true)
        .limit(200);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _empty(
            icon: Icons.error_outline,
            title: '讀取失敗',
            subtitle: snap.error.toString(),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _empty(
            icon: Icons.card_giftcard_outlined,
            title: '目前沒有獎勵紀錄',
            subtitle: '完成任務後會出現在這裡（示範）。',
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _rewardCard(uid: uid, doc: docs[i]),
        );
      },
    );
  }

  Widget _rewardCard({
    required String uid,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final m = doc.data();

    final title = _s(m['title']).trim();
    final desc = _s(m['description']).trim();
    final type = _s(m['type']).trim(); // points/ticket/coupon...
    final amount = _num(m['amount']);
    final claimed = _b(m['claimed'], fallback: false);

    final createdAt = _dt(m['createdAt']);
    final claimedAt = _dt(m['claimedAt']);

    final badgeColor = claimed ? Colors.grey : Colors.green;

    IconData icon;
    Color iconColor;

    switch (type) {
      case 'points':
        icon = Icons.stars_rounded;
        iconColor = Colors.orangeAccent;
        break;
      case 'ticket':
      case 'lottery':
        icon = Icons.confirmation_number_outlined;
        iconColor = Colors.purpleAccent;
        break;
      case 'coupon':
        icon = Icons.local_offer_outlined;
        iconColor = Colors.blueAccent;
        break;
      default:
        icon = Icons.card_giftcard_outlined;
        iconColor = _brand;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.isEmpty ? '任務獎勵' : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          claimed ? '已領取' : '可領取',
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (desc.isNotEmpty)
                    Text(
                      desc,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        height: 1.25,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _pill('數量', amount.toStringAsFixed(0)),
                      _pill('建立', _fmt(createdAt)),
                      if (claimed) _pill('領取', _fmt(claimedAt)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (!claimed)
                        ElevatedButton.icon(
                          onPressed: () => _claimOne(uid, doc.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text(
                            '領取',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text(
                            '已領取',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      const Spacer(),
                      IconButton(
                        tooltip: '刪除',
                        onPressed: () => _deleteReward(uid, doc.id),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$k：$v',
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }

  Future<void> _claimOne(String uid, String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('rewards')
          .doc(docId)
          .update({'claimed': true, 'claimedAt': FieldValue.serverTimestamp()});

      _toast('已領取（示範）');
    } catch (e) {
      _toast('領取失敗：$e');
    }
  }

  Future<void> _deleteReward(String uid, String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('刪除獎勵紀錄'),
          content: const Text('確定要刪除這筆獎勵紀錄嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('rewards')
          .doc(docId)
          .delete();

      _toast('已刪除');
    } catch (e) {
      _toast('刪除失敗：$e');
    }
  }

  Widget _empty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Colors.grey),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // formatting / parse
  // ------------------------------------------------------------
  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    final s = _s(v);
    return double.tryParse(s) ?? 0;
  }

  bool _b(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    final s = _s(v).toLowerCase().trim();
    if (s == 'true') return true;
    if (s == 'false') return false;
    return fallback;
  }

  DateTime? _dt(dynamic v) {
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y/$m/$day $hh:$mm';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  String _s(dynamic v) => v?.toString() ?? '';
}
