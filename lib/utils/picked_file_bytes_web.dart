import 'dart:typed_data';

Future<Uint8List?> resolvePickedFileBytesImpl({
  required Uint8List? bytes,
  required String? path,
}) async =>
    (bytes != null && bytes.isNotEmpty) ? bytes : null;
