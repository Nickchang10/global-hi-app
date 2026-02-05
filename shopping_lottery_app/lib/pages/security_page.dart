/* lib/pages/security_page.dart */

import 'package:flutter/material.dart';
import '../services/security_service.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final service = SecurityService.instance;

  final TextEditingController _attackCtrl = TextEditingController();
  final TextEditingController _blockCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("安全性設定")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ---------------- 防火牆 ----------------
          Card(
            child: SwitchListTile(
              title: const Text("啟用防火牆"),
              value: service.firewallEnabled,
              onChanged: (v) {
                setState(() => service.toggleFirewall(v));
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("防火牆已${v ? "開啟" : "關閉"}")));
              },
            ),
          ),

          const SizedBox(height: 12),

          // ---------------- 黑名單管理 ----------------
          Card(
            child: ExpansionTile(
              title: const Text("黑名單管理"),
              subtitle: Text(
                  service.blacklist.isEmpty ? "目前沒有封鎖的帳號" : "封鎖 ${service.blacklist.length} 位帳號"),
              children: [
                // 列出黑名單
                ...service.blacklist.map((u) => ListTile(
                      leading: const Icon(Icons.block, color: Colors.red),
                      title: Text(u),
                    )),

                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _blockCtrl,
                          decoration: const InputDecoration(
                            labelText: "封鎖使用者名稱",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (_blockCtrl.text.trim().isEmpty) return;
                          setState(() {
                            service.blockUser(_blockCtrl.text.trim());
                            _blockCtrl.clear();
                          });
                        },
                        child: const Text("封鎖"),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ---------------- 模擬攻擊 ----------------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("模擬攻擊事件（示範）",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _attackCtrl,
                    decoration: const InputDecoration(
                      labelText: "來源（IP 或帳號）",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  ElevatedButton(
                    onPressed: () {
                      if (_attackCtrl.text.trim().isEmpty) return;
                      setState(() {
                        service.simulateAttackAttempt(_attackCtrl.text.trim());
                        _attackCtrl.clear();
                      });
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text("已記錄攻擊事件")));
                    },
                    child: const Text("模擬攻擊"),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ---------------- 日誌 ----------------
          Card(
            child: ExpansionTile(
              title: const Text("安全日誌"),
              subtitle: Text("共 ${service.logs.length} 筆"),
              children: [
                ...service.logs.map((e) => ListTile(
                      leading: const Icon(Icons.event_note),
                      title: Text(e),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
