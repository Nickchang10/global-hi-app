// lib/utils/report_file_saver_web.dart
// Web implementation: download via Blob + Anchor
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;

/// Save bytes and trigger browser download.
/// Returns the filename (String) on success.
Future<String> saveReportBytes(
  Uint8List bytes,
  String filename, {
  String? mimeType,
  bool openFile = true, // ignored on web
}) async {
  mimeType ??= 'application/octet-stream';
  try {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();

    // Small delay then remove and revoke URL
    Future.delayed(const Duration(milliseconds: 500), () {
      anchor.remove();
      try {
        html.Url.revokeObjectUrl(url);
      } catch (_) {}
    });

    return filename;
  } catch (e) {
    throw Exception('Web: 無法下載檔案：$e');
  }
}
