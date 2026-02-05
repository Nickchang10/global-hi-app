import 'package:flutter/material.dart';

class SupportTabPage extends StatelessWidget {
  const SupportTabPage({super.key});

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _safeNav(BuildContext context, String routeName) {
    try {
      Navigator.of(context).pushNamed(routeName);
    } catch (_) {
      _toast(context, '尚未設定路由：$routeName');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('支援'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _tile(
            context,
            icon: Icons.support_agent_outlined,
            title: '線上客服',
            subtitle: '導到 /support/chat（若你有設定）',
            onTap: () => _safeNav(context, '/support/chat'),
          ),
          _tile(
            context,
            icon: Icons.help_outline,
            title: '常見問題 FAQ',
            subtitle: '導到 /support/faq（若你有設定）',
            onTap: () => _safeNav(context, '/support/faq'),
          ),
          _tile(
            context,
            icon: Icons.policy_outlined,
            title: '保固與售後',
            subtitle: '導到 /warranty（若你有設定）',
            onTap: () => _safeNav(context, '/warranty'),
          ),
          _tile(
            context,
            icon: Icons.notifications_outlined,
            title: '通知中心',
            subtitle: '導到 /notifications',
            onTap: () => _safeNav(context, '/notifications'),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
