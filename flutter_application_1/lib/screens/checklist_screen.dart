import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'jornada_screen.dart';
import 'widgets_conexion/connection_wrapper.dart';

class ChecklistScreen extends StatefulWidget {
  final String nombreUsuario;
  final String camionId;
  final String camion;
  final String placas;

  const ChecklistScreen({
    super.key,
    required this.nombreUsuario,
    required this.camionId,
    required this.camion,
    required this.placas,
  });

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  bool? cubrebocas, gafas, guantes, uniforme;
  final TextEditingController reporteController = TextEditingController();

  Future<void> guardarChecklist() async {
    if (cubrebocas == null ||
        gafas == null ||
        guantes == null ||
        uniforme == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("¡Faltan accesorios por marcar!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    DateTime ahora = DateTime.now();
    bool faltaAlgo =
        cubrebocas == false ||
        gafas == false ||
        guantes == false ||
        uniforme == false;

    if (faltaAlgo && reporteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Explica por qué te falta equipo."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final camionDoc = FirebaseFirestore.instance
          .collection("camiones")
          .doc(widget.camionId);

      await FirebaseFirestore.instance.collection("checklist").add({
        "operador": widget.nombreUsuario,
        "camion": widget.camion,
        "placas": widget.placas,
        "cubrebocas": cubrebocas,
        "gafas": gafas,
        "guantes": guantes,
        "uniforme": uniforme,
        "reporte": reporteController.text,
        "fecha": ahora,
        "equipo_completo": !faltaAlgo,
      });

      await camionDoc.update({
        "ocupado": true,
        "operador": widget.nombreUsuario,
      });
      await FirebaseFirestore.instance
          .collection("usuarios")
          .doc(widget.nombreUsuario)
          .set({
            "nombre": widget.nombreUsuario,
            "jornada_activa": true,
            "camion_id": widget.camionId,
            "camion_actual": widget.camion,
            "placas_actuales": widget.placas,
          }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => JornadaScreen(
            operador: widget.nombreUsuario,
            camion: widget.camion,
            placas: widget.placas,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool faltaAlgo =
        cubrebocas == false ||
        gafas == false ||
        guantes == false ||
        uniforme == false;

    return ConnectionWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(
          title: const Text(
            "Revisión de Uniforme",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        body: Column(
          children: [
            // Panel Superior: Información del Camión
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A8A),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    widget.camion.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Placas: ${widget.placas}",
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    const Text(
                      "Selecciona tu equipo actual:",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Grid de Accesorios (Ocupa el centro sin scroll)
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.4,
                        children: [
                          _buildGridItem(
                            "Cubrebocas",
                            Icons.masks_rounded,
                            cubrebocas,
                            (val) => setState(() => cubrebocas = val),
                          ),
                          _buildGridItem(
                            "Gafas",
                            Icons.visibility,
                            gafas,
                            (val) => setState(() => gafas = val),
                          ),
                          _buildGridItem(
                            "Guantes",
                            Icons.pan_tool,
                            guantes,
                            (val) => setState(() => guantes = val),
                          ),
                          _buildGridItem(
                            "Uniforme",
                            Icons.checkroom,
                            uniforme,
                            (val) => setState(() => uniforme = val),
                          ),
                        ],
                      ),
                    ),

                    // Área de Reporte (Solo si falta algo)
                    if (faltaAlgo) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: reporteController,
                        decoration: InputDecoration(
                          hintText: "Razón del equipo faltante...",
                          prefixIcon: const Icon(Icons.edit, color: Colors.red),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(15),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Botón de Acción Grande
                    SizedBox(
                      width: double.infinity,
                      height: 65,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: faltaAlgo
                              ? Colors.orange[800]
                              : const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 5,
                        ),
                        onPressed: guardarChecklist,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              faltaAlgo ? Icons.warning : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              faltaAlgo
                                  ? "CONFIRMAR FALTANTES"
                                  : "INICIAR JORNADA",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Item del Grid más visual y céntrico
  Widget _buildGridItem(
    String title,
    IconData icon,
    bool? state,
    Function(bool) onSelect,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 28,
            color: state == null
                ? Colors.grey
                : (state ? Colors.green : Colors.red),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _choiceBtn(Icons.close, false, state == false, onSelect),
              const SizedBox(width: 15),
              _choiceBtn(Icons.done, true, state == true, onSelect),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choiceBtn(
    IconData icon,
    bool value,
    bool isSelected,
    Function(bool) onSelect,
  ) {
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected
              ? (value ? Colors.green : Colors.red)
              : Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : Colors.grey[400],
        ),
      ),
    );
  }
}
