import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/cart_service.dart';
import 'order_success_page.dart';

class CheckoutFullPage extends StatefulWidget {
  const CheckoutFullPage({super.key});

  @override
  State<CheckoutFullPage> createState() => _CheckoutFullPageState();
}

class _CheckoutFullPageState extends State<CheckoutFullPage> {
  final CartService _cart = CartService.instance;

  // 信用卡欄位控制
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvcCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  // 發票欄位
  String _invoiceType = "二聯式（個人）";
  final _carrierCtrl = TextEditingController();
  final _companyIdCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();

  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final subtotal = _cart.total.toDouble();
    const shippingFee = 80.0;
    final total = subtotal + shippingFee;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
        title: Text(
          "Osmile 結帳流程",
          style: GoogleFonts.notoSansTc(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSection("🧾 訂單摘要", _buildOrderSummary(subtotal, shippingFee, total)),
            const SizedBox(height: 16),
            _buildSection("💳 信用卡付款", _buildCardForm()),
            const SizedBox(height: 16),
            _buildSection("💌 電子發票", _buildInvoiceForm()),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(total),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          content,
        ],
      ),
    );
  }

  // === 訂單摘要 ===
  Widget _buildOrderSummary(double subtotal, double ship, double total) {
    return Column(
      children: [
        _buildSummaryRow("商品金額", "NT \$${subtotal.toStringAsFixed(0)}"),
        _buildSummaryRow("運費", "NT \$${ship.toStringAsFixed(0)}"),
        const Divider(),
        _buildSummaryRow("總金額", "NT \$${total.toStringAsFixed(0)}", bold: true),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  color: bold ? Colors.redAccent : Colors.black,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }

  // === 信用卡區塊 ===
  Widget _buildCardForm() {
    return Column(
      children: [
        TextField(
          controller: _cardNumberCtrl,
          keyboardType: TextInputType.number,
          maxLength: 19,
          decoration: const InputDecoration(
            labelText: "卡號",
            hintText: "1234 5678 9012 3456",
            prefixIcon: Icon(Icons.credit_card, color: Colors.blueAccent),
            border: OutlineInputBorder(),
            counterText: "",
          ),
          onChanged: (v) {
            final cleaned = v.replaceAll(" ", "");
            final spaced = cleaned.replaceAllMapped(RegExp(r".{4}"),
                (match) => "${match.group(0)} ");
            _cardNumberCtrl.value = TextEditingValue(
                text: spaced.trim(),
                selection: TextSelection.collapsed(offset: spaced.length));
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _expiryCtrl,
                maxLength: 5,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "有效期限",
                  hintText: "MM/YY",
                  counterText: "",
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  if (v.length == 2 && !v.contains("/")) {
                    _expiryCtrl.text = "$v/";
                    _expiryCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: _expiryCtrl.text.length));
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _cvcCtrl,
                maxLength: 3,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "安全碼",
                  hintText: "123",
                  counterText: "",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: "持卡人姓名",
            hintText: "CHEN HSIAO MEI",
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  // === 發票區塊 ===
  Widget _buildInvoiceForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RadioListTile<String>(
          title: const Text("二聯式（個人）"),
          value: "二聯式（個人）",
          groupValue: _invoiceType,
          activeColor: Colors.blueAccent,
          onChanged: (v) => setState(() => _invoiceType = v!),
        ),
        RadioListTile<String>(
          title: const Text("三聯式（公司）"),
          value: "三聯式（公司）",
          groupValue: _invoiceType,
          activeColor: Colors.blueAccent,
          onChanged: (v) => setState(() => _invoiceType = v!),
        ),
        const SizedBox(height: 10),
        if (_invoiceType == "二聯式（個人）")
          TextField(
            controller: _carrierCtrl,
            decoration: const InputDecoration(
              labelText: "載具（選填）",
              hintText: "手機條碼 / 自然人憑證代碼",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone_android, color: Colors.blueAccent),
            ),
          ),
        if (_invoiceType == "三聯式（公司）") ...[
          TextField(
            controller: _companyIdCtrl,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: "統一編號",
              counterText: "",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business, color: Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _companyNameCtrl,
            decoration: const InputDecoration(
              labelText: "公司抬頭",
              border: OutlineInputBorder(),
              prefixIcon:
                  Icon(Icons.account_balance, color: Colors.blueAccent),
            ),
          ),
        ],
      ],
    );
  }

  // === 底部按鈕 ===
  Widget _buildBottomBar(double total) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -3))
      ]),
      child: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("NT \$${total.toStringAsFixed(0)}",
                    style: const TextStyle(
                        fontSize: 18,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.lock_outline),
                  label: const Text("確認結帳"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _handleCheckout,
                ),
              ],
            ),
    );
  }

  // === 模擬付款流程 ===
  void _handleCheckout() {
    if (_cardNumberCtrl.text.length < 19 ||
        _expiryCtrl.text.length < 5 ||
        _cvcCtrl.text.length < 3 ||
        _nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("請填寫完整的信用卡資訊")),
      );
      return;
    }

    if (_invoiceType == "三聯式（公司）" &&
        _companyIdCtrl.text.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("統一編號須為 8 碼")),
      );
      return;
    }

    setState(() => _isProcessing = true);
    Timer(const Duration(seconds: 2), () {
      _cart.clear();
      setState(() => _isProcessing = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              OrderSuccessPage(total: _cart.total, itemCount: 1),
        ),
      );
    });
  }
}
