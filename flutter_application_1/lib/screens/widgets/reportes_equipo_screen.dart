import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReportesEquipoScreen extends StatefulWidget {
  const ReportesEquipoScreen({super.key});

  @override
  State<ReportesEquipoScreen> createState() => _ReportesEquipoScreenState();
}

class _ReportesEquipoScreenState extends State<ReportesEquipoScreen> {
  DateTime _fechaSeleccionada = DateTime.now();

  // Función para abrir el calendario
  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? seleccionado = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale("es", "ES"),
    );
    if (seleccionado != null) {
      setState(() {
        _fechaSeleccionada = seleccionado;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text("Reportes de Equipo", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color.fromARGB(255, 76, 94, 175),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _seleccionarFecha(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de fecha seleccionada
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, d MMMM', 'es_ES').format(_fechaSeleccionada).toUpperCase(),
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (DateFormat('yyyyMMdd').format(_fechaSeleccionada) != DateFormat('yyyyMMdd').format(DateTime.now()))
                  TextButton(
                    onPressed: () => setState(() => _fechaSeleccionada = DateTime.now()),
                    child: const Text("VER HOY"),
                  )
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Usamos la misma consulta que YA te funcionaba para evitar errores de índice
              stream: FirebaseFirestore.instance
                  .collection("checklist")
                  .where("equipo_completo", isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Error al cargar datos"));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                // FILTRADO MANUAL POR FECHA (Para evitar el error de carga)
                final todosLosFaltantes = snapshot.data!.docs;
                final filtrados = todosLosFaltantes.where((doc) {
                  Timestamp? t = doc['fecha'] as Timestamp?;
                  if (t == null) return false;
                  DateTime d = t.toDate();
                  return d.year == _fechaSeleccionada.year &&
                         d.month == _fechaSeleccionada.month &&
                         d.day == _fechaSeleccionada.day;
                }).toList();

                if (filtrados.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fact_check, size: 80, color: Colors.grey[300]),
                        const Text("Sin reportes faltantes para este día", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: filtrados.length,
                  itemBuilder: (context, index) {
                    var reporte = filtrados[index].data() as Map<String, dynamic>;
                    return _buildCardBonita(reporte);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBonita(Map<String, dynamic> r) {
    String hora = r['fecha'] != null 
        ? DateFormat('HH:mm').format((r['fecha'] as Timestamp).toDate()) 
        : "--:--";

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        leading: CircleAvatar(
          backgroundColor: Colors.orange[100],
          child: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        ),
        title: Text(r['operador'] ?? "Operador", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("🚛 Camión: ${r['camion']}  •  $hora hrs"),
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("ARTÍCULOS FALTANTES:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    if (r['casco'] == false) _chipError("Casco"),
                    if (r['botas'] == false) _chipError("Botas"),
                    if (r['gafas'] == false) _chipError("Gafas"),
                    if (r['guantes'] == false) _chipError("Guantes"),
                    if (r['pantalon'] == false) _chipError("Pantalón"),
                    if (r['camisa'] == false) _chipError("Camisa"),
                  ],
                ),
                if (r['reporte'] != null && r['reporte'] != "") ...[
                  const Divider(height: 30),
                  const Text("OBSERVACIONES:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                  const SizedBox(height: 5),
                  Text("${r['reporte']}", style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _chipError(String texto) {
    return Chip(
      label: Text(texto, style: const TextStyle(color: Colors.red, fontSize: 11)),
      backgroundColor: Colors.red[50],
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}