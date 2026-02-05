import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'order_success_page.dart';

class PaymentCreditCardPage extends StatefulWidget {
  final double amount;
  const PaymentCreditCardPage({super.key, required this.amount});

  @override
  State<PaymentCreditCardPage> createState() => _PaymentCreditCardPageState();
}

class _PaymentCreditCardPageState extends State<PaymentCreditCardPage> {
  final _formKey = GlobalKey<FormState>();

  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isProcessing = false;
  String _cardBrand = "Visa";

  void _detectCardBrand(String input) {
    if (input.startsWith("5")) {
      setState(() => _cardBrand = "MasterCard");
    } else if (input.startsWith("4")) {
      setState(() => _cardBrand = "Visa");
    } else {
      setState(() => _cardBrand = "Card");
    }
  }

  void _submitPayment() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    // 模擬付款處理中
    Timer(const Duration(seconds: 2), () {
      setState(() => _isProcessing = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessPage(
            total: widget.amount.toInt(),
            itemCount: 1,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("信用卡付款", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildCardPreview(),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _cardNumberController,
                label: "卡號",
                hint: "1234 5678 9012 3456",
                maxLength: 19,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    v!.replaceAll(" ", "").length == 16 ? null : "請輸入正確卡號",
                onChanged: (v) {
                  if (v.length <= 19) {
                    final formatted = v
                        .replaceAll(" ", "")
                        .replaceAllMapped(RegExp(r".{4}"), (m) => "${m.group(0)} ");
                    _cardNumberController.value =
                        TextEditingValue(text: formatted.trim(), selection: TextSelection.collapsed(offset: formatted.length));
                    _detectCardBrand(v);
                  }
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _expiryController,
                      label: "有效期限",
                      hint: "MM/YY",
                      maxLength: 5,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          RegExp(r"^(0[1-9]|1[0-2])\/\d{2}$").hasMatch(v ?? "")
                              ? null
                              : "格式錯誤",
                      onChanged: (v) {
                        if (v.length == 2 && !v.contains("/")) {
                          _expiryController.text = "$v/";
                          _expiryController.selection = TextSelection.fromPosition(
                              TextPosition(offset: _expiryController.text.length));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      controller: _cvcController,
                      label: "安全碼 (CVC)",
                      hint: "123",
                      maxLength: 3,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      validator: (v) =>
                          v!.length == 3 ? null : "請輸入 3 位數安全碼",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _nameController,
                label: "持卡人姓名",
                hint: "CHEN HSIAO MEI",
                textCapitalization: TextCapitalization.characters,
                validator: (v) => v!.isEmpty ? "請輸入姓名" : null,
              ),
              const SizedBox(height: 30),
              _isProcessing
                  ? const CircularProgressIndicator(color: Colors.blueAccent)
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.lock_outline),
                      label: Text("付款 NT \$${widget.amount.toStringAsFixed(0)}"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _submitPayment,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.blueAccent.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Image.asset(
              _cardBrand == "Visa"
                  ? "assets/icons/visa.png"
                  : "assets/icons/mastercard.png",
              width: 60,
              errorBuilder: (_, __, ___) => const Icon(Icons.credit_card, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _cardNumberController.text.isEmpty
                ? "**** **** **** ****"
                : _cardNumberController.text,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _nameController.text.isEmpty
                    ? "CARD HOLDER"
                    : _nameController.text.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                _expiryController.text.isEmpty
                    ? "MM/YY"
                    : _expiryController.text,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int? maxLength,
    bool obscureText = false,
    TextInputType? keyboardType,
    Function(String)? onChanged,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        counterText: "",
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
