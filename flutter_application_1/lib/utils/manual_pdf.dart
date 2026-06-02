import 'package:flutter/material.dart';

import 'manual_pdf_stub.dart' if (dart.library.html) 'manual_pdf_web.dart';

Future<void> openManualPdf(BuildContext context) async {
  try {
    final opened = await openManualPdfImpl();
    if (!opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Manual abierto correctamente.')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo abrir el manual: $e')),
    );
  }
}
