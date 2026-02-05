// lib/pages/admin/marketing/admin_segment_templates_panel.dart
//
// ✅ AdminSegmentTemplatesPanel（範本 + 匯入/匯出）
// ------------------------------------------------------------
// - 顯示內建範本清單，一鍵套用到編輯頁。
// - 匯入/匯出 JSON（用 FileSaver + file_picker）
// - 整合 SegmentTemplates 與 SegmentService
// ------------------------------------------------------------

import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import '../../../services/segment_templates.dart';
import '../../../services/segment_service.dart';

class AdminSegmentTemplatesPanel extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onApply;

  const AdminSegmentTemplatesPanel({super.key, required this.onApply});

  @override
  State<AdminSegmentTemplatesPanel> createState() =>
      _AdminSegmentTemplatesPanelState();
}

class _AdminSegmentTemplatesPanelState
    extends State<AdminSegmentTemplatesPanel> {
  Future<void> _exportTemplate(Map<String, dynamic> rule) async {
    final name =
        'segment_rule_${DateTime.now().millisecondsSinceEpoch}.json';
    final bytes = Uint8List.fromList(
      const JsonEncoder.withIndent('  ').convert(rule).codeUnits,
    );
    await FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      ext: 'json',
      mimeType: MimeType.json,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已匯出 JSON 範本')),
    );
  }

  Future<void> _importTemplate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return;

    try {
      final file = result.files.first;
      final content = utf8.decode(file.bytes!);
      final decoded = json.decode(content);
      if (decoded is Map<String, dynamic>) {
        widget.onApply(decoded);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已匯入並套用範本')),
        );
      } else {
        throw 'JSON 結構無效';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('匯入失敗：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final templates = SegmentTemplates.allTemplates();
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('快速範本',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _importTemplate,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('匯入 JSON'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final t in templates)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(t['name']),
                    onPressed: () => widget.onApply(t['rule']),
                  ),
              ],
            ),
            const Divider(height: 24),
            OutlinedButton.icon(
              onPressed: () => _exportTemplate(SegmentService.defaultRule()),
              icon: const Icon(Icons.file_download),
              label: const Text('匯出目前規則 JSON'),
            ),
          ],
        ),
      ),
    );
  }
}
