// lib/pages/admin/marketing/admin_ai_campaign_assistant_page.dart
//
// ✅ AdminAiCampaignAssistantPage（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// ✅ 本次修正：
// - 修正 Flutter 3.33+ deprecation：DropdownButtonFormField 的 `value:` 改用 `initialValue:`
// - 其餘功能保持：活動企劃 AI 助理（可輸入、產出、儲存到 Firestore 等）
// ------------------------------------------------------------
//
// ⚠️ 你原檔很長（你只貼到錯誤資訊，未貼整份檔案）
// 這裡我提供「可直接套用的修補版本」：
// - 你只要把報錯那個 DropdownButtonFormField 區塊，改成下面這種寫法即可。
// - 若你要我輸出“整份完整版檔案”，請把該檔案完整貼上來，我才能 100% 不漏任何既有功能。

import 'package:flutter/material.dart';

/// ✅ 你原本頁面裡的 state
class AdminAiCampaignAssistantPage extends StatefulWidget {
  const AdminAiCampaignAssistantPage({super.key});

  @override
  State<AdminAiCampaignAssistantPage> createState() =>
      _AdminAiCampaignAssistantPageState();
}

class _AdminAiCampaignAssistantPageState
    extends State<AdminAiCampaignAssistantPage> {
  // 你原本一定有類似這個欄位
  String _channel = 'line';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 活動企劃助理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('投放渠道', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),

          // ✅ 修正重點：value -> initialValue
          DropdownButtonFormField<String>(
            initialValue: _channel, // ✅ 原本 value: _channel
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'line', child: Text('LINE')),
              DropdownMenuItem(value: 'fb', child: Text('Facebook')),
              DropdownMenuItem(value: 'ig', child: Text('Instagram')),
              DropdownMenuItem(value: 'google', child: Text('Google Ads')),
              DropdownMenuItem(value: 'edm', child: Text('EDM')),
            ],
            onChanged: (v) => setState(() => _channel = v ?? 'line'),
          ),

          const SizedBox(height: 20),
          const Text(
            '✅ 以上區塊直接替換你原本報錯的 DropdownButtonFormField 即可。',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
