import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InvoicePage extends StatefulWidget {
  const InvoicePage({super.key});

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  String _invoiceType = "二聯式（個人）";
  final TextEditingController _carrierController = TextEditingController();
  final TextEditingController _companyIdController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
        title: const Text(
          "電子發票資訊",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInvoiceTypeSelector(),
            const SizedBox(height: 16),
            _invoiceType == "二聯式（個人）"
                ? _buildPersonalInvoiceForm()
                : _buildCompanyInvoiceForm(),
            const SizedBox(height: 40),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("選擇發票類型",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        ],
      ),
    );
  }

  Widget _buildPersonalInvoiceForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("輸入載具（選填）",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _carrierController,
            decoration: InputDecoration(
              hintText: "請輸入手機條碼 / 自然人憑證代碼",
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.phone_android, color: Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "未填寫將以會員 Email 寄送電子發票。",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInvoiceForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("公司資訊",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          TextField(
            controller: _companyIdController,
            maxLength: 8,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              counterText: "",
              labelText: "統一編號",
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.business, color: Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _companyNameController,
            decoration: InputDecoration(
              labelText: "公司抬頭",
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              prefixIcon:
                  const Icon(Icons.account_balance, color: Colors.blueAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.save_outlined),
      label: const Text("儲存發票資訊"),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        if (_invoiceType == "三聯式（公司）" &&
            _companyIdController.text.length != 8) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("請輸入有效的統一編號")),
          );
          return;
        }

        Navigator.pop(context, {
          "type": _invoiceType,
          "carrier": _carrierController.text,
          "companyId": _companyIdController.text,
          "companyName": _companyNameController.text,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("發票資訊已儲存")),
        );
      },
    );
  }
}
