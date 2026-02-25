// lib/pages/customer_service_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomerServicePage extends StatelessWidget {
  const CustomerServicePage({super.key});

  static const routeName = '/customer-service';

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已複製到剪貼簿')));
  }

  Future<void> _showDialogSafe(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => const _CustomerServiceDialog(),
    );
    if (!context.mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('客服中心')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '聯絡我們',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.support_agent),
                    title: const Text('Line 客服'),
                    subtitle: const Text('@osmile（示範）'),
                    trailing: OutlinedButton(
                      onPressed: () => _copy(context, '@osmile'),
                      child: const Text('複製'),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email'),
                    subtitle: const Text('support@osmile.com.tw（示範）'),
                    trailing: OutlinedButton(
                      onPressed: () => _copy(context, 'support@osmile.com.tw'),
                      child: const Text('複製'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await _showDialogSafe(context);
                        if (!context.mounted) return;
                      },
                      icon: const Icon(Icons.info_outline),
                      label: const Text('查看客服說明'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '常見問題',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  SizedBox(height: 10),
                  _FaqTile(q: '如何查詢訂單？', a: '到「我的」→「訂單」即可查看。'),
                  _FaqTile(q: '如何使用優惠券？', a: '結帳頁可選擇可用的優惠券折抵。'),
                  _FaqTile(q: '如何申請退換貨？', a: '請聯繫客服並提供訂單編號與原因。'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ 把 AlertDialog 抽成 const widget，解掉 prefer_const_constructors（91~108）
/// - AlertDialog 本體內容固定（title/content/text 都是 const）
/// - actions 的 onPressed 仍可用（Navigator.of(context).pop）
class _CustomerServiceDialog extends StatelessWidget {
  const _CustomerServiceDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('客服資訊'),
      content: const Text('你可以透過 Line 或 Email 聯繫我們。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('關閉'),
        ),
      ],
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.q, required this.a});

  final String q;
  final String a;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(q, style: const TextStyle(fontWeight: FontWeight.w800)),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(a),
          ),
        ),
      ],
    );
  }
}
