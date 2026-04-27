import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReporteToneladasAdminScreen extends StatefulWidget {
  const ReporteToneladasAdminScreen({super.key});

  @override
  State<ReporteToneladasAdminScreen> createState() =>
      _ReporteToneladasAdminScreenState();
}

class _ReporteToneladasAdminScreenState
    extends State<ReporteToneladasAdminScreen> {
  String filtroTiempo = 'Todos';
  String? operadorSeleccionado = 'Todos';
  List<String> listaOperadores = ['Todos'];

  static const Color _bluePrimary = Color(0xFF1D4ED8);
  static const Color _blueSecondary = Color(0xFF2563EB);
  static const Color _bgColor = Color(0xFFF1F6FF);

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
                                ],
                                rows: docs.map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
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
