import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum _FiltroPeriodo { semana, mensual, anual, todos }

class ReporteGasolinaCamionesScreen extends StatefulWidget {
  const ReporteGasolinaCamionesScreen({super.key});

  @override
  State<ReporteGasolinaCamionesScreen> createState() =>
      _ReporteGasolinaCamionesScreenState();
}

class _ReporteGasolinaCamionesScreenState
    extends State<ReporteGasolinaCamionesScreen> {
  _FiltroPeriodo _filtro = _FiltroPeriodo.todos;
  bool _exportando = false;

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
      final sheet = excel['Gasolina'];

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

      final dir = await getTemporaryDirectory();
      final nombre =
          'reporte_gasolina_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File('${dir.path}/$nombre');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Reporte de gasolina de camiones');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Reporte de Gasolina de Camiones',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
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
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _FiltroPeriodo.values.map((f) {
                          final selected = _filtro == f;
                          return ChoiceChip(
                            label: Text(_labelFiltro(f)),
                            selected: selected,
                            onSelected: (_) => setState(() => _filtro = f),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _exportando
                          ? null
                          : () => _exportarExcel(filtrados),
                      icon: _exportando
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(_exportando ? 'Exportando' : 'Excel'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Registros: ${filtrados.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
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
                                  const Color(0xFF1E3A8A),
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
