import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../utils/download_file.dart';

class ReporteToneladasAdminScreen extends StatefulWidget {
  const ReporteToneladasAdminScreen({super.key});

  @override
  State<ReporteToneladasAdminScreen> createState() =>
      _ReporteToneladasAdminScreenState();
}


class _EditarRegistroToneladasDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> datos;

  const _EditarRegistroToneladasDialog({required this.docId, required this.datos});

  @override
  State<_EditarRegistroToneladasDialog> createState() =>
      _EditarRegistroToneladasDialogState();
}

class _EditarRegistroToneladasDialogState
    extends State<_EditarRegistroToneladasDialog> {
  late final TextEditingController _folioCtrl;
  late final TextEditingController _operadorCtrl;
  late final TextEditingController _productoCtrl;
  late final TextEditingController _pesoEntradaCtrl;
  late final TextEditingController _pesoSalidaCtrl;
  late final TextEditingController _pesoNetoCtrl;

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final d = widget.datos;
    _folioCtrl = TextEditingController(text: d['folio']?.toString() ?? '');
    _operadorCtrl = TextEditingController(text: d['operador']?.toString() ?? '');
    _productoCtrl = TextEditingController(text: d['producto']?.toString() ?? '');
    _pesoEntradaCtrl =
        TextEditingController(text: d['peso_entrada']?.toString() ?? '');
    _pesoSalidaCtrl =
        TextEditingController(text: d['peso_salida']?.toString() ?? '');
    _pesoNetoCtrl = TextEditingController(text: d['peso_neto']?.toString() ?? '');
  }

  @override
  void dispose() {
    _folioCtrl.dispose();
    _operadorCtrl.dispose();
    _productoCtrl.dispose();
    _pesoEntradaCtrl.dispose();
    _pesoSalidaCtrl.dispose();
    _pesoNetoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final folio = _folioCtrl.text.trim();
    final operador = _operadorCtrl.text.trim();
    final producto = _productoCtrl.text.trim();
    final pesoEntrada = double.tryParse(_pesoEntradaCtrl.text.trim()) ?? 0;
    final pesoSalida = double.tryParse(_pesoSalidaCtrl.text.trim()) ?? 0;
    final pesoNeto = double.tryParse(_pesoNetoCtrl.text.trim()) ?? 0;

    if (folio.isEmpty || operador.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folio y operador son obligatorios.')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      await FirebaseFirestore.instance
          .collection('registros_toneladas')
          .doc(widget.docId)
          .set({
        'folio': folio,
        'operador': operador,
        'producto': producto,
        'peso_entrada': pesoEntrada,
        'peso_salida': pesoSalida,
        'peso_neto': pesoNeto,
        'admin_editado_en': FieldValue.serverTimestamp(),
        'admin_editado': true,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro actualizado.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Editar registro',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(controller: _folioCtrl, decoration: const InputDecoration(labelText: 'Folio')),
            const SizedBox(height: 8),
            TextField(controller: _operadorCtrl, decoration: const InputDecoration(labelText: 'Operador')),
            const SizedBox(height: 8),
            TextField(controller: _productoCtrl, decoration: const InputDecoration(labelText: 'Producto')),
            const SizedBox(height: 8),
            TextField(controller: _pesoEntradaCtrl, decoration: const InputDecoration(labelText: 'Peso Entrada'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: _pesoSalidaCtrl, decoration: const InputDecoration(labelText: 'Peso Salida'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: _pesoNetoCtrl, decoration: const InputDecoration(labelText: 'Peso Neto'), keyboardType: TextInputType.number),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
                  label: Text(_guardando ? 'Guardando' : 'Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReporteToneladasAdminScreenState
    extends State<ReporteToneladasAdminScreen> {
  String filtroTiempo = 'Todos';
  String? operadorSeleccionado = 'Todos';
  List<String> listaOperadores = ['Todos'];
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _exportando = false;

  static const Color _bluePrimary = Color(0xFF1D4ED8);
  static const Color _blueSecondary = Color(0xFF2563EB);
  static const Color _bgColor = Color(0xFFF1F6FF);

  DateTime _soloFecha(DateTime fecha) {
    return DateTime(fecha.year, fecha.month, fecha.day);
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return '--/--/----';
    return DateFormat('dd/MM/yyyy').format(fecha);
  }

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
      final base = Platform.environment['USERPROFILE'] ?? Directory.current.path;
      return Directory('$base\Downloads');
    }

    final base = Platform.environment['HOME'] ?? Directory.current.path;
    return Directory('$base/Downloads');
  }

  String _valorTexto(dynamic value) {
    if (value == null) return '';
    return value.toString();
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
      if (hojaBase != 'Toneladas') {
        excel.rename(hojaBase, 'Toneladas');
      }
      final sheet = excel['Toneladas'];

      final otrasHojas = excel.tables.keys.where((name) => name != 'Toneladas').toList();
      for (final hoja in otrasHojas) {
        excel.delete(hoja);
      }

      sheet.appendRow([
        ex.TextCellValue('FECHA'),
        ex.TextCellValue('FOLIO'),
        ex.TextCellValue('OPERADOR'),
        ex.TextCellValue('PRODUCTO'),
        ex.TextCellValue('NETO (KG)'),
      ]);

      for (final doc in docs) {
        final data = doc.data();
        sheet.appendRow([
          ex.TextCellValue(_valorTexto(data['fecha_texto'])),
          ex.TextCellValue(_valorTexto(data['folio'])),
          ex.TextCellValue(_valorTexto(data['operador'])),
          ex.TextCellValue(_valorTexto(data['producto'])),
          ex.TextCellValue(NumberFormat('#,###').format(data['peso_neto'] ?? 0)),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('No se pudo generar el archivo.');
      final excelBytes = bytes is List<int> ? bytes : List<int>.from(bytes);

      final nombre =
          'reporte_toneladas_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

      final esEscritorio =
          !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

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

      final dir = esEscritorio ? _directorioDescargasEscritorio() : Directory.systemTemp;

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
        ], text: 'Reporte de toneladas');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _exportando = false);
      }
    }
  }

  Future<void> _seleccionarFecha({required bool esInicio}) async {
    final ahora = DateTime.now();
    final fechaInicial = esInicio
        ? (_fechaInicio ?? _fechaFin ?? ahora)
        : (_fechaFin ?? _fechaInicio ?? ahora);
    final primeraFecha = esInicio
        ? DateTime(2020)
        : (_fechaInicio != null ? _soloFecha(_fechaInicio!) : DateTime(2020));
    final ultimaFecha = esInicio
        ? (_fechaFin != null ? _soloFecha(_fechaFin!) : ahora)
        : ahora;

    final picked = await showDatePicker(
      context: context,
      initialDate: _soloFecha(fechaInicial),
      firstDate: primeraFecha,
      lastDate: ultimaFecha,
      locale: const Locale('es', 'MX'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _bluePrimary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: _bluePrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;

    setState(() {
      if (esInicio) {
        _fechaInicio = _soloFecha(picked);
        if (_fechaFin != null && _fechaFin!.isBefore(_fechaInicio!)) {
          _fechaFin = null;
        }
      } else {
        _fechaFin = _soloFecha(picked);
      }
    });
  }

  void _limpiarRangoFechas() {
    setState(() {
      _fechaInicio = null;
      _fechaFin = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _cargarOperadores();
  }

  // 1. CARGAR OPERADORES DESDE LA BASE DE DATOS
  Future<void> _cargarOperadores() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('registros_toneladas')
          .get();
      // Extraemos nombres únicos de los registros existentes
      final nombres = snapshot.docs
          .map((doc) => doc['operador'].toString())
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList();

      setState(() {
        listaOperadores = ['Todos', ...nombres];
      });
    } catch (e) {
      debugPrint("Error al cargar operadores: $e");
    }
  }

  // 2. LÓGICA DE FILTRADO PARA EL STREAM
  Query _queryFiltrada() {
    Query query = FirebaseFirestore.instance.collection('registros_toneladas');

    // Filtro por nombre
    if (operadorSeleccionado != null && operadorSeleccionado != 'Todos') {
      query = query.where('operador', isEqualTo: operadorSeleccionado);
    }

    final inicio = _fechaInicio == null ? null : _soloFecha(_fechaInicio!);
    final fin = _fechaFin == null ? null : _soloFecha(_fechaFin!);

    if (inicio != null) {
      query = query.where(
        'fecha_registro',
        isGreaterThanOrEqualTo: inicio,
      );
    }

    if (fin != null) {
      query = query.where(
        'fecha_registro',
        isLessThanOrEqualTo: fin.add(const Duration(days: 1)).subtract(
          const Duration(milliseconds: 1),
        ),
      );
    }

    // Filtro por tiempo
    DateTime ahora = DateTime.now();
    DateTime? fechaLimite;

    if (filtroTiempo == 'Día') {
      fechaLimite = DateTime(ahora.year, ahora.month, ahora.day);
    } else if (filtroTiempo == 'Semana') {
      fechaLimite = ahora.subtract(Duration(days: ahora.weekday - 1));
    } else if (filtroTiempo == 'Mes') {
      fechaLimite = DateTime(ahora.year, ahora.month, 1);
    } else if (filtroTiempo == 'Año') {
      fechaLimite = DateTime(ahora.year, 1, 1);
    }

    if (fechaLimite != null) {
      query = query.where(
        'fecha_registro',
        isGreaterThanOrEqualTo: fechaLimite,
      );
    }

    // Ordenar por fecha (descendente)
    return query.orderBy('fecha_registro', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        toolbarHeight: 74,
        title: const Text(
          'Reporte de Toneladas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _bluePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_bluePrimary, _blueSecondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
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
                    colors: [_bluePrimary, Color(0xFF06B6D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _bluePrimary.withValues(alpha: 0.25),
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
                        Icons.scale_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Panel de Control de Toneladas',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Consulta y genera papeletas administrativas.',
                            style: TextStyle(
                              color: Colors.white,
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Día', 'Semana', 'Mes', 'Año', 'Todos'].map((
                        t,
                      ) {
                        final seleccionado = filtroTiempo == t;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(t),
                            selected: seleccionado,
                            selectedColor: _bluePrimary,
                            backgroundColor: const Color(0xFFEFF6FF),
                            labelStyle: TextStyle(
                              color: seleccionado ? Colors.white : _bluePrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            side: BorderSide(
                              color: _bluePrimary.withValues(alpha: 0.22),
                            ),
                            onSelected: (val) =>
                                setState(() => filtroTiempo = t),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: operadorSeleccionado,
                    decoration: InputDecoration(
                      labelText: 'Filtrar por Operador',
                      prefixIcon: const Icon(Icons.person_rounded),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFBFDBFE)),
                      ),
                    ),
                    items: listaOperadores
                        .map(
                          (op) => DropdownMenuItem(value: op, child: Text(op)),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => operadorSeleccionado = val),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _bluePrimary,
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
                        : () async {
                            try {
                              final snap = await _queryFiltrada().get();
                              final docs = snap.docs
                                  .cast<QueryDocumentSnapshot<
                                      Map<String, dynamic>>>()
                                  .toList();
                              await _exportarExcel(docs);
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
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
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FBFF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Filtro por rango de fechas',
                          style: TextStyle(
                            color: _bluePrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _seleccionarFecha(esInicio: true),
                              icon: const Icon(Icons.date_range_rounded),
                              label: Text(
                                'Inicio: ${_formatearFecha(_fechaInicio)}',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _bluePrimary,
                                side: const BorderSide(
                                  color: Color(0xFFBFDBFE),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _seleccionarFecha(esInicio: false),
                              icon: const Icon(Icons.event_available_rounded),
                              label: Text('Fin: ${_formatearFecha(_fechaFin)}'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _bluePrimary,
                                side: const BorderSide(
                                  color: Color(0xFFBFDBFE),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed:
                                  (_fechaInicio != null || _fechaFin != null)
                                  ? _limpiarRangoFechas
                                  : null,
                              icon: const Icon(Icons.cleaning_services_rounded),
                              label: const Text('Limpiar rango'),
                              style: TextButton.styleFrom(
                                foregroundColor: _blueSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (_fechaInicio != null || _fechaFin != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Mostrando registros entre ${_formatearFecha(_fechaInicio)} y ${_formatearFecha(_fechaFin)}.',
                            style: const TextStyle(
                              color: Color(0xFF4B5563),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _queryFiltrada().snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        "Error: ${snapshot.error}\n(Asegurate de tener el indice en Firestore)",
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text("No se encontraron registros."),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.inventory_2_rounded,
                                size: 18,
                                color: _bluePrimary,
                              ),
                              const SizedBox(width: 7),
                              const Text(
                                'Registros filtrados:',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 6),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: Text(
                                  '${docs.length}',
                                  key: ValueKey(docs.length),
                                  style: const TextStyle(
                                    color: _bluePrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  _bluePrimary,
                                ),
                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      'FECHA',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'FOLIO',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'OPERADOR',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'PRODUCTO',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'NETO (KG)',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'PAPELETA',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'EDITAR',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                                rows: docs.map((doc) {
                                      final data = doc.data() as Map<String, dynamic>;
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(data['fecha_texto'] ?? '')),
                                      DataCell(Text(data['folio'] ?? '')),
                                      DataCell(Text(data['operador'] ?? '')),
                                      DataCell(Text(data['producto'] ?? '')),
                                      DataCell(
                                        Text(
                                          NumberFormat(
                                            '#,###',
                                          ).format(data['peso_neto'] ?? 0),
                                        ),
                                      ),
                                      DataCell(
                                        IconButton(
                                          tooltip: 'Generar papeleta PDF',
                                          icon: const Icon(
                                            Icons.picture_as_pdf,
                                            color: Color(0xFFDC2626),
                                          ),
                                          onPressed: () =>
                                              _generarPapeletaPDF(data),
                                        ),
                                      ),
                                          DataCell(
                                            IconButton(
                                              tooltip: 'Editar registro',
                                              icon: const Icon(Icons.edit_rounded),
                                              onPressed: () async {
                                                await showDialog<void>(
                                                  context: context,
                                                  builder: (_) => _EditarRegistroToneladasDialog(
                                                    docId: doc.id,
                                                    datos: data,
                                                  ),
                                                );
                                                // refresh operators list in case name changed
                                                _cargarOperadores();
                                              },
                                            ),
                                          ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- FUNCIÓN DE PDF ESTILO PAPELETA ---
  Future<void> _generarPapeletaPDF(Map<String, dynamic> datos) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Recicladora Guadalajara",
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal,
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "PAPELETA DE ENTRADA",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          "Folio: ${datos['folio']}",
                          style: pw.TextStyle(
                            color: PdfColors.red,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text("Fecha: ${datos['fecha_texto']}"),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1.5),
                pw.SizedBox(height: 20),

                // Datos del transporte
                pw.Text(
                  "DATOS DEL TRANSPORTE",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
                pw.SizedBox(height: 10),
                _filaPDF("CONDUCTOR:", datos['operador']),
                _filaPDF("CAMIÓN:", datos['camion']),
                _filaPDF("PLACAS:", datos['placas']),
                _filaPDF("PRODUCTO:", datos['producto']),

                pw.SizedBox(height: 30),

                // Pesos
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                  ),
                  child: pw.Column(
                    children: [
                      _filaPeso("PESO ENTRADA:", "${datos['peso_entrada']} Kg"),
                      _filaPeso("PESO SALIDA:", "${datos['peso_salida']} Kg"),
                      pw.Divider(),
                      _filaPeso(
                        "TOTAL NETO:",
                        "${datos['peso_neto']} Kg",
                        resaltar: true,
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Container(width: 200, child: pw.Divider()),
                      pw.Text("FIRMA DE RECEPCIÓN"),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }




  pw.Widget _filaPDF(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
          pw.SizedBox(width: 5),
          pw.Text(valor, style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  pw.Widget _filaPeso(String label, String valor, {bool resaltar = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: resaltar ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: resaltar ? 16 : 12,
            ),
          ),
          pw.Text(
            valor,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: resaltar ? 18 : 12,
              color: resaltar ? PdfColors.red : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
