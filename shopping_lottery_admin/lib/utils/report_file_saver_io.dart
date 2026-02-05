// lib/utils/report_file_saver_io.dart
// IO implementation: write to Downloads (if available) or temp directory then open with open_filex
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

/// Save bytes as a file on non-web platforms.
/// Returns the absolute file path (String) on success.
Future<String> saveReportBytes(
  Uint8List bytes,
  String filename, {
  String? mimeType,
  bool openFile = true,
}) async {
  if (kIsWeb) {
    throw Exception('This implementation is for IO platforms only. Use web implementation on web.');
  }

  mimeType ??= 'application/octet-stream';

  try {
    Directory? targetDir;

    // 1) Try Downloads directory (desktop platforms)
    try {
      targetDir = await _getDownloadsDirectorySafe();
    } catch (_) {
      targetDir = null;
    }

    // 2) Fallback to temporary directory
    targetDir ??= await getTemporaryDirectory();

    if (targetDir == null) {
      throw Exception('找不到可寫入的目錄（Downloads 或 Temporary）。');
    }

    // sanitize filename for safety
    final safeFilename = filename.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

    final filePath = '${targetDir.path}/$safeFilename';
    final file = File(filePath);

    await file.writeAsBytes(bytes, flush: true);

    // try to open file (if requested). Failure to open does not fail saving.
    if (openFile) {
      try {
        await OpenFilex.open(file.path);
      } catch (_) {
        // ignore open errors
      }
    }

    return file.path;
  } catch (e) {
    throw Exception('儲存檔案失敗：$e');
  }
}

/// Try to obtain a downloads directory in a safe way.
/// Returns null when Downloads is not available on the current platform.
Future<Directory?> _getDownloadsDirectorySafe() async {
  try {
    // getDownloadsDirectory is available on desktop platforms via path_provider.
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;

    // Android: try external storage "downloads" directory (requires proper permissions)
    if (Platform.isAndroid) {
      try {
        final ext = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (ext != null && ext.isNotEmpty) {
          return ext.first;
        }
      } catch (_) {
        // ignore
      }
    }

    // iOS: no public downloads folder via path_provider -> return null
    return null;
  } catch (_) {
    return null;
  }
}
