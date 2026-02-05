import 'package:flutter/material.dart';

class FeatureGate extends StatelessWidget {
  final bool enabled;
  final Widget child;

  /// disabled 時顯示用（可自訂 UI）
  final Widget? disabled;

  /// disabled 時的提示文字（用預設 disabled UI 時才會顯示）
  final String disabledMessage;

  const FeatureGate({
    super.key,
    required this.enabled,
    required this.child,
    this.disabled,
    this.disabledMessage = '此功能目前已停用',
  });

  @override
  Widget build(BuildContext context) {
    if (enabled) return child;

    if (disabled != null) return disabled!;

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('功能停用')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block_outlined, size: 44, color: cs.error),
                const SizedBox(height: 10),
                const Text('此功能目前不可使用',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 8),
                Text(disabledMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('返回'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
