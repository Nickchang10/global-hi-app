import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ RewardPage（獎勵 / 兌換｜修改後完整版）
/// ------------------------------------------------------------
/// ✅ 修正重點：
/// - ✅ 修正 curly_braces_in_flow_control_structures：所有 if 單行改用 { } 區塊
/// - 修正 Firestore/Map 動態取值 Object? 直接當 String 的錯（Object? -> String）
/// - 不依賴 FirestoreMockService / FirestoreService
/// - 使用 FirebaseAuth + Firestore：rewards / users / user_rewards
///
/// 建議 Firestore 結構：
/// rewards/{rid}
///   - title: String
///   - description: String (optional)
///   - imageUrl: String (optional)
///   - pointsCost: num (optional, default 0)
///   - stock: num (optional, default -1 表示不限量)
///   - isActive: bool (optional, default true)
///   - sort: num (optional)
///   - createdAt: Timestamp (optional)
///
/// users/{uid}
///   - points: num (optional, default 0)
///
/// user_rewards/{docId}
///   - uid: String
///   - rewardId: String
///   - title: String
///   - pointsCost: num
///   - claimedAt: Timestamp
/// ------------------------------------------------------------
class RewardPage extends StatefulWidget {
  const RewardPage({super.key});

  @override
  State<RewardPage> createState() => _RewardPageState();
}

class _RewardPageState extends State<RewardPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _onlyActive = true;
  bool _showMine = false;
  bool _processing = false;

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  void _goLogin() {
    Navigator.of(context, rootNavigator: true).pushNamed('/login');
  }

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _fs.collection('users').doc(uid);

  Query<Map<String, dynamic>> _rewardsQueryPrimary() {
    Query<Map<String, dynamic>> q = _fs.collection('rewards');
    if (_onlyActive) {
      q = q.where('isActive', isEqualTo: true);
    }
    q = q.orderBy('sort', descending: false).limit(200);
    return q;
  }

  Query<Map<String, dynamic>> _rewardsQueryFallback() {
    Query<Map<String, dynamic>> q = _fs.collection('rewards');
    if (_onlyActive) {
      q = q.where('isActive', isEqualTo: true);
    }
    q = q.orderBy(FieldPath.documentId, descending: true).limit(200);
    return q;
  }

  Query<Map<String, dynamic>> _myRewardsQuery(String uid) {
    return _fs
        .collection('user_rewards')
        .where('uid', isEqualTo: uid)
        .orderBy('claimedAt', descending: true)
        .limit(100);
  }

  Future<void> _claimReward({
    required User user,
    required String rewardId,
    required Map<String, dynamic> rewardData,
  }) async {
    if (_processing) {
      return;
    }

    final title = _s(rewardData['title'], '獎勵');
    final cost = _asNum(rewardData['pointsCost'], fallback: 0);
    final stock = _asNum(rewardData['stock'], fallback: -1); // -1 = unlimited

    setState(() => _processing = true);

    try {
      await _fs.runTransaction((tx) async {
        final userRef = _userRef(user.uid);
        final rewardRef = _fs.collection('rewards').doc(rewardId);

        final userSnap = await tx.get(userRef);
        final rewardSnap = await tx.get(rewardRef);

        final userData = userSnap.data() ?? <String, dynamic>{};
        final rData = rewardSnap.data() ?? <String, dynamic>{};

        final userPoints = _asNum(userData['points'], fallback: 0);
        final realCost = _asNum(rData['pointsCost'], fallback: cost);

        // stock 檢查
        final realStock = _asNum(
          rData['stock'],
          fallback: stock,
        ); // -1 = unlimited
        if (realStock == 0) {
          throw Exception('此獎勵已兌換完畢');
        }

        if (userPoints < realCost) {
          throw Exception('點數不足（目前 $userPoints，需要 $realCost）');
        }

        // 扣點
        tx.set(userRef, {
          'points': userPoints - realCost,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 扣庫存（若有限量）
        if (realStock > 0) {
          tx.set(rewardRef, {
            'stock': realStock - 1,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        // 寫入 user_rewards
        final urRef = _fs.collection('user_rewards').doc();
        tx.set(urRef, {
          'uid': user.uid,
          'rewardId': rewardId,
          'title': _s(rData['title'], title),
          'pointsCost': realCost,
          'claimedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ 已兌換：$title')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('兌換失敗：$e')));
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;

        return Scaffold(
          appBar: AppBar(
            title: Text(_showMine ? '我的獎勵' : '獎勵兌換'),
            actions: [
              IconButton(
                tooltip: '切換',
                onPressed: () => setState(() => _showMine = !_showMine),
                icon: Icon(
                  _showMine
                      ? Icons.redeem_outlined
                      : Icons.inventory_2_outlined,
                ),
              ),
              IconButton(
                tooltip: '重新整理',
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: Column(
            children: [
              _topBar(user),
              const Divider(height: 1),
              Expanded(
                child: _showMine
                    ? (user == null
                          ? _needLoginBox()
                          : _myRewardsList(user.uid))
                    : _rewardsList(user),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _topBar(User? user) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          FilterChip(
            label: const Text('只看上架'),
            selected: _onlyActive,
            onSelected: (v) => setState(() => _onlyActive = v),
          ),
          const SizedBox(width: 10),
          if (!_showMine && _processing)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          const Spacer(),
          if (user == null)
            TextButton.icon(
              onPressed: _goLogin,
              icon: const Icon(Icons.login),
              label: const Text('登入'),
            )
          else
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _userRef(user.uid).snapshots(),
              builder: (context, snap) {
                final pts = _asNum(snap.data?.data()?['points'], fallback: 0);
                return Chip(
                  label: Text('點數：$pts'),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _needLoginBox() {
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
                    '請先登入',
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

  Widget _rewardsList(User? user) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _rewardsQueryPrimary().snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _rewardsQueryFallback().snapshots(),
            builder: (context, snap2) {
              if (snap2.hasError) {
                return _errorBox('讀取失敗：\n${snap2.error}');
              }
              if (!snap2.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _renderRewards(
                user,
                snap2.data!.docs,
                note: '（已改用 docId 排序）',
              );
            },
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _renderRewards(user, snap.data!.docs);
      },
    );
  }

  Widget _renderRewards(
    User? user,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    String note = '',
  }) {
    if (docs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(note, style: const TextStyle(color: Colors.grey)),
            ),
          _empty('目前沒有可兌換的獎勵'),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: docs.length + (note.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (note.isNotEmpty && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(note, style: const TextStyle(color: Colors.grey)),
          );
        }

        final i = note.isNotEmpty ? index - 1 : index;
        final doc = docs[i];
        final d = doc.data();

        final title = _s(d['title'], '獎勵');
        final desc = _s(d['description'], '');
        final imageUrl = _s(d['imageUrl'], '');
        final cost = _asNum(d['pointsCost'], fallback: 0);
        final stock = _asNum(d['stock'], fallback: -1);

        final stockText = stock < 0 ? '不限量' : '剩餘 $stock';

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: _thumb(imageUrl, title),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              [if (desc.isNotEmpty) desc, '點數：$cost', stockText].join('  •  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: FilledButton.tonal(
              onPressed: (user == null || _processing || stock == 0)
                  ? null
                  : () => _claimReward(
                      user: user,
                      rewardId: doc.id,
                      rewardData: d,
                    ),
              child: Text(user == null ? '登入後兌換' : '兌換'),
            ),
            onTap: () => _showDetail(doc.id, d),
          ),
        );
      },
    );
  }

  Widget _myRewardsList(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _myRewardsQuery(uid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _errorBox('讀取我的獎勵失敗：\n${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [_empty('你還沒有兌換任何獎勵')],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final d = doc.data();

            final title = _s(d['title'], '獎勵');
            final rewardId = _s(d['rewardId'], '');
            final cost = _asNum(d['pointsCost'], fallback: 0);

            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.redeem_outlined),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text('點數：$cost  •  rewardId：$rewardId'),
              ),
            );
          },
        );
      },
    );
  }

  void _showDetail(String id, Map<String, dynamic> d) {
    final title = _s(d['title'], '獎勵');
    final desc = _s(d['description'], '');
    final imageUrl = _s(d['imageUrl'], '');
    final cost = _asNum(d['pointsCost'], fallback: 0);
    final stock = _asNum(d['stock'], fallback: -1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 14,
              bottom: 16 + bottomInset,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  if (imageUrl.isNotEmpty) const SizedBox(height: 12),
                  _detailRow('獎勵ID', id),
                  _detailRow('點數需求', '$cost'),
                  _detailRow('庫存', stock < 0 ? '不限量' : '$stock'),
                  if (desc.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      '說明',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(desc, style: const TextStyle(color: Colors.blueGrey)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('關閉'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _thumb(String url, String title) {
    if (url.isEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        child: Text(title.isNotEmpty ? title.substring(0, 1) : '?'),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => CircleAvatar(
          backgroundColor: Colors.grey.shade200,
          child: Text(title.isNotEmpty ? title.substring(0, 1) : '?'),
        ),
      ),
    );
  }

  Widget _detailRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(k, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _empty(String text) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
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
