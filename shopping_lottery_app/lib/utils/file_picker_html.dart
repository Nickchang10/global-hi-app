// lib/utils/file_picker_html.dart
//
// ✅ Web File Picker（不使用 dart:html）
// ------------------------------------------------------------
// - 使用 package:web + dart:js_interop
// - 提供 pickWebFile() 選檔並讀取 bytes
//
// 需要套件：web
// pubspec.yaml:
//   dependencies:
//     web: ^1.0.0
// ------------------------------------------------------------

import 'dart:async';
import 'dart:typed_data';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class PickedWebFile {
  final String name;
  final String? mime;
  final Uint8List bytes;

  const PickedWebFile({
    required this.name,
    required this.mime,
    required this.bytes,
  });
}

Future<PickedWebFile?> pickWebFile({
  String accept = '*/*',
  bool multiple = false,
}) async {
  final completer = Completer<PickedWebFile?>();

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept
    ..multiple = multiple;

  input.style.display = 'none';
  web.document.body?.append(input);

  StreamSubscription? sub;

  void cleanup() {
    try {
      sub?.cancel();
    } catch (_) {}
    try {
      input.remove();
    } catch (_) {}
  }

  sub = input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.length == 0) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final file = files.item(0);
    if (file == null) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final reader = web.FileReader();

    reader.onLoadEnd.listen((_) {
      try {
        // ✅ 讀取失敗：reader.error 可能不為 null，且 result 也可能為 null
        if (reader.error != null || reader.result == null) {
          cleanup();
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        final result = reader.result!;
        final buf = result as JSArrayBuffer;

        // JSArrayBuffer -> Uint8List
        final bytes = Uint8List.view(buf.toDart);

        cleanup();
        if (!completer.isCompleted) {
          completer.complete(
            PickedWebFile(
              name: file.name,
              mime: file.type.isEmpty ? null : file.type,
              bytes: bytes,
            ),
          );
        }
      } catch (_) {
        cleanup();
        if (!completer.isCompleted) completer.complete(null);
      }
    });

    // 開始讀取
    try {
      reader.readAsArrayBuffer(file);
    } catch (_) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    }
  });

  input.click();
  return completer.future;
}
