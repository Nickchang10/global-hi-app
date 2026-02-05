// lib/utils/file_picker_html.dart
// Web implementation: use <input type="file"> and FileReader to return bytes.
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> pickImageFileWeb() {
  final completer = Completer<Uint8List?>();
  final input = html.FileUploadInputElement();
  input.accept = 'image/*';
  input.multiple = false;
  input.click();

  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final file = files.first;
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is String) {
        // data:*;base64,xxxxx
        final parts = result.split(',');
        final dataStr = parts.length > 1 ? parts[1] : parts[0];
        try {
          final bytes = base64Decode(dataStr);
          completer.complete(Uint8List.fromList(bytes));
        } catch (e) {
          completer.complete(null);
        }
      } else {
        completer.complete(null);
      }
    });
    reader.readAsDataUrl(file);
  });

  // if user cancels, we don't get onChange; still return null after a short timeout? better to keep completer
  return completer.future;
}
