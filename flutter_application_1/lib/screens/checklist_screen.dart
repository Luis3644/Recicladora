import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'jornada_screen.dart';
import 'widgets_conexion/connection_wrapper.dart';

class ChecklistScreen extends StatefulWidget {
  final String nombreUsuario;
  final String camion;
  final String placas;

  const ChecklistScreen({
    super.key,
    required this.nombreUsuario,
    required this.camion,
    required this.placas,
  });

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  // --- VARIABLES DE EQUIPO ---
  // null = no seleccionado, true = tiene, false = no tiene
  bool? casco;
  bool? botas;
  bool? pantalon;
  bool? camisa;
  bool? gafas;
  bool? guantes;

  final TextEditingController reporteController = TextEditingController();

  Future<void> guardarChecklist() async {
    // Validar que TODO haya sido seleccionado (ya sea Sí o No)
    if (casco == null || botas == null || pantalon == null || 
        camisa == null || gafas == null || guantes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, marca todos los accesorios."), backgroundColor: Colors.red),
      );
      return;
    }

    DateTime ahora = DateTime.now();
    bool faltaAlgo = casco == false || botas == false || pantalon == false || 
                     camisa == false || gafas == false || guantes == false;

    // Validación de reporte obligatorio si marcó alguna "X"
    if (faltaAlgo && reporteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debes reportar por qué te falta equipo."), 
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection("camiones")
          .where("tipo", isEqualTo: widget.camion)
          .get();
          
      if (snapshot.docs.isEmpty) return;
      var camionDoc = snapshot.docs.first;

      await FirebaseFirestore.instance.collection("checklist").add({
        "operador": widget.nombreUsuario,
        "camion": widget.camion,
        "placas": widget.placas,
        "casco": casco,
        "botas": botas,
        "pantalon": pantalon,
        "camisa": camisa,
        "gafas": gafas,
        "guantes": guantes,
        "reporte": reporteController.text,
        "fecha": ahora,
        "equipo_completo": !faltaAlgo,
      });

      await camionDoc.reference.update({"ocupado": true, "operador": widget.nombreUsuario});
      await FirebaseFirestore.instance.collection("usuarios").doc(widget.nombreUsuario).set({
        "jornada_activa": true,
        "camion_actual": widget.camion,
        "placas_actuales": widget.placas,
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => JornadaScreen(operador: widget.nombreUsuario, camion: widget.camion, placas: widget.placas))
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Variable lógica para mostrar u ocultar el campo de reporte
    bool faltaAlgo = casco == false || botas == false || pantalon == false || 
                     camisa == false || gafas == false || guantes == false;

    return ConnectionWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Revisión de Uniforme"),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              // --- ÁREA VISUAL ---
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      const Text("Referencia de Equipo", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 200,
                        child: Image.asset('assets/imagenes/equipo/base.png', fit: BoxFit.contain),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- LISTA DE ACCESORIOS CON BOTONES ---
              const Text("¿Cuentas con el siguiente equipo?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              _buildSelectorItem("Casco de seguridad", casco, (val) => setState(() => casco = val)),
              _buildSelectorItem("Gafas de protección", gafas, (val) => setState(() => gafas = val)),
              _buildSelectorItem("Camisa de uniforme", camisa, (val) => setState(() => camisa = val)),
              _buildSelectorItem("Guantes de trabajo", guantes, (val) => setState(() => guantes = val)),
              _buildSelectorItem("Pantalón de seguridad", pantalon, (val) => setState(() => pantalon = val)),
              _buildSelectorItem("Botas con casquillo", botas, (val) => setState(() => botas = val)),

              const SizedBox(height: 20),

              // --- CUADRO DE REPORTE (SOLO SE MUESTRA SI FALTA ALGO) ---
              if (faltaAlgo) ...[
                const Text("Reportar Problema", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(
                  controller: reporteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Explica por qué no cuentas con el equipo...",
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.red, width: 2)),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // --- BOTÓN FINAL ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: faltaAlgo ? Colors.orange[800] : Colors.green[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: guardarChecklist,
                  child: Text(
                    faltaAlgo ? "CONFIRMAR CON FALTANTES" : "INICIAR JORNADA", 
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget personalizado para los botones de Sí/No
  Widget _buildSelectorItem(String title, bool? state, Function(bool) onSelect) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
          
          // Botón de X (No tiene)
          IconButton(
            onPressed: () => onSelect(false),
            icon: Icon(Icons.cancel, color: state == false ? Colors.red : Colors.grey[300], size: 30),
          ),
          
          // Botón de Palomita (Sí tiene)
          IconButton(
            onPressed: () => onSelect(true),
            icon: Icon(Icons.check_circle, color: state == true ? Colors.green : Colors.grey[300], size: 30),
          ),
        ],
      ),
    );
  }
}