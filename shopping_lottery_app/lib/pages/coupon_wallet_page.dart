import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ✅ CouponWalletPage（我的優惠券｜完整版｜移除 FirestoreMockService.userCoupons）
/// ------------------------------------------------------------
/// Firestore 讀取路徑（建議）
/// - users/{uid}/coupons/{userCouponId}
///   欄位可包含：
///   - code: String
///   - title: String
///   - description: String
///   - type: String ("percent" / "amount")
///   - value: num
///   - minSpend: num (optional)
///   - isUsed: bool
///   - isActive: bool
///   - expireAt: Timestamp (optional)
///   - createdAt: Timestamp (optional)
///   - usedAt: Timestamp (optional)
///   - couponId: String (optional, 若你是 reference coupons/{couponId})
///
/// ✅ 若你的 users/{uid}/coupons 只存 couponId（沒有 code/title 等），
///   本頁也能顯示（會嘗試去 coupons/{couponId} 補資料；補不到就用 fallback）。
/// ------------------------------------------------------------
class CouponWalletPage extends StatefulWidget {
  const CouponWalletPage({super.key});

  @override
  State<CouponWalletPage> createState() => _CouponWalletPageState();
}

class _CouponWalletPageState extends State<CouponWalletPage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  User? get _user => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> _userCouponsRef(String uid) {
    return _fs.collection('users').doc(uid).collection('coupons');
  }

  DocumentReference<Map<String, dynamic>> _couponRef(String couponId) {
    return _fs.collection('coupons').doc(couponId);
  }

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) {
      return fallback;
    }
    if (v is num) {
      return v;
    }
    if (v is String) {
      return num.tryParse(v) ?? fallback;
    }
    return fallback;
  }

  DateTime? _asDate(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is Timestamp) {
      return v.toDate();
    }
    if (v is DateTime) {
      return v;
    }
    return null;
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) {
      return '';
    }
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  String _money(num v) {
    final n = v.round();
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;
      buf.write(s[i]);
      if (idx > 1 && idx % 3 == 1) {
        buf.write(',');
      }
    }
    return 'NT\$ $buf';
  }

  String _discountText(Map<String, dynamic> d) {
    final type = _s(d['type'], 'amount').toLowerCase();
    final value = _asNum(d['value'], fallback: 0);
    if (type == 'percent') {
      return '${value.toStringAsFixed(0)}% OFF';
    }
    return '${_money(value)} OFF';
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的優惠券'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '可使用'),
            Tab(text: '已使用'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已重新整理')));
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: user == null
          ? _needLogin(context)
          : TabBarView(
              controller: _tab,
              children: [
                _list(uid: user.uid, used: false),
                _list(uid: user.uid, used: true),
              ],
            ),
    );
  }

  Widget _needLogin(BuildContext context) {
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
                    '請先登入才能查看優惠券',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed('/login'),
                    child: const Text('前往登入'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _list({required String uid, required bool used}) {
    // ✅ 為了避免 orderBy 欄位不存在造成 runtime error，這裡不做 orderBy
    // 讀出後在 client side 做排序。
    final stream = _userCouponsRef(uid).limit(300).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _error('讀取失敗：${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        // 分類：可用 / 已用
        final filtered = docs.where((doc) {
          final d = doc.data();
          final isUsed = (d['isUsed'] ?? false) == true;
          final isActive = (d['isActive'] ?? true) == true;

          // 可用頁：未使用 & 啟用（若你不維護 isActive，也不會擋）
          if (!used) {
            return !isUsed && isActive;
          }
          // 已使用頁：已使用
          return isUsed;
        }).toList();

        // 排序：先看 expireAt 最近的在上（可用），已用則 usedAt 新的在上
        filtered.sort((a, b) {
          final da = a.data();
          final db = b.data();

          final ta = used ? _asDate(da['usedAt']) : _asDate(da['expireAt']);
          final tb = used ? _asDate(db['usedAt']) : _asDate(db['expireAt']);

          // null 排最後
          if (ta == null && tb == null) {
            return 0;
          }
          if (ta == null) {
            return 1;
          }
          if (tb == null) {
            return -1;
          }

          return used ? tb.compareTo(ta) : ta.compareTo(tb);
        });

        if (filtered.isEmpty) {
          return _empty(used ? '尚無已使用優惠券' : '目前沒有可使用的優惠券');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final doc = filtered[i];
            final d = doc.data();

            final hasMainFields =
                _s(d['code']).isNotEmpty || _s(d['title']).isNotEmpty;

            // ✅ 若 users/{uid}/coupons 只有 couponId，嘗試去 coupons/{couponId} 補資料
            final couponId = _s(d['couponId']).trim();

            if (!hasMainFields && couponId.isNotEmpty) {
              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: _couponRef(couponId).get(),
                builder: (context, snap2) {
                  final merged = <String, dynamic>{...d};
                  if (snap2.data?.data() != null) {
                    merged.addAll(snap2.data!.data()!);
                  }
                  return _couponTile(
                    uid: uid,
                    docId: doc.id,
                    data: merged,
                    isUsed: (d['isUsed'] ?? false) == true,
                  );
                },
              );
            }

            return _couponTile(
              uid: uid,
              docId: doc.id,
              data: d,
              isUsed: (d['isUsed'] ?? false) == true,
            );
          },
        );
      },
    );
  }

  Widget _couponTile({
    required String uid,
    required String docId,
    required Map<String, dynamic> data,
    required bool isUsed,
  }) {
    final title = _s(data['title'], _s(data['name'], '優惠券'));
    final code = _s(data['code']).trim();
    final desc = _s(data['description'], _s(data['desc'])).trim();

    final minSpend = _asNum(data['minSpend'], fallback: 0);
    final expireAt = _asDate(data['expireAt']);
    final usedAt = _asDate(data['usedAt']);

    final subtitleLines = <String>[];
    if (desc.isNotEmpty) {
      subtitleLines.add(desc);
    }
    if (minSpend > 0) {
      subtitleLines.add('低消：${_money(minSpend)}');
    }
    if (!isUsed && expireAt != null) {
      subtitleLines.add('到期：${_fmtDate(expireAt)}');
    }
    if (isUsed && usedAt != null) {
      subtitleLines.add('使用：${_fmtDate(usedAt)}');
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isUsed
              ? Colors.grey.withValues(alpha: 0.15)
              : Colors.green.withValues(alpha: 0.12),
          child: Icon(
            Icons.confirmation_number_outlined,
            color: isUsed ? Colors.grey : Colors.green.shade700,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: isUsed ? Colors.grey : null,
          ),
        ),
        subtitle: Text(
          [
            _discountText(data),
            if (code.isNotEmpty) '代碼：$code',
            if (subtitleLines.isNotEmpty) subtitleLines.join('  •  '),
          ].where((e) => e.trim().isNotEmpty).join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'detail') {
              await _showDetail(context, data, isUsed: isUsed);
            } else if (v == 'copy') {
              if (code.isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('此優惠券沒有代碼可複製')));
                return;
              }
              await Clipboard.setData(ClipboardData(text: code));
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已複製優惠碼')));
            } else if (v == 'mark_used') {
              await _markUsed(uid: uid, docId: docId, used: true);
            } else if (v == 'mark_unused') {
              await _markUsed(uid: uid, docId: docId, used: false);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'detail', child: Text('查看詳情')),
            const PopupMenuItem(value: 'copy', child: Text('複製代碼')),
            const PopupMenuDivider(),
            if (!isUsed)
              const PopupMenuItem(
                value: 'mark_used',
                child: Text('標記為已使用（測試用）'),
              )
            else
              const PopupMenuItem(
                value: 'mark_unused',
                child: Text('改回未使用（測試用）'),
              ),
          ],
        ),
        onTap: () => _showDetail(context, data, isUsed: isUsed),
      ),
    );
  }

  Future<void> _showDetail(
    BuildContext context,
    Map<String, dynamic> data, {
    required bool isUsed,
  }) async {
    final title = _s(data['title'], _s(data['name'], '優惠券'));
    final code = _s(data['code']).trim();
    final desc = _s(data['description'], _s(data['desc'])).trim();

    final type = _s(data['type'], 'amount');
    final value = _asNum(data['value'], fallback: 0);
    final minSpend = _asNum(data['minSpend'], fallback: 0);

    final expireAt = _asDate(data['expireAt']);
    final usedAt = _asDate(data['usedAt']);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '折扣：${type.toLowerCase() == 'percent' ? '${value.toStringAsFixed(0)}% OFF' : '${_money(value)} OFF'}',
              ),
              if (minSpend > 0) Text('低消：${_money(minSpend)}'),
              if (code.isNotEmpty) Text('代碼：$code'),
              if (!isUsed && expireAt != null) Text('到期：${_fmtDate(expireAt)}'),
              if (isUsed && usedAt != null) Text('使用：${_fmtDate(usedAt)}'),
              const SizedBox(height: 10),
              Text(desc.isEmpty ? '（無描述）' : desc),
              const SizedBox(height: 8),
              Text(
                isUsed ? '狀態：已使用' : '狀態：可使用',
                style: TextStyle(
                  color: isUsed ? Colors.grey : Colors.green.shade700,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
          if (code.isNotEmpty)
            FilledButton.tonal(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已複製優惠碼')));
              },
              child: const Text('複製代碼'),
            ),
        ],
      ),
    );
  }

  Future<void> _markUsed({
    required String uid,
    required String docId,
    required bool used,
  }) async {
    try {
      await _userCouponsRef(uid).doc(docId).set({
        'isUsed': used,
        'usedAt': used ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(used ? '已標記為已使用' : '已改回未使用')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  Widget _empty(String text) {
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
                  const Icon(
                    Icons.local_offer_outlined,
                    size: 56,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    text,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _error(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(text, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
