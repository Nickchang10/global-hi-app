// lib/utils/csv_download_web.dart
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert' show utf8;
import 'dart:html' as html;

Future<void> downloadCsv(String filename, String csvContent) async {
  final bytes = utf8.encode(csvContent);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final a = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';

  html.document.body?.children.add(a);
  a.click();
  a.remove();

  html.Url.revokeObjectUrl(url);
}
