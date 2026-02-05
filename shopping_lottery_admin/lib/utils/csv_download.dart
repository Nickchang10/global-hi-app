// lib/utils/csv_download.dart
import 'csv_download_stub.dart' if (dart.library.html) 'csv_download_web.dart' as impl;

/// Web：觸發下載
/// 非 Web：no-op 或你可改成 copy clipboard
Future<void> downloadCsv(String filename, String csvContent) {
  return impl.downloadCsv(filename, csvContent);
}
