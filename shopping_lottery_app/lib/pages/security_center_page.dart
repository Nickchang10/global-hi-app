import 'package:flutter/material.dart';
import 'package:osmile_shopping_app/pages/change_password_page.dart';

/// 🛡️ 帳號安全中心（完整版）
///
/// 功能：
/// ✅ 顯示帳號安全概況  
/// ✅ 更改密碼  
/// ✅ 裝置管理（模擬登入裝置）  
/// ✅ 帳號綁定（模擬綁定 Google / Line）  
/// ✅ 安全通知開關  
class SecurityCenterPage extends StatefulWidget {
  const SecurityCenterPage({super.key});

  @override
  State<SecurityCenterPage> createState() => _SecurityCenterPageState();
}

class _SecurityCenterPageState extends State<SecurityCenterPage> {
  bool _securityNotice = true;
  bool _biometricEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🔒 安全中心"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF6F8FB),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 20),
          _buildSecurityOptions(context),
          const SizedBox(height: 20),
          _buildDeviceSection(),
          const SizedBox(height: 20),
          _buildBindingSection(),
        ],
      ),
    );
  }

  // ===========================================================
  // 帳號安全概況
  // ===========================================================
  Widget _buildSummaryCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "帳號安全概況",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            ListTile(
              leading: Icon(Icons.verified_user, color: Colors.green),
              title: Text("密碼保護：已設定"),
              subtitle: Text("建議每 3 個月更新一次密碼"),
            ),
            ListTile(
              leading: Icon(Icons.security, color: Colors.blueAccent),
              title: Text("雙重驗證：未啟用"),
              subtitle: Text("開啟可提升帳號安全性"),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // 安全設定項目
  // ===========================================================
  Widget _buildSecurityOptions(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text("更改密碼"),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
              );
            },
          ),
          const Divider(height: 0),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text("安全通知"),
            subtitle: const Text("登入異常時通知你"),
            value: _securityNotice,
            onChanged: (v) => setState(() => _securityNotice = v),
          ),
          const Divider(height: 0),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text("啟用生物辨識"),
            subtitle: const Text("使用指紋或臉部登入"),
            value: _biometricEnabled,
            onChanged: (v) => setState(() => _biometricEnabled = v),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // 裝置登入紀錄（模擬）
  // ===========================================================
  Widget _buildDeviceSection() {
    final devices = [
      {
        "name": "iPhone 15 Pro",
        "location": "台北市",
        "time": "今日 10:23",
        "active": true
      },
      {
        "name": "MacBook Air M2",
        "location": "新北市",
        "time": "昨日 22:10",
        "active": false
      },
      {
        "name": "Samsung S24 Ultra",
        "location": "台中市",
        "time": "11月28日 14:37",
        "active": false
      },
    ];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "登入裝置",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...devices.map((d) {
              return ListTile(
                leading: Icon(
                  d["active"] ? Icons.phone_iphone : Icons.devices,
                  color: d["active"] ? Colors.green : Colors.grey,
                ),
                title: Text(d["name"]),
                subtitle: Text("${d["location"]} ・ ${d["time"]}"),
                trailing: d["active"]
                    ? const Text("目前使用中",
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold))
                    : TextButton(
                        child: const Text("登出"),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("${d["name"]} 已登出")),
                          );
                        },
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // 帳號綁定（模擬）
  // ===========================================================
  Widget _buildBindingSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.link, color: Colors.blueAccent),
            title: Text("帳號綁定"),
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text("Email"),
            trailing: const Text("已綁定", style: TextStyle(color: Colors.green)),
            onTap: () {},
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.g_mobiledata),
            title: const Text("Google 帳號"),
            trailing:
                const Text("未綁定", style: TextStyle(color: Colors.orange)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("模擬：已成功綁定 Google 帳號 ✅"),
              ));
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text("LINE 帳號"),
            trailing:
                const Text("未綁定", style: TextStyle(color: Colors.orange)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("模擬：已成功綁定 LINE 帳號 ✅"),
              ));
            },
          ),
        ],
      ),
    );
  }
}
