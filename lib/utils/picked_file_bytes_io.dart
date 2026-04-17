import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> resolvePickedFileBytesImpl({
  required Uint8List? bytes,
  required String? path,
}) async {
  if (bytes != null && bytes.isNotEmpty) return bytes;
  if (path == null || path.isEmpty) return null;
  try {
    return await File(path).readAsBytes();
  } catch (_) {
    return null;
  }
}
