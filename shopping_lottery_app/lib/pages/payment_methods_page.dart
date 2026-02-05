// lib/pages/payment_methods_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentMethodsPage extends StatefulWidget {
  /// 允許你從 main.dart 傳入 mock 資料：
  /// PaymentMethodsPage(cards: FirestoreMockService.demoCards())
  final List<dynamic> cards;

  /// 若為 true：點選卡片會 pop 回上一頁（回傳選到的卡 Map）
  final bool selectionMode;

  const PaymentMethodsPage({
    super.key,
    required this.cards,
    this.selectionMode = false,
  });

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _primary = Colors.blueAccent;
  static const Color _brand = Colors.orangeAccent;

  static const String _kPrefsCards = 'payment_cards_v1';

  final List<_CardItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // -------------------------
  // Persistence
  // -------------------------
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsCards);

      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _items
            ..clear()
            ..addAll(decoded
                .whereType<Map>()
                .map((m) => _CardItem.fromJson(m.cast<String, dynamic>())));
        }
      } else {
        final parsed = _parseIncoming(widget.cards);
        _items
          ..clear()
          ..addAll(parsed);

        if (_items.isNotEmpty && !_items.any((e) => e.isDefault)) {
          _items[0] = _items[0].copyWith(isDefault: true);
        }
        await _persist();
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_CardItem> _parseIncoming(List<dynamic> raw) {
    final out = <_CardItem>[];
    for (final x in raw) {
      if (x is _CardItem) {
        out.add(x);
      } else if (x is Map) {
        out.add(_CardItem.fromJson(x.cast<String, dynamic>()));
      } else if (x is Map<String, dynamic>) {
        out.add(_CardItem.fromJson(x));
      }
    }

    if (out.isEmpty) {
      out.add(
        _CardItem(
          id: _id(),
          brand: 'VISA',
          holder: 'DemoUser',
          last4: '4242',
          expMonth: 12,
          expYear: DateTime.now().year + 2,
          isDefault: true,
        ),
      );
    }
    return out;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kPrefsCards,
        jsonEncode(_items.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  // -------------------------
  // Helpers
  // -------------------------
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _id() => 'card_${DateTime.now().millisecondsSinceEpoch}_${_items.length}';

  void _select(_CardItem item) {
    if (!widget.selectionMode) return;
    Navigator.pop(context, item.toJson());
  }

  Future<void> _openEditor({_CardItem? editing}) async {
    final result = await showModalBottomSheet<_CardItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _CardEditorSheet(
        primary: _primary,
        brand: _brand,
        initial: editing,
      ),
    );

    if (result == null) return;

    setState(() {
      if (editing == null) {
        _items.insert(0, result.copyWith(id: _id()));
      } else {
        final idx = _items.indexWhere((e) => e.id == editing.id);
        if (idx != -1) {
          _items[idx] = result.copyWith(id: editing.id, isDefault: _items[idx].isDefault);
        }
      }

      if (_items.length == 1) {
        _items[0] = _items[0].copyWith(isDefault: true);
      }
    });

    await _persist();
    _toast(editing == null ? '已新增付款方式' : '已更新付款方式');
  }

  void _setDefault(String id) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    setState(() {
      for (int i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(isDefault: _items[i].id == id);
      }
    });
    await _persist();
    _toast('已設為預設付款方式');
  }

  Future<void> _delete(String id) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除付款方式'),
        content: const Text('確定要刪除這張卡片嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _items.removeWhere((e) => e.id == id));
    if (_items.isNotEmpty && !_items.any((e) => e.isDefault)) {
      _items[0] = _items[0].copyWith(isDefault: true);
    }
    await _persist();
    _toast('已刪除');
  }

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(widget.selectionMode ? '選擇付款方式' : '付款方式',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.8,
        actions: [
          IconButton(
            tooltip: '新增',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_card_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _EmptyState(
                  icon: Icons.credit_card_off_outlined,
                  title: '尚無付款方式',
                  subtitle: '新增一張卡片，結帳更快速。',
                  buttonText: '新增卡片',
                  onPressed: () => _openEditor(),
                  primary: _primary,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                  children: [
                    if (widget.selectionMode)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: _primary.withOpacity(0.9)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '點選卡片即可帶回結帳頁（示範）。',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    for (final c in _items) ...[
                      _CardTile(
                        item: c,
                        primary: _primary,
                        brand: _brand,
                        onTap: () => _select(c),
                        onSetDefault: () => _setDefault(c.id),
                        onEdit: () => _openEditor(editing: c),
                        onDelete: () => _delete(c.id),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 70),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('新增卡片', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

// ======================================================
// Widgets
// ======================================================

class _CardTile extends StatelessWidget {
  final _CardItem item;
  final Color primary;
  final Color brand;
  final VoidCallback onTap;
  final VoidCallback onSetDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CardTile({
    required this.item,
    required this.primary,
    required this.brand,
    required this.onTap,
    required this.onSetDefault,
    required this.onEdit,
    required this.onDelete,
  });

  IconData _brandIcon(String b) {
    final t = b.toUpperCase();
    if (t.contains('VISA')) return Icons.credit_card;
    if (t.contains('MASTER')) return Icons.payments_outlined;
    if (t.contains('JCB')) return Icons.credit_score_outlined;
    if (t.contains('AMEX')) return Icons.account_balance_wallet_outlined;
    return Icons.credit_card_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final exp = '${item.expMonth.toString().padLeft(2, '0')}/${item.expYear.toString().substring(item.expYear.toString().length - 2)}';
    final masked = '••••  ••••  ••••  ${item.last4}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_brandIcon(item.brand), color: primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.brand, style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(masked, style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('到期：$exp · 持卡人：${item.holder}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (item.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: brand.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: brand.withOpacity(0.25)),
                      ),
                      child: Text('預設', style: TextStyle(color: brand, fontWeight: FontWeight.w900)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: item.isDefault ? null : onSetDefault,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('設為預設'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(color: primary.withOpacity(0.35)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '編輯',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: '刪除',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardEditorSheet extends StatefulWidget {
  final Color primary;
  final Color brand;
  final _CardItem? initial;

  const _CardEditorSheet({
    required this.primary,
    required this.brand,
    required this.initial,
  });

  @override
  State<_CardEditorSheet> createState() => _CardEditorSheetState();
}

class _CardEditorSheetState extends State<_CardEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _number;
  late final TextEditingController _holder;
  late final TextEditingController _expMonth;
  late final TextEditingController _expYear;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _number = TextEditingController(text: i == null ? '' : '**** **** **** ${i.last4}');
    _holder = TextEditingController(text: i?.holder ?? '');
    _expMonth = TextEditingController(text: (i?.expMonth ?? '').toString());
    _expYear = TextEditingController(text: (i?.expYear ?? '').toString());
  }

  @override
  void dispose() {
    _number.dispose();
    _holder.dispose();
    _expMonth.dispose();
    _expYear.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
    );
  }

  String _detectBrand(String digits) {
    if (digits.isEmpty) return 'CARD';
    if (digits.startsWith('4')) return 'VISA';
    if (digits.startsWith('5')) return 'MASTERCARD';
    if (digits.startsWith('34') || digits.startsWith('37')) return 'AMEX';
    if (digits.startsWith('35')) return 'JCB';
    return 'CARD';
  }

  String _onlyDigits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + inset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.initial == null ? '新增卡片' : '編輯卡片',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _number,
                keyboardType: TextInputType.number,
                decoration: _dec('卡號（示範：只會保存末四碼）', Icons.credit_card_outlined),
                validator: (v) {
                  final digits = _onlyDigits(v ?? '');
                  // 編輯時可能是 ****，允許只填末四碼或完整卡號
                  if (digits.length < 4) return '請輸入至少末四碼';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _holder,
                decoration: _dec('持卡人姓名', Icons.person_outline),
                validator: (v) => (v == null || v.trim().isEmpty) ? '請輸入持卡人' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expMonth,
                      keyboardType: TextInputType.number,
                      decoration: _dec('月 MM', Icons.calendar_month_outlined),
                      validator: (v) {
                        final m = int.tryParse((v ?? '').trim());
                        if (m == null || m < 1 || m > 12) return '1~12';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _expYear,
                      keyboardType: TextInputType.number,
                      decoration: _dec('年 YYYY', Icons.event_outlined),
                      validator: (v) {
                        final y = int.tryParse((v ?? '').trim());
                        if (y == null || y < 2000) return '年份不正確';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (!(_formKey.currentState?.validate() ?? false)) return;

                    final digits = _onlyDigits(_number.text);
                    final last4 = digits.substring(digits.length - 4);
                    final brand = _detectBrand(digits);

                    final item = _CardItem(
                      id: widget.initial?.id ?? 'temp',
                      brand: brand,
                      holder: _holder.text.trim(),
                      last4: last4,
                      expMonth: int.parse(_expMonth.text.trim()),
                      expYear: int.parse(_expYear.text.trim()),
                      isDefault: widget.initial?.isDefault ?? false,
                    );

                    Navigator.pop(context, item);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('儲存', style: TextStyle(fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '安全提示：此示範 App 僅保存卡片末四碼與到期日，不保存完整卡號與 CVV。',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;
  final Color primary;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(18),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// Model
// ======================================================

class _CardItem {
  final String id;
  final String brand;
  final String holder;
  final String last4;
  final int expMonth;
  final int expYear;
  final bool isDefault;

  _CardItem({
    required this.id,
    required this.brand,
    required this.holder,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    required this.isDefault,
  });

  _CardItem copyWith({
    String? id,
    String? brand,
    String? holder,
    String? last4,
    int? expMonth,
    int? expYear,
    bool? isDefault,
  }) {
    return _CardItem(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      holder: holder ?? this.holder,
      last4: last4 ?? this.last4,
      expMonth: expMonth ?? this.expMonth,
      expYear: expYear ?? this.expYear,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'holder': holder,
        'last4': last4,
        'expMonth': expMonth,
        'expYear': expYear,
        'isDefault': isDefault,
      };

  factory _CardItem.fromJson(Map<String, dynamic> m) {
    // 兼容常見 key（mock 可能叫 numberLast4/expiryMonth/expiryYear/default）
    final last4 = (m['last4'] ?? m['numberLast4'] ?? m['last'] ?? '0000').toString();
    final expMonth = (m['expMonth'] ?? m['expiryMonth'] ?? 12);
    final expYear = (m['expYear'] ?? m['expiryYear'] ?? (DateTime.now().year + 1));

    return _CardItem(
      id: (m['id'] ?? 'card_${DateTime.now().millisecondsSinceEpoch}').toString(),
      brand: (m['brand'] ?? m['type'] ?? 'CARD').toString(),
      holder: (m['holder'] ?? m['name'] ?? 'Card Holder').toString(),
      last4: last4.length >= 4 ? last4.substring(last4.length - 4) : last4.padLeft(4, '0'),
      expMonth: (expMonth is int) ? expMonth : int.tryParse(expMonth.toString()) ?? 12,
      expYear: (expYear is int) ? expYear : int.tryParse(expYear.toString()) ?? (DateTime.now().year + 1),
      isDefault: (m['isDefault'] == true) || (m['default'] == true),
    );
  }
}
