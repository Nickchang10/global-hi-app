import 'dart:io';
import 'dart:typed_data';

Future<String?> saveReportBytes({
  String? filename,
  String? fileName,
  String? name,
  required List<int> bytes,
  String mimeType = 'application/octet-stream',
}) async {
  final finalName = filename ?? fileName ?? name ?? 'report.bin';

  // 不額外引入 path_provider，直接寫到 systemTemp，確保「可編譯」
  final dir = Directory.systemTemp.createTempSync('osmile_reports_');
  final file = File('${dir.path}${Platform.pathSeparator}$finalName');

  await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);
  return '已輸出：${file.path}';
}
