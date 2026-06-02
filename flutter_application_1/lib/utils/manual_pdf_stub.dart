import 'dart:io';

import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

Future<bool> openManualPdfImpl() async {
  const assetPath = 'MANUAL PROYECTO.pdf';
  final bytes = await rootBundle.load(assetPath);
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/manual_proyecto.pdf');
  await file.writeAsBytes(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    flush: true,
  );

  final result = await OpenFile.open(file.path);
  return result.type != ResultType.error;
}
