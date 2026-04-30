import 'dart:typed_data';

import 'picked_file_bytes_io.dart'
    if (dart.library.html) 'picked_file_bytes_web.dart';

/// Resolves bytes from [FilePicker] result: uses in-memory bytes when present,
/// otherwise reads from [path] on IO (large PDFs often have null bytes).
Future<Uint8List?> resolvePickedFileBytes({
  required Uint8List? bytes,
  required String? path,
}) =>
    resolvePickedFileBytesImpl(bytes: bytes, path: path);
