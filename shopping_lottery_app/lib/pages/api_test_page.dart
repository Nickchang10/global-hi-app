import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class ApiTestPage extends StatefulWidget {
  const ApiTestPage({super.key});

  @override
  State<ApiTestPage> createState() => _ApiTestPageState();
}

class _ApiTestPageState extends State<ApiTestPage> {
  String _result = "尚未執行測試";

  Future<void> _sendTestRequest() async {
    final username = AuthService.instance.username ?? "訪客";
    final api = ApiService.instance;

    if (api.token == null) {
      await api.generateToken(username);
    }

    final response = await api.sendSecureRequest(
      endpoint: "/api/test/secure",
      payload: {"user": username, "action": "Test Request"},
    );

    setState(() {
      _result = response.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🔐 API 安全封包測試"),
        backgroundColor: const Color(0xFF007BFF),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_lock),
              label: const Text("送出加密 API 請求"),
              onPressed: _sendTestRequest,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _result,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
