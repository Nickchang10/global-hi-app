// lib/utils/report_file_saver.dart
// Cross-platform export: picks web implementation when dart:html is available,
// otherwise uses the IO implementation.

export 'report_file_saver_io.dart' // fallback (non-web)
    if (dart.library.html) 'report_file_saver_web.dart';
