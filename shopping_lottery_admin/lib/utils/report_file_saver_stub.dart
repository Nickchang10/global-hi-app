/// Fallback（理論上不會走到）
/// 讓 analyzer 不報錯，也確保條件匯出在任何平台都有預設實作。
Future<String?> saveReportBytes({
  String? filename,
  String? fileName,
  String? name,
  required List<int> bytes,
  String mimeType = 'application/octet-stream',
}) async {
  final finalName = filename ?? fileName ?? name ?? 'report.bin';
  return 'Stub saver: $finalName (${bytes.length} bytes)';
}
