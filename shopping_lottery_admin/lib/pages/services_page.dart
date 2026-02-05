// lib/pages/services_page.dart
//
// ✅ ServicesPage（最終穩定可編譯完整版）
// ------------------------------------------------------------
// - Route: /services
// - Firestore：site_contents/services
//   欄位建議：title(String), content(String)
// - 若文件不存在或欄位空白：顯示預設內容
// - 支援：重新整理、即時更新、錯誤顯示、空白防呆、Debug 提示（僅 Debug 模式）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  static const String routeName = '/services';

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  final DocumentReference<Map<String, dynamic>> _docRef =
      FirebaseFirestore.instance.collection('site_contents').doc('services');

  static const String _fallbackTitle = '服務項目';
  static const String _fallbackContent = '''
這裡是「服務項目」頁面。

你可以在 Firestore 的 site_contents/services 設定 title、content 來更新顯示內容。

例如：
- 智慧穿戴設備與緊急求助整合方案
- 家庭安全守護系統
- 雲端定位追蹤與通知平台
- 客製化照護與售後支援服務
''';

  // -------------------------
  // 工具方法
  // -------------------------
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  String _asStr(dynamic v) => (v ?? '').toString().trim();

  String _safeTitle(Map<String, dynamic>? data) {
    final t = _asStr(data?['title']);
    return t.isEmpty ? _fallbackTitle : t;
  }

  String _safeContent(Map<String, dynamic>? data) {
    final c = _asStr(data?['content']);
    return c.isEmpty ? _fallbackContent : c;
  }

  Future<void> _refresh() async {
    try {
      await _docRef.get(const GetOptions(source: Source.server));
      _snack('已重新整理');
    } catch (e) {
      _snack('重新整理失敗：$e');
    } finally {
      if (mounted) setState(() {});
    }
  }

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _docRef.snapshots(),
      builder: (context, snap) {
        final bool loading =
            snap.connectionState == ConnectionState.waiting && !snap.hasData;

        final bool exists = snap.data?.exists == true;
        final Map<String, dynamic>? data = snap.data?.data();

        final String title = exists ? _safeTitle(data) : _fallbackTitle;
        final String content = exists ? _safeContent(data) : _fallbackContent;

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              IconButton(
                tooltip: '重新整理',
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : (snap.hasError
                  ? _Body(
                      title: _fallbackTitle,
                      content: '讀取失敗：${snap.error}\n\n請稍後再試或聯繫管理員。',
                      debugHint:
                          kDebugMode ? 'doc=site_contents/services' : null,
                    )
                  : _Body(
                      title: title,
                      content: content,
                      debugHint: kDebugMode
                          ? 'doc=site_contents/services exists=$exists'
                          : null,
                    )),
        );
      },
    );
  }
}

// -------------------------
// 主體內容元件
// -------------------------
class _Body extends StatelessWidget {
  final String title;
  final String content;
  final String? debugHint;

  const _Body({
    required this.title,
    required this.content,
    this.debugHint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 12),
        SelectableText(
          content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
                fontSize: 15,
              ),
        ),
        if (debugHint != null) ...[
          const SizedBox(height: 18),
          Divider(color: cs.outline.withOpacity(0.25)),
          Text(
            debugHint!,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
