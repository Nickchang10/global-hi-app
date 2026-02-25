// lib/utils/report_file_saver_web.dart
import 'dart:typed_data';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<String?> saveReportBytes({
  String? filename,
  String? fileName,
  String? name,
  required List<int> bytes,
  String mimeType = 'application/octet-stream',
}) async {
  final finalName = filename ?? fileName ?? name ?? 'report.bin';

  final u8 = Uint8List.fromList(bytes);

  // ✅ 這裡關鍵：JSArray<BlobPart>
  final parts = <web.BlobPart>[(u8.toJS as web.BlobPart)].toJS;

  final blob = web.Blob(parts, web.BlobPropertyBag(type: mimeType));

  final url = web.URL.createObjectURL(blob);

  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = finalName
    ..style.display = 'none';

  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();

  web.URL.revokeObjectURL(url);

  return '已下載：$finalName';
}
