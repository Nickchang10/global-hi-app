import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/shop_scaffold.dart';
import '../router_adapter.dart';

enum PaymentMethod { credit, convenience, atm }

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  PaymentMethod _method = PaymentMethod.credit;
  bool _processing = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final cart = appState.cart;
    final total = appState.getTotalPrice();

    if (cart.isEmpty) {
      return ShopScaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('購物車是空的', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('返回首頁'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ShopScaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('結帳', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),

              _SectionCard(
                title: '訂單摘要',
                child: Column(
                  children: [
                    ...cart.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.product.name} x ${item.quantity}',
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(formatTwd(item.product.price * item.quantity), style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        )),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('總計', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(formatTwd(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.red)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _SectionCard(
                title: '收件資訊',
                child: Column(
                  children: [
                    _LabeledField(label: '收件人姓名', controller: _nameCtrl, hintText: '請輸入姓名'),
                    const SizedBox(height: 12),
                    _LabeledField(label: '聯絡電話', controller: _phoneCtrl, hintText: '請輸入手機號碼', keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    _LabeledField(label: '配送地址', controller: _addressCtrl, hintText: '請輸入完整地址', maxLines: 3),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _SectionCard(
                title: '付款方式',
                child: Column(
                  children: [
                    _RadioTile(
                      value: PaymentMethod.credit,
                      groupValue: _method,
                      icon: Icons.credit_card,
                      title: '信用卡 / 金融卡',
                      onChanged: (v) => setState(() => _method = v),
                    ),
                    const SizedBox(height: 10),
                    _RadioTile(
                      value: PaymentMethod.convenience,
                      groupValue: _method,
                      icon: Icons.account_balance_wallet_outlined,
                      title: '超商代碼繳費',
                      onChanged: (v) => setState(() => _method = v),
                    ),
                    const SizedBox(height: 10),
                    _RadioTile(
                      value: PaymentMethod.atm,
                      groupValue: _method,
                      icon: Icons.account_balance_outlined,
                      title: 'ATM 轉帳',
                      onChanged: (v) => setState(() => _method = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _SectionCard(
                title: null,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('應付金額', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(formatTwd(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: _processing ? null : () => _pay(context),
                      child: SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: Center(
                          child: _processing
                              ? const Text('處理中...')
                              : const Text('確認付款', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pay(BuildContext context) async {
    setState(() => _processing = true);

    await Future<void>.delayed(const Duration(seconds: 2));

    final state = context.read<AppState>();
    final total = state.getTotalPrice();
    final items = List.of(state.cart);

    state.createOrder(items, total);
    state.clearCart();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('付款成功！您可以到訂單記錄中撰寫評論')));
    context.go('/orders');

    setState(() => _processing = false);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.title,
  });

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

class _RadioTile extends StatelessWidget {
  const _RadioTile({
    required this.value,
    required this.groupValue,
    required this.icon,
    required this.title,
    required this.onChanged,
  });

  final PaymentMethod value;
  final PaymentMethod groupValue;
  final IconData icon;
  final String title;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Radio<PaymentMethod>(
              value: value,
              groupValue: groupValue,
              onChanged: (v) => v == null ? null : onChanged(v),
            ),
            Icon(icon, color: Colors.black54),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
}
