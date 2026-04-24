import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../utils/download_file.dart';

enum _FiltroPeriodo { semana, mensual, anual, todos }

class ReporteGasolinaCamionesScreen extends StatefulWidget {
  const ReporteGasolinaCamionesScreen({super.key});

  @override
  State<ReporteGasolinaCamionesScreen> createState() =>
      _ReporteGasolinaCamionesScreenState();
}

class _ReporteGasolinaCamionesScreenState
    extends State<ReporteGasolinaCamionesScreen> {
  static const Color _greenPrimary = Color(0xFF0F766E);
  static const Color _greenSecondary = Color(0xFF10B981);
  static const Color _bg = Color(0xFFF1FBF7);

  _FiltroPeriodo _filtro = _FiltroPeriodo.todos;
  bool _exportando = false;

  String _mensajeDescargaPorPlataforma() {
    if (kIsWeb) {
      return 'En web, el archivo Excel se descarga en la carpeta predeterminada del navegador.';
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'En computadora, el archivo Excel se guarda en la carpeta Downloads.';
    }

    return 'En movil, al exportar se abre el selector para compartir el archivo Excel.';
  }

  Directory _directorioDescargasEscritorio() {
    if (Platform.isWindows) {
      final base =
          Platform.environment['USERPROFILE'] ?? Directory.current.path;
      return Directory('$base\\Downloads');
    }

    final base = Platform.environment['HOME'] ?? Directory.current.path;
    return Directory('$base/Downloads');
  }

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _coincidePeriodo(DateTime fecha) {
    final ahora = DateTime.now();

    switch (_filtro) {
      case _FiltroPeriodo.semana:
        return fecha.isAfter(ahora.subtract(const Duration(days: 7)));
      case _FiltroPeriodo.mensual:
        return fecha.year == ahora.year && fecha.month == ahora.month;
      case _FiltroPeriodo.anual:
        return fecha.year == ahora.year;
      case _FiltroPeriodo.todos:
        return true;
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrarRegistros(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final fecha = _toDate(doc.data()['fecha']);
      if (fecha == null) return _filtro == _FiltroPeriodo.todos;
      return _coincidePeriodo(fecha);
    }).toList();
  }

  String _valorMostrado(Map<String, dynamic> registro, String campo) {
    final manual = registro['admin_manual'];
    if (manual is Map<String, dynamic>) {
      final valorManual = manual[campo];
      if (valorManual != null && valorManual.toString().trim().isNotEmpty) {
        return valorManual.toString();
      }
    }

    final valor = registro[campo];
    if (valor == null) return '';
    return valor.toString();
  }

  String _automovilMostrado(Map<String, dynamic> registro) {
    final manual = registro['admin_manual'];
    if (manual is Map<String, dynamic>) {
      final valorManual = manual['automovil'];
      if (valorManual != null && valorManual.toString().trim().isNotEmpty) {
        return valorManual.toString();
      }
    }
    return (registro['automovil'] ?? registro['camion'] ?? '').toString();
  }

  bool _tieneTicket(Map<String, dynamic> registro) {
    final ticket = registro['ticket_url'];
    return ticket != null && ticket.toString().trim().isNotEmpty;
  }

  Future<void> _copiarDatosRegistro(Map<String, dynamic> registro) async {
    final fecha = _toDate(registro['fecha']);
    final texto = [
      'FECHA: ${fecha == null ? '-' : DateFormat('dd/MM/yyyy').format(fecha)}',
      'FOLIO: ${_valorMostrado(registro, 'folio')}',
      'CONCEPTO: ${_valorMostrado(registro, 'concepto').toUpperCase()}',
      'AUTOMOVIL: ${_automovilMostrado(registro).toUpperCase()}',
      'CANTIDAD: ${_valorMostrado(registro, 'cantidad')}',
      'UNIDAD: ${_valorMostrado(registro, 'unidad').toUpperCase()}',
      'MONTO: ${_valorMostrado(registro, 'monto')}',
      'METODO PAGO: ${_valorMostrado(registro, 'metodo_pago').toUpperCase()}',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Datos copiados al portapapeles.')),
    );
  }

  Future<void> _abrirRevisionRegistro(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _RevisionTicketGasolinaDialog(doc: doc),
    );
  }

  Future<void> _exportarExcel(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para exportar.')),
      );
      return;
    }

    setState(() => _exportando = true);

    try {
      final excel = ex.Excel.createExcel();
      final nombresHojas = excel.tables.keys.toList();

      if (nombresHojas.isEmpty) {
        throw Exception('No se pudo inicializar la hoja de Excel.');
      }

      final hojaBase = nombresHojas.first;
      if (hojaBase != 'Gasolina') {
        excel.rename(hojaBase, 'Gasolina');
      }
      final sheet = excel['Gasolina'];

      // Seguridad extra: elimina hojas residuales y deja solo "Gasolina".
      final otrasHojas = excel.tables.keys
          .where((name) => name != 'Gasolina')
          .toList();
      for (final hoja in otrasHojas) {
        excel.delete(hoja);
      }

      sheet.appendRow([
        ex.TextCellValue('FECHA'),
        ex.TextCellValue('FOLIO'),
        ex.TextCellValue('CONCEPTO'),
        ex.TextCellValue('AUTOMOVIL'),
        ex.TextCellValue('CANTIDAD'),
        ex.TextCellValue('KG/LT'),
        ex.TextCellValue('MONTO'),
        ex.TextCellValue('METODO DE PAGO'),
      ]);

      final fechaFormat = DateFormat('dd/MM/yyyy');

      for (final doc in docs) {
        final r = doc.data();
        final fecha = _toDate(r['fecha']);
        sheet.appendRow([
          ex.TextCellValue(fecha == null ? '-' : fechaFormat.format(fecha)),
          ex.TextCellValue(_valorMostrado(r, 'folio')),
          ex.TextCellValue(_valorMostrado(r, 'concepto').toUpperCase()),
          ex.TextCellValue(_automovilMostrado(r).toUpperCase()),
          ex.TextCellValue(_valorMostrado(r, 'cantidad')),
          ex.TextCellValue(_valorMostrado(r, 'unidad').toUpperCase()),
          ex.TextCellValue(_valorMostrado(r, 'monto')),
          ex.TextCellValue(_valorMostrado(r, 'metodo_pago').toUpperCase()),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('No se pudo generar el archivo.');
      final excelBytes = bytes is List<int> ? bytes : List<int>.from(bytes);

      final nombre =
          'reporte_gasolina_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

      final esEscritorio =
          !kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

      if (kIsWeb) {
        await downloadFile(
          Uint8List.fromList(excelBytes),
          nombre,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archivo Excel descargado.')),
        );
        return;
      }

      final dir = esEscritorio
          ? _directorioDescargasEscritorio()
          : Directory.systemTemp;

      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final file = File('${dir.path}/$nombre');
      await file.writeAsBytes(excelBytes, flush: true);

      if (esEscritorio) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archivo Excel guardado en: ${file.path}')),
        );
      } else {
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Reporte de gasolina de camiones');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
    } finally {
      if (mounted) {
        setState(() => _exportando = false);
      }
    }
  }

  String _labelFiltro(_FiltroPeriodo filtro) {
    switch (filtro) {
      case _FiltroPeriodo.semana:
        return 'Semana';
      case _FiltroPeriodo.mensual:
        return 'Mensual';
      case _FiltroPeriodo.anual:
        return 'Anual';
      case _FiltroPeriodo.todos:
        return 'Todos';
    }
  }

  IconData _iconoFiltro(_FiltroPeriodo filtro) {
    switch (filtro) {
      case _FiltroPeriodo.semana:
        return Icons.date_range_rounded;
      case _FiltroPeriodo.mensual:
        return Icons.calendar_month_rounded;
      case _FiltroPeriodo.anual:
        return Icons.event_repeat_rounded;
      case _FiltroPeriodo.todos:
        return Icons.all_inclusive_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Reporte de Gasolina',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: _greenPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_greenPrimary, _greenSecondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('registros_gasolina')
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error cargando registros.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final filtrados = _filtrarRegistros(docs);

          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 18 * (1 - value)),
                      child: Opacity(opacity: value, child: child),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_greenPrimary, _greenSecondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: _greenPrimary.withValues(alpha: 0.24),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.local_gas_station_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Control Administrativo de Gasolina',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Registros visibles: ${filtrados.length}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBAE6D3)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _FiltroPeriodo.values.map((f) {
                            final selected = _filtro == f;
                            return ChoiceChip(
                              avatar: Icon(
                                _iconoFiltro(f),
                                size: 14,
                                color: selected ? Colors.white : _greenPrimary,
                              ),
                              label: Text(_labelFiltro(f)),
                              selected: selected,
                              selectedColor: _greenPrimary,
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : _greenPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              side: BorderSide(
                                color: _greenPrimary.withValues(alpha: 0.24),
                              ),
                              onSelected: (_) => setState(() => _filtro = f),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _greenPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _exportando
                            ? null
                            : () => _exportarExcel(filtrados),
                        icon: _exportando
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_rounded),
                        label: Text(_exportando ? 'Exportando' : 'Excel'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _mensajeDescargaPorPlataforma(),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCDEBDD)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: filtrados.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay registros para el periodo seleccionado.',
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  _greenPrimary,
                                ),
                                headingTextStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                                dataTextStyle: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 13,
                                ),
                                columns: const [
                                  DataColumn(label: Text('FECHA')),
                                  DataColumn(label: Text('FOLIO')),
                                  DataColumn(label: Text('CONCEPTO')),
                                  DataColumn(label: Text('AUTOMOVIL')),
                                  DataColumn(label: Text('CANTIDAD')),
                                  DataColumn(label: Text('KG/LT')),
                                  DataColumn(label: Text('MONTO')),
                                  DataColumn(label: Text('METODO DE PAGO')),
                                  DataColumn(label: Text('TICKET')),
                                  DataColumn(label: Text('ACCIONES')),
                                ],
                                rows: filtrados.map((doc) {
                                  final r = doc.data();
                                  final fecha = _toDate(r['fecha']);
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          fecha == null
                                              ? '-'
                                              : DateFormat(
                                                  'dd/MM/yyyy',
                                                ).format(fecha),
                                        ),
                                      ),
                                      DataCell(
                                        Text(_valorMostrado(r, 'folio')),
                                      ),
                                      DataCell(
                                        Text(
                                          _valorMostrado(
                                            r,
                                            'concepto',
                                          ).toUpperCase(),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _automovilMostrado(r).toUpperCase(),
                                        ),
                                      ),
                                      DataCell(
                                        Text(_valorMostrado(r, 'cantidad')),
                                      ),
                                      DataCell(
                                        Text(
                                          _valorMostrado(
                                            r,
                                            'unidad',
                                          ).toUpperCase(),
                                        ),
                                      ),
                                      DataCell(
                                        Text(_valorMostrado(r, 'monto')),
                                      ),
                                      DataCell(
                                        Text(
                                          _valorMostrado(
                                            r,
                                            'metodo_pago',
                                          ).toUpperCase(),
                                        ),
                                      ),
                                      DataCell(
                                        _tieneTicket(r)
                                            ? TextButton.icon(
                                                onPressed: () =>
                                                    _abrirRevisionRegistro(doc),
                                                icon: const Icon(
                                                  Icons.photo_library_rounded,
                                                  size: 16,
                                                ),
                                                label: const Text('Ver'),
                                              )
                                            : const Text('Sin foto'),
                                      ),
                                      DataCell(
                                        Wrap(
                                          spacing: 4,
                                          children: [
                                            IconButton(
                                              tooltip: 'Revisar ticket y capturar',
                                              onPressed: () =>
                                                  _abrirRevisionRegistro(doc),
                                              icon: const Icon(
                                                Icons.edit_note_rounded,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Copiar datos',
                                              onPressed: () =>
                                                  _copiarDatosRegistro(r),
                                              icon: const Icon(
                                                Icons.content_copy_rounded,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RevisionTicketGasolinaDialog extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _RevisionTicketGasolinaDialog({required this.doc});

  @override
  State<_RevisionTicketGasolinaDialog> createState() =>
      _RevisionTicketGasolinaDialogState();
}

class _RevisionTicketGasolinaDialogState
    extends State<_RevisionTicketGasolinaDialog> {
  late final TextEditingController _folioController;
  late final TextEditingController _automovilController;
  late final TextEditingController _cantidadController;
  late final TextEditingController _montoController;

  String _concepto = 'gasolina';
  String _unidad = 'litros';
  String _metodoPago = 'efectivo';
  bool _guardando = false;

  Map<String, dynamic> get _registro => widget.doc.data();

  String _baseValue(String key) {
    final manual = _registro['admin_manual'];
    if (manual is Map<String, dynamic>) {
      final valorManual = manual[key];
      if (valorManual != null && valorManual.toString().trim().isNotEmpty) {
        return valorManual.toString();
      }
    }
    final valor = _registro[key];
    return valor == null ? '' : valor.toString();
  }

  @override
  void initState() {
    super.initState();
    _folioController = TextEditingController(text: _baseValue('folio'));
    _automovilController = TextEditingController(
      text: _baseValue('automovil').isNotEmpty
          ? _baseValue('automovil')
          : _baseValue('camion'),
    );
    _cantidadController = TextEditingController(text: _baseValue('cantidad'));
    _montoController = TextEditingController(text: _baseValue('monto'));

    final concepto = _baseValue('concepto').toLowerCase();
    final unidad = _baseValue('unidad').toLowerCase();
    final metodoPago = _baseValue('metodo_pago').toLowerCase();

    if (['gasolina', 'diesel', 'gas'].contains(concepto)) {
      _concepto = concepto;
    }
    if (['litros', 'kilogramos'].contains(unidad)) {
      _unidad = unidad;
    }
    if (['efectivo', 'debito', 'credito'].contains(metodoPago)) {
      _metodoPago = metodoPago;
    }
  }

  @override
  void dispose() {
    _folioController.dispose();
    _automovilController.dispose();
    _cantidadController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _copiarDatos() async {
    final texto = [
      'FOLIO: ${_folioController.text.trim()}',
      'CONCEPTO: ${_concepto.toUpperCase()}',
      'AUTOMOVIL: ${_automovilController.text.trim().toUpperCase()}',
      'CANTIDAD: ${_cantidadController.text.trim()}',
      'UNIDAD: ${_unidad.toUpperCase()}',
      'MONTO: ${_montoController.text.trim()}',
      'METODO PAGO: ${_metodoPago.toUpperCase()}',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Datos copiados al portapapeles.')),
    );
  }

  Future<void> _guardarCapturaManual() async {
    final folio = _folioController.text.trim();
    final automovil = _automovilController.text.trim();
    final cantidad = _cantidadController.text.trim();
    final monto = _montoController.text.trim();

    if (folio.isEmpty || automovil.isEmpty || cantidad.isEmpty || monto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos.')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      await FirebaseFirestore.instance
          .collection('registros_gasolina')
          .doc(widget.doc.id)
          .set({
            'admin_manual': {
              'folio': folio,
              'concepto': _concepto,
              'automovil': automovil,
              'cantidad': cantidad,
              'unidad': _unidad,
              'monto': monto,
              'metodo_pago': _metodoPago,
            },
            'admin_captura_manual': true,
            'captura_pendiente_admin': false,
            'admin_actualizado_en': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos manuales guardados.')),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketUrl = (_registro['ticket_url'] ?? '').toString();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Revision de ticket de gasolina',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final vertical = constraints.maxWidth < 920;

                    final imagenTicket = Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: ticketUrl.isEmpty
                            ? const Center(
                                child: Text('No hay ticket cargado.'),
                              )
                            : InteractiveViewer(
                                minScale: 1,
                                maxScale: 6,
                                child: Image.network(
                                  ticketUrl,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                  loadingBuilder: (context, child, loading) {
                                    if (loading == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Text(
                                      'No se pudo cargar la imagen del ticket.',
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    );

                    final formulario = SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _folioController,
                            decoration: const InputDecoration(
                              labelText: 'Folio',
                              prefixIcon: Icon(Icons.receipt_long_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _concepto,
                            items: const [
                              DropdownMenuItem(
                                value: 'gasolina',
                                child: Text('Gasolina'),
                              ),
                              DropdownMenuItem(
                                value: 'diesel',
                                child: Text('Diesel'),
                              ),
                              DropdownMenuItem(value: 'gas', child: Text('Gas')),
                            ],
                            onChanged: (value) {
                              if (value != null) setState(() => _concepto = value);
                            },
                            decoration: const InputDecoration(
                              labelText: 'Concepto',
                              prefixIcon: Icon(Icons.category_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _automovilController,
                            decoration: const InputDecoration(
                              labelText: 'Automovil',
                              prefixIcon: Icon(Icons.local_shipping_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _cantidadController,
                            decoration: const InputDecoration(
                              labelText: 'Cantidad',
                              prefixIcon: Icon(Icons.numbers_rounded),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _unidad,
                            items: const [
                              DropdownMenuItem(
                                value: 'litros',
                                child: Text('Litros'),
                              ),
                              DropdownMenuItem(
                                value: 'kilogramos',
                                child: Text('Kilogramos'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) setState(() => _unidad = value);
                            },
                            decoration: const InputDecoration(
                              labelText: 'Unidad',
                              prefixIcon: Icon(Icons.straighten_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _montoController,
                            decoration: const InputDecoration(
                              labelText: 'Monto',
                              prefixIcon: Icon(Icons.attach_money_rounded),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _metodoPago,
                            items: const [
                              DropdownMenuItem(
                                value: 'efectivo',
                                child: Text('Efectivo'),
                              ),
                              DropdownMenuItem(
                                value: 'debito',
                                child: Text('Tarjeta Debito'),
                              ),
                              DropdownMenuItem(
                                value: 'credito',
                                child: Text('Tarjeta Credito'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _metodoPago = value);
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Metodo de pago',
                              prefixIcon: Icon(Icons.payment_rounded),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (vertical) {
                      return Column(
                        children: [
                          Expanded(flex: 6, child: imagenTicket),
                          const SizedBox(height: 12),
                          Expanded(flex: 5, child: formulario),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(flex: 6, child: imagenTicket),
                        const SizedBox(width: 14),
                        Expanded(flex: 4, child: formulario),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copiarDatos,
                      icon: const Icon(Icons.content_copy_rounded),
                      label: const Text('Copiar datos'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _guardando ? null : _guardarCapturaManual,
                      icon: _guardando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_guardando ? 'Guardando...' : 'Guardar datos'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
