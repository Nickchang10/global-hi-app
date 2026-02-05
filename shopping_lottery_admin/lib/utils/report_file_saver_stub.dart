// lib/utils/report_file_saver_stub.dart
//
// ✅ Stub 版本：非 Web / 非 IO 平台使用
// ------------------------------------------------------------

Future<String> saveReportBytes({
  required String filename,
  required List<int> bytes,
  required String mimeType,
}) async {
  throw UnsupportedError('此平台不支援檔案儲存功能');
}
