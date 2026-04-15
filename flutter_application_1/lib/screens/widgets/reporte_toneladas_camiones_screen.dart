import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReporteToneladasAdminScreen extends StatefulWidget {
  const ReporteToneladasAdminScreen({super.key});

  @override
  State<ReporteToneladasAdminScreen> createState() => _ReporteToneladasAdminScreenState();
}

class _ReporteToneladasAdminScreenState extends State<ReporteToneladasAdminScreen> {
  String filtroTiempo = 'Todos';
  String? operadorSeleccionado = 'Todos';
  List<String> listaOperadores = ['Todos'];

  @override
  void initState() {
    super.initState();
    _cargarOperadores();
  }

  // 1. CARGAR OPERADORES DESDE LA BASE DE DATOS
  Future<void> _cargarOperadores() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('registros_toneladas').get();
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
      query = query.where('fecha_registro', isGreaterThanOrEqualTo: fechaLimite);
    }

    // Ordenar por fecha (descendente)
    return query.orderBy('fecha_registro', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF0F766E);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Panel Administrativo', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- ÁREA DE FILTROS ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Día', 'Semana', 'Mes', 'Año', 'Todos'].map((t) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(t),
                          selected: filtroTiempo == t,
                          selectedColor: primaryGreen,
                          labelStyle: TextStyle(color: filtroTiempo == t ? Colors.white : Colors.black),
                          onSelected: (val) => setState(() => filtroTiempo = t),
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
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: listaOperadores.map((op) => DropdownMenuItem(value: op, child: Text(op))).toList(),
                  onChanged: (val) => setState(() => operadorSeleccionado = val),
                ),
              ],
            ),
          ),

          // --- TABLA DE DATOS ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _queryFiltrada().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}\n(Asegúrate de tener el índice en Firestore)"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text("No se encontraron registros."));
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(const Color(0xFF1E293B)),
                      columns: const [
                        DataColumn(label: Text('FECHA', style: TextStyle(color: Colors.white))),
                        DataColumn(label: Text('FOLIO', style: TextStyle(color: Colors.white))),
                        DataColumn(label: Text('OPERADOR', style: TextStyle(color: Colors.white))),
                        DataColumn(label: Text('PRODUCTO', style: TextStyle(color: Colors.white))),
                        DataColumn(label: Text('NETO (KG)', style: TextStyle(color: Colors.white))),
                        DataColumn(label: Text('PAPELETA', style: TextStyle(color: Colors.white))),
                      ],
                      rows: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DataRow(cells: [
                          DataCell(Text(data['fecha_texto'] ?? '')),
                          DataCell(Text(data['folio'] ?? '')),
                          DataCell(Text(data['operador'] ?? '')),
                          DataCell(Text(data['producto'] ?? '')),
                          DataCell(Text(NumberFormat('#,###').format(data['peso_neto'] ?? 0))),
                          DataCell(IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                            onPressed: () => _generarPapeletaPDF(data),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
                    pw.Text("Recicladora Guadalajara", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("PAPELETA DE ENTRADA", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text("Folio: ${datos['folio']}", style: pw.TextStyle(color: PdfColors.red, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.Text("Fecha: ${datos['fecha_texto']}"),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1.5),
                pw.SizedBox(height: 20),
                
                // Datos del transporte
                pw.Text("DATOS DEL TRANSPORTE", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                pw.SizedBox(height: 10),
                _filaPDF("CONDUCTOR:", datos['operador']),
                _filaPDF("CAMIÓN:", datos['camion']),
                _filaPDF("PLACAS:", datos['placas']),
                _filaPDF("PRODUCTO:", datos['producto']),
                
                pw.SizedBox(height: 30),
                
                // Pesos
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
                  child: pw.Column(
                    children: [
                      _filaPeso("PESO ENTRADA:", "${datos['peso_entrada']} Kg"),
                      _filaPeso("PESO SALIDA:", "${datos['peso_salida']} Kg"),
                      pw.Divider(),
                      _filaPeso("TOTAL NETO:", "${datos['peso_neto']} Kg", resaltar: true),
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
      child: pw.Row(children: [
        pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(width: 5),
        pw.Text(valor, style: const pw.TextStyle(fontSize: 12)),
      ]),
    );
  }

  pw.Widget _filaPeso(String label, String valor, {bool resaltar = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: resaltar ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: resaltar ? 16 : 12)),
          pw.Text(valor, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: resaltar ? 18 : 12, color: resaltar ? PdfColors.red : PdfColors.black)),
        ],
      ),
    );
  }
}