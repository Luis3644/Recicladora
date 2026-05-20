import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../utils/download_file.dart';

const _kBlue     = Color(0xFF1D4ED8);
const _kBlue2    = Color(0xFF2563EB);
const _kBg       = Color(0xFFF1F6FF);
const _kDanger   = Color(0xFFDC2626);
const _kDangerBg = Color(0xFFFEF2F2);

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo editar
// ─────────────────────────────────────────────────────────────────────────────
class _EditarDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> datos;
  const _EditarDialog({required this.docId, required this.datos});

  @override
  State<_EditarDialog> createState() => _EditarDialogState();
}

class _EditarDialogState extends State<_EditarDialog> {
  late final TextEditingController _folio;
  late final TextEditingController _operador;
  late final TextEditingController _producto;
  late final TextEditingController _entrada;
  late final TextEditingController _salida;
  late final TextEditingController _neto;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final d = widget.datos;
    _folio    = TextEditingController(text: d['folio']?.toString()        ?? '');
    _operador = TextEditingController(text: d['operador']?.toString()     ?? '');
    _producto = TextEditingController(text: d['producto']?.toString()     ?? '');
    _entrada  = TextEditingController(text: d['peso_entrada']?.toString() ?? '');
    _salida   = TextEditingController(text: d['peso_salida']?.toString()  ?? '');
    _neto     = TextEditingController(text: d['peso_neto']?.toString()    ?? '');
  }

  @override
  void dispose() {
    for (final c in [_folio, _operador, _producto, _entrada, _salida, _neto])
      c.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_folio.text.trim().isEmpty || _operador.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Folio y operador son obligatorios.')));
      return;
    }
    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('registros_toneladas')
          .doc(widget.docId)
          .set({
        'folio':            _folio.text.trim(),
        'operador':         _operador.text.trim(),
        'producto':         _producto.text.trim(),
        'peso_entrada':     double.tryParse(_entrada.text.trim()) ?? 0,
        'peso_salida':      double.tryParse(_salida.text.trim())  ?? 0,
        'peso_neto':        double.tryParse(_neto.text.trim())    ?? 0,
        'admin_editado':    true,
        'admin_editado_en': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro actualizado.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Editar registro',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            for (final entry in [
              ['Folio',        _folio,    TextInputType.text],
              ['Operador',     _operador, TextInputType.text],
              ['Producto',     _producto, TextInputType.text],
              ['Peso Entrada', _entrada,  TextInputType.number],
              ['Peso Salida',  _salida,   TextInputType.number],
              ['Peso Neto',    _neto,     TextInputType.number],
            ]) ...[
              TextField(
                controller:   entry[1] as TextEditingController,
                keyboardType: entry[2] as TextInputType,
                decoration: InputDecoration(
                  labelText: entry[0] as String,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _kBlue),
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 16),
                label: Text(_guardando ? 'Guardando…' : 'Guardar'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen principal
// ─────────────────────────────────────────────────────────────────────────────
class ReporteToneladasAdminScreen extends StatefulWidget {
  const ReporteToneladasAdminScreen({super.key});

  @override
  State<ReporteToneladasAdminScreen> createState() =>
      _ReporteToneladasAdminScreenState();
}

class _ReporteToneladasAdminScreenState
    extends State<ReporteToneladasAdminScreen> {

  String    _filtroTiempo = 'Día';
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool      _exportando   = false;

  // ── CAMBIO 2: filtros INDEPENDIENTES y COMBINABLES ────────────────────────
  // Ahora operador y material son filtros separados que se aplican juntos
  String? _operadorSeleccionado = 'Todos';
  String? _materialSeleccionado = 'Todos';

  List<String> _operadores = ['Todos'];
  List<String> _materiales = ['Todos'];

  @override
  void initState() {
    super.initState();
    _cargarOpciones();
  }

  Future<void> _cargarOpciones() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('registros_toneladas')
          .get();

      final ops  = snap.docs
          .map((d) => d['operador']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList()..sort();

      final mats = snap.docs
          .map((d) => d['producto']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList()..sort();

      setState(() {
        _operadores = ['Todos', ...ops];
        _materiales = ['Todos', ...mats];
      });
    } catch (e) {
      debugPrint('Error cargando opciones: $e');
    }
  }

  // ── Helpers generales ─────────────────────────────────────────────────────
  DateTime _soloFecha(DateTime f) => DateTime(f.year, f.month, f.day);

  String _fmtFecha(DateTime? f) =>
      f == null ? '--/--/----' : DateFormat('dd/MM/yyyy').format(f);

  String _mensajeDescarga() {
    if (kIsWeb) return 'El archivo se descarga en la carpeta del navegador.';
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS))
      return 'El archivo se guarda en la carpeta Downloads.';
    return 'En móvil se abre el selector para compartir el archivo.';
  }

  Directory _downloadsDir() {
    if (Platform.isWindows) {
      final base = Platform.environment['USERPROFILE'] ?? Directory.current.path;
      return Directory('$base\\Downloads');
    }
    final base = Platform.environment['HOME'] ?? Directory.current.path;
    return Directory('$base/Downloads');
  }

  // ── Selectores independientes ─────────────────────────────────────────────
  Future<void> _mostrarSelectorOperador() async {
    final sel = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SelectorBottomSheet(
        items:        _operadores,
        seleccionado: _operadorSeleccionado ?? 'Todos',
        titulo:       'Seleccionar operador',
        icono:        Icons.person_rounded,
      ),
    );
    if (sel != null) setState(() => _operadorSeleccionado = sel);
  }

  Future<void> _mostrarSelectorMaterial() async {
    final sel = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SelectorBottomSheet(
        items:        _materiales,
        seleccionado: _materialSeleccionado ?? 'Todos',
        titulo:       'Seleccionar material',
        icono:        Icons.category_rounded,
      ),
    );
    if (sel != null) setState(() => _materialSeleccionado = sel);
  }

  // ── Query con filtros combinados ──────────────────────────────────────────
  // Nota: Firestore no permite dos where en campos distintos sin índice compuesto.
  // Aplicamos el segundo filtro en memoria para evitar requerir índice extra.
  Query _query() {
    Query q = FirebaseFirestore.instance.collection('registros_toneladas');

    // Aplicamos en Firestore solo UN filtro (el más restrictivo primero)
    final filtrarOp  = _operadorSeleccionado != null && _operadorSeleccionado != 'Todos';
    final filtrarMat = _materialSeleccionado != null && _materialSeleccionado != 'Todos';

    if (filtrarOp) {
      q = q.where('operador', isEqualTo: _operadorSeleccionado);
    } else if (filtrarMat) {
      q = q.where('producto', isEqualTo: _materialSeleccionado);
    }

    // Rango de fechas
    final tieneRango = _fechaInicio != null || _fechaFin != null;
    if (tieneRango) {
      if (_fechaInicio != null)
        q = q.where('fecha_registro',
            isGreaterThanOrEqualTo: _soloFecha(_fechaInicio!));
      if (_fechaFin != null)
        q = q.where('fecha_registro',
            isLessThanOrEqualTo: _soloFecha(_fechaFin!)
                .add(const Duration(days: 1))
                .subtract(const Duration(milliseconds: 1)));
    } else {
      final ahora = DateTime.now();
      DateTime? limite;
      if (_filtroTiempo == 'Día')    limite = DateTime(ahora.year, ahora.month, ahora.day);
      if (_filtroTiempo == 'Semana') limite = ahora.subtract(Duration(days: ahora.weekday - 1));
      if (_filtroTiempo == 'Mes')    limite = DateTime(ahora.year, ahora.month, 1);
      if (_filtroTiempo == 'Año')    limite = DateTime(ahora.year, 1, 1);
      if (limite != null)
        q = q.where('fecha_registro', isGreaterThanOrEqualTo: limite);
    }

    return q.orderBy('fecha_registro', descending: true);
  }

  // Filtrado en memoria para el segundo filtro combinado
  List<QueryDocumentSnapshot> _filtrarEnMemoria(List<QueryDocumentSnapshot> docs) {
    final filtrarOp  = _operadorSeleccionado != null && _operadorSeleccionado != 'Todos';
    final filtrarMat = _materialSeleccionado != null && _materialSeleccionado != 'Todos';

    // Si ambos están activos, el que no fue al Firestore se aplica aquí
    if (filtrarOp && filtrarMat) {
      return docs.where((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return d['producto']?.toString() == _materialSeleccionado;
      }).toList();
    }
    return docs;
  }

  // ── Eliminar ──────────────────────────────────────────────────────────────
  Future<void> _eliminar(String docId, String folio) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _kDangerBg, shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline_rounded, color: _kDanger, size: 30),
                ),
                const SizedBox(height: 14),
                Text('Eliminar folio "$folio"',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('Esta acción no se puede deshacer.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kDanger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Eliminar',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ) ??
        false;

    if (!ok) return;
    try {
      await FirebaseFirestore.instance
          .collection('registros_toneladas')
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Registro eliminado'),
          backgroundColor: _kDanger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        _cargarOpciones();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  // ── Excel ─────────────────────────────────────────────────────────────────
  Future<void> _exportarExcel(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay registros para exportar.')));
      return;
    }
    setState(() => _exportando = true);
    try {
      final excel = ex.Excel.createExcel();
      final base  = excel.tables.keys.first;
      if (base != 'Toneladas') excel.rename(base, 'Toneladas');
      final sheet = excel['Toneladas'];
      for (final h in excel.tables.keys.where((n) => n != 'Toneladas').toList())
        excel.delete(h);

      sheet.appendRow([
        ex.TextCellValue('FECHA'),
        ex.TextCellValue('HORA'),
        ex.TextCellValue('FOLIO'),
        ex.TextCellValue('CONDUCTOR'),
        ex.TextCellValue('CAMIÓN'),
        ex.TextCellValue('PLACAS'),
        ex.TextCellValue('PRODUCTO'),
        ex.TextCellValue('PESO ENTRADA (KG)'),
        ex.TextCellValue('PESO SALIDA (KG)'),
        ex.TextCellValue('PESO NETO (KG)'),
      ]);

      for (final doc in docs) {
        final d = doc.data();
        final fechaTexto = d['fecha_texto']?.toString() ?? '';
        final partes = fechaTexto.split(' ');
        final fecha  = partes.isNotEmpty ? partes[0] : '';
        final hora   = partes.length > 1 ? partes[1] : '';

        sheet.appendRow([
          ex.TextCellValue(fecha),
          ex.TextCellValue(hora),
          ex.TextCellValue(d['folio']?.toString()    ?? ''),
          ex.TextCellValue(d['operador']?.toString() ?? ''),
          ex.TextCellValue(d['camion']?.toString()   ?? ''),
          ex.TextCellValue(d['placas']?.toString()   ?? ''),
          ex.TextCellValue(d['producto']?.toString() ?? ''),
          ex.DoubleCellValue((d['peso_entrada'] as num?)?.toDouble() ?? 0),
          ex.DoubleCellValue((d['peso_salida']  as num?)?.toDouble() ?? 0),
          ex.DoubleCellValue((d['peso_neto']    as num?)?.toDouble() ?? 0),
        ]);
      }

      final bytes  = excel.encode();
      if (bytes == null) throw Exception('No se pudo generar el archivo.');
      final nombre =
          'reporte_toneladas_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final esEscritorio =
          !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

      if (kIsWeb) {
        await downloadFile(Uint8List.fromList(bytes), nombre,
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Archivo Excel descargado.')));
        return;
      }
      final dir = esEscritorio ? _downloadsDir() : Directory.systemTemp;
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('${dir.path}/$nombre');
      await file.writeAsBytes(List<int>.from(bytes), flush: true);
      if (esEscritorio) {
        if (mounted) ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Guardado en: ${file.path}')));
      } else {
        await Share.shareXFiles([XFile(file.path)], text: 'Reporte de toneladas');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  // ── CAMBIO 1: PDF dinámico con logo ───────────────────────────────────────
  // Cada registro tiene altura fija estimada; llenamos la página hasta que no
  // quepa el siguiente y solo entonces abrimos una nueva página.
  Future<void> _exportarPDF(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay registros para exportar.')));
      return;
    }
    setState(() => _exportando = true);
    try {
      // Cargar logo desde assets
      pw.ImageProvider? logoImage;
      try {
        final logoData =
            await rootBundle.load('assets/images/logo 2 recicladora.png');
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {
        // Si no existe el asset, seguimos sin logo
      }

      final double pageH        = PdfPageFormat.a4.height;
      final double pageW        = PdfPageFormat.a4.width;
      const double margin       = 28.0;
      const double headerH      = 52.0;  // alto del encabezado de página
      const double recordH      = 158.0; // alto estimado de una tarjeta de registro
      const double recordGap    = 12.0;  // espacio entre registros
      final double usableH      = pageH - margin * 2 - headerH - 8;

      // Cuántos registros caben por página
      int _porPagina(double disponible) {
        int n = 0;
        double usado = 0;
        while (true) {
          final sig = (n == 0 ? 0 : recordGap) + recordH;
          if (usado + sig > disponible) break;
          usado += sig;
          n++;
        }
        return n == 0 ? 1 : n; // al menos 1 aunque sea muy grande
      }

      final regPorPagina = _porPagina(usableH);
      final totalPaginas = (docs.length / regPorPagina).ceil();

      final pdf = pw.Document();

      for (int p = 0; p < totalPaginas; p++) {
        final inicio = p * regPorPagina;
        final fin    = (inicio + regPorPagina).clamp(0, docs.length);
        final grupo  = docs.sublist(inicio, fin);

        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat(pageW, pageH,
              marginAll: margin),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Encabezado de página con logo ─────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal700,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo + nombre empresa
                    pw.Row(children: [
                      if (logoImage != null) ...[
                        pw.Container(
                          width: 36, height: 36,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),
                        pw.SizedBox(width: 10),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Recicladora Guadalajara',
                              style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.Text('Reporte de Toneladas',
                              style: pw.TextStyle(
                                  color: PdfColors.white.shade(0.7), fontSize: 10)),
                        ],
                      ),
                    ]),
                    // Página y fecha
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Pág. ${p + 1} / $totalPaginas',
                            style: const pw.TextStyle(
                                color: PdfColors.white, fontSize: 11)),
                        pw.Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                          style: pw.TextStyle(
                              color: PdfColors.white.shade(0.7), fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // ── Registros del grupo ───────────────────────────────
              ...grupo.asMap().entries.map((entry) {
                final d = entry.value.data() as Map<String, dynamic>;
                return pw.Container(
                  margin: pw.EdgeInsets.only(
                      top: entry.key == 0 ? 0 : recordGap),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Sub-encabezado
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.teal50,
                          borderRadius: pw.BorderRadius.only(
                            topLeft:  pw.Radius.circular(6),
                            topRight: pw.Radius.circular(6),
                          ),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'PAPELETA DE ENTRADA  —  Folio: ${d['folio'] ?? '—'}',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 11,
                                  color: PdfColors.teal900),
                            ),
                            pw.Text(
                              d['fecha_texto']?.toString() ?? '',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey700),
                            ),
                          ],
                        ),
                      ),
                      // Cuerpo: 2 columnas
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            // Columna izquierda: transporte
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  _pdfLabel('DATOS DEL TRANSPORTE'),
                                  pw.SizedBox(height: 5),
                                  _pdfRow('Conductor', d['operador'] ?? '—'),
                                  _pdfRow('Camión',    d['camion']   ?? '—'),
                                  _pdfRow('Placas',    d['placas']   ?? '—'),
                                  _pdfRow('Producto',  d['producto'] ?? '—'),
                                ],
                              ),
                            ),
                            pw.SizedBox(width: 16),
                            // Columna derecha: pesos
                            pw.Container(
                              width: 180,
                              padding: const pw.EdgeInsets.all(10),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(
                                    color: PdfColors.grey300, width: 0.8),
                                borderRadius: pw.BorderRadius.circular(4),
                                color: PdfColors.grey50,
                              ),
                              child: pw.Column(children: [
                                _pdfLabel('PESOS'),
                                pw.SizedBox(height: 6),
                                _pdfPeso('Peso Entrada',
                                    '${d['peso_entrada'] ?? 0} kg'),
                                _pdfPeso('Peso Salida',
                                    '${d['peso_salida'] ?? 0} kg'),
                                pw.Divider(
                                    color: PdfColors.teal700,
                                    thickness: 0.8),
                                pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('NETO:',
                                        style: pw.TextStyle(
                                            fontWeight: pw.FontWeight.bold,
                                            fontSize: 13,
                                            color: PdfColors.teal900)),
                                    pw.Text(
                                      '${NumberFormat('#,###').format(d['peso_neto'] ?? 0)} kg',
                                      style: pw.TextStyle(
                                          fontWeight: pw.FontWeight.bold,
                                          fontSize: 15,
                                          color: PdfColors.red700),
                                    ),
                                  ],
                                ),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ));
      }

      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error PDF: $e')));
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  // Helpers PDF
  pw.Widget _pdfLabel(String texto) => pw.Text(texto,
      style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
          color: PdfColors.teal800,
          letterSpacing: 0.5));

  pw.Widget _pdfRow(String label, String valor) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text('$label:',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                    color: PdfColors.grey800)),
          ),
          pw.Expanded(
            child: pw.Text(valor,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
          ),
        ]),
      );

  pw.Widget _pdfPeso(String label, String valor) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text(valor,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                    color: PdfColors.black)),
          ],
        ),
      );

  // ── Selector de fecha ─────────────────────────────────────────────────────
  Future<void> _pickFecha({required bool esInicio}) async {
    final ahora = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _soloFecha(esInicio
          ? (_fechaInicio ?? _fechaFin ?? ahora)
          : (_fechaFin ?? _fechaInicio ?? ahora)),
      firstDate: esInicio
          ? DateTime(2020)
          : (_fechaInicio != null ? _soloFecha(_fechaInicio!) : DateTime(2020)),
      lastDate: esInicio
          ? (_fechaFin != null ? _soloFecha(_fechaFin!) : ahora)
          : ahora,
      locale: const Locale('es', 'MX'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _kBlue,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: _kBlue,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (esInicio) {
        _fechaInicio = _soloFecha(picked);
        if (_fechaFin != null && _fechaFin!.isBefore(_fechaInicio!))
          _fechaFin = null;
      } else {
        _fechaFin = _soloFecha(picked);
      }
    });
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        toolbarHeight: 64,
        title: const Text('Reporte de Toneladas',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kBlue, _kBlue2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(children: [
          _Banner(),
          const SizedBox(height: 12),

          // ── Panel de filtros ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBFDBFE)),
              boxShadow: const [
                BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: Column(children: [
              // Chips de periodo
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Día', 'Semana', 'Mes', 'Año', 'Todos'].map((t) {
                    final sel = _filtroTiempo == t;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(t),
                        selected: sel,
                        selectedColor: _kBlue,
                        backgroundColor: const Color(0xFFEFF6FF),
                        labelStyle: TextStyle(
                            color: sel ? Colors.white : _kBlue,
                            fontWeight: FontWeight.w700),
                        side: BorderSide(color: _kBlue.withOpacity(0.22)),
                        onSelected: (_) => setState(() => _filtroTiempo = t),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // ── CAMBIO 2: Dos selectores independientes en paralelo ──
              // Se muestran los dos siempre, cada uno con su valor.
              // Ambos filtros se combinan en la query.
              Row(children: [
                // Selector operador
                Expanded(
                  child: GestureDetector(
                    onTap: _mostrarSelectorOperador,
                    child: _FiltroChip(
                      icono:  Icons.person_rounded,
                      titulo: 'Operador',
                      valor:  _operadorSeleccionado == 'Todos' || _operadorSeleccionado == null
                          ? 'Todos'
                          : _operadorSeleccionado!,
                      activo: _operadorSeleccionado != null &&
                          _operadorSeleccionado != 'Todos',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Selector material
                Expanded(
                  child: GestureDetector(
                    onTap: _mostrarSelectorMaterial,
                    child: _FiltroChip(
                      icono:  Icons.category_rounded,
                      titulo: 'Material',
                      valor:  _materialSeleccionado == 'Todos' || _materialSeleccionado == null
                          ? 'Todos'
                          : _materialSeleccionado!,
                      activo: _materialSeleccionado != null &&
                          _materialSeleccionado != 'Todos',
                    ),
                  ),
                ),
              ]),

              // Indicador de filtro combinado activo
              if ((_operadorSeleccionado != null && _operadorSeleccionado != 'Todos') &&
                  (_materialSeleccionado != null && _materialSeleccionado != 'Todos')) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _kBlue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kBlue.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.filter_alt_rounded, color: _kBlue, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Mostrando $_operadorSeleccionado + $_materialSeleccionado',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: _kBlue),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _operadorSeleccionado = 'Todos';
                        _materialSeleccionado = 'Todos';
                      }),
                      child: const Icon(Icons.close_rounded, color: _kBlue, size: 16),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 12),

              // Botones exportar
              Row(children: [
                Expanded(
                  child: _ExportBtn(
                    label:   'Excel',
                    icon:    Icons.download_rounded,
                    color:   _kBlue,
                    loading: _exportando,
                    onPressed: () async {
                      final snap = await _query().get();
                      final docs = _filtrarEnMemoria(snap.docs)
                          .cast<QueryDocumentSnapshot<Map<String, dynamic>>>()
                          .toList();
                      await _exportarExcel(docs);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ExportBtn(
                    label:   'PDF',
                    icon:    Icons.picture_as_pdf_rounded,
                    color:   _kDanger,
                    loading: _exportando,
                    onPressed: () async {
                      final snap = await _query().get();
                      final docs = _filtrarEnMemoria(snap.docs)
                          .cast<QueryDocumentSnapshot<Map<String, dynamic>>>()
                          .toList();
                      await _exportarPDF(docs);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_mensajeDescarga(),
                    style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 12),

              // Rango de fechas
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FBFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rango de fechas',
                        style: TextStyle(
                            color: _kBlue, fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _DateBtn(
                          label: 'Inicio: ${_fmtFecha(_fechaInicio)}',
                          icon:  Icons.date_range_rounded,
                          onTap: () => _pickFecha(esInicio: true),
                        ),
                        _DateBtn(
                          label: 'Fin: ${_fmtFecha(_fechaFin)}',
                          icon:  Icons.event_available_rounded,
                          onTap: () => _pickFecha(esInicio: false),
                        ),
                        if (_fechaInicio != null || _fechaFin != null)
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _fechaInicio = null;
                              _fechaFin    = null;
                            }),
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            label: const Text('Limpiar'),
                            style: TextButton.styleFrom(foregroundColor: _kBlue),
                          ),
                      ],
                    ),
                    if (_fechaInicio != null || _fechaFin != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Del ${_fmtFecha(_fechaInicio)} al ${_fmtFecha(_fechaFin)}',
                        style: const TextStyle(
                            color: Color(0xFF4B5563), fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),

          // ── Tabla ────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _query().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snap.error}\n(Verifica índices en Firestore)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _kDanger),
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: _kBlue));
                }

                final todosLosDocs = snap.data!.docs;
                // Aplicar filtro en memoria (segundo filtro combinado)
                final docs = _filtrarEnMemoria(todosLosDocs);

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_rounded, size: 52, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        const Text('No hay registros para este filtro.',
                            style: TextStyle(color: Color(0xFF94A3B8))),
                      ],
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x10000000),
                          blurRadius: 12,
                          offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                      child: Row(children: [
                        const Icon(Icons.inventory_2_rounded,
                            size: 17, color: _kBlue),
                        const SizedBox(width: 6),
                        const Text('Registros:',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(width: 6),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text('${docs.length}',
                              key: ValueKey(docs.length),
                              style: const TextStyle(
                                  color: _kBlue,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                        ),
                      ]),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(_kBlue),
                            dataRowMinHeight: 46,
                            dataRowMaxHeight: 52,
                            horizontalMargin: 14,
                            columnSpacing: 18,
                            columns: const [
                              DataColumn(label: Text('FECHA',    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('FOLIO',    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('OPERADOR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('PRODUCTO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('NETO (KG)',style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('EDITAR',   style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('ELIMINAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                            ],
                            rows: docs.map((doc) {
                              final d = doc.data() as Map<String, dynamic>;
                              return DataRow(cells: [
                                DataCell(Text(d['fecha_texto'] ?? '',
                                    style: const TextStyle(fontSize: 13))),
                                DataCell(Text(d['folio'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 13))),
                                DataCell(Text(d['operador'] ?? '',
                                    style: const TextStyle(fontSize: 13))),
                                DataCell(Text(d['producto'] ?? '',
                                    style: const TextStyle(fontSize: 13))),
                                DataCell(Text(
                                  NumberFormat('#,###').format(d['peso_neto'] ?? 0),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 13),
                                )),
                                DataCell(IconButton(
                                  tooltip: 'Editar',
                                  icon: const Icon(Icons.edit_rounded,
                                      color: _kBlue, size: 20),
                                  onPressed: () async {
                                    await showDialog<void>(
                                      context: context,
                                      builder: (_) =>
                                          _EditarDialog(docId: doc.id, datos: d),
                                    );
                                    _cargarOpciones();
                                  },
                                )),
                                DataCell(IconButton(
                                  tooltip: 'Eliminar',
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      color: _kDanger, size: 20),
                                  onPressed: () =>
                                      _eliminar(doc.id, d['folio'] ?? ''),
                                )),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget chip de filtro (operador / material)
// ─────────────────────────────────────────────────────────────────────────────
class _FiltroChip extends StatelessWidget {
  final IconData icono;
  final String   titulo;
  final String   valor;
  final bool     activo;

  const _FiltroChip({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.activo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:  activo ? _kBlue.withOpacity(0.08) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: activo ? _kBlue : const Color(0xFFBFDBFE), width: activo ? 1.5 : 1),
      ),
      child: Row(children: [
        Icon(icono, color: _kBlue, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: _kBlue.withOpacity(0.7))),
            Text(valor,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: activo ? _kBlue : const Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        Icon(Icons.keyboard_arrow_down_rounded,
            color: _kBlue, size: 18),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BottomSheet selector genérico
// ─────────────────────────────────────────────────────────────────────────────
class _SelectorBottomSheet extends StatefulWidget {
  final List<String> items;
  final String       seleccionado;
  final String       titulo;
  final IconData     icono;

  const _SelectorBottomSheet({
    required this.items,
    required this.seleccionado,
    required this.titulo,
    required this.icono,
  });

  @override
  State<_SelectorBottomSheet> createState() => _SelectorBottomSheetState();
}

class _SelectorBottomSheetState extends State<_SelectorBottomSheet> {
  late String      _sel;
  final _search  = TextEditingController();
  List<String>    _filtrados = [];

  @override
  void initState() {
    super.initState();
    _sel       = widget.seleccionado;
    _filtrados = widget.items;
    _search.addListener(() {
      final q = _search.text.toLowerCase();
      setState(() =>
          _filtrados = widget.items.where((o) => o.toLowerCase().contains(q)).toList());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _kBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(widget.icono, color: _kBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Text(widget.titulo,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Buscar…',
              prefixIcon: const Icon(Icons.search_rounded, color: _kBlue),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _filtrados.length,
            itemBuilder: (_, i) {
              final item = _filtrados[i];
              final sel  = item == _sel;
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: sel ? _kBlue : _kBlue.withOpacity(0.1),
                  child: item == 'Todos'
                      ? Icon(Icons.all_inclusive_rounded,
                          color: sel ? Colors.white : _kBlue, size: 16)
                      : Text(
                          item.substring(0, item.length.clamp(0, 1)).toUpperCase(),
                          style: TextStyle(
                              color: sel ? Colors.white : _kBlue,
                              fontWeight: FontWeight.w800,
                              fontSize: 12),
                        ),
                ),
                title: Text(item,
                    style: TextStyle(
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                        color: sel ? _kBlue : const Color(0xFF0F172A),
                        fontSize: 14)),
                trailing: sel
                    ? const Icon(Icons.check_circle_rounded,
                        color: _kBlue, size: 20)
                    : null,
                onTap: () => Navigator.of(context).pop(item),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────
class _Banner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kBlue, Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: _kBlue.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.scale_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Panel de Control de Toneladas',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            SizedBox(height: 3),
            Text('Consulta y genera papeletas administrativas.',
                style: TextStyle(color: Colors.white70, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }
}

class _ExportBtn extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final bool         loading;
  final VoidCallback onPressed;

  const _ExportBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(icon, size: 18),
      label: Text(loading ? 'Exportando…' : label,
          style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _DateBtn extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final VoidCallback onTap;

  const _DateBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _kBlue,
        side: const BorderSide(color: Color(0xFFBFDBFE)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}