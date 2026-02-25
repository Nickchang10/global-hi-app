import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminCampaignDrawPage extends StatefulWidget {
  const AdminCampaignDrawPage({super.key, required this.campaignId});

  final String campaignId;

  @override
  State<AdminCampaignDrawPage> createState() => _AdminCampaignDrawPageState();
}

class _AdminCampaignDrawPageState extends State<AdminCampaignDrawPage> {
  DocumentReference<Map<String, dynamic>> get _campaignRef =>
      FirebaseFirestore.instance.collection('campaigns').doc(widget.campaignId);

  CollectionReference<Map<String, dynamic>> get _participantsRef =>
      _campaignRef.collection('participants');

  CollectionReference<Map<String, dynamic>> get _winnersRef =>
      _campaignRef.collection('winners');

  bool _busy = false;

  Future<int> _countDocs(CollectionReference<Map<String, dynamic>> ref) async {
    final snap = await ref.get();
    return snap.size;
  }

  Future<void> _drawWinners({
    required int count,
    bool allowRepeatAcrossRuns = false,
  }) async {
    if (count <= 0) return;

    setState(() => _busy = true);
    try {
      // 1) 取所有參加者
      final participantsSnap = await _participantsRef.get();
      final participants = participantsSnap.docs;

      if (participants.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('目前沒有參加者')));
        return;
      }

      // 2) 取現有得獎者（避免重複）
      final winnersSnap = await _winnersRef.get();
      final winnerIds = winnersSnap.docs.map((d) => d.id).toSet();

      final pool = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final p in participants) {
        if (allowRepeatAcrossRuns || !winnerIds.contains(p.id)) {
          pool.add(p);
        }
      }

      if (pool.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('沒有可抽選的名單（可能都已得獎）')));
        return;
      }

      final drawCount = min(count, pool.length);

      // 3) 隨機抽
      pool.shuffle(Random());
      final picked = pool.take(drawCount).toList();

      // 4) 寫入 winners（用 batch）
      final batch = FirebaseFirestore.instance.batch();
      for (final p in picked) {
        final uid = p.id;
        final m = p.data();

        batch.set(_winnersRef.doc(uid), <String, dynamic>{
          'uid': uid,
          'displayName': (m['displayName'] ?? m['name'] ?? '').toString(),
          'email': (m['email'] ?? '').toString(),
          'phone': (m['phone'] ?? '').toString(),
          'drawnAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 5) 更新 campaign 概覽
      batch.set(_campaignRef, <String, dynamic>{
        'lastDrawAt': FieldValue.serverTimestamp(),
        'winnersCount': FieldValue.increment(picked.length),
      }, SetOptions(merge: true));

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已抽出 $drawCount 位得獎者')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('抽獎失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearWinners() async {
    setState(() => _busy = true);
    try {
      final snap = await _winnersRef.get();
      final docs = snap.docs;
      if (docs.isEmpty) return;

      // 分批刪除（避免 500 限制）
      const chunkSize = 400;
      for (int i = 0; i < docs.length; i += chunkSize) {
        final chunk = docs.sublist(i, (i + chunkSize).clamp(0, docs.length));
        final batch = FirebaseFirestore.instance.batch();
        for (final d in chunk) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }

      await _campaignRef.set(<String, dynamic>{
        'winnersCount': 0,
        'lastDrawAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已清空得獎者名單')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('清空失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDrawDialog(int suggested) async {
    final c = TextEditingController(text: suggested.toString());
    bool allowRepeat = false;

    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('抽獎設定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: c,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '抽出人數',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: allowRepeat,
                  onChanged: (v) => allowRepeat = (v == true),
                ),
                const Expanded(child: Text('允許重複得獎（跨次抽獎也可能再中）')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(c.text.trim()) ?? 0;
              Navigator.pop(context, n);
            },
            child: const Text('開始抽獎'),
          ),
        ],
      ),
    );

    if (result == null) return;
    final n = result;
    if (n <= 0) return;

    await _drawWinners(count: n, allowRepeatAcrossRuns: allowRepeat);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _campaignRef.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('活動抽獎')),
            body: Center(
              child: Text(
                '讀取活動失敗：${snap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('活動抽獎')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snap.data!.data() ?? <String, dynamic>{};
        final title = (data['title'] ?? data['name'] ?? '活動抽獎').toString();
        final status = (data['status'] ?? 'draft').toString();
        final defaultWinnerCount = _toInt(data['winnerCount'], fallback: 1);

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              IconButton(
                tooltip: '抽獎',
                onPressed: _busy
                    ? null
                    : () => _openDrawDialog(defaultWinnerCount),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.casino),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: '清空得獎者',
                onPressed: _busy ? null : _clearWinners,
                icon: const Icon(Icons.delete_sweep),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _InfoCard(
                campaignId: widget.campaignId,
                status: status,
                winnerCount: defaultWinnerCount,
              ),
              const SizedBox(height: 12),
              FutureBuilder<int>(
                future: _countDocs(_participantsRef),
                builder: (context, s) => _StatTile(
                  title: '參加者數',
                  value: s.data?.toString() ?? '—',
                  icon: Icons.people,
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<int>(
                future: _countDocs(_winnersRef),
                builder: (context, s) => _StatTile(
                  title: '得獎者數',
                  value: s.data?.toString() ?? '—',
                  icon: Icons.emoji_events,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '得獎者名單',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _WinnersList(winnersRef: _winnersRef),
              const SizedBox(height: 80),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _busy ? null : () => _openDrawDialog(defaultWinnerCount),
            icon: const Icon(Icons.casino),
            label: const Text('抽獎'),
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.campaignId,
    required this.status,
    required this.winnerCount,
  });

  final String campaignId;
  final String status;
  final int winnerCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('活動資訊', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  avatar: const Icon(Icons.key, size: 16),
                  label: Text(campaignId),
                ),
                Chip(
                  avatar: const Icon(Icons.flag, size: 16),
                  label: Text(status),
                ),
                Chip(
                  avatar: const Icon(Icons.confirmation_number, size: 16),
                  label: Text('預設抽出：$winnerCount'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
    );
  }
}

class _WinnersList extends StatelessWidget {
  const _WinnersList({required this.winnersRef});

  final CollectionReference<Map<String, dynamic>> winnersRef;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: winnersRef
          .orderBy('drawnAt', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            '讀取得獎者失敗：${snap.error}',
            style: const TextStyle(color: Colors.red),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          );
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Text('尚無得獎者', style: TextStyle(color: Colors.grey[700]));
        }

        return Card(
          elevation: 0.6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final m = d.data();
              final name = (m['displayName'] ?? '').toString().trim();
              final email = (m['email'] ?? '').toString().trim();
              final phone = (m['phone'] ?? '').toString().trim();

              return ListTile(
                leading: const Icon(Icons.emoji_events),
                title: Text(
                  name.isEmpty ? d.id : name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  [email, phone].where((e) => e.isNotEmpty).join(' · '),
                ),
                trailing: Text(
                  d.id,
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

int _toInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}
