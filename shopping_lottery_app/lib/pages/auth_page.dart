import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _loginNameCtrl =
      TextEditingController(text: "展場訪客");
  final TextEditingController _registerNameCtrl = TextEditingController();
  final TextEditingController _registerEmailCtrl = TextEditingController();
  final TextEditingController _registerPhoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginNameCtrl.dispose();
    _registerNameCtrl.dispose();
    _registerEmailCtrl.dispose();
    _registerPhoneCtrl.dispose();
    super.dispose();
  }

  void _doQuickLogin() {
    final name =
        _loginNameCtrl.text.trim().isEmpty ? "展場訪客" : _loginNameCtrl.text.trim();
    UserService.instance.loginDemo(name: name);
  }

  void _doRegister() {
    final name = _registerNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("請至少輸入暱稱")),
      );
      return;
    }

    UserService.instance.registerDemo(
      name: name,
      email: _registerEmailCtrl.text.trim().isEmpty
          ? null
          : _registerEmailCtrl.text.trim(),
      phone: _registerPhoneCtrl.text.trim().isEmpty
          ? null
          : _registerPhoneCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // LOGO + 標題
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.watch_outlined,
                    color: Colors.blueAccent,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Osmile 購物商城",
                  style: GoogleFonts.notoSansTc(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "展場 Demo：登入 / 註冊皆為模擬，不會建立真實帳號",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),

                // Tab 切換
                Container(
                  width: size.width,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey[700],
                    tabs: const [
                      Tab(text: "快速登入"),
                      Tab(text: "註冊新帳號"),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  height: 320,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLoginTab(),
                      _buildRegisterTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🔹 快速登入（展場 Demo 用）
  Widget _buildLoginTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "登入 / 一鍵體驗",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "這裡不會真的驗證帳號密碼，只是模擬登入流程，用來 demo App 功能。",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _loginNameCtrl,
            decoration: const InputDecoration(
              labelText: "顯示暱稱",
              border: OutlineInputBorder(),
              hintText: "例如：展場訪客、小明",
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text(
                "一鍵登入（模擬）",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _doQuickLogin,
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 註冊 Tab（模擬建立帳號）
  Widget _buildRegisterTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListView(
        children: [
          const Text(
            "建立新帳號（模擬）",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _registerNameCtrl,
            decoration: const InputDecoration(
              labelText: "暱稱 *",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _registerEmailCtrl,
            decoration: const InputDecoration(
              labelText: "Email（選填）",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _registerPhoneCtrl,
            decoration: const InputDecoration(
              labelText: "手機（選填）",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.person_add_alt, color: Colors.white),
              label: const Text(
                "模擬註冊並登入",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _doRegister,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "註冊後會直接登入，此流程完全不會送出到伺服器，只是為了展示會員體驗。",
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
