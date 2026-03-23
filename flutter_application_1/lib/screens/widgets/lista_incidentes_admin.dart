import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ListaIncidentesAdmin extends StatefulWidget {
  const ListaIncidentesAdmin({super.key});

  @override
  State<ListaIncidentesAdmin> createState() => _ListaIncidentesAdminState();
}

class _ListaIncidentesAdminState extends State<ListaIncidentesAdmin> {
  DateTime _fechaSeleccionada = DateTime.now();

  // Función para abrir el calendario (Date Picker)
  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? seleccionado = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      // Configuración de idioma
      locale: const Locale("es", "ES"),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color.fromARGB(255, 76, 94, 175), // Azul Admin
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: const Color.fromARGB(255, 76, 94, 175)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (seleccionado != null && seleccionado != _fechaSeleccionada) {
      setState(() {
        _fechaSeleccionada = seleccionado;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Definimos el rango de 24 horas para la consulta en Firebase
    DateTime inicioDia = DateTime(_fechaSeleccionada.year, _fechaSeleccionada.month, _fechaSeleccionada.day);
    DateTime finDia = inicioDia.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB), // Fondo gris azulado muy claro
      appBar: AppBar(
        title: const Text("Incidentes en Ruta", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color.fromARGB(255, 76, 94, 175),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () => _seleccionarFecha(context),
            tooltip: "Filtrar por fecha",
          ),
        ],
      ),
      body: Column(
        children: [
          // Encabezado dinámico de fecha
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_note, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, d MMMM', 'es_ES').format(_fechaSeleccionada).toUpperCase(),
                      style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                // Botón para resetear a hoy si estamos en otra fecha
                if (DateFormat('yyyyMMdd').format(_fechaSeleccionada) != DateFormat('yyyyMMdd').format(DateTime.now()))
                  GestureDetector(
                    onTap: () => setState(() => _fechaSeleccionada = DateTime.now()),
                    child: const Text(
                      "VOLVER A HOY",
                      style: TextStyle(color: Color.fromARGB(255, 76, 94, 175), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  )
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("reportes")
                  .where("fecha", isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
                  .where("fecha", isLessThan: Timestamp.fromDate(finDia))
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Error al conectar con la base de datos"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_turned_in_outlined, size: 70, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        const Text("No hay incidentes registrados para este día", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var r = docs[index].data() as Map<String, dynamic>;
                    return _buildIncidentCard(context, r);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(BuildContext context, Map<String, dynamic> r) {
    String hora = "00:00";
    if (r['fecha'] != null) {
      hora = DateFormat('HH:mm').format((r['fecha'] as Timestamp).toDate());
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera de la tarjeta: Operador y Hora
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(hora, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['operador'] ?? "Operador Desconocido", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("Placas: ${r['placas'] ?? 'N/A'}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(8)),
                  child: Text("🚛 ${r['camion']}", style: TextStyle(color: Colors.blueGrey[700], fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
          
          // Mensaje del incidente
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: Text(
              r['mensaje'] ?? "Sin descripción del problema",
              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
            ),
          ),

          // Foto del incidente si existe
          if (r['fotoUrl'] != null && r['fotoUrl'] != "") ...[
            const SizedBox(height: 15),
            GestureDetector(
              onTap: () => _verFoto(context, r['fotoUrl']),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                child: Image.network(
                  r['fotoUrl'],
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 100,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ] else
            const SizedBox(height: 15),
        ],
      ),
    );
  }

  // Pantalla completa para la foto con zoom
  void _verFoto(BuildContext context, String url) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Cerrar",
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
              Positioned( // CORREGIDO AQUÍ (Antes era Position8)
                top: 40,
                right: 20,
                child: CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}