import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart'; // Opcional, para compartir/descargar

class ListaIncidentesAdmin extends StatefulWidget {
  const ListaIncidentesAdmin({super.key});

  @override
  State<ListaIncidentesAdmin> createState() => _ListaIncidentesAdminState();
}

class _ListaIncidentesAdminState extends State<ListaIncidentesAdmin> {
  static const Color _primary = Color(0xFF0F172A);
  static const Color _accent = Color(0xFF06B6D4);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _bg = Color(0xFFF8FAFC);

  DateTime _fechaSeleccionada = DateTime.now();

  // --- Función para Descargar la Imagen ---
  Future<void> _descargarImagen(BuildContext context, String url) async {
    try {
      // Mostrar aviso de descarga
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iniciando descarga...')),
      );

      final response = await http.get(Uri.parse(url));
      final bytes = response.bodyBytes;

      // Obtener directorio temporal o de descargas
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/reporte_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(path);
      await file.writeAsBytes(bytes);

      // Usamos Share para que el usuario elija guardarla en su galería o archivos
      await Share.shareXFiles([XFile(path)], text: 'Imagen de Reporte Recicladora');
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al descargar: $e')),
      );
    }
  }

  // --- Visor de Foto Mejorado con Opción de Descarga ---
  void _verFoto(BuildContext context, String url) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.download_rounded, color: Colors.white),
                onPressed: () => _descargarImagen(context, url),
                tooltip: 'Descargar imagen',
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const CircularProgressIndicator(color: Colors.white);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inicioDia = DateTime(_fechaSeleccionada.year, _fechaSeleccionada.month, _fechaSeleccionada.day);
    final finDia = inicioDia.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Panel de Administración', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSelectorFecha(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reportes')
                  .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
                  .where('fecha', isLessThan: Timestamp.fromDate(finDia))
                  .orderBy('fecha', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('No hay reportes hoy'));

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final r = docs[index].data() as Map<String, dynamic>;
                    return _buildCompactCard(context, r);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorFecha() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('EEEE, d MMMM', 'es_ES').format(_fechaSeleccionada).toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, color: _primary),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _fechaSeleccionada,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _fechaSeleccionada = picked);
            },
            icon: const Icon(Icons.calendar_month, size: 18),
            label: const Text('Cambiar'),
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
          )
        ],
      ),
    );
  }

  // --- DISEÑO COMPACTO DE LA TARJETA ---
  Widget _buildCompactCard(BuildContext context, Map<String, dynamic> r) {
    final hora = r['fecha'] != null 
        ? DateFormat('HH:mm').format((r['fecha'] as Timestamp).toDate()) 
        : '--:--';
    
    final tieneFoto = r['fotosUrl'] != null && (r['fotosUrl'] as List).isNotEmpty;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: _danger.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(hora, style: const TextStyle(color: _danger, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r['operador'] ?? 'Operador',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Text('Camión: ${r['camion'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            const Divider(height: 20),
            Text(
              r['mensaje'] ?? 'Sin descripción',
              style: const TextStyle(fontSize: 14, color: _primary),
            ),
            const SizedBox(height: 10),
            if (tieneFoto)
              OutlinedButton.icon(
                onPressed: () => _verFoto(context, r['fotosUrl'][0]),
                icon: const Icon(Icons.image_search_rounded, size: 18),
                label: const Text('VER FOTO DEL REPORTE'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )
            else
              const Text('Sin evidencia fotográfica', style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}