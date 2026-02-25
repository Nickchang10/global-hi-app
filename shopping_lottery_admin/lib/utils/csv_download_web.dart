// lib/utils/csv_download_web.dart
//
// ✅ Web 端 CSV 下載（不使用 dart:html）
// - 使用 package:web + dart:js_interop
//
// 依賴：
//   dependencies:
//     web: ^1.1.1

import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// 常用：下載 CSV
void downloadCsv(String csv, [String filename = 'export.csv']) {
  downloadTextFile(csv, filename: filename, mimeType: 'text/csv;charset=utf-8');
}

/// 相容別名（如果你別處叫這個）
void downloadCsvWeb(String csv, [String filename = 'export.csv']) {
  downloadCsv(csv, filename);
}

/// 泛用：下載純文字檔
void downloadTextFile(
  String content, {
  required String filename,
  String mimeType = 'text/plain;charset=utf-8',
}) {
  final parts = JSArray<web.BlobPart>();
  parts.add(content.toJS);

  final blob = web.Blob(parts, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);

  try {
    final a = web.document.createElement('a') as web.HTMLAnchorElement;
    a.href = url;
    a.download = filename;
    a.style.display = 'none';

    (web.document.body ?? web.document.documentElement)?.append(a);
    a.click();
    a.remove();
  } finally {
    web.URL.revokeObjectURL(url);
  }
}
