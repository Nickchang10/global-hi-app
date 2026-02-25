import 'package:flutter/material.dart';

/// ✅ ChatSupportPage（客服支援｜最終完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正：
/// - ✅ withOpacity -> withValues(alpha: ...)（deprecated_member_use）
///
/// 功能：
/// - 顯示客服支援入口：
///   1) 線上客服聊天室（route: /chat_room，帶 roomId）
///   2) 常見問題 FAQ（route: /faq，可自行改）
///   3) 客服信箱/電話（示意）
///
/// 注意：
/// - 你若沒有 /chat_room 或 /faq 路由，請改成你專案實際路由。
class ChatSupportPage extends StatelessWidget {
  const ChatSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('客服支援')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        children: [
          _heroCard(cs),
          const SizedBox(height: 12),

          _actionCard(
            cs,
            icon: Icons.forum_outlined,
            title: '線上客服聊天室',
            subtitle: '立即與客服對話（可整合 Firestore）',
            onTap: () {
              // ✅ 導到你剛剛的 ChatRoomPage
              // route args 結構依你專案可調整
              Navigator.of(context).pushNamed(
                '/chat_room',
                arguments: <String, dynamic>{
                  'roomId': 'support',
                  'title': 'Osmile 客服',
                },
              );
            },
          ),
          const SizedBox(height: 10),

          _actionCard(
            cs,
            icon: Icons.help_outline,
            title: '常見問題 FAQ',
            subtitle: '付款、配送、保固、SOS、定位等',
            onTap: () {
              Navigator.of(context).pushNamed('/faq');
            },
          ),
          const SizedBox(height: 10),

          _actionCard(
            cs,
            icon: Icons.email_outlined,
            title: '客服信箱',
            subtitle: 'support@osmile.com.tw（示意）',
            onTap: () {
              _showInfoDialog(
                context,
                title: '客服信箱',
                content: 'support@osmile.com.tw\n\n（此為示意，請替換成你正式信箱）',
              );
            },
          ),
          const SizedBox(height: 10),

          _actionCard(
            cs,
            icon: Icons.call_outlined,
            title: '客服電話',
            subtitle: '02-1234-5678（示意）',
            onTap: () {
              _showInfoDialog(
                context,
                title: '客服電話',
                content: '02-1234-5678\n\n（此為示意，請替換成你正式電話）',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _heroCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: cs.primary.withValues(alpha: 0.12),
            child: Icon(Icons.support_agent, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '需要協助嗎？',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  '你可以直接開啟客服聊天室，或先查看 FAQ。',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
    ColorScheme cs, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _showInfoDialog(
    BuildContext context, {
    required String title,
    required String content,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }
}
