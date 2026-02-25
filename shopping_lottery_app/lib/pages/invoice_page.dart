// lib/pages/invoice_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class InvoicePage extends StatefulWidget {
  const InvoicePage({super.key});

  static const routeName = '/invoice';

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  String _invoiceType = '二聯式（個人）';

  final TextEditingController _carrierController = TextEditingController();
  final TextEditingController _companyIdController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();

  TextStyle _noto({double? fontSize, FontWeight? fontWeight, Color? color}) {
    return GoogleFonts.getFont(
      'Noto Sans TC',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  bool get _isCompany => _invoiceType == '三聯式（公司）';

  @override
  void dispose() {
    _carrierController.dispose();
    _companyIdController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  bool _validateCompany(BuildContext ctx) {
    final companyId = _companyIdController.text.trim();
    final companyName = _companyNameController.text.trim();

    if (companyId.length != 8) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('請輸入有效的統一編號（8 碼）')));
      return false;
    }
    if (int.tryParse(companyId) == null) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('統一編號需為數字')));
      return false;
    }
    if (companyName.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('請輸入公司抬頭')));
      return false;
    }
    return true;
  }

  bool _validateCarrier(BuildContext ctx) {
    final carrier = _carrierController.text.trim();
    if (carrier.isEmpty) return true;

    final phoneBarcodeOk = carrier.length == 8 && carrier.startsWith('/');
    final citizenCertOk = RegExp(r'^[A-Z]{2}\d{14}$').hasMatch(carrier);

    if (!phoneBarcodeOk && !citizenCertOk) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('載具格式不正確（示範：/XXXXXXX 或 AA00000000000000）'),
        ),
      );
      return false;
    }
    return true;
  }

  void _save() {
    final ctx = context;

    if (_isCompany) {
      if (!_validateCompany(ctx)) return;
    } else {
      if (!_validateCarrier(ctx)) return;
    }

    final result = <String, dynamic>{
      'type': _invoiceType,
      'carrier': _carrierController.text.trim(),
      'companyId': _companyIdController.text.trim(),
      'companyName': _companyNameController.text.trim(),
    };

    Navigator.pop(ctx, result);
  }

  @override
  Widget build(BuildContext context) {
    const pageBg = Color(0xFFF5F6FA);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
        title: Text(
          '電子發票資訊',
          style: _noto(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInvoiceTypeSelector(),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _isCompany
                  ? _buildCompanyInvoiceForm()
                  : _buildPersonalInvoiceForm(),
            ),
            const SizedBox(height: 40),
            _buildSaveButton(),
            const SizedBox(height: 8),
            Text(
              '提示：此頁為示範版，正式串接可將結果存入 user profile / order draft。',
              style: _noto(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({Key? key, required Widget child}) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInvoiceTypeSelector() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '選擇發票類型',
            style: _noto(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),

          // ✅ 注意：某些 SDK 的 onChanged 回傳 String?
          RadioGroup<String>(
            groupValue: _invoiceType,
            onChanged: (String? v) {
              if (v == null) return;
              setState(() => _invoiceType = v);
            },
            child: Column(
              children: [
                RadioListTile<String>(
                  value: '二聯式（個人）',
                  title: Text('二聯式（個人）', style: _noto(fontSize: 14)),
                  activeColor: Colors.blueAccent,
                ),
                RadioListTile<String>(
                  value: '三聯式（公司）',
                  title: Text('三聯式（公司）', style: _noto(fontSize: 14)),
                  activeColor: Colors.blueAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInvoiceForm() {
    final carrier = _carrierController.text.trim();
    return _card(
      key: const ValueKey('personal'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '輸入載具（選填）',
            style: _noto(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _carrierController,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) {
                final upper = newValue.text.toUpperCase();
                return newValue.copyWith(
                  text: upper,
                  selection: newValue.selection,
                  composing: TextRange.empty,
                );
              }),
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
              LengthLimitingTextInputFormatter(16),
            ],
            decoration: InputDecoration(
              hintText: '手機條碼 / 自然人憑證代碼',
              hintStyle: _noto(color: Colors.grey.shade600, fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(
                Icons.phone_android,
                color: Colors.blueAccent,
              ),
              suffixIcon: carrier.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          setState(() => _carrierController.clear()),
                    ),
              helperText: '未填寫將以會員 Email 寄送電子發票。',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Text(
            '示範規則：/XXXXXXX（手機條碼）或 AA00000000000000（自然人憑證）',
            style: _noto(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInvoiceForm() {
    return _card(
      key: const ValueKey('company'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('公司資訊', style: _noto(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          TextField(
            controller: _companyIdController,
            maxLength: 8,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: InputDecoration(
              counterText: '',
              labelText: '統一編號',
              labelStyle: _noto(fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.business, color: Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _companyNameController,
            decoration: InputDecoration(
              labelText: '公司抬頭',
              labelStyle: _noto(fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(
                Icons.account_balance,
                color: Colors.blueAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.save_outlined),
        label: Text(
          '儲存發票資訊',
          style: _noto(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _save,
      ),
    );
  }
}
