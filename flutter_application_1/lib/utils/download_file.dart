import 'dart:typed_data';

import 'download_file_stub.dart'
    if (dart.library.html) 'download_file_web.dart';

Future<void> downloadFile(Uint8List bytes, String fileName, String mimeType) {
  return downloadFileImpl(bytes, fileName, mimeType);
}
