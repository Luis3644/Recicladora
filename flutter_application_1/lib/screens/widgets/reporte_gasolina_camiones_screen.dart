import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
          ex.TextCellValue((r['folio'] ?? '').toString()),
          ex.TextCellValue((r['concepto'] ?? '').toString().toUpperCase()),
          ex.TextCellValue(
            (r['automovil'] ?? r['camion'] ?? '').toString().toUpperCase(),
          ),
          ex.TextCellValue((r['cantidad'] ?? '').toString()),
          ex.TextCellValue((r['unidad'] ?? '').toString().toUpperCase()),
          ex.TextCellValue((r['monto'] ?? '').toString()),
          ex.TextCellValue((r['metodo_pago'] ?? '').toString().toUpperCase()),
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
                                        Text((r['folio'] ?? '').toString()),
                                      ),
                                      DataCell(
                                        Text(
                                          (r['concepto'] ?? '')
                                              .toString()
                                              .toUpperCase(),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          (r['automovil'] ?? r['camion'] ?? '')
                                              .toString()
                                              .toUpperCase(),
                                        ),
                                      ),
                                      DataCell(
                                        Text((r['cantidad'] ?? '').toString()),
                                      ),
                                      DataCell(
                                        Text(
                                          (r['unidad'] ?? '')
                                              .toString()
                                              .toUpperCase(),
                                        ),
                                      ),
                                      DataCell(
                                        Text((r['monto'] ?? '').toString()),
                                      ),
                                      DataCell(
                                        Text(
                                          (r['metodo_pago'] ?? '')
                                              .toString()
                                              .toUpperCase(),
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
