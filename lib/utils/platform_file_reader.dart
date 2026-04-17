import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'picked_file_bytes.dart';

/// Reads file bytes from a [PlatformFile] in the order the platform supports:
/// in-memory [PlatformFile.bytes], [PlatformFile.readStream] (Android content://),
/// then filesystem [PlatformFile.path] (IO only).
Future<Uint8List?> readPlatformFileBytes(PlatformFile picked) async {
  if (picked.bytes != null && picked.bytes!.isNotEmpty) {
    return picked.bytes;
  }

  final stream = picked.readStream;
  if (stream != null) {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    final full = builder.takeBytes();
    if (full.isNotEmpty) return full;
  }

  return resolvePickedFileBytes(bytes: null, path: picked.path);
}
