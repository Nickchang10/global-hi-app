import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ CardManagementPage（信用卡/付款卡管理｜最終完整版｜可編譯）
/// ------------------------------------------------------------
/// - ✅ prefer_const_constructors：能 const 的 UI 都改 const
/// - ✅ use_build_context_synchronously：
///     bottomSheet async 後使用 sheetContext 前，改用 sheetContext.mounted guard
/// - ✅ DropdownButtonFormField：value 已 deprecated -> 改用 initialValue
/// - ✅ 不依賴第三方套件（web/app 都能跑）
/// - ✅ Firestore（可選）：
///   users/{uid}/payment_cards/{cardId}
///   - holderName (String)
///   - nickname (String)
///   - brand (String) 例如 visa/master/amex/unknown
///   - last4 (String) 例如 "1234"
///   - expMonth (int) 1-12
///   - expYear (int) 例如 2028
///   - isDefault (bool)
///   - createdAt/updatedAt (Timestamp)
///
/// ⚠️ 安全提醒：
/// - 不存完整卡號、也不存 CVC（示範/管理用途）
/// - 真正金流卡片應交給金流 SDK（Stripe/綠界/藍新等）
/// ------------------------------------------------------------
class CardManagementPage extends StatefulWidget {
  const CardManagementPage({super.key});

  @override
  State<CardManagementPage> createState() => _CardManagementPageState();
}

class _CardManagementPageState extends State<CardManagementPage> {
  final _fs = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // -------------------------
  // Firestore refs
  // -------------------------
  CollectionReference<Map<String, dynamic>>? _cardsRef() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return null;
    return _fs.collection('users').doc(uid).collection('payment_cards');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? _cardsStream() {
    final ref = _cardsRef();
    if (ref == null) return null;
    return ref
        .orderBy('isDefault', descending: true)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final uid = _uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('卡片管理'),
        actions: [
          IconButton(
            tooltip: '新增卡片',
            onPressed: uid == null ? null : () => _openEditor(context, cs),
            icon: const Icon(Icons.add_card),
          ),
        ],
      ),
      body: uid == null
          ? _needLogin(cs)
          : Column(
              children: [
                const _IntroCard(),
                Expanded(child: _cardsList(cs)),
              ],
            ),
      floatingActionButton: uid == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(context, cs),
              icon: const Icon(Icons.add),
              label: const Text('新增卡片'),
            ),
    );
  }

  Widget _needLogin(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('請先登入才能管理卡片', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pushNamed('/login'),
              child: const Text('前往登入'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardsList(ColorScheme cs) {
    final stream = _cardsStream();
    if (stream == null) {
      return Center(
        child: Text('尚未登入', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '載入失敗：${snap.error}',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '目前沒有已保存的卡片\n按右下角「新增卡片」建立一張示範卡',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final d = docs[i];
            final m = d.data();

            final card = _CardDoc(
              id: d.id,
              holderName: (m['holderName'] ?? '').toString(),
              nickname: (m['nickname'] ?? '').toString(),
              brand: (m['brand'] ?? 'unknown').toString(),
              last4: (m['last4'] ?? '').toString(),
              expMonth: _asInt(m['expMonth']),
              expYear: _asInt(m['expYear']),
              isDefault: (m['isDefault'] is bool)
                  ? (m['isDefault'] as bool)
                  : false,
            );

            return _cardTile(cs, card);
          },
        );
      },
    );
  }

  Widget _cardTile(ColorScheme cs, _CardDoc card) {
    final brandLabel = _brandLabel(card.brand);
    final title = card.nickname.trim().isNotEmpty
        ? card.nickname.trim()
        : brandLabel;
    final holder = card.holderName.trim().isNotEmpty
        ? card.holderName.trim()
        : '（未填持卡人）';
    final last4 = card.last4.trim().isNotEmpty ? card.last4.trim() : '----';
    final exp = (card.expMonth > 0 && card.expYear > 0)
        ? '${card.expMonth.toString().padLeft(2, '0')}/${(card.expYear % 100).toString().padLeft(2, '0')}'
        : '--/--';

    return Card(
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primary.withValues(alpha: 0.12),
          child: Icon(_brandIcon(card.brand), color: cs.primary),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            if (card.isDefault) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.35),
                  ),
                ),
                child: const Text(
                  '預設',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('持卡人：$holder'),
              const SizedBox(height: 4),
              Text('卡號：•••• •••• •••• $last4   到期：$exp'),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          tooltip: '操作',
          onSelected: (v) async {
            if (v == 'edit') {
              _openEditor(context, cs, existing: card);
            } else if (v == 'default') {
              await _setDefault(card.id);
            } else if (v == 'delete') {
              await _deleteCard(card.id, title);
            }
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'edit', child: Text('編輯')),
            PopupMenuItem(value: 'default', child: Text('設為預設')),
            PopupMenuItem(value: 'delete', child: Text('刪除')),
          ],
        ),
        onTap: () => _openEditor(context, cs, existing: card),
      ),
    );
  }

  // -------------------------
  // Actions
  // -------------------------
  Future<void> _openEditor(
    BuildContext context,
    ColorScheme cs, {
    _CardDoc? existing,
  }) async {
    final ref = _cardsRef();
    if (ref == null) {
      _snack('請先登入');
      return;
    }

    final holderCtrl = TextEditingController(text: existing?.holderName ?? '');
    final nickCtrl = TextEditingController(text: existing?.nickname ?? '');
    final numberCtrl = TextEditingController(
      text: existing?.last4.isNotEmpty == true
          ? '**** **** **** ${existing!.last4}'
          : '',
    );
    final expCtrl = TextEditingController(
      text: (existing != null && existing.expMonth > 0 && existing.expYear > 0)
          ? '${existing.expMonth.toString().padLeft(2, '0')}/${(existing.expYear % 100).toString().padLeft(2, '0')}'
          : '',
    );

    String brand = existing?.brand ?? 'unknown';
    bool isDefault = existing?.isDefault ?? false;

    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> save() async {
              if (saving) return;

              final ok = formKey.currentState?.validate() ?? false;
              if (!ok) return;

              setSheet(() => saving = true);

              try {
                final parsed = _parseExp(expCtrl.text.trim());
                final last4 = _extractLast4(numberCtrl.text.trim());

                final data = <String, dynamic>{
                  'holderName': holderCtrl.text.trim(),
                  'nickname': nickCtrl.text.trim(),
                  'brand': brand,
                  'last4': last4,
                  'expMonth': parsed.$1,
                  'expYear': parsed.$2,
                  'isDefault': isDefault,
                  'updatedAt': FieldValue.serverTimestamp(),
                  if (existing == null)
                    'createdAt': FieldValue.serverTimestamp(),
                };

                if (existing == null) {
                  final doc = await ref.add(data);
                  if (isDefault) {
                    await _unsetOthersDefault(doc.id);
                  }
                } else {
                  await ref.doc(existing.id).set(data, SetOptions(merge: true));
                  if (isDefault) {
                    await _unsetOthersDefault(existing.id);
                  }
                }

                // ✅ use_build_context_synchronously 修正：先檢查 mounted
                if (!mounted) return;
                if (!sheetContext.mounted) return;

                Navigator.of(sheetContext).pop();
                _snack(existing == null ? '已新增卡片' : '已更新卡片');
              } catch (e) {
                _snack('儲存失敗：$e');
              } finally {
                setSheet(() => saving = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 6,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            existing == null ? '新增卡片' : '編輯卡片',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '關閉',
                          onPressed: saving
                              ? null
                              : () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: nickCtrl,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: '卡片名稱（可選）',
                        hintText: '例如：我的主卡 / 公司卡',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    /// ✅ 這裡修正：value deprecated -> initialValue
                    DropdownButtonFormField<String>(
                      initialValue: brand,
                      items: const [
                        DropdownMenuItem(value: 'unknown', child: Text('未知')),
                        DropdownMenuItem(value: 'visa', child: Text('VISA')),
                        DropdownMenuItem(
                          value: 'master',
                          child: Text('Mastercard'),
                        ),
                        DropdownMenuItem(value: 'amex', child: Text('AMEX')),
                        DropdownMenuItem(value: 'jcb', child: Text('JCB')),
                      ],
                      onChanged: saving
                          ? null
                          : (v) {
                              if (v == null) return;
                              setSheet(() => brand = v);
                            },
                      decoration: const InputDecoration(
                        labelText: '卡別',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: holderCtrl,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: '持卡人（可選）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: numberCtrl,
                      enabled: !saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '卡號（只會保存末四碼）',
                        hintText: '例如：4111 1111 1111 1111',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return '請輸入卡號（用於取末四碼）';
                        final last4 = _extractLast4(t);
                        if (last4.length != 4) return '卡號格式不正確（無法取得末四碼）';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: expCtrl,
                      enabled: !saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '到期日（MM/YY）',
                        hintText: '例如：08/28',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return '請輸入到期日';
                        try {
                          final parsed = _parseExp(t);
                          final mm = parsed.$1;
                          final yy = parsed.$2;
                          if (mm < 1 || mm > 12) return '月份需 01~12';
                          if (yy < 2000) return '年份格式不正確';
                          return null;
                        } catch (_) {
                          return '格式需為 MM/YY（例如 08/28）';
                        }
                      },
                    ),

                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: isDefault,
                      onChanged: saving
                          ? null
                          : (v) => setSheet(() => isDefault = v),
                      title: const Text('設為預設卡'),
                      subtitle: const Text('設為預設會取消其他卡的預設狀態'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: saving ? null : save,
                        icon: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(saving ? '儲存中…' : '儲存'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    holderCtrl.dispose();
    nickCtrl.dispose();
    numberCtrl.dispose();
    expCtrl.dispose();
  }

  Future<void> _setDefault(String cardId) async {
    final ref = _cardsRef();
    if (ref == null) return;

    try {
      await ref.doc(cardId).set(<String, dynamic>{
        'isDefault': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _unsetOthersDefault(cardId);
      _snack('已設為預設卡');
    } catch (e) {
      _snack('設定失敗：$e');
    }
  }

  Future<void> _unsetOthersDefault(String keepId) async {
    final ref = _cardsRef();
    if (ref == null) return;

    try {
      final snap = await ref.where('isDefault', isEqualTo: true).get();
      final batch = _fs.batch();
      for (final d in snap.docs) {
        if (d.id == keepId) continue;
        batch.set(d.reference, <String, dynamic>{
          'isDefault': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _deleteCard(String cardId, String title) async {
    final ref = _cardsRef();
    if (ref == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除卡片'),
        content: Text('確定要刪除「$title」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ref.doc(cardId).delete();
      _snack('已刪除');
    } catch (e) {
      _snack('刪除失敗：$e');
    }
  }

  // -------------------------
  // Utils
  // -------------------------
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  /// 解析 MM/YY 或 MM/YYYY
  static (int, int) _parseExp(String s) {
    final t = s.trim();
    final parts = t.split('/');
    if (parts.length != 2) throw const FormatException('bad exp');
    final mm = int.parse(parts[0].trim());
    final yyRaw = parts[1].trim();

    int yyyy;
    if (yyRaw.length == 2) {
      yyyy = 2000 + int.parse(yyRaw);
    } else if (yyRaw.length == 4) {
      yyyy = int.parse(yyRaw);
    } else {
      throw const FormatException('bad year');
    }
    return (mm, yyyy);
  }

  /// 從輸入中抓末四碼（忽略空白/非數字）
  static String _extractLast4(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 4) return '';
    return digits.substring(digits.length - 4);
  }

  static String _brandLabel(String brand) {
    switch (brand) {
      case 'visa':
        return 'VISA';
      case 'master':
        return 'Mastercard';
      case 'amex':
        return 'AMEX';
      case 'jcb':
        return 'JCB';
      default:
        return '卡片';
    }
  }

  static IconData _brandIcon(String brand) {
    switch (brand) {
      case 'visa':
      case 'master':
      case 'amex':
      case 'jcb':
        return Icons.credit_card;
      default:
        return Icons.credit_card;
    }
  }
}

// -------------------------
// Small widgets / models
// -------------------------
class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        elevation: 1,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(child: Icon(Icons.wallet)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '這裡是示範「卡片管理」頁：只保存末四碼與到期日等資訊。\n'
                  '若要正式金流，請改用金流 SDK（Stripe/綠界/藍新等）。',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardDoc {
  final String id;
  final String holderName;
  final String nickname;
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;
  final bool isDefault;

  const _CardDoc({
    required this.id,
    required this.holderName,
    required this.nickname,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    required this.isDefault,
  });
}
